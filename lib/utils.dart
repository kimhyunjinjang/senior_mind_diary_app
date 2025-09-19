import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 스택을 싹 비우고 새 화면으로
void navigateReset(BuildContext context, Widget screen) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => screen),
        (route) => false,
  );
}

/// 일반 push
Future<T?> navigateTo<T>(BuildContext context, Widget screen) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute(builder: (_) => screen),
  );
}

extension ColorAlphaCompat on Color {
  /// 0.0~1.0 알파 값을 받아 모든 Flutter 버전에서 안전하게 동작
  Color withAlphaFraction(double a) {
    final v = a.clamp(0.0, 1.0) as double;
    return withAlpha((v * 255).round()); // deprecated 아님, 광범위 호환
  }
}

String emotionKeyFor(String uid) => 'emotionData:$uid';

Future<Map<String, Map<String, String>>> readEmotionCache(String key) async {
  final prefs = await SharedPreferences.getInstance();
  final s = prefs.getString(key);
  if (s == null) return {};
  final raw = json.decode(s) as Map<String, dynamic>;
  return raw.map((k, v) => MapEntry(k, Map<String, String>.from(v)));
}

Future<void> writeEmotionCache(
    String key,
    Map<String, Map<String, String>> data,
    ) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, json.encode(data));
}

Future<void> ensureUserDocDefaults() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final ref = FirebaseFirestore.instance.collection('users').doc(uid);
  final snap = await ref.get();

  final data = snap.data();
  final hasField = (data != null && data.containsKey('canWriteSelf'));

  if (!hasField) {
    await ref.set({'canWriteSelf': true}, SetOptions(merge: true));
  }
}

/// 회원가입 직후: 무조건 온보딩(역할 선택) 시작 — 뒤로가기 없음
Future<void> startOnboardingAfterSignUp(BuildContext context) async {
  final u = FirebaseAuth.instance.currentUser!;
  await u.reload();
  await u.getIdToken(true);

  await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
    'createdAt': FieldValue.serverTimestamp(),
    'onboardingDone': false,
  }, SetOptions(merge: true));
}

enum PostAuthRoute { calendar, roleSelect, inviteCode }

Future<PostAuthRoute> decidePostAuthRoute() async {
  final u = FirebaseAuth.instance.currentUser!;
  await u.reload();
  await u.getIdToken(true);

  final doc = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
  final data = doc.data() ?? {};
  final role = data['role'] as String?;
  final done = data['onboardingDone'] == true;

  if (done) return PostAuthRoute.calendar;
  if (role == null) return PostAuthRoute.roleSelect;
  if (role == 'guardian') return PostAuthRoute.inviteCode;

  // 시니어인데 done 누락 → 보정
  await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
    'onboardingDone': true,
    'canWriteSelf': true,
  }, SetOptions(merge: true));
  return PostAuthRoute.calendar;
}

// 날짜를 yyyy-MM-dd 형식으로 포맷하는 함수
String formatDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

bool isBeforeToday(DateTime day) {
  final today = DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day); // 오늘 00:00

  final dateOnly = DateTime(day.year, day.month, day.day); // 비교 대상도 00:00

  return dateOnly.isBefore(todayOnly);
}

bool isSameOrBeforeToday(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day); // 오늘 날짜 (00:00:00)

  final localDay = day.toLocal();
  final justDay = DateTime(
      localDay.year, localDay.month, localDay.day); // 선택한 날짜 (00:00:00)

  return !justDay.isAfter(today);
}