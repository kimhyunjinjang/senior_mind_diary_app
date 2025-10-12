import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils.dart';
import 'calendar_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

String _gen6() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random.secure();
  return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
}

Future<String> _createCodeFor(String ownerUid) async {
  final code = _gen6();
  final doc = FirebaseFirestore.instance.collection('inviteCodes').doc(code);
  try {
    await doc.set({
      'ownerUid': ownerUid,
      'createdAt': FieldValue.serverTimestamp(),
      'used': false,
      // 유효기간 24시간
      'expiresAt': DateTime.now().toUtc().add(const Duration(hours: 24)).toIso8601String(),
    }, SetOptions(merge: false));
    return code;
  } on FirebaseException {
    final alt = _gen6();
    await FirebaseFirestore.instance.collection('inviteCodes').doc(alt).set({
      'ownerUid': ownerUid,
      'createdAt': FieldValue.serverTimestamp(),
      'used': false,
      'expiresAt': DateTime.now().toUtc().add(const Duration(hours: 24)).toIso8601String(),
    });
    return alt;
  }
}

class MyInviteCodeScreen extends StatefulWidget {
  const MyInviteCodeScreen({super.key});

  @override
  State<MyInviteCodeScreen> createState() => _MyInviteCodeScreenState();
}

class _MyInviteCodeScreenState extends State<MyInviteCodeScreen> {
  String _code = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (!mounted || uid.isEmpty) { setState(() => _loading = false); return; }

      // ✅ 이미 공유 중이면: 토스트 후 캘린더로 리셋 (네 기존 원웨이 정책 유지)
      try {
        final me = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final linked = (me.data()?['sharedWith'] as String?)?.isNotEmpty == true;
        if (linked && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미 공유 중입니다.')));
          navigateReset(context, const CalendarScreen());
          return;
        }
      } catch (_) {}

      final c = await _createCodeFor(uid);
      if (!mounted) return;
      setState(() { _code = c; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('공유 등록'),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('아래 6자리 코드를 보호자에게 전달하세요', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SelectableText(
                        _code.isEmpty ? '생성 실패' : _code,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 2),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _code.isEmpty ? null : () async {
                      await Clipboard.setData(ClipboardData(text: _code));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('코드가 복사되었습니다.')));
                    },
                    style: ElevatedButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero, // ✅ 직사각형!
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    child: const Text('복사'),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => navigateReset(context, const CalendarScreen()),
                  child: const Text('완료'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}