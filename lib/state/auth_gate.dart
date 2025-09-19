import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../screens/calendar_screen.dart';
import '../screens/account_register_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = authSnap.data;
        if (user == null) {
          return const AccountRegisterScreen(); // 로그인/온보딩 시작
        }

        // 로그인됨 → role을 '서버에서' 확인(캐시 착시 방지)
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users').doc(user.uid)
              .get(const GetOptions(source: Source.server)),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final data = snap.data?.data() ?? {};
            final role = (data['role'] as String?) ?? '';

            if (role.isEmpty) {
              // 역할 미설정 사용자만 역할 선택으로
              return const AccountRegisterScreen();
            }

            // 역할 확정 → 메인(보호자/시니어 공용 달력)
            return const CalendarScreen();
          },
        );
      },
    );
  }
}
