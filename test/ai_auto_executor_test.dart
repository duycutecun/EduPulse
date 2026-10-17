import 'package:edupulse/core/ai/ai_copilot_service.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI-2.2 — executor TỰ THỰC THI: các thao tác ghi dữ liệu tự động phải
/// qua đúng TaskRepository, chặn trùng, và luôn có đường hoàn tác.
void main() {
  late TaskRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    repo = TaskRepository.instance;
  });

  TodayTask makeTask({
    String id = 't1',
    String title = 'Toán ch5',
    String subject = '📐 Toán',
    DateTime? scheduledAt,
  }) {
    return TodayTask(
      id: id,
      title: title,
      subject: subject,
      priority: 'medium',
      estimateMinutes: 45,
      scheduledAt: scheduledAt ?? DateTime.now(),
    );
  }

  String storedSubject() {
    final ids = StorageService.getTodayTaskIds();
    expect(ids, isNotEmpty);
    return TodayTask.fromJsonString(StorageService.getTodayTaskJson(ids.first)!)
        .subject;
  }

  group('performAddTask', () {
    test('tạo mới thành công — hoàn tác xoá bỏ task vừa tạo', () async {
      final outcome = await AiCopilotService.performAddTask({
        'title': 'Toán ch5',
        'subject': 'Toán',
        'minutes': 45,
        'priority': 'high',
      });

      expect(outcome.kind, AiActionResultKind.done);
      expect(outcome.message, contains('Toán ch5'));
      expect(StorageService.getTodayTaskIds().length, 1);
      // Môn được chuẩn hoá trước khi ghi (AI-2.1) — thống kê theo môn không vỡ.
      expect(storedSubject(), '📐 Toán');

      await outcome.undo!();
      expect(StorageService.getTodayTaskIds(), isEmpty);
    });

    test('trùng → duplicate, không tạo thêm bản sao', () async {
      await repo.createTaskIfMissing(makeTask(id: 'a', title: 'Ôn hàm số'));
      final outcome = await AiCopilotService.performAddTask({
        'title': 'on HAM SO',
        'subject': 'Toán',
      });

      expect(outcome.kind, AiActionResultKind.duplicate);
      expect(StorageService.getTodayTaskIds(), ['a']);
      expect(outcome.undo, isNull);
    });

    test('không nói số phút → mặc định 25', () async {
      final outcome =
          await AiCopilotService.performAddTask({'title': 'Đọc bài'});
      expect(outcome.kind, AiActionResultKind.done);
      final task = TodayTask.fromJsonString(StorageService.getTodayTaskJson(
          StorageService.getTodayTaskIds().first)!);
      expect(task.estimateMinutes, 25);
    });

    test('có scheduledAt → đúng ngày AI hẹn', () async {
      final outcome = await AiCopilotService.performAddTask({
        'title': 'Luyện đề',
        'scheduledAt': '2026-12-31T20:00:00',
      });
      expect(outcome.kind, AiActionResultKind.done);
      final task = TodayTask.fromJsonString(StorageService.getTodayTaskJson(
          StorageService.getTodayTaskIds().first)!);
      expect(task.scheduledAt?.hour, 20);
      expect(task.scheduledAt?.day, 31);
      expect(task.scheduledAt?.month, 12);
    });
  });

  group('performEditTask', () {
    test('sửa số phút + tên mới → done, undo trả đúng snapshot', () async {
      await repo.createTaskIfMissing(makeTask(id: 't1'));

      final outcome = await AiCopilotService.performEditTask({
        'title': 'Toán ch5',
        'newTitle': 'Toán chuyên đề',
        'minutes': 60,
      });
      expect(outcome.kind, AiActionResultKind.done);

      final edited = repo.getTaskById('t1');
      expect(edited!.title, 'Toán chuyên đề');
      expect(edited.estimateMinutes, 60);

      await outcome.undo!();
      final restored = repo.getTaskById('t1');
      expect(restored!.title, 'Toán ch5');
      expect(restored.estimateMinutes, 45);
    });

    test('không tìm thấy task → failed, không tự tạo', () async {
      final outcome = await AiCopilotService.performEditTask({
        'title': 'Không tồn tại',
        'newTitle': 'Bậy',
      });
      expect(outcome.kind, AiActionResultKind.failed);
      expect(StorageService.getTodayTaskIds(), isEmpty);
    });

    test('AI chỉ đọc tên, không đưa giá trị mới → rejected (chờ form)',
        () async {
      await repo.createTaskIfMissing(makeTask(id: 't1'));
      final outcome =
          await AiCopilotService.performEditTask({'title': 'Toán ch5'});
      expect(outcome.kind, AiActionResultKind.rejected);
      expect(repo.getTaskById('t1')!.estimateMinutes, 45);
    });

    test('hasEditFields đọc đúng bộ giá trị thay đổi', () {
      expect(AiCopilotService.hasEditFields({'title': 'X'}), isFalse);
      expect(AiCopilotService.hasEditFields({'title': 'X', 'minutes': 30}),
          isTrue);
      expect(
          AiCopilotService.hasEditFields(
              {'title': 'X', 'scheduledAt': '2026-12-31'}),
          isTrue);
    });
  });

  group('performRescheduleTask', () {
    test('dời +2 ngày → done, undo trả về lịch cũ', () async {
      final today = DateTime.now();
      await repo.createTaskIfMissing(makeTask(id: 't1'));

      final outcome = await AiCopilotService.performRescheduleTask({
        'title': 'Toán ch5',
        'days': 2,
      });
      expect(outcome.kind, AiActionResultKind.done);

      final moved = repo.getTaskById('t1')!;
      final dayDiff = DateTime(moved.scheduledAt!.year,
              moved.scheduledAt!.month, moved.scheduledAt!.day)
          .difference(DateTime(today.year, today.month, today.day))
          .inDays;
      expect(dayDiff, 2);

      await outcome.undo!();
      final back = repo.getTaskById('t1')!;
      expect(back.scheduledAt!.year, today.year);
      expect(back.scheduledAt!.month, today.month);
      expect(back.scheduledAt!.day, today.day);
    });

    test('task đã hoàn thành → failed, không dời lịch', () async {
      await repo.createTaskIfMissing(makeTask(id: 't1'));
      await repo.toggleTaskDone('t1');

      final outcome = await AiCopilotService.performRescheduleTask({
        'title': 'Toán ch5',
        'days': 1,
      });
      // getTasksForDay() đã loại task xong nên không tìm thấy task gốc —
      // điều quan trọng là bế tắc (failed), tuyệt đối không dời lịch.
      expect(outcome.kind, AiActionResultKind.failed);
    });

    test('không tìm thấy task → failed', () async {
      final outcome = await AiCopilotService.performRescheduleTask({
        'title': 'Không tồn tại',
      });
      expect(outcome.kind, AiActionResultKind.failed);
    });
  });

  group('performSaveNote', () {
    test('ghi chú lưu thành công — undo xoá đúng ghi chú AI vừa tạo', () async {
      final outcome = await AiCopilotService.performSaveNote({
        'title': 'Công thức điện phân',
        'body': 'anot dương catot âm...',
        'subject': 'Hóa',
      });
      expect(outcome.kind, AiActionResultKind.done);

      final ids = StorageService.getStudyNoteIds();
      expect(ids.length, 1);
      final note =
          StudyNote.fromJsonString(StorageService.getStudyNoteJson(ids.first)!);
      expect(note.title, 'Công thức điện phân');

      await outcome.undo!();
      expect(StorageService.getStudyNoteIds(), isEmpty);
      expect(StorageService.getStudyNoteJson(ids.first), isNull);
    });
  });

  group('planFromAction — kế hoạch phải xem trước rồi mới áp dụng', () {
    AiCopilotAction planAction(Map<String, dynamic> payload) => AiCopilotAction(
          type: AiActionType.plan,
          label: 'Xem kế hoạch',
          icon: Icons.calendar_month_rounded,
          payload: payload,
        );

    test('payload hợp lệ → AiStudyPlan với ngày theo dayOffset', () {
      final now = DateTime(2026, 10, 17);
      final plan = AiCopilotService.planFromAction(
          planAction({
            'summary': 'Lộ trình 3 ngày',
            'tasks': [
              {
                'title': 'Ôn hàm số',
                'subject': 'Toán',
                'minutes': 45,
                'dayOffset': 0
              },
              {
                'title': 'Luyện đề',
                'subject': 'Hóa',
                'minutes': 90,
                'dayOffset': 1
              },
            ],
          }),
          now: now);

      expect(plan.tasks.length, 2);
      expect(plan.summary, 'Lộ trình 3 ngày');
      expect(plan.tasks[0].scheduledAt.day, 17);
      expect(plan.tasks[1].scheduledAt.day, 18);
      // phút bị kẹp về biên để kế hoạch không nướng 3 giờ liền.
      expect(plan.tasks[1].estimateMinutes, 90);
      // Không áp dụng gì trước khi người dùng bấm Áp dụng.
      expect(StorageService.getTodayTaskIds(), isEmpty);
    });

    test('task thiếu title bị bỏ, summary rỗng tự sinh', () {
      final plan = AiCopilotService.planFromAction(
          planAction({
            'tasks': [
              {'subject': 'Toán'},
              {'title': 'Hợp lệ'},
            ],
          }),
          now: DateTime(2026, 10, 17));
      expect(plan.tasks.length, 1);
      expect(plan.summary, contains('1 nhiệm vụ'));
    });
  });
}
