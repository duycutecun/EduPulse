import 'models/study_models.dart';

/// Kết quả tổng hợp giờ học của tuần lịch hiện tại (Thứ 2 → Chủ nhật).
class WeeklySummary {
  /// 00:00 sáng Thứ 2 của tuần chứa ngày tham chiếu.
  final DateTime weekStart;

  /// Giờ học theo ngày: index 0 = T2 ... 6 = CN. Chỉ tính tuần lịch này.
  final List<double> dailyHours;

  /// Phân bổ theo môn (chỉ tính log trong tuần, không phải toàn bộ lịch sử).
  final Map<String, double> subjectHours;

  WeeklySummary({
    required this.weekStart,
    required this.dailyHours,
    required this.subjectHours,
  });

  double get totalHours => dailyHours.fold(0.0, (s, v) => s + v);
  double get avgDaily => totalHours / 7;
}

/// Đầu tuần (Thứ 2 00:00) của ngày cho trước.
DateTime weekStartOf(DateTime d) =>
    DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

/// Tổng hợp log học vào tuần lịch (T2–CN) chứa [now].
///
/// Sửa bug cũ: trước đây dùng cửa sổ trượt 7×24h + index theo weekday của log,
/// khiến log cuối tuần trước rơi nhầm vào cột của tuần này. Giờ đây chỉ log
/// nằm trong [weekStart, weekStart + 7 ngày) được tính.
WeeklySummary summarizeWeek(List<StudyLog> logs, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final start = weekStartOf(ref);
  final end = start.add(const Duration(days: 7));

  final daily = List<double>.filled(7, 0.0);
  final subjects = <String, double>{};

  for (final log in logs) {
    if (!log.date.isBefore(start) && log.date.isBefore(end)) {
      daily[log.date.weekday - 1] += log.hours;
      subjects[log.subject] = (subjects[log.subject] ?? 0) + log.hours;
    }
  }

  return WeeklySummary(weekStart: start, dailyHours: daily, subjectHours: subjects);
}

/// Tổng số giờ học trong tuần lịch hiện tại (dùng cho leaderboard weekly_hours).
double weeklyHoursOf(List<StudyLog> logs, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final start = weekStartOf(ref);
  var total = 0.0;
  for (final log in logs) {
    if (!log.date.isBefore(start)) total += log.hours;
  }
  return total;
}
