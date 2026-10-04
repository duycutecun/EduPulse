import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/core/constants/subject_catalog.dart';
import 'package:edupulse/features/exams/domain/models/exam_model.dart';
import 'package:edupulse/features/progress/domain/progress_engine.dart';
import 'package:edupulse/features/progress/domain/progress_insights.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';

/// QA-5.1 — Kiểm thử Tính toán Tiến độ (BE-5.1), Nhận định AI (AI-5.1) và
/// Đếm ngược Kỳ thi (BE-5.2).
///
/// Toàn bộ [ProgressEngine] là hàm thuần nhận `now` tường minh, nhờ vậy test
/// chuyển giao ngày/tuần/tháng chính xác mà không cần bơm đồng hồ hệ thống.

StudySession _session({
  required DateTime at,
  String subject = '📐 Toán',
  int minutes = 30,
  int? understanding,
}) {
  return StudySession(
    id: 's-${at.microsecondsSinceEpoch}-$subject',
    completedAt: at,
    subject: subject,
    plannedMinutes: minutes,
    actualMinutes: minutes,
    understanding: understanding,
  );
}

TodayTask _task({
  required String id,
  String subject = '📐 Toán',
  String status = 'todo',
  DateTime? scheduledAt,
  DateTime? createdAt,
}) {
  return TodayTask(
    id: id,
    title: 'Nhiệm vụ $id',
    subject: subject,
    status: status,
    scheduledAt: scheduledAt,
    createdAt: createdAt,
  );
}

void main() {
  // now cố định — thứ trong tuần không quan trọng vì test tự suy chỉ số từ
  // weekday của chính mốc đã cho.
  final now = DateTime(2026, 3, 18, 10, 30);

  group('ProgressWindow — nửa mở [start, end)', () {
    test('chứa mốc đầu, không chứa mốc cuối', () {
      final w = ProgressWindow(DateTime(2026, 3, 18), DateTime(2026, 3, 19));
      expect(w.contains(DateTime(2026, 3, 18, 0, 0, 0)), isTrue);
      expect(w.contains(DateTime(2026, 3, 18, 23, 59, 59)), isTrue);
      expect(w.contains(DateTime(2026, 3, 19)), isFalse);
      expect(w.contains(DateTime(2026, 3, 17, 23, 59, 59)), isFalse);
    });
  });

  group('ProgressEngine — biên ngày/tuần/tháng', () {
    test('startOfDay cắt về 00:00', () {
      expect(ProgressEngine.startOfDay(now), DateTime(2026, 3, 18));
    });

    test('startOfWeek luôn rơi vào Thứ 2 và không muộn hơn now', () {
      final start = ProgressEngine.startOfWeek(now);
      expect(start.weekday, DateTime.monday);
      expect(start.hour, 0);
      expect(start.isAfter(now), isFalse);
      expect(start.add(const Duration(days: 7)).isAfter(now), isTrue);
    });

    test('startOfMonth cắt về ngày 1', () {
      expect(ProgressEngine.startOfMonth(now), DateTime(2026, 3, 1));
    });

    test('windowOf(day) là đúng một ngày', () {
      final w = ProgressEngine.windowOf(ProgressRange.day, now);
      expect(w.start, DateTime(2026, 3, 18));
      expect(w.end, DateTime(2026, 3, 19));
    });
  });

  group('minutesOn / dayProgress', () {
    test('cộng đúng phút của các phiên trong ngày, bỏ phiên ngày khác', () {
      final sessions = [
        _session(at: DateTime(2026, 3, 18, 8), minutes: 25),
        _session(at: DateTime(2026, 3, 18, 20), minutes: 35),
        _session(at: DateTime(2026, 3, 19, 0, 0), minutes: 99), // ngày kế
        _session(at: DateTime(2026, 3, 17, 23, 59), minutes: 99), // ngày trước
      ];
      expect(ProgressEngine.minutesOn(sessions, now), 60);
    });

    test('đếm nhiệm vụ hoàn thành / tổng theo ngày lịch', () {
      final tasks = [
        _task(
            id: 'a',
            scheduledAt: DateTime(2026, 3, 18, 9),
            status: 'completed'),
        _task(id: 'b', scheduledAt: DateTime(2026, 3, 18, 10), status: 'todo'),
        _task(
            id: 'c',
            scheduledAt: DateTime(2026, 3, 19, 9),
            status: 'completed'),
      ];
      final day = ProgressEngine.dayProgress(const [], tasks, now);
      expect(day.tasksTotal, 2);
      expect(day.tasksCompleted, 1);
      expect(day.completionRate, 0.5);
      expect(day.remaining, 1);
    });

    test('thứ tự ưu tiên: scheduledAt rồi mới tới createdAt', () {
      final tasks = [
        _task(id: 'a', createdAt: DateTime(2026, 3, 18, 1)), // không có lịch
        _task(
            id: 'b',
            scheduledAt: DateTime(2026, 3, 18, 9),
            createdAt: DateTime(2026, 1, 1)),
      ];
      final day = ProgressEngine.dayProgress(const [], tasks, now);
      expect(day.tasksTotal, 2);
    });

    test('nhiệm vụ không có mốc thời gian nào → không tính', () {
      final day = ProgressEngine.dayProgress(
        const [],
        [_task(id: 'a')],
        now,
      );
      expect(day.tasksTotal, 0);
      expect(day.completionRate, 0);
    });
  });

  group('weekProgress', () {
    test('phân bổ phút vào đúng cột thứ trong tuần (T2..CN)', () {
      final start = ProgressEngine.startOfWeek(now);
      StudySession on(int weekdayIndex, int minutes) => _session(
            at: start.add(Duration(days: weekdayIndex, hours: 9)),
            minutes: minutes,
          );

      final week = ProgressEngine.weekProgress(
        [on(0, 10), on(2, 20), on(6, 30)],
        const [],
        now,
      );
      expect(week.dailyMinutes[0], 10);
      expect(week.dailyMinutes[2], 20);
      expect(week.dailyMinutes[6], 30);
      expect(week.totalMinutes, 60);
      expect(week.totalHours, 1.0);
    });

    test('phiên ngoài tuần hiện tại không lọt vào cột nào', () {
      final start = ProgressEngine.startOfWeek(now);
      final sessions = [
        _session(at: start.subtract(const Duration(days: 1)), minutes: 99),
        _session(at: start.add(const Duration(days: 7)), minutes: 99),
      ];
      final week = ProgressEngine.weekProgress(sessions, const [], now);
      expect(week.totalMinutes, 0);
    });
  });

  group('subjectProgress — BE-5.1', () {
    test("gộp 'Toán' và '📐 Toán' về một môn sau chuẩn hoá", () {
      final sessions = [_session(at: now, subject: 'Toán', minutes: 40)];
      final tasks = [
        _task(
            id: 'a', subject: '📐 Toán', status: 'completed', scheduledAt: now),
      ];
      final list = ProgressEngine.subjectProgress(sessions, tasks, now);
      expect(list.length, 1);
      final toan = list.single;
      expect(toan.subject, AppSubjects.normalize('Toán'));
      expect(toan.minutes, 40);
      expect(toan.sessionCount, 1);
      expect(toan.tasksTotal, 1);
      expect(toan.tasksCompleted, 1);
    });

    test('điểm hiểu bài trung bình chỉ tính các phiên có chấm', () {
      final sessions = [
        _session(at: now, understanding: 4),
        _session(at: now.add(const Duration(minutes: 1)), understanding: 2),
        _session(at: now.add(const Duration(minutes: 2))), // không chấm
      ];
      final list = ProgressEngine.subjectProgress(sessions, const [], now);
      expect(list.single.avgUnderstanding, 3.0);
    });

    test('sắp môn theo thời gian học giảm dần', () {
      final sessions = [
        _session(at: now, subject: '📖 Văn', minutes: 10),
        _session(at: now, subject: '📐 Toán', minutes: 50),
      ];
      final list = ProgressEngine.subjectProgress(sessions, const [], now);
      expect(list.first.subject, AppSubjects.normalize('📐 Toán'));
      expect(list.first.minutes, 50);
    });
  });

  group('neglectedSubjects — môn bỏ quên', () {
    test('môn học cách đây 10 ngày bị coi là bỏ quên', () {
      final tenDaysAgo =
          ProgressEngine.startOfDay(now).subtract(const Duration(days: 10));
      final sessions = [_session(at: tenDaysAgo, subject: '⚡ Lý', minutes: 20)];
      final list = ProgressEngine.neglectedSubjects(sessions, const [], now);
      expect(list.map((s) => s.subject), contains(AppSubjects.normalize('Lý')));
    });

    test('môn học hôm qua không bị báo bỏ quên', () {
      final yesterday = ProgressEngine.startOfDay(now)
          .subtract(const Duration(days: 1))
          .add(const Duration(hours: 9));
      final sessions = [_session(at: yesterday, subject: '⚡ Lý')];
      expect(
          ProgressEngine.neglectedSubjects(sessions, const [], now), isEmpty);
    });

    test('môn chưa từng có phiên học thì không báo động', () {
      expect(
          ProgressEngine.neglectedSubjects(const [], const [], now), isEmpty);
    });
  });

  group('ProgressSnapshot', () {
    test('lastWeekMinutes tách đúng cửa sổ tuần trước', () {
      final start = ProgressEngine.startOfWeek(now);
      final sessions = [
        _session(at: start.subtract(const Duration(days: 2)), minutes: 120),
        _session(at: start.add(const Duration(days: 1, hours: 9)), minutes: 30),
      ];
      final snap = ProgressEngine.snapshot(sessions, const [], now);
      expect(snap.lastWeekMinutes, 120);
      expect(snap.week.totalMinutes, 30);
    });

    test('weekDeltaPercent tăng/giảm đúng chiều, null khi tuần trước trống',
        () {
      final start = ProgressEngine.startOfWeek(now);
      final sessions = [
        _session(at: start.subtract(const Duration(days: 2)), minutes: 100),
        _session(
            at: start.add(const Duration(days: 1, hours: 9)), minutes: 150),
      ];
      final snap = ProgressEngine.snapshot(sessions, const [], now);
      expect(snap.weekDeltaPercent, 50);

      final empty = ProgressEngine.snapshot(const [], const [], now);
      expect(empty.weekDeltaPercent, isNull);
      expect(empty.hasData, isFalse);
    });
  });

  group('ProgressInsights — AI-5.1', () {
    test('localInsight trả null khi tuần trắng (không bịa câu động viên)', () {
      final snap = ProgressEngine.snapshot(const [], const [], now);
      expect(ProgressInsights.localInsight(snap), isNull);
    });

    test('localInsight nêu môn dẫn đầu bằng số liệu thật', () {
      final snap = ProgressEngine.snapshot(
        [_session(at: now, subject: '📐 Toán', minutes: 120)],
        const [],
        now,
      );
      final insight = ProgressInsights.localInsight(snap);
      expect(insight, isNotNull);
      expect(insight, contains('Toán'));
      expect(insight, contains('2.0h'));
    });

    test('buildPrompt mang đúng con số đã tổng hợp', () {
      final snap = ProgressEngine.snapshot(
        [_session(at: now, subject: '📐 Toán', minutes: 45)],
        const [],
        now,
      );
      final prompt = ProgressInsights.buildPrompt(snap);
      expect(prompt, contains('45 phút'));
      expect(prompt, contains('Toán'));
    });
  });

  group('ExamModel — đếm ngược & pha (BE-5.2)', () {
    ExamModel examAt(DateTime dateTime) =>
        ExamModel(id: 'e1', name: 'THPTQG', dateTime: dateTime);

    test('> 7 ngày còn lại → pha normal', () {
      final exam = examAt(DateTime(2026, 4, 10, 8));
      expect(exam.phaseAt(DateTime(2026, 4, 1)), ExamPhase.normal);
    });

    test('đúng 7 ngày → pha revision', () {
      final exam = examAt(DateTime(2026, 4, 8, 8));
      final at = DateTime(2026, 4, 1, 8);
      expect(exam.daysLeftAt(at), 7);
      expect(exam.phaseAt(at), ExamPhase.revision);
    });

    test('trong ngày thi → pha examDay', () {
      final exam = examAt(DateTime(2026, 4, 8, 8));
      final at = DateTime(2026, 4, 8, 12);
      expect(exam.isExamDayAt(at), isTrue);
      expect(exam.phaseAt(at), ExamPhase.examDay);
    });

    test('sau 23:59:59 ngày thi → pha postExam', () {
      final exam = examAt(DateTime(2026, 4, 8, 8));
      final at = DateTime(2026, 4, 9, 0, 30);
      expect(exam.isExamDayOverAt(at), isTrue);
      expect(exam.phaseAt(at), ExamPhase.postExam);
    });

    test('remainingAt không phụ thuộc đồng hồ hệ thống', () {
      final exam = examAt(DateTime(2026, 4, 8, 8));
      expect(
        exam.remainingAt(DateTime(2026, 4, 7, 8)),
        const Duration(days: 1),
      );
    });
  });
}
