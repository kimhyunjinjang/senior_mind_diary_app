import 'package:flutter/material.dart';
import '../state/app_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SearchDiaryScreen extends StatefulWidget {
  const SearchDiaryScreen({super.key});

  @override
  State<SearchDiaryScreen> createState() => _SearchDiaryScreenState();
}

class _SearchDiaryScreenState extends State<SearchDiaryScreen> {
  String _keyword = '';

  String? _role;          // 'senior' | 'guardian'
  bool _linked = false;   // 보호자-시니어 연결 여부
  bool _resolving = true;
  bool _clearedOnce = false; // 보호자 미연결 시 1회만 캐시 비우기

  @override
  void initState() {
    super.initState();
    _resolveRoleAndLink();
  }

  Future<void> _resolveRoleAndLink() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() { _role = 'senior'; _linked = false; _resolving = false; });
        return;
      }

      // 내 역할 확인
      final me = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final role = (me.data()?['role'] as String?) ?? 'senior';

      bool linked = false;
      if (role == 'guardian') {
        // 나를 sharedWith로 가진 시니어가 있는지 확인
        final q = await FirebaseFirestore.instance
            .collection('users')
            .where('sharedWith', isEqualTo: uid)
            .limit(1)
            .get();
        linked = q.docs.isNotEmpty;
      }

      if (!mounted) return;
      setState(() {
        _role = role;
        _linked = linked;
        _resolving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _role = 'senior'; _linked = false; _resolving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resolving) {
      return Scaffold(
        appBar: AppBar(title: Text('일기 검색')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isGuardian = _role == 'guardian';
    final blocked = isGuardian && !_linked; // ← 보호자 & 미연결이면 차단

    // 보호자 미연결일 때, 이전 검색 잔상 제거(1회만)
    if (blocked && !_clearedOnce) {
      _clearedOnce = true;
      // 메모리 캐시를 비워 UI 잔상 제거 (다른 화면 영향 최소)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) emotionDataNotifier.value = {};
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('일기 검색')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              enabled: !blocked, // ✅ 보호자 미연결이면 입력 비활성
              decoration: InputDecoration(
                labelText: blocked ? '연결된 시니어가 없습니다' : '검색어를 입력하세요',
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _keyword = value),
            ),
          ),

          Expanded(
            child: blocked
                ? const Center(
                child: Text('연결이 해제되어 검색을 사용할 수 없습니다.',
                    style: TextStyle(fontSize: 16, color: Colors.grey)))
                : ValueListenableBuilder<Map<String, Map<String, String>>>(
              valueListenable: emotionDataNotifier,
              builder: (context, diaryData, _) {
                final filteredEntries = diaryData.entries.where((entry) {
                  final diaryText = entry.value['diary'] ?? '';
                  return _keyword.isEmpty ||
                      diaryText.toLowerCase().contains(_keyword.toLowerCase());
                }).toList();

                if (filteredEntries.isEmpty) {
                  return const Center(
                    child: Text(
                      '일치하는 일기가 없습니다.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredEntries.length,
                  itemBuilder: (context, index) {
                    final date = filteredEntries[index].key;
                    final emotion = filteredEntries[index].value['emotion'] ??
                        '';
                    final diary = filteredEntries[index].value['diary'] ?? '';

                    return ListTile(
                      title: Text('[$date] $emotion'),
                      subtitle: RichText(
                        text: TextSpan(
                          children: _highlightKeyword(diary, _keyword),
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _highlightKeyword(String text, String keyword) {
    if (keyword.isEmpty) return [TextSpan(text: text)];
    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();
    int start = 0;
    int index;

    while ((index = lowerText.indexOf(lowerKeyword, start)) != -1) {
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + keyword.length),
          style: const TextStyle(
            backgroundColor: Colors.yellow,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      start = index + keyword.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
  }
}
