import 'study_timeline.dart';

/// Kết quả tổng hợp giờ học của tuần lịch hiện tại (Thứ 2 → Chủ nhật).
class WeeklySummary {
  /// 00:00 sáng Thứ 2 của tuần chứa ngày tham chiếu.
  final DateTime weekStart;

  /// Giờ học theo ngày: index 0 = T2 ... 6 = CN. Chỉ tính tuần lịch này.
  final List<double> dailyHours;

  /// Phân bổ theo môn (chỉ tính dòng nhật ký trong tuần, không phải toàn bộ
  /// lịch sử).
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

/// Tổng hợp nhật ký học vào tuần lịch (T2–CN) chứa [now].
///
/// Sửa bug cũ: trước đây dùng cửa sổ trượt 7×24h + index theo weekday của log,
/// khiến log cuối tuần trước rơi nhầm vào cột của tuần này. Giờ đây chỉ dòng
/// nhật ký nằm trong [weekStart, weekStart + 7 ngày) được tính.
///
/// Nhận **dòng nhật ký đã gộp** ([StudyTimelineEntry]) chứ không nhận `StudyLog`:
/// sau khi bỏ ghi trùng ở vòng Pomodoro, `StudyLog` chỉ còn là ghi chép nhập
/// tay, nên đếm riêng nó sẽ ra tổng giờ học thiếu hẳn phần lớn thời gian thật.
WeeklySummary summarizeWeek(
  List<StudyTimelineEntry> entries, {
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final start = weekStartOf(ref);
  final end = start.add(const Duration(days: 7));

  final daily = List<double>.filled(7, 0.0);
  final subjects = <String, double>{};

  for (final entry in entries) {
    if (!entry.date.isBefore(start) && entry.date.isBefore(end)) {
      daily[entry.date.weekday - 1] += entry.hours;
      final subject = entry.subject.isEmpty ? 'khác' : entry.subject;
      subjects[subject] = (subjects[subject] ?? 0) + entry.hours;
    }
  }

  return WeeklySummary(
    weekStart: start,
    dailyHours: daily,
    subjectHours: subjects,
  );
}

/// Tổng số giờ học trong tuần lịch hiện tại (dùng cho leaderboard weekly_hours).
double weeklyHoursOf(
  List<StudyTimelineEntry> entries, {
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final start = weekStartOf(ref);
  var total = 0.0;
  for (final entry in entries) {
    if (!entry.date.isBefore(start)) total += entry.hours;
  }
  return total;
}
