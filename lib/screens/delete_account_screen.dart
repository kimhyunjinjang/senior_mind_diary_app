import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'account_register_screen.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});
  @override State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _pwd = TextEditingController();
  bool _busy = false; String? _msg;
  bool _showPassword = false;

  @override void dispose() { _pwd.dispose(); super.dispose(); }

  Future<void> _deleteAll() async {
    if (_busy) return;
    setState(() { _busy = true; _msg = null; });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final email = user.email!;
      // 1) 최근 로그인 필요 → 비밀번호 재인증
      final cred = EmailAuthProvider.credential(email: email, password: _pwd.text);
      await user.reauthenticateWithCredential(cred);

      final uid = user.uid;
      final fs = FirebaseFirestore.instance;

      // 2) 내가 '보호자'라서 누군가가 sharedWith == 내 uid 인 시니어가 있다면 끊어주기
      final q = await fs.collection('users').where('sharedWith', isEqualTo: uid).get();
      for (final d in q.docs) {
        await d.reference.update({'sharedWith': FieldValue.delete()});
      }

      // 3) 내 일기 전체 삭제(소량 기준; 많으면 반복/백엔드로 이관)
      const page = 400;
      while (true) {
        final batch = fs.batch();
        final snaps = await fs.collection('users').doc(uid).collection('diaries').limit(page).get();
        for (final doc in snaps.docs) { batch.delete(doc.reference); }
        await batch.commit();
        if (snaps.docs.length < page) break;
      }

      // 4) 내 user 문서 삭제
      await fs.collection('users').doc(uid).delete();

      // 5) 계정 삭제
      await user.delete(); // 최근 로그인 안 했으면 requires-recent-login 에러

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,  // 바깥 터치로 닫기 불가
        builder: (ctx) => AlertDialog(
          title: const Text('삭제 완료'),
          content: const Text('계정이 삭제되었습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      // 완전 초기화로 교체
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AccountRegisterScreen()),
            (route) => false,
      );

    } on FirebaseAuthException catch (e) {
      setState(() => _msg = (e.code == 'requires-recent-login')
          ? '보안을 위해 다시 로그인한 뒤 삭제를 시도하세요.'
          : '삭제 실패: ${e.code}');
    } catch (e) {
      setState(() => _msg = '삭제 중 오류: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('계정 삭제')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        children: [
          const Text('계정 삭제하면 다음 항목들이 영구 삭제됩니다.', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('• 이메일 계정\n• 일기\n• 보호자 연결'),
          const SizedBox(height: 16),
          const Text('비밀번호 입력 후 삭제를 진행하세요.'),
          const SizedBox(height: 20),

          TextField(
            controller: _pwd,
            obscureText: !_showPassword,
            decoration: InputDecoration(
                labelText: '비밀번호',
                border: OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: _showPassword ? '비밀번호 숨기기' : '비밀번호 보기',
              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
            ),
          textInputAction: TextInputAction.done,
          // 키보드가 더 덮지 않게 스크롤 여유
            scrollPadding: const EdgeInsets.only(bottom: 120),
            onSubmitted: (_) => _busy ? null : _deleteAll(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _showPassword,
                onChanged: (v) => setState(() => _showPassword = v ?? false),
              ),
              const Text('비밀번호 보이기', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _deleteAll,
              child: _busy ? const CircularProgressIndicator() : const Text('계정 삭제'),
            ),
          ),
          if (_msg != null) ...[
            const SizedBox(height: 8),
            Text(_msg!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }
}
