import 'package:flutter/material.dart';

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