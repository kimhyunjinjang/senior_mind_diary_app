import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils.dart';
import 'calendar_screen.dart';
import 'invite_code_input_screen.dart';
import 'my_invite_code_screen.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  bool _busy = false;

  Future<void> _setUserDoc(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('로그인이 필요합니다.');
    await FirebaseFirestore.instance.collection('users').doc(uid)
        .set(data, SetOptions(merge: true));
  }

  // ① 공유하지 않고 사용 (= 시니어 개인 사용) → 바로 달력
  Future<void> _useWithoutSharing() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _setUserDoc({
        'role': 'senior',
        'canWriteSelf': true,
        'onboardingDone': true,
      });
      navigateReset(context, const CalendarScreen());
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ② 지금 바로 보호자 초대 → 시니어로 저장 후 초대코드 화면
  Future<void> _inviteNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _setUserDoc({
        'role': 'senior',
        'canWriteSelf': true,
        'onboardingDone': true,
      });
      // 원웨이: 초대코드 화면 먼저 → 거기서 '완료' 시 달력
      navigateReset(context, const MyInviteCodeScreen());
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ③ 보호자 선택 → 코드 입력 화면
  Future<void> _chooseGuardian() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _setUserDoc({
        'role': 'guardian',
        'canWriteSelf': false,
        'onboardingDone': true, // 코드 인증 전까지 미완료
      });
      navigateReset(context, const InviteCodeInputScreen());
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('처리 중 오류가 발생했습니다: $e')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    final txt = const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

    return WillPopScope( // ← 원웨이: 물리 뒤로가기 차단
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('역할 선택'),
          automaticallyImplyLeading: false, // ← 앱바 뒤로가기 제거
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '어떻게 사용하실까요?',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '• "나 혼자 일기 쓰기"는 다른 사람과 공유하지 않고 나만 일기를 씁니다\n'
                        '• "공유하여 일기 쓰기"는 다른 사람에게 초대코드를 보내고 일기를 공유합니다\n'
                        '• "가족 및 지인으로 일기만 읽기"는 초대코드를 받아 연결해 일기를 볼 수 있습니다',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 28),

                  // ① 공유하지 않고 사용
                  ElevatedButton.icon(
                    onPressed: _useWithoutSharing,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: shape,
                      backgroundColor: Colors.indigo.shade500,
                      foregroundColor: Colors.white,
                      textStyle: txt,
                    ),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('나 혼자 일기 쓰기'),
                  ),
                  const SizedBox(height: 12),

                  // ② 지금 바로 보호자 초대
                  OutlinedButton.icon(
                    onPressed: _inviteNow,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: shape,
                      side: BorderSide(color: Colors.indigo.shade400, width: 1.4),
                      foregroundColor: Colors.indigo.shade600,
                      textStyle: txt,
                    ),
                    icon: const Icon(Icons.group_add),
                    label: const Text('공유하며 일기 쓰기'),
                  ),
                  const SizedBox(height: 12),

                  // ③ 보호자
                  OutlinedButton.icon(
                    onPressed: _chooseGuardian,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: shape,
                      side: BorderSide(color: Colors.grey.shade400, width: 1.2),
                      foregroundColor: Colors.black87,
                      textStyle: txt,
                    ),
                    icon: const Icon(Icons.visibility),
                    label: const Text('가족 및 지인으로 일기만 읽기'),
                  ),
                ],
              ),
            ),

            if (_busy)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}