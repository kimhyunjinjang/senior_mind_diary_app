import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'calendar_screen.dart';
import '../utils.dart';

class InviteCodeInputScreen extends StatefulWidget {
  const InviteCodeInputScreen({super.key});

  @override
  State<InviteCodeInputScreen> createState() => _InviteCodeInputScreenState();
}

class _InviteCodeInputScreenState extends State<InviteCodeInputScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final input = _codeController.text.trim();
      if (input.isEmpty) {
        setState(() {
          _error = '코드를 입력하세요.';
          _loading = false;
        });
        return;
      }

      final viewerUid = FirebaseAuth.instance.currentUser?.uid;
      if (viewerUid == null || viewerUid.isEmpty) {
        setState(() {
          _error = '로그인 정보가 없습니다.';
          _loading = false;
        });
        return;
      }

      // ✅ 6자리 초대코드(숫자만) 판별
      // 영문+숫자 6자리로 운영하면 정규식을 교체:
      // final isInviteCode = RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(input);
      final isInviteCode = RegExp(r'^[A-Za-z0-9]{6}$').hasMatch(input);

      if (isInviteCode) {
        // === 신규 방식: inviteCodes/{code} 매핑 조회 ===
        final snap = await FirebaseFirestore.instance
            .collection('inviteCodes')
            .doc(input)
            .get();

        if (!snap.exists) {
          setState(() {
            _error = '유효하지 않은 코드입니다.';
            _loading = false;
          });
          return;
        }

        final data = snap.data()!;
        final used = (data['used'] as bool?) ?? false;

        // (선택) 만료 체크
        final expIso = data['expiresAt'] as String?;
        if (expIso != null) {
          final exp = DateTime.tryParse(expIso)?.toUtc();
          if (exp != null && DateTime.now().toUtc().isAfter(exp)) {
            setState(() {
              _error = '코드가 만료되었습니다.';
              _loading = false;
            });
            return;
          }
        }

        if (used) {
          setState(() {
            _error = '이미 사용된 코드입니다.';
            _loading = false;
          });
          return;
        }

        final ownerUid = data['ownerUid'] as String?;
        if (ownerUid == null || ownerUid.isEmpty) {
          setState(() {
            _error = '코드 데이터가 올바르지 않습니다.';
            _loading = false;
          });
          return;
        }

        // 🔒 단일 보호자 운영안: 시니어 문서에 sharedWith = viewerUid 설정
        await FirebaseFirestore.instance
            .collection('users')
            .doc(ownerUid)
            .set({'sharedWith': viewerUid}, SetOptions(merge: true));

        // 재사용 방지 플래그
        await FirebaseFirestore.instance
            .collection('inviteCodes')
            .doc(input)
            .update({
          'used': true,
          'viewerUid': viewerUid,
          'usedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        navigateReset(context, const CalendarScreen());
        return;
      } else {
        // === 레거시 유지: 입력값을 UID로 간주해서 바로 링크 (과거 호환용)
        final ownerUid = input;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(ownerUid)
            .set({'sharedWith': viewerUid}, SetOptions(merge: true));

        if (!mounted) return;
        navigateReset(context, const CalendarScreen());
        return;
      }
    } catch (e) {
      setState(() {
        _error = '오류: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('코드 입력')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Text(
              '시니어가 보낸 초대 코드를 입력하세요.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _verify(), // ✅ 기존 이벤트 명칭 유지
              decoration: InputDecoration(
                hintText: '6자리 코드 또는 UID',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _verify, // ✅ 기존 버튼 핸들러 명칭 유지
                child: _loading
                    ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('연결하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}