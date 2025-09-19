import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils.dart';
import 'role_select_screen.dart';
import 'invite_code_input_screen.dart';
import 'calendar_screen.dart';
import 'forgot_password_screen.dart';

class AccountRegisterScreen extends StatefulWidget {
  const AccountRegisterScreen({super.key});

  @override
  State<AccountRegisterScreen> createState() => _AccountRegisterScreenState();
}

class _AccountRegisterScreenState extends State<AccountRegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();
  bool _isLogin = false; // false=회원가입, true=로그인
  bool _busy = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final auth = FirebaseAuth.instance;
      final email = _emailCtrl.text.trim();
      final pw = _pwCtrl.text;
      final pw2 = _pwConfirmCtrl.text;

      if (email.isEmpty || pw.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 입력하세요.')));
        return;
      }

      if (!_isLogin) {
        // ✅ 회원가입 시: 비밀번호 확인 및 최소 길이 체크
        if (pw.length < 6) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('비밀번호는 6자 이상으로 설정하세요.')));
          return;
        }
        if (pw2.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('비밀번호 확인을 입력하세요.')));
          return;
        }
        if (pw != pw2) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')));
          return;
        }
      }

      final current = auth.currentUser;
      final cred = EmailAuthProvider.credential(email: email, password: pw);

      if (_isLogin) {
        // ===== 로그인 플로우 =====
        if (current != null && current.isAnonymous) {
          // 익명 → 기존 계정으로 로그인하려는 경우: 데이터 보존 위해 링크 먼저 시도
          try {
            await current.linkWithCredential(cred);
          } on FirebaseAuthException catch (e) {
            if (e.code == 'credential-already-in-use' ||
                e.code == 'email-already-in-use') {
              // 이미 그 이메일 계정이 존재 → 링크 불가 → 익명 로그아웃 후 정상 로그인
              await auth.signOut();
              await auth.signInWithEmailAndPassword(email: email, password: pw);
            } else {
              rethrow;
            }
          }
        } else {
          // 일반 로그인
          await auth.signInWithEmailAndPassword(email: email, password: pw);
        }

        // 로그인 후 라우팅 (기존 유저의 필드 덮어쓰지 않음!)
        await _routeAfterAuth();
      } else {
        // ===== 회원가입 플로우 =====
        if (current != null && current.isAnonymous) {
          // 익명 → 이메일 계정으로 "전환(링크)" = 가입 + 로그인
          await current.linkWithCredential(cred);
        } else {
          // 익명이 아니면, 혹시 다른 계정 로그인 중이면 안내 후 진행
          if (current != null && !current.isAnonymous) {
            final ok = await showDialog<bool>(
              context: context,
              builder:
                  (ctx) => AlertDialog(
                    title: const Text('다른 계정이 로그인 중'),
                    content: const Text('로그아웃 후 입력한 이메일로 새로 가입할까요?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('진행'),
                      ),
                    ],
                  ),
            );
            if (ok != true) {
              return;
            }
            await auth.signOut();
          }
          await auth.createUserWithEmailAndPassword(email: email, password: pw);
        }

        // 신규 가입자 문서 초기화(신규일 때만 안전하게 merge)
        final uid = auth.currentUser!.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'createdAt': FieldValue.serverTimestamp(),
          'onboardingDone': false, // 신규만 false
          // role은 건드리지 않음(없으면 자연히 null)
        }, SetOptions(merge: true));

        // 가입 직후에는 역할 선택부터
        navigateReset(context, const RoleSelectScreen());
      }
    } on FirebaseAuthException catch (e) {
      String msg = '인증 오류 (${e.code})';
      switch (e.code) {
        case 'email-already-in-use':
          msg = '이미 가입된 이메일입니다. 로그인으로 진행해 주세요.';
          break;
        case 'user-not-found':
          msg = '가입되지 않은 이메일입니다.';
          break;
        case 'wrong-password':
          msg = '비밀번호가 일치하지 않습니다.';
          break;
        case 'invalid-email':
          msg = '이메일 형식이 올바르지 않습니다.';
          break;
        case 'too-many-requests':
          msg = '시도가 많습니다. 잠시 후 다시 시도해 주세요.';
          break;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('문제가 발생했습니다: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _routeAfterAuth() async {
    final auth = FirebaseAuth.instance;
    await auth.currentUser?.reload();
    final uid = auth.currentUser!.uid;

    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snap.data() ?? {};
    final role = data['role']; // 'senior' | 'guardian' | null
    final onboardingDone = (data['onboardingDone'] == true);

    if (role == null || onboardingDone == false) {
      // 역할/온보딩 미완 → 역할 선택
      navigateReset(context, const RoleSelectScreen());
      return;
    }

    // 역할/온보딩 완료 → 메인 화면
    navigateReset(context, const CalendarScreen());
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    VoidCallback? onSubmitted,
    String? helperText,
  }) {
    return TextField(
      controller: controller,
      obscureText: !_showPassword, // ✅ 보이기/숨기기
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperMaxLines: 2,
        suffixIcon: IconButton(
          tooltip: _showPassword ? '비밀번호 숨기기' : '비밀번호 보기',
          icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ),
      ),
      onSubmitted: (_) => onSubmitted?.call(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isLogin ? '로그인' : '계정 등록';
    final cta = _isLogin ? '로그인' : '가입하기';
    final toggleText = _isLogin ? '계정이 없나요? 회원가입' : '이미 계정이 있나요? 로그인';

    // 비밀번호 일치 여부 간단 힌트
    final pw = _pwCtrl.text;
    final pw2 = _pwConfirmCtrl.text;
    final showMatchHint = !_isLogin && pw.isNotEmpty && pw2.isNotEmpty;
    final isMatch = pw == pw2;

    return Scaffold(
      resizeToAvoidBottomInset: true,

      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        children: [
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: '이메일'),
            onSubmitted: (_) {
              if (_isLogin) {
                _onSubmit();
              }
            },
          ),
          const SizedBox(height: 12),

          // ✅ 비밀번호
          _buildPasswordField(
            controller: _pwCtrl,
            label: '비밀번호',
            onSubmitted: _isLogin ? _onSubmit : null,
            helperText: _isLogin ? null : '비밀번호는 6자 이상이어야 합니다.',
          ),
          const SizedBox(height: 12),

          // ✅ 회원가입일 때만 비밀번호 확인 표시
          if (!_isLogin) ...[
            _buildPasswordField(controller: _pwConfirmCtrl, label: '비밀번호 확인'),
            const SizedBox(height: 6),
            // ✅ 실시간 일치 힌트(선택 사항, 최소 변경)
            if (showMatchHint)
              Text(
                isMatch ? '비밀번호가 일치합니다.' : '비밀번호가 일치하지 않습니다.',
                style: TextStyle(
                  fontSize: 13,
                  color: isMatch ? Colors.green : Colors.red,
                ),
              ),
            const SizedBox(height: 6),
          ],

            if (_isLogin)
            // 로그인 모드: 같은 줄에 '보이기'(좌) + '찾기'(우)
              Row(
                children: [
                  // 왼쪽: 체크박스 + 라벨
                  Expanded(
                    child: Row(
                      children: [
                        Checkbox(
                          value: _showPassword,
                          onChanged: (v) => setState(() => _showPassword = v ?? false),
                        ),
                        const Text('비밀번호 보이기', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                  // 오른쪽: 비밀번호 찾기
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _busy
                        ? null
                        : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                      );
                    },
                    child: const Text('비밀번호 찾기', style: TextStyle(fontSize: 14)),
                  ),
                ],
              )
            else
            // 회원가입 모드: 체크박스만
              Row(
                children: [
                  Checkbox(
                    value: _showPassword,
                    onChanged: (v) => setState(() => _showPassword = v ?? false),
                  ),
                  const Text('비밀번호 보이기', style: TextStyle(fontSize: 16)),
                ],
              ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _onSubmit,
              child: Text(cta),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed:
                _busy
                    ? null
                    : () => setState(() {
                      _isLogin = !_isLogin;
                      // 모드 전환 시 확인 필드/메시지 정리
                      _pwConfirmCtrl.clear();
                    }),
            child: Text(toggleText),
          ),
        ],
      ),
    );
  }
}
