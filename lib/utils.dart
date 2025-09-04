import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';

bool isBeforeToday(DateTime day) {
  final today = DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day); // 오늘 00:00

  final dateOnly = DateTime(day.year, day.month, day.day); // 비교 대상도 00:00

  return dateOnly.isBefore(todayOnly);
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

void goHome(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => CalendarScreen()),
        (route) => false,
  );
}

