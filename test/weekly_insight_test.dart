import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/features/progress/domain/progress_engine.dart';
import 'package:edupulse/features/progress/domain/progress_insights.dart';

/// Đặc tả 5.4 — biểu đồ tuần phải kèm diễn giải và hành động cụ thể.
/// Các hàm dưới đây là phần thuần số liệu (offline), nguồn cho panel dưới biểu đồ.
void main() {
  DayProgress day({int minutes = 0, int total = 0, int done = 0}) =>
      DayProgress(
        day: DateTime(2026, 10, 14),
        studyMinutes: minutes,
        tasksTotal: total,
        tasksCompleted: done,
      );

  WeekProgress week({
    required List<int> daily,
    int tasksTotal = 0,
    int tasksCompleted = 0,
  }) =>
      WeekProgress(
        weekStart: DateTime(2026, 10, 12),
        dailyMinutes: daily,
        tasksTotal: tasksTotal,
        tasksCompleted: tasksCompleted,
      );

  SubjectProgress subject(String name, {int minutes = 0}) => SubjectProgress(
        subject: name,
        minutes: minutes,
        sessionCount: minutes > 0 ? 1 : 0,
        tasksTotal: 0,
        tasksCompleted: 0,
        avgUnderstanding: null,
        lastStudied: minutes > 0 ? DateTime(2026, 10, 10) : null,
      );

  ProgressSnapshot snapshot({
    required WeekProgress w,
    int lastWeekMinutes = 0,
    List<SubjectProgress> subjects = const [],
    List<SubjectProgress> neglected = const [],
  }) =>
      ProgressSnapshot(
        today: day(minutes: 30),
        week: w,
        lastWeekMinutes: lastWeekMinutes,
        subjects: subjects,
        neglectedSubjects: neglected,
      );

  test('tuần trắng → diễn giải + hành động khởi đầu', () {
    final s = snapshot(w: week(daily: List<int>.filled(7, 0)));
    expect(ProgressInsights.weeklyInterpretation(s),
        'Tuần này chưa có phiên học nào.');
    expect(ProgressInsights.weeklyNextStep(s),
        'Bắt đầu một phiên 25 phút hôm nay để có dữ liệu tuần.');
  });

  test('học ít hơn tuần trước → diễn giải nêu mức giảm', () {
    final s = snapshot(
      w: week(daily: [30, 0, 0, 0, 0, 0, 0], tasksTotal: 4, tasksCompleted: 3),
      lastWeekMinutes: 100,
    );
    expect(ProgressInsights.weeklyInterpretation(s), contains('ít hơn'));
    expect(ProgressInsights.weeklyInterpretation(s), contains('%'));
  });

  test('môn bị bỏ quên → bước tiếp theo nhắm đúng môn đó', () {
    final s = snapshot(
      w: week(daily: [60, 0, 0, 0, 0, 0, 0], tasksTotal: 4, tasksCompleted: 4),
      lastWeekMinutes: 30,
      subjects: [subject('Toán', minutes: 60)],
      neglected: [subject('Lý')],
    );
    expect(ProgressInsights.weeklyNextStep(s), contains('Lý'));
    expect(ProgressInsights.weeklyNextStep(s), contains('25 phút'));
  });

  test('tỉ lệ hoàn thành thấp → đề xuất chia nhỏ nhiệm vụ', () {
    final s = snapshot(
      w: week(
          daily: [60, 30, 0, 0, 0, 0, 0], tasksTotal: 10, tasksCompleted: 3),
      lastWeekMinutes: 90,
      subjects: [subject('Toán', minutes: 90)],
    );
    expect(ProgressInsights.weeklyNextStep(s), contains('Chia nhiệm vụ'));
    expect(ProgressInsights.weeklyInterpretation(s), contains('kế hoạch tuần'));
  });

  test(
      'nhịp ổn định (không delta, tỉ lệ cao) → câu động viên + bước thêm phiên',
      () {
    final s = snapshot(
      w: week(
          daily: [30, 30, 30, 0, 0, 0, 0], tasksTotal: 4, tasksCompleted: 4),
      subjects: [subject('Toán', minutes: 90)],
    );
    expect(ProgressInsights.weeklyInterpretation(s), contains('ổn định'));
    expect(ProgressInsights.weeklyNextStep(s), contains('môn khó nhất'));
  });
}
