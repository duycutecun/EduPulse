import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/features/leaderboard/domain/personal_records.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';

StudySession session(DateTime at,
        {int minutes = 30, String subject = 'Toán'}) =>
    StudySession(
      id: 's-${at.microsecondsSinceEpoch}-$minutes',
      completedAt: at,
      subject: subject,
      plannedMinutes: minutes,
      actualMinutes: minutes,
    );

MockScore score(DateTime at, double value, {String subject = 'Toán'}) =>
    MockScore(
        id: 'm-${at.microsecondsSinceEpoch}',
        date: at,
        subject: subject,
        score: value);

void main() {
  group('formatStudyMinutes', () {
    test('định dạng phút/giờ tiếng Việt', () {
      expect(formatStudyMinutes(0), '0 phút');
      expect(formatStudyMinutes(45), '45 phút');
      expect(formatStudyMinutes(60), '1 giờ');
      expect(formatStudyMinutes(95), '1 giờ 35 phút');
      expect(formatStudyMinutes(120), '2 giờ');
    });
  });

  group('computePersonalRecords', () {
    test('không có dữ liệu → rỗng', () {
      final r = computePersonalRecords(
        sessions: const [],
        scores: const [],
        streak: 0,
        streakRecord: 0,
      );
      expect(r.hasData, isFalse);
      expect(r.records, isEmpty);
      expect(identical(r, PersonalRecords.empty), isTrue);
    });

    test('tính phiên dài nhất, ngày và tuần học nhiều nhất', () {
      final records = computePersonalRecords(
        sessions: [
          session(DateTime(2026, 3, 16, 9), minutes: 30),
          session(DateTime(2026, 3, 16, 15), minutes: 40),
          session(DateTime(2026, 3, 17), minutes: 50),
        ],
        scores: const [],
        streak: 0,
        streakRecord: 0,
        now: DateTime(2026, 3, 18),
      );

      final longest =
          records.records.firstWhere((r) => r.id == 'longest_session');
      expect(longest.value, '50 phút');

      final busiest = records.records.firstWhere((r) => r.id == 'busiest_day');
      expect(busiest.value, '1 giờ 10 phút');
      expect(busiest.detail, '16/03');

      final bestWeek = records.records.firstWhere((r) => r.id == 'best_week');
      expect(bestWeek.value, '2 giờ');
      expect(bestWeek.detail, contains('16/03'));

      expect(records.totalMinutes, 120);
    });

    test('điểm thi thử cao nhất kèm môn và ngày', () {
      final records = computePersonalRecords(
        sessions: const [],
        scores: [
          score(DateTime(2026, 3, 10), 6.0, subject: 'Lý'),
          score(DateTime(2026, 3, 12), 8.5, subject: 'Toán'),
        ],
        streak: 0,
        streakRecord: 0,
      );
      final best = records.records.firstWhere((r) => r.id == 'best_score');
      expect(best.value, '8.5 điểm');
      expect(best.detail, contains('Toán'));
      expect(best.detail, contains('12/03'));
      expect(records.records.firstWhere((r) => r.id == 'score_count').value,
          '2 lần');
    });

    test('kỷ lục chuỗi được làm nổi khi chạm/khoá kỷ lục', () {
      final atRecord = computePersonalRecords(
        sessions: const [],
        scores: const [],
        streak: 5,
        streakRecord: 5,
      );
      expect(
          atRecord.records.firstWhere((r) => r.id == 'streak_record').highlight,
          isTrue);

      final behind = computePersonalRecords(
        sessions: const [],
        scores: const [],
        streak: 3,
        streakRecord: 7,
      );
      expect(
          behind.records.firstWhere((r) => r.id == 'streak_record').highlight,
          isFalse);
      expect(behind.records.firstWhere((r) => r.id == 'current_streak').detail,
          'Kỷ lục: 7 ngày');
    });

    test('ghi chú chỉ xuất hiện khi có dữ liệu', () {
      final withNotes = computePersonalRecords(
        sessions: const [],
        scores: const [],
        streak: 0,
        streakRecord: 0,
        notesCount: 3,
      );
      expect(withNotes.records.map((r) => r.id), contains('notes_count'));

      final without = computePersonalRecords(
        sessions: [session(DateTime(2026, 3, 16))],
        scores: const [],
        streak: 0,
        streakRecord: 0,
      );
      expect(without.records.map((r) => r.id), isNot(contains('notes_count')));
    });

    test('dữ liệu trống nhưng có streak vẫn coi là có dữ liệu', () {
      final records = computePersonalRecords(
        sessions: const [],
        scores: const [],
        streak: 2,
        streakRecord: 2,
      );
      expect(records.hasData, isTrue);
      expect(records.records.map((r) => r.id), contains('current_streak'));
    });
  });
}
