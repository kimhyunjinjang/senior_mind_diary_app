bool isBeforeToday(DateTime day) {
  final today = DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day); // 오늘 00:00

  final dateOnly = DateTime(day.year, day.month, day.day); // 비교 대상도 00:00

  return dateOnly.isBefore(todayOnly);
}
