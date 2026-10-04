import '../../../core/constants/subject_catalog.dart';
import '../../study/domain/models/study_models.dart';
import '../../tasks/domain/models/task_state.dart';

/// Khoảng thời gian tổng hợp tiến độ.
enum ProgressRange { day, week, month }

/// Một mốc bắt đầu/kết thúc nửa mở `[start, end)`.
///
/// Dùng nửa mở thay vì đóng để không đếm trùng phiên đúng 00:00 — lỗi kinh điển
/// khiến một phiên nằm ở cả ngày hôm trước lẫn hôm sau.
class ProgressWindow {
  final DateTime start;
  final DateTime end;
  const ProgressWindow(this.start, this.end);

  bool contains(DateTime at) => !at.isBefore(start) && at.isBefore(end);
}

/// Tiến độ một ngày.
class DayProgress {
  final DateTime day;
  final int studyMinutes;
  final int tasksTotal;
  final int tasksCompleted;

  const DayProgress({
    required this.day,
    required this.studyMinutes,
    required this.tasksTotal,
    required this.tasksCompleted,
  });

  double get completionRate =>
      tasksTotal == 0 ? 0 : (tasksCompleted / tasksTotal).clamp(0.0, 1.0);

  int get remaining => (tasksTotal - tasksCompleted).clamp(0, tasksTotal);
}

/// Tiến độ một tuần lịch (Thứ 2 → Chủ nhật).
class WeekProgress {
  final DateTime weekStart;

  /// Phút học mỗi ngày, index 0 = T2 … 6 = CN.
  final List<int> dailyMinutes;

  final int tasksTotal;
  final int tasksCompleted;

  const WeekProgress({
    required this.weekStart,
    required this.dailyMinutes,
    required this.tasksTotal,
    required this.tasksCompleted,
  });

  int get totalMinutes => dailyMinutes.fold(0, (a, b) => a + b);
  double get totalHours => totalMinutes / 60.0;
  double get avgDailyMinutes => totalMinutes / 7.0;

  double get completionRate =>
      tasksTotal == 0 ? 0 : (tasksCompleted / tasksTotal).clamp(0.0, 1.0);
}

/// Tiến độ một môn học.
/// Xu hướng học của một môn so với kỳ liền trước.
enum SubjectTrend { up, flat, down }

class SubjectProgress {
  final String subject;
  final int minutes;
  final int sessionCount;
  final int tasksTotal;
  final int tasksCompleted;

  /// Điểm hiểu bài trung bình 1–5; `null` khi chưa phiên nào được chấm.
  final double? avgUnderstanding;

  /// Lần học gần nhất; `null` nếu chỉ có nhiệm vụ, chưa có phiên.
  final DateTime? lastStudied;

  /// Phút học môn này ở [lastPeriodMinutes] tuần trước — nền để tính
  /// [trend]. `null` nghĩa là chưa đủ dữ liệu so sánh.
  final int? lastPeriodMinutes;

  const SubjectProgress({
    required this.subject,
    required this.minutes,
    required this.sessionCount,
    required this.tasksTotal,
    required this.tasksCompleted,
    required this.avgUnderstanding,
    required this.lastStudied,
    this.lastPeriodMinutes,
  });

  /// Xu hướng học của môn (đặc tả 5.12: `Toán ↑`, `Vật lý →`).
  ///
  /// `null` = chưa đủ dữ liệu ở cả hai kỳ so sánh — đặc tả yêu cầu "Trends
  /// are not presented when insufficient data exists" (FE-5.2), nên tuyệt đối
  /// không đoán.
  SubjectTrend? get trend {
    final previous = lastPeriodMinutes;
    if (previous == null || previous == 0 || sessionCount == 0) return null;
    final delta = minutes - previous;
    if (delta > 0) return SubjectTrend.up;
    if (delta < 0) return SubjectTrend.down;
    return SubjectTrend.flat;
  }

  double get hours => minutes / 60.0;

  double get completionRate =>
      tasksTotal == 0 ? 0 : (tasksCompleted / tasksTotal).clamp(0.0, 1.0);
}

/// Bức tranh tiến độ đầy đủ cho màn Tổng quan.
class ProgressSnapshot {
  final DayProgress today;
  final WeekProgress week;

  /// So sánh tuần này với tuần trước (phút).
  final int lastWeekMinutes;

  /// Tiến độ theo môn trong tuần hiện tại, sắp theo thời gian giảm dần.
  final List<SubjectProgress> subjects;

  /// Môn bị bỏ quên: có nhiệm vụ/phiên trong quá khứ nhưng lâu rồi không học.
  final List<SubjectProgress> neglectedSubjects;

  const ProgressSnapshot({
    required this.today,
    required this.week,
    required this.lastWeekMinutes,
    required this.subjects,
    required this.neglectedSubjects,
  });

  int? get weekDeltaPercent {
    if (lastWeekMinutes <= 0) return null;
    return (((week.totalMinutes - lastWeekMinutes) / lastWeekMinutes) * 100)
        .round();
  }

  bool get hasData => week.totalMinutes > 0 || subjects.isNotEmpty;
}

/// BE-5.1 — Bộ tính toán dữ liệu tiến độ.
///
/// Toàn bộ là **hàm thuần** nhận `now` tường minh: kết quả không phụ thuộc đồng
/// hồ hệ thống nên kiểm thử được chuyển giao ngày/tuần/tháng chính xác, và
/// không có nhánh nào âm thầm đọc `DateTime.now()` giữa tính toán.
abstract class ProgressEngine {
  /// 00:00 của ngày chứa [at].
  static DateTime startOfDay(DateTime at) =>
      DateTime(at.year, at.month, at.day);

  /// 00:00 Thứ 2 của tuần chứa [at].
  static DateTime startOfWeek(DateTime at) =>
      startOfDay(at).subtract(Duration(days: at.weekday - 1));

  /// 00:00 ngày đầu tháng chứa [at].
  static DateTime startOfMonth(DateTime at) => DateTime(at.year, at.month);

  /// Cửa sổ nửa mở cho một khoảng.
  static ProgressWindow windowOf(ProgressRange range, DateTime now) {
    switch (range) {
      case ProgressRange.day:
        final s = startOfDay(now);
        return ProgressWindow(s, s.add(const Duration(days: 1)));
      case ProgressRange.week:
        final s = startOfWeek(now);
        return ProgressWindow(s, s.add(const Duration(days: 7)));
      case ProgressRange.month:
        final s = startOfMonth(now);
        return ProgressWindow(s, DateTime(now.year, now.month + 1));
    }
  }

  /// Ngày mà một nhiệm vụ thuộc về: ưu tiên `scheduledAt`, rồi `createdAt`.
  ///
  /// Không dùng `updatedAt` để gán ngày hoàn thành: sửa lại một task cũ sẽ
  /// kéo nó sang hôm nay và làm sai tỉ lệ hoàn thành của ngày.
  static DateTime? _taskDay(TodayTask task) {
    final at = task.scheduledAt ?? task.createdAt;
    return at == null ? null : startOfDay(at);
  }

  /// Phút học thực tế của một ngày.
  static int minutesOn(List<StudySession> sessions, DateTime day) {
    final window = windowOf(ProgressRange.day, day);
    return sessions
        .where((s) => window.contains(s.completedAt))
        .fold(0, (sum, s) => sum + s.actualMinutes);
  }

  /// Tiến độ một ngày: thời gian học + tỉ lệ hoàn thành nhiệm vụ.
  static DayProgress dayProgress(
    List<StudySession> sessions,
    List<TodayTask> tasks,
    DateTime day,
  ) {
    final window = windowOf(ProgressRange.day, day);
    final dayTasks = tasks.where((t) {
      final d = _taskDay(t);
      return d != null && window.contains(d);
    }).toList();
    final completed = dayTasks
        .where((t) => TaskStatus.fromString(t.status).isTerminal)
        .length;

    return DayProgress(
      day: startOfDay(day),
      studyMinutes: minutesOn(sessions, day),
      tasksTotal: dayTasks.length,
      tasksCompleted: completed,
    );
  }

  /// Tiến độ tuần lịch chứa [now].
  static WeekProgress weekProgress(
    List<StudySession> sessions,
    List<TodayTask> tasks,
    DateTime now,
  ) {
    final start = startOfWeek(now);
    final window = ProgressWindow(start, start.add(const Duration(days: 7)));

    final daily = List<int>.filled(7, 0);
    for (final s in sessions) {
      if (!window.contains(s.completedAt)) continue;
      final index = startOfDay(s.completedAt).difference(start).inDays;
      if (index >= 0 && index < 7) daily[index] += s.actualMinutes;
    }

    final weekTasks = tasks.where((t) {
      final d = _taskDay(t);
      return d != null && window.contains(d);
    }).toList();
    final completed = weekTasks
        .where((t) => TaskStatus.fromString(t.status).isTerminal)
        .length;

    return WeekProgress(
      weekStart: start,
      dailyMinutes: daily,
      tasksTotal: weekTasks.length,
      tasksCompleted: completed,
    );
  }

  /// Tiến độ theo môn trong cửa sổ [range] quanh [now].
  static List<SubjectProgress> subjectProgress(
    List<StudySession> sessions,
    List<TodayTask> tasks,
    DateTime now, {
    ProgressRange range = ProgressRange.week,
  }) {
    final window = windowOf(range, now);

    // Gom nhóm sau khi chuẩn hoá để `'Toán'` và `'📐 Toán'` không tách đôi.
    String keyOf(String subject) => AppSubjects.normalize(subject);

    final minutes = <String, int>{};
    final sessionCount = <String, int>{};
    final understandingSum = <String, int>{};
    final understandingCount = <String, int>{};
    final lastStudied = <String, DateTime>{};

    for (final s in sessions) {
      if (!window.contains(s.completedAt)) continue;
      final key = keyOf(s.subject);
      minutes[key] = (minutes[key] ?? 0) + s.actualMinutes;
      sessionCount[key] = (sessionCount[key] ?? 0) + 1;
      final u = s.understanding;
      if (u != null) {
        understandingSum[key] = (understandingSum[key] ?? 0) + u;
        understandingCount[key] = (understandingCount[key] ?? 0) + 1;
      }
      final prev = lastStudied[key];
      if (prev == null || s.completedAt.isAfter(prev)) {
        lastStudied[key] = s.completedAt;
      }
    }

    final tasksTotal = <String, int>{};
    final tasksCompleted = <String, int>{};
    for (final t in tasks) {
      final d = _taskDay(t);
      if (d == null || !window.contains(d)) continue;
      final key = keyOf(t.subject);
      tasksTotal[key] = (tasksTotal[key] ?? 0) + 1;
      if (TaskStatus.fromString(t.status).isTerminal) {
        tasksCompleted[key] = (tasksCompleted[key] ?? 0) + 1;
      }
    }

    // Nền so sánh: cùng khoảng thời gian nhưng lùi 1 tuần (hoặc 1 tháng với
    // range tháng) — chỉ khi kỳ trước có dữ liệu thì mới báo xu hướng.
    final previousWindow = ProgressWindow(
      window.start.subtract(window.end.difference(window.start)),
      window.start,
    );
    final previousMinutes = <String, int>{};
    for (final s in sessions) {
      if (!previousWindow.contains(s.completedAt)) continue;
      final key = keyOf(s.subject);
      previousMinutes[key] = (previousMinutes[key] ?? 0) + s.actualMinutes;
    }

    final keys = {...minutes.keys, ...tasksTotal.keys};
    final result = keys.map((key) {
      final count = understandingCount[key] ?? 0;
      return SubjectProgress(
        subject: key,
        minutes: minutes[key] ?? 0,
        sessionCount: sessionCount[key] ?? 0,
        tasksTotal: tasksTotal[key] ?? 0,
        tasksCompleted: tasksCompleted[key] ?? 0,
        avgUnderstanding: count == 0 ? null : (understandingSum[key]! / count),
        lastStudied: lastStudied[key],
        lastPeriodMinutes: previousMinutes[key],
      );
    }).toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));

    return result;
  }

  /// Môn bị bỏ quên: có dấu vết học trong [lookbackDays] nhưng lần cuối đã
  /// cách đây ≥ [staleDays] ngày. Chỉ xét môn từng được học (có phiên), tránh
  /// báo động cho môn chưa từng bắt đầu.
  static List<SubjectProgress> neglectedSubjects(
    List<StudySession> sessions,
    List<TodayTask> tasks,
    DateTime now, {
    int lookbackDays = 30,
    int staleDays = 7,
  }) {
    final lookbackStart =
        startOfDay(now).subtract(Duration(days: lookbackDays));
    final cutoff = startOfDay(now).subtract(Duration(days: staleDays));

    final bySubject = subjectProgress(
      sessions,
      tasks,
      now,
      range: ProgressRange.month,
    );
    // `subjectProgress` tháng chỉ nhìn 1 tháng; với lookback dài hơn ta tự gom.
    final minutes = <String, int>{};
    final lastSeen = <String, DateTime>{};
    for (final s in sessions) {
      if (s.completedAt.isBefore(lookbackStart)) continue;
      final key = AppSubjects.normalize(s.subject);
      minutes[key] = (minutes[key] ?? 0) + s.actualMinutes;
      final prev = lastSeen[key];
      if (prev == null || s.completedAt.isAfter(prev)) {
        lastSeen[key] = s.completedAt;
      }
    }

    final result = <SubjectProgress>[];
    for (final entry in lastSeen.entries) {
      if (!entry.value.isBefore(cutoff)) continue; // vẫn còn học gần đây
      final stats = bySubject.where((s) => s.subject == entry.key).toList();
      result.add(SubjectProgress(
        subject: entry.key,
        minutes: minutes[entry.key] ?? 0,
        sessionCount: stats.isEmpty ? 0 : stats.first.sessionCount,
        tasksTotal: stats.isEmpty ? 0 : stats.first.tasksTotal,
        tasksCompleted: stats.isEmpty ? 0 : stats.first.tasksCompleted,
        avgUnderstanding: stats.isEmpty ? null : stats.first.avgUnderstanding,
        lastStudied: entry.value,
      ));
    }
    result.sort((a, b) => a.lastStudied!.compareTo(b.lastStudied!));
    return result;
  }

  /// Bức tranh tiến độ đầy đủ.
  static ProgressSnapshot snapshot(
    List<StudySession> sessions,
    List<TodayTask> tasks,
    DateTime now,
  ) {
    final week = weekProgress(sessions, tasks, now);
    final lastWeekStart = week.weekStart.subtract(const Duration(days: 7));
    final lastWeekWindow = ProgressWindow(lastWeekStart, week.weekStart);
    final lastWeekMinutes = sessions
        .where((s) => lastWeekWindow.contains(s.completedAt))
        .fold(0, (sum, s) => sum + s.actualMinutes);

    return ProgressSnapshot(
      today: dayProgress(sessions, tasks, now),
      week: week,
      lastWeekMinutes: lastWeekMinutes,
      subjects: subjectProgress(sessions, tasks, now),
      neglectedSubjects: neglectedSubjects(sessions, tasks, now),
    );
  }
}
