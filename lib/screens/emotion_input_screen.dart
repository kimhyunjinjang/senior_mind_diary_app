import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../state/app_state.dart';
import '../utils.dart';
import '../services/emotion_storage.dart';
import '../widgets/emotion_button.dart';

class EmotionInputScreen extends StatefulWidget {
  final DateTime selectedDay;

  const EmotionInputScreen({super.key, required this.selectedDay});

  @override
  State<EmotionInputScreen> createState() => _EmotionInputScreenState();
}

class _EmotionInputScreenState extends State<EmotionInputScreen> {
  final TextEditingController _diaryController = TextEditingController();
  String? _selectedEmotion;

  @override
  void initState() {
    super.initState();
    _loadSavedDiary(); // 일기 내용 불러오기
  }

  Future<void> _loadSavedDiary() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return; // 익명이라도 uid는 있음
    final key = emotionKeyFor(uid);

    final data = await readEmotionCache(key);
    final formattedDate = formatDate(widget.selectedDay);
    final saved = data[formattedDate];
    if (saved != null) {
      setState(() {
        _selectedEmotion = saved['emotion'];
        _diaryController.text = saved['diary'] ?? '';
      });
    }
  }

  void _saveData() async {
    if (_selectedEmotion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('감정을 선택해주세요.')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (uid == null) return;
    final key = emotionKeyFor(uid);

    // 1) 기존 캐시 읽기
    final data = await readEmotionCache(key);

    // 2) 오늘 날짜 데이터 업데이트
    final date = formatDate(widget.selectedDay);
    data[date] = {'emotion': _selectedEmotion!, 'diary': _diaryController.text};

    // 3) 캐시 저장 + UI 반영
    await writeEmotionCache(key, data);
    emotionDataNotifier.value = data;

    // 4) Firestore 저장
    await saveEmotionAndNote(
      date: date,
      emotion: _selectedEmotion!,
      note: _diaryController.text,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('감정과 일기가 저장되었습니다.')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${widget.selectedDay.month}월 ${widget.selectedDay.day}일 감정 입력'),
      ),
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
            TextField(
              controller: _diaryController,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: '오늘 하루를 간단히 기록해보세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveData,
              child: Text('저장하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade400,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}