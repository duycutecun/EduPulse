import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/active_study_session.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';
import 'package:edupulse/features/study/domain/study_timeline.dart';
import 'package:edupulse/features/study/domain/weekly_summary.dart';

void main() {
  StudySession session({
    required String id,
    required DateTime at,
    int minutes = 25,
    String subject = 'Toán',
    String? taskId = 'task-1',
    String? reflection,
  }) =>
      StudySession(
        id: id,
        completedAt: at,
        taskId: taskId,
        subject: subject,
        plannedMinutes: 25,
        actualMinutes: minutes,
        startedAt: at.subtract(Duration(minutes: minutes)),
        endedAt: at,
        reflectionNote: reflection,
      );

  group('buildStudyTimeline', () {
    test('Gộp cả phiên học lẫn ghi chép nhập tay', () {
      final now = DateTime(2026, 3, 4, 9);
      final entries = buildStudyTimeline(
        logs: [StudyLog(id: 'l1', date: now, subject: 'Văn', hours: 1.0)],
        sessions: [session(id: 's1', at: now)],
      );
      expect(entries, hasLength(2));
      expect(entries.where((e) => e.fromSession), hasLength(1));
      expect(entries.where((e) => !e.fromSession), hasLength(1));
    });

    test('Sắp xếp mới nhất trước, bất kể nguồn', () {
      final base = DateTime(2026, 3, 4, 9);
      final entries = buildStudyTimeline(
        logs: [
          StudyLog(id: 'l1', date: base, subject: 'A', hours: 1),
          StudyLog(id: 'l2', date: base.add(const Duration(days: 2)), subject: 'B', hours: 1),
        ],
        sessions: [session(id: 's1', at: base.add(const Duration(days: 1)))],
      );
      expect(entries.map((e) => e.id), ['l2', 's1', 'l1']);
    });

    test('Phiên học đổi phút sang giờ, dùng actualMinutes thật', () {
      final entries = buildStudyTimeline(
        logs: const [],
        sessions: [session(id: 's1', at: DateTime(2026, 3, 4, 9), minutes: 50)],
      );
      expect(entries.single.hours, closeTo(50 / 60, 1e-9));
    });

    test('Dòng từ phiên học mang theo taskId để xoá đúng chỗ', () {
      final entries = buildStudyTimeline(
        logs: const [],
        sessions: [
          session(id: 's1', at: DateTime(2026, 3, 4, 9), taskId: 'task-9'),
          session(id: 's2', at: DateTime(2026, 3, 4, 10), taskId: null),
        ],
      );
      expect(entries.first.id, 's2');
      expect(entries.first.taskId, isNull);
      expect(entries.last.taskId, 'task-9');
      expect(entries.last.fromSession, isTrue);
    });

    test('Ghi chú lấy từ reflectionNote của phiên, giữ nguyên ghi chép nhập tay', () {
      final base = DateTime(2026, 3, 4, 9);
      final entries = buildStudyTimeline(
        logs: [StudyLog(id: 'l1', date: base, subject: 'A', hours: 1, note: 'tự ghi')],
        sessions: [session(id: 's1', at: base, reflection: 'học chắc phần lý thuyết')],
      );
      final fromSession = entries.firstWhere((e) => e.fromSession);
      final fromLog = entries.firstWhere((e) => !e.fromSession);
      expect(fromSession.note, 'học chắc phần lý thuyết');
      expect(fromLog.note, 'tự ghi');
    });

    test('ID trùng nhau giữa hai nguồn không bị lọc bỏ', () {
      final base = DateTime(2026, 3, 4, 9);
      final entries = buildStudyTimeline(
        logs: [StudyLog(id: 'same', date: base, subject: 'A', hours: 0.5)],
        sessions: [session(id: 'same', at: base)],
      );
      expect(entries, hasLength(2));
      expect(totalHoursOf(entries), closeTo(0.5 + 25 / 60, 1e-9));
    });
  });

  group('totalHoursOf', () {
    test('Cộng dồn cả hai nguồn', () {
      final base = DateTime(2026, 3, 4, 9);
      final entries = buildStudyTimeline(
        logs: [StudyLog(id: 'l1', date: base, subject: 'A', hours: 1.0)],
        sessions: [session(id: 's1', at: base, minutes: 60)],
      );
      expect(totalHoursOf(entries), closeTo(2.0, 1e-9));
    });

    test('Danh sách rỗng → 0', () {
      expect(totalHoursOf(const []), 0.0);
    });
  });

  group('Tổng hợp tuần dùng timeline hợp nhất', () {
    test('Chỉ phiên học pomodoro vẫn ra tổng giờ tuần', () {
      final today = DateTime.now();
      final summary = summarizeWeek([
        StudyTimelineEntry.fromSession(session(id: 's1', at: today, minutes: 45)),
      ]);
      expect(summary.totalHours, closeTo(0.75, 1e-9));
      expect(summary.subjectHours['Toán'], closeTo(0.75, 1e-9));
    });

    test('weeklyHoursOf cũng tính cả phiên học', () {
      final today = DateTime.now();
      expect(
        weeklyHoursOf([StudyTimelineEntry.fromSession(session(id: 's1', at: today, minutes: 30))]),
        closeTo(0.5, 1e-9),
      );
    });

    test('Phiên học tuần trước không lọn vào tuần này', () {
      final now = DateTime.now();
      final lastWeek = now.subtract(const Duration(days: 7));
      final summary = summarizeWeek([
        StudyTimelineEntry.fromSession(session(id: 'old', at: lastWeek, minutes: 60)),
      ]);
      expect(summary.totalHours, 0.0);
    });

    test('Phiên học môn rỗng gộp vào nhóm "khác"', () {
      final today = DateTime.now();
      final summary = summarizeWeek([
        StudyTimelineEntry.fromSession(session(id: 's1', at: today, subject: '', minutes: 20)),
      ]);
      expect(summary.subjectHours.keys, contains('khác'));
    });
  });

  group('Tín hiệu cập nhật thời gian học (BE-3.3)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
    });

    test('ghi phiên → revision tăng, để widget vẽ lại ngay', () async {
      final repo = StudySessionRepository.instance;
      final before = repo.revision.value;

      await repo.save(session(id: 's1', at: DateTime.now()));

      expect(repo.revision.value, greaterThan(before));
      expect(repo.minutesOn(DateTime.now()), 25,
          reason: 'tổng phút đã có ngay, không cần đợi điều hướng');
    });

    test('cập nhật phản hồi cũng báo tín hiệu', () async {
      final repo = StudySessionRepository.instance;
      await repo.save(session(id: 's1', at: DateTime.now()));
      final before = repo.revision.value;

      await repo.updateFeedback('s1', mood: 5, understanding: 4);

      expect(repo.revision.value, greaterThan(before));
    });

    test('xoá phiên cũng báo tín hiệu — tổng giờ phải giảm theo', () async {
      final repo = StudySessionRepository.instance;
      await repo.save(session(id: 's1', at: DateTime.now()));
      final before = repo.revision.value;

      repo.delete('s1');

      expect(repo.revision.value, greaterThan(before));
      expect(repo.minutesOn(DateTime.now()), 0);
    });

    test('lưu ảnh chụp vòng đang chạy KHÔNG báo tín hiệu', () {
      // Lưu ảnh chụp diễn ra mỗi lần bấm bắt đầu/tạm dừng. Bắn tín hiệu ở đây
      // sẽ vẽ lại toàn bộ widget giữa lúc đếm giờ.
      final repo = StudySessionRepository.instance;
      final before = repo.revision.value;

      repo.saveActive(ActiveStudySession(
        taskId: 't1',
        subject: 'Toan',
        totalSeconds: 1500,
        remainingAtAnchor: 1500,
        anchorAt: DateTime.now(),
        startedAt: DateTime.now(),
      ));

      expect(repo.revision.value, before);
    });
  });

  group('Không còn ghi trùng ở vòng pomodoro', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
    });

    test('Một phiên 25 phút chỉ sinh một bản ghi, không có StudyLog đi kèm', () {
      final now = DateTime.now();
      final pomodoroSession = session(id: 's1', at: now, minutes: 25);

      StorageService.setStudySessionJson(pomodoroSession.id, pomodoroSession.toJsonString());
      final ids = StorageService.getStudySessionIds()..add(pomodoroSession.id);
      StorageService.setStudySessionIds(ids);

      // Không ghi thêm StudyLog cho cùng khoảng thời gian.
      final timeline = buildStudyTimeline(
        logs: StorageService.getStudyLogIds()
            .map(StorageService.getStudyLogJson)
            .whereType<String>()
            .map(StudyLog.fromJsonString)
            .toList(),
        sessions: StorageService.getStudySessionIds()
            .map(StorageService.getStudySessionJson)
            .whereType<String>()
            .map(StudySession.fromJsonString)
            .toList(),
      );

      expect(timeline, hasLength(1));
      expect(totalHoursOf(timeline), closeTo(25 / 60, 1e-9));
    });
  });
}
