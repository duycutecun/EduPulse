import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/ai/study_rhythm.dart';
import 'package:edupulse/core/ai/weekly_report.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';

/// Test Giai đoạn "AI hiểu bạn" (nhịp học) + báo cáo tuần cho gia đình.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  StudySession session(String id, DateTime at, int minutes,
      {int? focus, int? effectiveness, String subject = 'Toán'}) {
    return StudySession(
      id: id,
      subject: subject,
      completedAt: at,
      plannedMinutes: minutes,
      actualMinutes: minutes,
      focus: focus,
      effectiveness: effectiveness,
    );
  }

  void saveSessions(List<StudySession> list) {
    final ids = <String>[];
    for (final s in list) {
      StorageService.setStudySessionJson(s.id, s.toJsonString());
      ids.add(s.id);
    }
    StorageService.setStudySessionIds(ids);
  }

  group('StudyRhythm — giờ vàng', () {
    test('chưa đủ dữ liệu → null (không bịa giờ vàng)', () {
      saveSessions([
        session('s1', DateTime(2026, 10, 1, 20), 25, focus: 5),
      ]);
      expect(
          StudyRhythm.peakHour(now: DateTime(2026, 10, 1, 22)), isNull);
    });

    test('2 phiên tối muộn chất lượng cao → giờ vàng 20h', () {
      saveSessions([
        session('s1', DateTime(2026, 9, 29, 20), 25, focus: 5, effectiveness: 5),
        session('s2', DateTime(2026, 9, 30, 20), 45, focus: 4, effectiveness: 5),
        session('s3', DateTime(2026, 9, 30, 9), 25, focus: 2, effectiveness: 2),
      ]);
      final peak = StudyRhythm.peakHour(now: DateTime(2026, 10, 1, 22));
      expect(peak, isNotNull);
      expect(peak!.summary, contains('20'));
      expect(peak.confidence, greaterThan(0));
    });
  });

  group('StudyRhythm — burnout', () {
    test('2 phiên gần nhất đều thấp → cảnh báo', () {
      saveSessions([
        session('b1', DateTime(2026, 9, 30, 15), 60, focus: 2, effectiveness: 2),
        session('b2', DateTime(2026, 10, 1, 16), 60, focus: 1, effectiveness: 2),
        session('b3', DateTime(2026, 9, 25, 10), 25, focus: 5, effectiveness: 5),
      ]);
      final risk = StudyRhythm.burnoutRisk(now: DateTime(2026, 10, 1, 22));
      expect(risk, isNotNull);
      expect(risk!.summary, contains('nặng nhọc'));
    });

    test('phiên cuối khoẻ mạnh → không cảnh báo', () {
      saveSessions([
        session('c1', DateTime(2026, 9, 30, 15), 60, focus: 2, effectiveness: 2),
        session('c2', DateTime(2026, 10, 1, 16), 45, focus: 4, effectiveness: 4),
      ]);
      expect(
          StudyRhythm.burnoutRisk(now: DateTime(2026, 10, 1, 22)), isNull);
    });
  });

  group('StudyRhythm — môn bị bỏ quên', () {
    test('môn có task nhưng 6 ngày không học → bị nhắc', () {
      saveSessions([
        session('n1', DateTime(2026, 9, 25, 20), 30, subject: 'Toán'),
      ]);
      // Task Hóa hôm nay, nhưng không có phiên Hóa nào.
      final task = TodayTask(
        id: 't1',
        title: 'Cân bằng hóa',
        subject: 'Hóa',
        priority: 'high',
        status: 'todo',
        estimateMinutes: 45,
      );
      StorageService.setTodayTaskJson('t1', task.toJsonString());
      StorageService.setTodayTaskIds(['t1']);

      final neglected = StudyRhythm.neglectedSubject(
          now: DateTime(2026, 10, 1, 22));
      expect(neglected, isNotNull);
      expect(neglected!.subject, 'Hóa');
    });
  });

  group('StudyRhythm — đề xuất thứ tự task', () {
    test('môn yếu nhất (điểm thi thử thấp) được đẩy lên trước', () {
      final m = MockScore(
          id: 'm1', subject: 'Hóa', score: 5.0, date: DateTime(2026, 9, 20));
      StorageService.setMockScoreJson('m1', m.toJsonString());
      StorageService.setMockScoreIds(['m1']);

      TodayTask task(String id, String subject) => TodayTask(
            id: id,
            title: 'Học $subject',
            subject: subject,
            priority: 'medium',
            status: 'todo',
            estimateMinutes: 45,
          );
      final tasks = [task('a', 'Toán'), task('b', 'Hóa'), task('c', 'Lý')];

      final ordered = StudyRhythm.suggestOrder(tasks);
      expect(ordered.first.subject, 'Hóa'); // môn yếu nhất lên đầu
      expect(ordered.length, 3); // không mất task nào
    });
  });

  group('WeeklyReport — cửa sổ tin cậy', () {
    test('tắt hết mục → không có báo cáo (không ép chia sẻ)', () {
      final report = WeeklyReport.build(
        enabled: const {
          'study_time': false,
          'readiness': false,
          'mock_score': false,
          'exam_countdown': false,
        },
        now: DateTime(2026, 10, 1),
      );
      expect(report, isNull);
    });

    test('chỉ bật thời gian học → báo cáo có phút focus, không lộ điểm', () {
      saveSessions([
        session('w1', DateTime(2026, 9, 29, 20), 25),
        session('w2', DateTime(2026, 9, 30, 20), 35),
      ]);
      final report = WeeklyReport.build(
        enabled: const {
          'study_time': true,
          'readiness': false,
          'mock_score': false,
          'exam_countdown': false,
        },
        now: DateTime(2026, 10, 1),
      );
      expect(report, isNotNull);
      expect(report!.headline, contains('60 phút'));
      final text = report.toPlainText(studentName: 'Minh');
      expect(text, contains('Thời gian tập trung'));
      expect(text, isNot(contains('Chỉ số sẵn sàng')));
      expect(text, isNot(contains('Điểm')));
    });

    test('điểm thi thử chỉ vào báo cáo khi học sinh bật', () {
      final m = MockScore(
          id: 'mm', subject: 'Toán', score: 8.5, date: DateTime(2026, 9, 30));
      StorageService.setMockScoreJson('mm', m.toJsonString());
      StorageService.setMockScoreIds(['mm']);

      final off = WeeklyReport.build(
        enabled: const {
          'study_time': true,
          'readiness': false,
          'mock_score': false,
        },
        now: DateTime(2026, 10, 1),
      );
      expect(off!.toPlainText(studentName: ''), isNot(contains('8.5')));

      final on = WeeklyReport.build(
        enabled: const {
          'study_time': true,
          'readiness': false,
          'mock_score': true,
        },
        now: DateTime(2026, 10, 1),
      );
      expect(on!.toPlainText(studentName: ''), contains('8.5'));
    });
  });
}
