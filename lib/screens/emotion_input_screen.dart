import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../state/app_state.dart';
import '../utils.dart';
import '../services/emotion_storage.dart';
import '../widgets/emotion_button.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:typed_data';

class EmotionInputScreen extends StatefulWidget {
  final DateTime selectedDay;

  const EmotionInputScreen({super.key, required this.selectedDay});

  @override
  State<EmotionInputScreen> createState() => _EmotionInputScreenState();
}

class _EmotionInputScreenState extends State<EmotionInputScreen> {
  final TextEditingController _diaryController = TextEditingController();
  String? _selectedEmotion;
  bool _loading = true;

  // 여러 장 첨부용 상태
  final List<File> _pickedImages = [];          // 새로 고른 로컬 파일들
  List<String> _existingImageUrls = [];         // 이미 저장돼 있던 URL들
  final Set<int> _removeExistingIdx = {};       // 기존 URL 중 삭제 표시된 인덱스
  bool _uploading = false;
  static const int _maxImages = 3;              // 시니어 UX: 최대 3장 권장

  late final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _loadSavedDiary(); // 일기 내용 불러오기
  }

  @override
  void dispose() {
    _diaryController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedDiary() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return; // 익명이라도 uid는 있음
    final key = emotionKeyFor(uid);

    final data = await readEmotionCache(key);
    final formattedDate = formatDate(widget.selectedDay);
    final saved = data[formattedDate];
    if (saved != null) {
      _selectedEmotion = saved['emotion'] as String?;
      final text = (saved['diary'] as String?) ?? '';

      // 레거시 1장(imageUrl) + 신규 여러 장(imageUrls) 병합
      final single = saved['imageUrl'];
      final multi = saved['imageUrls'];
      _existingImageUrls = [
        if (single is String && single.isNotEmpty) single,
        if (multi is List) ...multi.cast<String>(),
      ];

      _diaryController.value = _diaryController.value.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing: TextRange.empty,
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickFromGallery() async {
    if (_pickedImages.length + _existingImageUrls.length >= _maxImages) {
      _showLimitSnack();
      return;
    }

    final picker = ImagePicker();
    final list = await picker.pickMultiImage(imageQuality: 85);
    if (list.isEmpty) return;

    final canAdd = _maxImages - (_pickedImages.length + _existingImageUrls.length);
    final take = list.take(canAdd);

    setState(() {
      _pickedImages.addAll(take.map((x) => File(x.path)));
    });

    if (list.length > canAdd) _showLimitSnack();
  }

  Future<void> _pickFromCamera() async {
    if (_pickedImages.length + _existingImageUrls.length >= _maxImages) {
      _showLimitSnack();
      return;
    }
    final picker = ImagePicker();
    final one = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (one != null) {
      setState(() => _pickedImages.add(File(one.path)));
    }
  }

  void _showLimitSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('사진은 최대 $_maxImages장까지 첨부할 수 있어요.')),
    );
  }

  void _toggleRemoveExisting(int index) {
    setState(() {
      if (_removeExistingIdx.contains(index)) {
        _removeExistingIdx.remove(index);
      } else {
        _removeExistingIdx.add(index);
      }
    });
  }

  void _removeNewPicked(int index) {
    setState(() => _pickedImages.removeAt(index));
  }

  Future<List<String>> _uploadNewOnes(String uid, String date) async {
    if (_pickedImages.isEmpty) return [];
    setState(() => _uploading = true);

    final uploaded = <String>[];
    try {
      for (int i = 0; i < _pickedImages.length; i++) {
        final file = _pickedImages[i];
        final name = '$date-${DateTime.now().millisecondsSinceEpoch}-$i.jpg';
        final ref = _storage.ref('diary_images/$uid/$name');
        debugPrint('UPLOAD → bucket=${_storage.bucket}, path=${ref.fullPath}');

        try {
          final bytes = await file.readAsBytes(); // putData로 전환(세션 꼬임 회피)
          await ref.putData(
            bytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          final url = await ref.getDownloadURL();
          uploaded.add(url);
          debugPrint('UPLOAD OK → $url');
        } on FirebaseException catch (e, st) {
          debugPrint('UPLOAD FAIL(Firebase) → code=${e.code}, msg=${e.message}');
          debugPrint('UPLOAD FAIL ST → $st');
          rethrow;
        } catch (e, st) {
          debugPrint('UPLOAD FAIL(Other) → $e');
          debugPrint('UPLOAD FAIL ST → $st');
          rethrow;
        }
      }
      return uploaded;
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteRemovedExistingFromStorage() async {
    // 표시된 기존 URL만 실제로 삭제
    for (final idx in _removeExistingIdx) {
      if (idx >= 0 && idx < _existingImageUrls.length) {
        final url = _existingImageUrls[idx];
        try {
          // ★ 중요: 우리가 강제로 지정한 버킷 인스턴스 사용
          final ref = _storage.refFromURL(url);

          // ★ 디버그 로그 (버킷/경로/원본 URL)
          debugPrint('DELETE → bucket=${_storage.bucket}, path=${ref.fullPath}');
          debugPrint('DELETE URL → $url');

          await ref.delete();

          debugPrint('DELETE OK  → ${ref.fullPath}');
        } catch (e) {
          // 에러도 찍어서 원인 파악
          debugPrint('DELETE FAIL → url=$url, error=$e');
          // 이미 삭제되었거나 접근 불가 시 무시
        }
      }
    }
  }

  void _saveData() async {
    if (_selectedEmotion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('감정을 선택해주세요.')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      setState(() => _uploading = true);

      debugPrint('🟢 1. 저장 시작 - UID: $uid');

      final key = emotionKeyFor(uid);
      final Map<String, Map<String, dynamic>> data = await readEmotionCache(key);
      final date = formatDate(widget.selectedDay);

      debugPrint('🟢 2. 새 이미지 업로드 시작 (${_pickedImages.length}장)');
      // 1) 새 이미지 업로드
      final newUrls = await _uploadNewOnes(uid, date);
      debugPrint('🟢 3. 업로드 완료: ${newUrls.length}장');

      // 2) 남길 기존 URL만 필터링
      final keptExisting = <String>[];
      for (int i = 0; i < _existingImageUrls.length; i++) {
        if (!_removeExistingIdx.contains(i)) {
          keptExisting.add(_existingImageUrls[i]);
        }
      }

      // 3) 최종 배열
      final imageUrls = [...keptExisting, ...newUrls];

      debugPrint('🟢 4. 최종 이미지 개수: ${imageUrls.length}장');

      debugPrint('🟢 5. 로컬 캐시 저장 시작');
      // 4) 로컬 캐시 저장
      final entry = <String, dynamic>{
        'emotion': _selectedEmotion!,
        'diary': _diaryController.text,
        if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      };

      data[date] = entry;
      await writeEmotionCache(key, data);
      emotionDataNotifier.value = data;
      debugPrint('🟢 6. 로컬 캐시 저장 완료');

      debugPrint('🟢 7. Firestore 저장 시작');
      // 5) Firestore 저장
      await saveEmotionAndNoteMulti(
        date: date,
        emotion: _selectedEmotion!,
        note: _diaryController.text,
        imageUrls: imageUrls,
      );
      debugPrint('🟢 8. Firestore 저장 완료');

      debugPrint('🟢 9. 삭제 표시된 이미지 제거 시작');
      // 6) Storage에서 삭제 표시된 기존 파일 제거
      await _deleteRemovedExistingFromStorage();
      debugPrint('🟢 10. 모든 작업 완료! ✨');

      if (!mounted) return;

      // ✅ 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('감정과 일기가 저장되었습니다.')),
      );

      Navigator.pop(context);

    } catch (e, stackTrace) {
      // ✅ 에러 처리 추가!
      debugPrint('❌ 저장 실패: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 실패: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  // 사용자 친화적인 에러 메시지
  String _getFriendlyError(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'object-not-found':
          return '이미지 저장소에 문제가 있습니다.';
        case 'unauthorized':
        case 'permission-denied':
          return '저장 권한이 없습니다.';
        case 'canceled':
          return '저장이 취소되었습니다.';
        case 'retry-limit-exceeded':
          return '네트워크가 불안정합니다. 다시 시도해주세요.';
        default:
          return '저장 중 오류가 발생했습니다. (${error.code})';
      }
    }
    return '알 수 없는 오류가 발생했습니다.';
  }

  Widget _buildThumbnails() {
    final tiles = <Widget>[];

    // 기존 URL 목록 (삭제 토글 가능)
    for (int i = 0; i < _existingImageUrls.length; i++) {
      final removed = _removeExistingIdx.contains(i);
      tiles.add(Stack(
        children: [
          Opacity(
            opacity: removed ? 0.4 : 1.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _existingImageUrls[i],
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              icon: Icon(removed ? Icons.undo : Icons.close, size: 18),
              onPressed: () => _toggleRemoveExisting(i),
              tooltip: removed ? '복구' : '삭제',
            ),
          ),
        ],
      ));
    }
    // 새로 고른 로컬 파일 목록 (즉시 제거 가능)
    for (int i = 0; i < _pickedImages.length; i++) {
      tiles.add(Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _pickedImages[i],
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => _removeNewPicked(i),
              tooltip: '삭제',
            ),
          ),
        ],
      ));
    }

    if (tiles.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(spacing: 8, runSpacing: 8, children: tiles);
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${widget.selectedDay.month}월 ${widget.selectedDay.day}일 감정 입력';

    return Scaffold(
      appBar: AppBar(title: Text(dateLabel)),
        body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('오늘 기분은 어땠나요?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                EmotionButton(
                  emoji: '😊',
                  label: '기분 좋음',
                  color: Colors.lightBlue.shade200,
                  onTap: () => setState(() => _selectedEmotion = '기분 좋음'),
                  selected: _selectedEmotion == '기분 좋음',
                ),
                EmotionButton(
                  emoji: '😐',
                  label: '보통',
                  color: const Color(0xFFE6D3B3),
                  onTap: () => setState(() => _selectedEmotion = '보통'),
                  selected: _selectedEmotion == '보통',
                ),
                EmotionButton(
                  emoji: '😞',
                  label: '기분 안 좋음',
                  color: Colors.grey.shade400,
                  onTap: () => setState(() => _selectedEmotion = '기분 안 좋음'),
                  selected: _selectedEmotion == '기분 안 좋음',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ▼ 이미지 컨트롤 + 썸네일
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo),
                  label: const Text('사진 추가'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _pickFromCamera,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('촬영'),
                ),
                const SizedBox(width: 12),
                if (_uploading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildThumbnails(),
            const SizedBox(height: 24),

            TextField(
              controller: _diaryController,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: (_diaryController.text.isEmpty && !_loading)
                    ? '오늘 하루를 간단히 기록해보세요'
                    : null,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _uploading ? null : _saveData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade400,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('저장하기'),
            ),
          ],
        ),
      ),
    );
  }
}