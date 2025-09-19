import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/account_register_screen.dart';
import 'screens/role_select_screen.dart';
import 'screens/invite_code_input_screen.dart';
import 'screens/calendar_screen.dart';

class EntryRouter extends StatelessWidget {
  const EntryRouter({super.key});

  bool _linked(dynamic sw) => sw is String ? sw.isNotEmpty : (sw is List && sw.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, auth) {
        if (!auth.hasData) return const AccountRegisterScreen(); // 미로그인 → 계정 등록 시작

        final uid = auth.data!.uid;
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final data = snap.data?.data() ?? {};
            final role = data['role'] as String?;
            final done = data['onboardingDone'] == true;

            if (done) return const CalendarScreen();              // 온보딩 완료 → 메인
            if (role == null) return const RoleSelectScreen();    // 역할 미선택 → 역할
            if (role == 'guardian' && !_linked(data['sharedWith'])) {
              return const InviteCodeInputScreen();               // 보호자 미연결 → 코드 입력
            }
            return const RoleSelectScreen(); // 시니어 미완료 등 → 역할로 유도
          },
        );
      },
    );
  }
}
