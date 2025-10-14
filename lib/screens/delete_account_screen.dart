import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'account_register_screen.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _pwd = TextEditingController();
  bool _busy = false;
  String? _msg;
  bool _showPassword = false;
  String _statusText = '';

  @override
  void dispose() {
    _pwd.dispose();
    super.dispose();
  }

  Future<void> _deleteAll() async {
    if (_busy) return;

    // 비밀번호 입력 확인
    if (_pwd.text.trim().isEmpty) {
      setState(() => _msg = '비밀번호를 입력하세요.');
      return;
    }

    setState(() {
      _busy = true;
      _msg = null;
      _statusText = '삭제를 시작합니다...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final email = user.email!;
      final uid = user.uid;
      final fs = FirebaseFirestore.instance;

      // 1) 비밀번호 재인증 (보안 필수!)
      setState(() => _statusText = '본인 확인 중...');
      final cred = EmailAuthProvider.credential(email: email, password: _pwd.text);
      await user.reauthenticateWithCredential(cred);

      // 2) 보호자 연결 해제
      setState(() => _statusText = '보호자 연결 해제 중...');
      final q = await fs.collection('users').where('sharedWith', isEqualTo: uid).get();
      for (final d in q.docs) {
        await d.reference.update({'sharedWith': FieldValue.delete()});
      }

      // 3) Cloud Functions 호출 - 서버에서 무거운 작업 처리
      setState(() => _statusText = '서버에서 데이터 삭제 중...\n잠시만 기다려주세요.');

      try {
        final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
        final callable = functions.httpsCallable('deleteUserAccount');

        await callable.call();
      } catch (functionsError) {
        // Functions 에러 발생 시 - 로컬에서 삭제 시도
        print('Functions 에러, 로컬 삭제로 전환: $functionsError');

        // 로컬 삭제 (기존 방식)
        setState(() => _statusText = '일기 삭제 중...');
        const page = 400;
        while (true) {
          final batch = fs.batch();
          final snaps = await fs.collection('users').doc(uid)
              .collection('diaries').limit(page).get();
          for (final doc in snaps.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
          if (snaps.docs.length < page) break;
        }

        // 사용자 문서 삭제
        setState(() => _statusText = '사용자 정보 삭제 중...');
        await fs.collection('users').doc(uid).delete();

        // 계정 삭제
        setState(() => _statusText = '계정 삭제 중...');
        await user.delete();
      }

      if (!mounted) return;

      // 완료 다이얼로그
      await showDialog(
        context: context,
        barrierDismissible: false,
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

      // 회원가입 화면으로 이동
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AccountRegisterScreen()),
            (route) => false,
      );

    } on FirebaseAuthException catch (e) {
      String errorMsg;

      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'invalid-email') {
        errorMsg = '비밀번호가 올바르지 않습니다.\n다시 확인해주세요.';
      } else if (e.code == 'requires-recent-login') {
        errorMsg = '보안을 위해 다시 로그인한 뒤\n삭제를 시도하세요.';
      } else if (e.code == 'too-many-requests') {
        errorMsg = '너무 많이 시도하셨습니다.\n잠시 후 다시 시도해주세요.';
      } else if (e.code == 'network-request-failed') {
        errorMsg = '인터넷 연결을 확인해주세요.';
      } else {
        errorMsg = '삭제에 실패했습니다.\n다시 시도해주세요.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg,
              style: const TextStyle(fontSize: 18),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _msg = '삭제 중 오류가 발생했습니다.\n다시 시도해주세요.');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '삭제 중 오류가 발생했습니다.\n다시 시도해주세요.',
              style: TextStyle(fontSize: 18),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
          const Text(
              '계정 삭제하면 다음 항목들이 영구 삭제됩니다.',
              style: TextStyle(fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 8),
          const Text('• 이메일 계정\n• 일기\n• 보호자 연결'),
          const SizedBox(height: 16),
          const Text('비밀번호 입력 후 삭제를 진행하세요.'),
          const SizedBox(height: 20),

          // 진행 중이 아닐 때만 입력 필드 표시
          if (!_busy) ...[
            TextField(
              controller: _pwd,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: '비밀번호',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _showPassword ? '비밀번호 숨기기' : '비밀번호 보기',
                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
              textInputAction: TextInputAction.done,
              scrollPadding: const EdgeInsets.only(bottom: 120),
              onSubmitted: (_) => _deleteAll(),
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
                onPressed: _deleteAll,
                child: const Text('계정 삭제'),
              ),
            ),
          ] else ...[
            // 진행 중 표시
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '앱을 종료하지 마세요',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_msg != null) ...[
            const SizedBox(height: 8),
            Text(_msg!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }
}