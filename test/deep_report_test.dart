import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/features/progress/domain/deep_report.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';

void main() {
  MockScore score({
    String id = 'x',
    String subject = 'Toán',
    String? topic,
    required double value,
    DateTime? date,
  }) =>
      MockScore(
        id: id,
        date: date ?? DateTime(2026, 9, 1),
        subject: subject,
        score: value,
        topic: topic,
      );

  StudySession session({
    required String id,
    required DateTime at,
    int minutes = 30,
    String subject = 'Toán',
  }) =>
      StudySession(
        id: id,
        completedAt: at,
        subject: subject,
        plannedMinutes: minutes,
        actualMinutes: minutes,
      );

  group('weeklyAverageScores', () {
    test('gộp điểm theo tuần lịch (Thứ 2 → Chủ nhật) và tính trung bình', () {
      final weeks = weeklyAverageScores([
        score(id: 'a', value: 4, date: DateTime(2026, 3, 16)), // T2 tuần 16/3
        score(id: 'b', value: 8, date: DateTime(2026, 3, 18)), // T4 tuần 16/3
        score(id: 'c', value: 6, date: DateTime(2026, 3, 9)), // T2 tuần 9/3
      ]);

      expect(weeks, hasLength(2));
      // Tuần cũ trước.
      expect(weeks.first.weekStart, DateTime(2026, 3, 9));
      expect(weeks.first.average, 6.0);
      expect(weeks.first.count, 1);
      // Tuần sau.
      expect(weeks.last.weekStart, DateTime(2026, 3, 16));
      expect(weeks.last.average, 6.0);
      expect(weeks.last.count, 2);
    });

    test('Chủ nhật và Thứ 2 kề nhau thuộc hai tuần khác nhau', () {
      final weeks = weeklyAverageScores([
        score(id: 'a', value: 7, date: DateTime(2026, 3, 15)), // CN
        score(id: 'b', value: 3, date: DateTime(2026, 3, 16)), // T2 sau đó
      ]);

      expect(weeks, hasLength(2));
      expect(weeks.first.weekStart, DateTime(2026, 3, 9));
      expect(weeks.last.weekStart, DateTime(2026, 3, 16));
    });

    test('giữ tối đa maxWeeks tuần GẦN nhất (không rối khi nhiều dữ liệu cũ)', () {
      final scores = [
        for (var w = 0; w < 10; w++)
          score(
              id: 'w$w',
              value: 5,
              date: DateTime(2026, 3, 9).add(Duration(days: 7 * w))),
      ];

      final weeks = weeklyAverageScores(scores, maxWeeks: 4);
      expect(weeks, hasLength(4));
      expect(weeks.last.weekStart,
          DateTime(2026, 3, 9).add(const Duration(days: 7 * 9)));
    });

    test('danh sách rỗng → rỗng (không bịa dữ liệu)', () {
      expect(weeklyAverageScores(const []), isEmpty);
    });
  });

  group('DeepReport.build', () {
    // Thứ Tư 18/03/2026: tuần này T2 16/3, tuần trước T2 9/3.
    final now = DateTime(2026, 3, 18, 10, 0);

    test('chủ đề yếu: chỉ giữ dưới ngưỡng 6.5, yếu nhất trước', () {
      final report = DeepReport.build([
        score(topic: 'Hàm số', value: 4, date: DateTime(2026, 3, 18)),
        score(topic: 'Hàm số', value: 5, date: DateTime(2026, 3, 16)),
        score(topic: 'Hình học', value: 8, date: DateTime(2026, 3, 17)),
        score(topic: 'Điện', value: 7, date: DateTime(2026, 3, 17)),
      ], [], now: now);

      expect(report.weakTopics.map((t) => t.topic).toList(),
          ['Hàm số']);
      expect(report.weakTopics.single.attempts, 2);
    });

    test('chủ đề đều >= 6.5 → không có chủ đề cần ưu tiên', () {
      final report = DeepReport.build([
        score(topic: 'Hàm số', value: 7, date: DateTime(2026, 3, 17)),
        score(topic: 'Hình học', value: 8, date: DateTime(2026, 3, 18)),
      ], [], now: now);

      expect(report.weakTopics, isEmpty);
    });

    test('môn yếu nhất đứng đầu danh sách theo môn', () {
      final report = DeepReport.build([
        score(subject: 'Lý', value: 4, date: DateTime(2026, 3, 18)),
        score(subject: 'Lý', value: 5, date: DateTime(2026, 3, 16)),
        score(subject: 'Toán', value: 9, date: DateTime(2026, 3, 17)),
        score(subject: 'Toán', value: 8, date: DateTime(2026, 3, 15)),
      ], [], now: now);

      expect(report.subjects.first.subject, 'Lý');
      expect(report.overallAverage, closeTo(6.5, 0.001));
    });

    test('giờ học: gộp tuần này vs tuần trước theo actualMinutes', () {
      final report = DeepReport.build(
        [],
        [
          session(id: 'a', at: DateTime(2026, 3, 17, 20, 0), minutes: 30),
          session(id: 'b', at: DateTime(2026, 3, 18, 20, 0), minutes: 15),
          session(id: 'c', at: DateTime(2026, 3, 19, 20, 0), minutes: 0), // tương lai nhẹ, vẫn tuần này
          session(id: 'd', at: DateTime(2026, 3, 9, 20, 0), minutes: 45), // tuần trước
        ],
        now: now,
      );

      expect(report.hasSessions, isTrue);
      expect(report.hoursComparison.thisWeekMinutes, greaterThan(0));
      expect(report.hoursComparison.lastWeekMinutes, 45);
    });

    test('không dữ liệu nào → báo cáo rỗng, không crash', () {
      final report = DeepReport.build([], [], now: now);

      expect(report.hasScores, isFalse);
      expect(report.hasSessions, isFalse);
      expect(report.weeklyBuckets, isEmpty);
      expect(report.subjects, isEmpty);
      expect(report.weakTopics, isEmpty);
      expect(report.scoreTrend.trend, isNull);
    });

    test('xu hướng tăng đi theo bộ weeklyBuckets sắp tăng dần', () {
      final report = DeepReport.build([
        score(id: 'a', value: 6, date: DateTime(2026, 3, 9)),
        score(id: 'b', value: 7, date: DateTime(2026, 3, 16)),
        score(id: 'c', value: 8.5, date: DateTime(2026, 3, 18)),
      ], [], now: now);

      expect(report.weeklyBuckets.first.weekStart, DateTime(2026, 3, 9));
      expect(report.weeklyBuckets.last.weekStart, DateTime(2026, 3, 16));
      expect(report.scoreTrend.trend, 'up');
    });
  });
}