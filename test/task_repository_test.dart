import 'dart:io';

import 'package:edupulse/core/migration/data_migration.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';
import 'package:edupulse/features/tasks/domain/models/task_state.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// QA-2.1 — hành vi của Single Source of Truth cho Task.
///
/// Điểm cốt lõi được kiểm ở đây: **mọi lần xóa đều có thể hoàn tác**, và
/// **chuyển trạng thái sai không được ghi dữ liệu**.
void main() {
  late TaskRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    repo = TaskRepository.instance;
  });

  TodayTask makeTask({
    String id = 't1',
    String title = 'Ôn tập',
    DateTime? scheduledAt,
    DateTime? deadline,
    String priority = 'medium',
    String? note,
  }) {
    return TodayTask(
      id: id,
      title: title,
      subject: '📐 Toán',
      priority: priority,
      estimateMinutes: 45,
      scheduledAt: scheduledAt,
      deadline: deadline,
      note: note,
    );
  }

  group('createTask', () {
    test('ghi task + đăng ký id, đóng dấu createdAt/updatedAt', () async {
      final task = makeTask();
      final result = await repo.createTask(task);

      expect(result.success, isTrue);
      expect(StorageService.getTodayTaskIds(), contains('t1'));
      final saved = repo.getTaskById('t1');
      expect(saved, isNotNull);
      expect(saved!.createdAt, isNotNull);
      expect(saved.updatedAt, isNotNull);
    });

    test('id trùng → update, không nhân bản', () async {
      await repo.createTask(makeTask());
      await repo.createTask(makeTask(title: 'Sửa lại'));

      expect(StorageService.getTodayTaskIds().length, 1);
      expect(repo.getTaskById('t1')!.title, 'Sửa lại');
    });

    test('tạo lại 2 task giữ đúng thứ tự', () async {
      await repo.createTask(makeTask(id: 'a'));
      await repo.createTask(makeTask(id: 'b'));
      await repo.createTask(makeTask(id: 'c'));
      expect(StorageService.getTodayTaskIds(), ['a', 'b', 'c']);
    });
  });

  group('updateTask', () {
    test('giữ nguyên id và createdAt khi sửa', () async {
      await repo.createTask(makeTask());
      final before = repo.getTaskById('t1')!;

      await Future<void>.delayed(const Duration(milliseconds: 5));
      final edited = before.copyWith(title: 'Đã đổi tên');
      await repo.updateTask(edited);

      final after = repo.getTaskById('t1')!;
      expect(after.title, 'Đã đổi tên');
      expect(after.createdAt, before.createdAt);
      expect(after.updatedAt!.isAfter(before.updatedAt!), isTrue);
    });

    test('sửa task không tồn tại → báo lỗi, không ghi rác', () async {
      final result = await repo.updateTask(makeTask(id: 'ghost'));
      expect(result.failed, isTrue);
      expect(result.error, contains('không còn tồn tại'));
      expect(StorageService.getTodayTaskIds(), isEmpty);
    });
  });

  group('toggleTaskDone — qua state machine', () {
test('todo → completed, isDone đồng bộ', () async {
      await repo.createTask(makeTask());

      final result = await repo.toggleTaskDone('t1');
      expect(result.success, isTrue);
      final task = repo.getTaskById('t1')!;
      expect(task.isDone, isTrue);
      expect(task.status, TaskStatus.completed.value);
    });

    test('task mới không có skipReason', () async {
      await repo.createTask(makeTask());
      expect(repo.getTaskById('t1')!.skipReason, isNull);
    });

    test('completed → todo (bỏ đánh dấu)', () async {
      await repo.createTask(makeTask());
      await repo.toggleTaskDone('t1');
      final result = await repo.toggleTaskDone('t1');

      expect(result.success, isTrue);
      expect(repo.getTaskById('t1')!.isDone, isFalse);
    });

    test('task không tồn tại → lỗi rõ ràng', () async {
      final result = await repo.toggleTaskDone('ghost');
      expect(result.failed, isTrue);
      expect(result.error, contains('Không tìm thấy'));
    });
  });

  group('setTaskStatus — chặn chuyển trạng thái nguy hiểm', () {
    test('completed → rescheduled bị từ chối, dữ liệu giữ nguyên', () async {
      await repo.createTask(makeTask());
      await repo.toggleTaskDone('t1');
      final doneAt = repo.getTaskById('t1')!.updatedAt;

      final result =
          await repo.setTaskStatus('t1', TaskStatus.rescheduled);

      expect(result.failed, isTrue);
      expect(result.error, contains('Không thể chuyển'));
      final task = repo.getTaskById('t1')!;
      expect(task.status, TaskStatus.completed.value);
      expect(task.updatedAt, doneAt, reason: 'bị từ chối thì không được ghi lại');
    });

    test('skipped → completed bị từ chối', () async {
      await repo.createTask(makeTask());
      await repo.skipTask('t1', reason: 'Quá khó');

      final result = await repo.setTaskStatus('t1', TaskStatus.completed);
      expect(result.failed, isTrue);
      expect(repo.getTaskById('t1')!.status, TaskStatus.notCompleted.value);
    });

    test('bỏ qua kèm lý do được lưu đúng', () async {
      await repo.createTask(makeTask());
      final result = await repo.skipTask('t1', reason: 'Không đủ thời gian');

      expect(result.success, isTrue);
      final task = repo.getTaskById('t1')!;
      expect(task.status, TaskStatus.notCompleted.value);
      expect(task.isDone, isFalse);
      expect(task.skipReason, 'Không đủ thời gian');
    });
  });

  group('rescheduleTask — cập nhật task hiện tại, không tạo bản sao (FE-2.4)', () {
    test('đổi ngày, tăng rescheduleCount, reset về todo', () async {
      final now = DateTime.now();
      await repo.createTask(makeTask(scheduledAt: now));
      final tomorrow = now.add(const Duration(days: 1));

      final result = await repo.rescheduleTask('t1', tomorrow);

      expect(result.success, isTrue);
      expect(StorageService.getTodayTaskIds().length, 1,
          reason: 'không được sinh task trùng');
      final task = repo.getTaskById('t1')!;
      expect(task.rescheduleCount, 1);
      expect(task.status, TaskStatus.scheduled.value);
      expect(task.isDone, isFalse);
      expect(DateUtils.dateOnly(task.scheduledAt!),
          DateUtils.dateOnly(tomorrow));
    });

    test('giữ nguyên giờ đã hẹn, chỉ đổi ngày', () async {
      final now = DateTime.now();
      await repo.createTask(
          makeTask(scheduledAt: DateTime(now.year, now.month, now.day, 20, 30)));

      final target = now.add(const Duration(days: 3));
      await repo.rescheduleTask('t1', target);

      final task = repo.getTaskById('t1')!;
      expect(task.scheduledAt!.hour, 20);
      expect(task.scheduledAt!.minute, 30);
      expect(DateUtils.dateOnly(task.scheduledAt!), DateUtils.dateOnly(target));
    });

    test('task đã hoàn thành không được dời', () async {
      await repo.createTask(makeTask());
      await repo.toggleTaskDone('t1');

      final result =
          await repo.rescheduleTask('t1', DateTime.now().add(const Duration(days: 2)));
      expect(result.failed, isTrue);
      expect(repo.getTaskById('t1')!.status, TaskStatus.completed.value);
    });

    test('dời nhiều lần vẫn chỉ có 1 task', () async {
      await repo.createTask(makeTask());
      final now = DateTime.now();
      for (var i = 1; i <= 4; i++) {
        await repo.rescheduleTask('t1', now.add(Duration(days: i)));
      }
      expect(StorageService.getTodayTaskIds().length, 1);
      expect(repo.getTaskById('t1')!.rescheduleCount, 4);
    });
  });

  group('deleteTask + restoreTask — FE-2.5 Undo', () {
    test('xóa rồi hoàn tác: task trở lại nguyên vẹn và đúng vị trí', () async {
      await repo.createTask(makeTask(id: 'a'));
      await repo.createTask(makeTask(id: 'b'));
      await repo.createTask(makeTask(id: 'c'));

      final ref = await repo.deleteTask('b');
      expect(StorageService.getTodayTaskIds(), ['a', 'c']);
      expect(repo.getTaskById('b'), isNull);

      await repo.restoreTask(ref);
      expect(StorageService.getTodayTaskIds(), ['a', 'b', 'c']);
      final restored = repo.getTaskById('b')!;
      expect(restored.title, 'Ôn tập');
      expect(restored.createdAt, isNotNull);
    });

test('hoàn tác nhiều lần xóa liên tiếp giữ đúng thứ tự', () async {
      await repo.createTask(makeTask(id: 'a'));
      await repo.createTask(makeTask(id: 'b'));

      final refA = await repo.deleteTask('a');
      final refB = await repo.deleteTask('b');
      expect(StorageService.getTodayTaskIds(), isEmpty);

      // Hoàn tác theo thứ tự ngược thời gian (đúng thứ tự người dùng gặp).
      await repo.restoreTask(refB);
      await repo.restoreTask(refA);
      expect(StorageService.getTodayTaskIds(), ['a', 'b']);
    });

    test('xóa task cuối cùng trong danh sách → vị trí 0', () async {
      await repo.createTask(makeTask(id: 'a'));
      await repo.createTask(makeTask(id: 'b'));
      final ref = await repo.deleteTask('b');
      await repo.restoreTask(ref);
      expect(StorageService.getTodayTaskIds().indexOf('b'), 1);
    });
  });

  group('reorderTasks — đổi thứ tự không mất task', () {
    test('sắp xếp lại đúng thứ tự yêu cầu', () async {
      await repo.createTask(makeTask(id: 'a'));
      await repo.createTask(makeTask(id: 'b'));
      await repo.createTask(makeTask(id: 'c'));

      await repo.reorderTasks(['c', 'a', 'b']);
      expect(StorageService.getTodayTaskIds(), ['c', 'a', 'b']);
    });

    test('id lạ bị bỏ qua, task chưa nhắc tới được giữ lại', () async {
      await repo.createTask(makeTask(id: 'a'));
      await repo.createTask(makeTask(id: 'b'));
      await repo.createTask(makeTask(id: 'c'));

      await repo.reorderTasks(['c', 'ghost-id']);

      final ids = StorageService.getTodayTaskIds();
      expect(ids, ['c', 'a', 'b']);
      expect(ids.length, 3, reason: 'không task nào được mất');
    });

    test('id lặp trong yêu cầu không sinh bản ghi trùng', () async {
      await repo.createTask(makeTask(id: 'a'));
      await repo.createTask(makeTask(id: 'b'));

      await repo.reorderTasks(['a', 'a', 'a']);
      expect(StorageService.getTodayTaskIds(), ['a', 'b']);
    });
  });

  group('splitTask — Chia nhỏ (FE-2.1/FE-2.2)', () {
    test('chia 2 phần: tổng phút giữ nguyên, tên có (i/n)', () async {
      await repo.createTask(makeTask(note: 'ghi chú dài'));

      final split = await repo.splitTask('t1');

      expect(split.success, isTrue);
      expect(split.parts.length, 2, reason: '45 phút ÷ 25 → 2 phần');
      final total = split.parts.fold<int>(0, (s, p) => s + p.estimateMinutes);
      expect(total, 45, reason: 'không được mất phút nào');
      expect(split.parts.first.title, contains('(1/2)'));
      expect(split.parts.last.title, contains('(2/2)'));
    });

    test('task gốc bị thay thế, không tồn tại song song', () async {
      await repo.createTask(makeTask());
      final split = await repo.splitTask('t1', parts: 3);

      expect(repo.getTaskById('t1'), isNull);
      final ids = StorageService.getTodayTaskIds();
      expect(ids.length, 3);
      for (final part in split.parts) {
        expect(ids, contains(part.id));
        expect(repo.getTaskById(part.id)!.isDone, isFalse);
      }
    });

    test('giữ môn, chủ đề, hạn chót, giờ hẹn; ghi chú chỉ ở phần đầu', () async {
      final now = DateTime.now();
      await repo.createTask(makeTask(
        scheduledAt: now,
        deadline: now.add(const Duration(days: 2)),
        note: 'tập trung đoạn 3',
      ));

      final split = await repo.splitTask('t1', parts: 2);

      for (final part in split.parts) {
        expect(part.subject, '📐 Toán');
        expect(part.deadline, now.add(const Duration(days: 2)));
        expect(part.scheduledAt, now);
      }
      expect(split.parts.first.note, 'tập trung đoạn 3');
      expect(split.parts.last.note, isNull);
    });

    test('phần đều nhau: 60 phút ÷ 3 = 20 mỗi phần', () async {
      await repo.createTask(makeTask());
      await repo.updateTask(repo.getTaskById('t1')!.copyWith(estimateMinutes: 60));

      final split = await repo.splitTask('t1', parts: 3);
      expect(split.parts.map((p) => p.estimateMinutes), [20, 20, 20]);
    });

    test('phần dư được dồn vào phần đầu, không mất phút', () async {
      await repo.createTask(makeTask());
      final split = await repo.splitTask('t1', parts: 3);
      expect(split.parts.map((p) => p.estimateMinutes), [15, 15, 15]);
    });

    test('task ≤ 25 phút không chia được', () async {
      await repo.createTask(makeTask());
      final task = repo.getTaskById('t1')!;
      await repo.updateTask(task.copyWith(estimateMinutes: 20));

      final split = await repo.splitTask('t1');
      expect(split.failed, isTrue);
      expect(split.error, contains('đủ ngắn'));
      expect(StorageService.getTodayTaskIds(), ['t1']);
    });

    test('task đã hoàn thành không chia được', () async {
      await repo.createTask(makeTask());
      await repo.toggleTaskDone('t1');

      final split = await repo.splitTask('t1');
      expect(split.failed, isTrue);
      expect(repo.getTaskById('t1'), isNotNull);
    });

    test('id không tồn tại → lỗi, không ghi rác', () async {
      final split = await repo.splitTask('ghost');
      expect(split.failed, isTrue);
      expect(StorageService.getTodayTaskIds(), isEmpty);
    });

    test('undoSplit trả lại đúng task gốc và đúng vị trí', () async {
      await repo.createTask(makeTask(id: 'a'));
      await repo.createTask(makeTask(id: 'b', title: 'Bài dài 90 phút'));
      await repo.updateTask(
          repo.getTaskById('b')!.copyWith(estimateMinutes: 90));

      final split = await repo.splitTask('b');
      expect(split.success, isTrue);
      expect(split.parts.length, 4, reason: '90 phút ÷ 25 → 4 phần');
      expect(StorageService.getTodayTaskIds().length, 5, reason: 'a + 4 phần');

      await repo.undoSplit(split);

      expect(StorageService.getTodayTaskIds(), ['a', 'b']);
      final original = repo.getTaskById('b')!;
      expect(original.title, 'Bài dài 90 phút');
      expect(original.estimateMinutes, 90);
    });

    test('undoSplit xoá hết phần con', () async {
      await repo.createTask(makeTask());
      final split = await repo.splitTask('t1', parts: 4);
      expect(split.parts.length, 4);

      await repo.undoSplit(split);

      expect(StorageService.getTodayTaskIds(), ['t1']);
      for (final part in split.parts) {
        expect(repo.getTaskById(part.id), isNull);
      }
    });

    test('chia nhỏ nhiều lần không sinh id trùng, không mất task', () async {
      await repo.createTask(makeTask());
      await repo.updateTask(repo.getTaskById('t1')!.copyWith(estimateMinutes: 90));

      final first = await repo.splitTask('t1', parts: 2);
      expect(first.parts.map((p) => p.estimateMinutes), [45, 45]);

      final second = await repo.splitTask(first.parts.first.id, parts: 2);
      expect(second.success, isTrue);

      final ids = StorageService.getTodayTaskIds();
      expect(ids.length, 3, reason: '2 phần đầu, 1 bị thay bằng 2 phần mới');
      expect(ids.length, ids.toSet().length, reason: 'id phải là duy nhất');
      expect(repo.getTaskById('t1'), isNull);
      for (final id in ids) {
        expect(repo.getTaskById(id), isNotNull);
      }
    });
  });

  group('getTasksForDay — bộ lọc "hôm nay" duy nhất', () {
    test('task ngày mai không hiện ở hôm nay', () async {
      await repo.createTask(makeTask(
          id: 'today', scheduledAt: DateTime.now()));
      await repo.createTask(makeTask(
          id: 'tomorrow',
          scheduledAt: DateTime.now().add(const Duration(days: 1))));

      final ids = repo.getTasksForDay().map((t) => t.id).toList();
      expect(ids, ['today']);
    });

    test('task quá hạn chưa xong vẫn thấy ở hôm nay', () async {
      await repo.createTask(makeTask(
        id: 'overdue',
        deadline: DateTime.now().subtract(const Duration(days: 3)),
      ));
      expect(repo.getTasksForDay().map((t) => t.id), ['overdue']);
    });

    test('task đã hoàn thành không kéo theo vào ngày mới', () async {
      await repo.createTask(makeTask(
          id: 'done', scheduledAt: DateTime.now()));
      await repo.toggleTaskDone('done');

      expect(repo.getTasksForDay(), isEmpty);
    });

    test('task không lịch không hạn → thuộc hôm nay', () async {
      await repo.createTask(makeTask(id: 'loose'));
      expect(repo.getTasksForDay().map((t) => t.id), ['loose']);
    });

    test('task không lịch không hạn không hiện ở ngày khác', () async {
      await repo.createTask(makeTask(id: 'loose'));
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(repo.getTasksForDay(tomorrow), isEmpty);
    });

    test('lọc theo ngày được yêu cầu', () async {
      final now = DateTime.now();
      await repo.createTask(makeTask(
          id: 'd1', scheduledAt: now.add(const Duration(days: 1))));
      await repo.createTask(makeTask(
          id: 'd2', scheduledAt: now.add(const Duration(days: 2))));

      expect(repo.getTasksForDay(now.add(const Duration(days: 2)))
          .map((t) => t.id), ['d2']);
    });

    test('task JSON hỏng không làm sập danh sách', () async {
      await repo.createTask(makeTask(id: 'good'));
      StorageService.setTodayTaskJson('bad', '{không phải json');

      final ids = repo.getTasksForDay().map((t) => t.id).toList();
      expect(ids, contains('good'));
      expect(repo.getTaskById('bad'), isNull);
    });
  });

  group('revision — tín hiệu refresh cho UI', () {
    test('mọi mutation đều tăng revision', () async {
      final start = repo.revision.value;
      await repo.createTask(makeTask());
      expect(repo.revision.value, greaterThan(start));
    });

    test('mutation bị từ chối thì revision không đổi', () async {
      await repo.createTask(makeTask());
      await repo.toggleTaskDone('t1');
      final before = repo.revision.value;

      final rejected =
          await repo.setTaskStatus('t1', TaskStatus.rescheduled);
      expect(rejected.failed, isTrue);
      expect(repo.revision.value, before);
    });
  });

  group('offline-first (QA-2.1)', () {
    test('ghi local thành công dù cloud chưa cấu hình', () async {
      // SupabaseService.isConfigured = false trong test ⇒ không gọi network,
      // nhưng thao tác local vẫn phải hoàn tất.
      await repo.createTask(makeTask());
      expect(repo.getTaskById('t1'), isNotNull);
    });

    test('dữ liệu sống sót qua vòng đời app (đọc lại từ storage)', () async {
      await repo.createTask(makeTask(note: 'ghi chú'));
      // Mô phỏng app bị kill và mở lại: chỉ storage còn.
      final reloaded = TodayTask.fromJsonString(
          StorageService.getTodayTaskJson('t1')!);
      expect(reloaded.note, 'ghi chú');
      expect(reloaded.subject, '📐 Toán');
    });
  });

  group('migration v2 (BE-2.3) tương thích dữ liệu cũ', () {
test('task v1 không có createdAt/updatedAt → được backfill', () async {
      SharedPreferences.setMockInitialValues({
        'today_task_ids': ['legacy-1'],
        'task_legacy-1': '{"id":"legacy-1","title":"Bài cũ",'
            '"subject":"📐 Toán","estimateMinutes":30}',
      });
      await StorageService.init();

      expect(DataMigration.needsMigration(), isTrue);
      final report = DataMigration.run(DataMigration.defaultSteps());

      expect(report.success, isTrue);
      final migrated = repo.getTaskById('legacy-1')!;
      expect(migrated.title, 'Bài cũ', reason: 'không mất task');
      expect(migrated.estimateMinutes, 30);
      expect(migrated.createdAt, isNotNull);
      expect(migrated.updatedAt, isNotNull);
      expect(DataMigration.needsMigration(), isFalse,
          reason: 'đã đánh dấu version mới');
    });

    test('task mồ côi (mất khỏi danh sách id) được cứu lại', () async {
      SharedPreferences.setMockInitialValues({
        'today_task_ids': <String>[],
        'task_orphan': '{"id":"orphan","title":"Task mồ côi",'
            '"subject":"📐 Toán","estimateMinutes":30}',
      });
      await StorageService.init();

      final report = DataMigration.run(DataMigration.defaultSteps());

      expect(report.success, isTrue);
      expect(StorageService.getTodayTaskIds(), contains('orphan'));
      expect(repo.getTaskById('orphan')!.title, 'Task mồ côi');
    });

    test('JSON hỏng được giữ nguyên, không xoá', () async {
      SharedPreferences.setMockInitialValues({
        'today_task_ids': ['broken'],
        'task_broken': '{không phải json',
      });
      await StorageService.init();

      final report = DataMigration.run(DataMigration.defaultSteps());

      expect(report.success, isTrue);
      expect(StorageService.getTodayTaskJson('broken'), '{không phải json');
    });

    test('isDone và status mâu thuẫn → vá theo status', () async {
      SharedPreferences.setMockInitialValues({
        'today_task_ids': ['conflict'],
'task_conflict': '{"id":"conflict","title":"X",'
            '"subject":"📐 Toán","estimateMinutes":20,'
            '"status":"todo","isDone":true}',
      });
      await StorageService.init();

      DataMigration.run(DataMigration.defaultSteps());

      final task = repo.getTaskById('conflict')!;
      expect(task.status, 'todo');
      expect(task.isDone, isFalse);
    });

    test('skipped giữ nguyên skipReason', () async {
      SharedPreferences.setMockInitialValues({
        'today_task_ids': ['skipped-task'],
        'task_skipped-task': '{"id":"skipped-task","title":"X",'
            '"subject":"📐 Toán","estimateMinutes":20,'
            '"status":"skipped","isDone":false,"skipReason":"Quá khó"}',
      });
      await StorageService.init();

      DataMigration.run(DataMigration.defaultSteps());

      final task = repo.getTaskById('skipped-task')!;
      expect(task.status, 'skipped');
      expect(task.skipReason, 'Quá khó');
      expect(task.isDone, isFalse);
    });

test('migration là idempotent — chạy lại không đổi dữ liệu', () async {
      SharedPreferences.setMockInitialValues({
        'today_task_ids': ['a'],
        'task_a': '{"id":"a","title":"A","subject":"📐 Toán",'
            '"estimateMinutes":20,"status":"todo"}',
      });
      await StorageService.init();

      DataMigration.run(DataMigration.defaultSteps());
      final first = repo.getTaskById('a')!.toJsonString();
      final created1 = repo.getTaskById('a')!.createdAt;

      // Ép chạy lại từ version cũ: phải cho kết quả y hệt, không nhân bản,
      // không đổi createdAt (backfill lần 2 không được ghi đè timestamp thật).
      StorageService.setInt('data_schema_version', 0);
      expect(DataMigration.needsMigration(), isTrue);
      DataMigration.run(DataMigration.defaultSteps());

expect(StorageService.getTodayTaskIds(), ['a']);
      expect(repo.getTaskById('a')!.toJsonString(), first);
      expect(repo.getTaskById('a')!.createdAt, created1,
          reason: 'không được đổi createdAt');
    });
  });

  group('migration v3 — dọn StudyLog trùng của pomodoro', () {
    String logJson(String id, String subject, double hours, String note, String iso) =>
        '{"id":"$id","subject":"$subject","hours":$hours,'
        '"date":"$iso","note":"$note"}';

    Future<void> seed({
      required List<Map<String, String>> logs,
      required List<Map<String, String>> sessions,
    }) async {
      final values = <String, Object>{
        'study_log_ids': logs.map((l) => l['id']!).toList(),
        'study_session_ids': sessions.map((s) => s['id']!).toList(),
      };
      for (final log in logs) {
        values['study_log_${log['id']}'] = log['json']!;
      }
      for (final s in sessions) {
        values['study_session_${s['id']}'] = s['json']!;
      }
      SharedPreferences.setMockInitialValues(values);
      await StorageService.init();
    }

    test('xoá dòng log trùng, GIỮ phiên học (bản ghi giàu thông tin hơn)',
        () async {
      final at = DateTime(2026, 5, 4, 14, 30).toIso8601String();
      await seed(
        logs: [
          {
            'id': 'dup',
            'json': logJson('dup', '📐 Toán', 0.4166666666666667,
                'Focus: On tap phan', at),
          }
        ],
        sessions: [
          {
            'id': 's1',
            'json': '{"id":"s1","completedAt":"$at","subject":"📐 Toán",'
                '"plannedMinutes":25,"actualMinutes":25,"understanding":4}',
          }
        ],
      );

      final report = DataMigration.run(DataMigration.defaultSteps());

      expect(report.success, isTrue);
      expect(StorageService.getStudyLogIds(), isEmpty,
          reason: 'dòng log trùng phải biến mất');
      expect(StudySessionRepository.instance.getAll(), hasLength(1),
          reason: 'phiên học phải còn nguyên');
    });

    test('ghi chú nhập tay của người dùng được giữ', () async {
      final at = DateTime(2026, 5, 4, 9).toIso8601String();
      await seed(
        logs: [
          {
            'id': 'manual',
            'json': logJson('manual', '📐 Toán', 1.5, 'Ôn bài tập chưa làm', at),
          }
        ],
        sessions: const [],
      );

      DataMigration.run(DataMigration.defaultSteps());

      expect(StorageService.getStudyLogIds(), ['manual']);
    });

    test('ghi chú mẫu "Phiên N" của bản cũ bị xoá dù không còn phiên học',
        () async {
      final at = DateTime(2026, 4, 1, 8).toIso8601String();
      await seed(
        logs: [
          {'id': 'r1', 'json': logJson('r1', 'Pomodoro', 0.4166666666666667, 'Phiên 3', at)}
        ],
        sessions: const [],
      );

      DataMigration.run(DataMigration.defaultSteps());

      expect(StorageService.getStudyLogIds(), isEmpty);
    });

    test('log khác độ dài hoặc khác môn với phiên học thì giữ lại', () async {
      final at = DateTime(2026, 5, 4, 14, 30).toIso8601String();
      await seed(
        logs: [
          {
            'id': 'other-subject',
            'json': logJson('other-subject', '📚 Văn', 0.4166666666666667, '', at),
          },
          {
            'id': 'other-length',
            'json': logJson('other-length', '📐 Toán', 2.0, '', at),
          },
        ],
        sessions: [
          {
            'id': 's1',
            'json': '{"id":"s1","completedAt":"$at","subject":"📐 Toán",'
                '"plannedMinutes":25,"actualMinutes":25}',
          }
        ],
      );

      DataMigration.run(DataMigration.defaultSteps());

      expect(StorageService.getStudyLogIds(),
          containsAll(['other-subject', 'other-length']));
    });

    test('idempotent: chạy lại không xoá thêm dòng nhập tay còn lại', () async {
      final at = DateTime(2026, 5, 4, 9).toIso8601String();
      await seed(
        logs: [
          {'id': 'dup', 'json': logJson('dup', '📐 Toán', 0.4166666666666667, 'Phiên 1', at)},
          {'id': 'manual', 'json': logJson('manual', '📐 Toán', 1.0, 'tự ghi', at)},
        ],
        sessions: const [],
      );

      DataMigration.run(DataMigration.defaultSteps());
      expect(StorageService.getStudyLogIds(), ['manual']);

      StorageService.setInt('data_schema_version', 0);
      DataMigration.run(DataMigration.defaultSteps());
      expect(StorageService.getStudyLogIds(), ['manual']);
    });
  });

  group('Single Write Path — không màn nào tự ghi Task', () {
    // Tầng hạ tầng được phép ghi trực tiếp: repository là nơi duy nhất quyết
    // định luật, còn storage/migration/sync/backup thao tác trên khoá thô.
    const allowed = {
      'lib/core/utils/storage_service.dart',
      'lib/core/migration/data_migration.dart',
      'lib/core/utils/data_transfer.dart',
      'lib/core/utils/supabase_service.dart',
      'lib/features/tasks/domain/repositories/task_repository.dart',
      'lib/features/study/domain/repositories/study_session_repository.dart',
    };
    const forbidden = [
      'setTodayTaskJson',
      'setTodayTaskIds',
      'removeTodayTask',
      'setTaskAttachmentJson',
      'setTaskAttachmentIds',
      'setStudySessionJson',
      'setStudySessionIds',
      'removeStudySession',
    ];

    test('mọi màn hình đi qua TaskRepository', () {
      final offenders = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        if (allowed.contains(path)) continue;

        final source = entity.readAsStringSync();
        for (final call in forbidden) {
          if (source.contains('$call(')) {
            offenders.add('$path → $call()');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'Các màn tự ghi Task vòng qua repository sẽ mất '
              'createdAt, chống trùng và Undo:\n${offenders.join('\n')}');
    });

    test('chỉ repository mới giải mã được StudySession', () {
      // Đọc phiên học ở 6 nơi từng tự lặp `try/catch` + jsonDecode, nên phiên
      // JSON hỏng bị nuốt im lặng ở một chỗ lại hiện ra ở chỗ khác.
      const allowed = {
        'lib/features/study/domain/models/study_models.dart',
        'lib/features/study/domain/repositories/study_session_repository.dart',
      };

      // Ranh giới trước tên là bắt buộc: `ActiveStudySession.fromJson` chứa
      // nguyên văn chuỗi `StudySession.fromJson`, nên khớp bằng `contains` sẽ
      // cấm oan một tệp hoàn toàn không đụng tới `StudySession`.
      final decoderPattern =
          RegExp(r'(?<![A-Za-z0-9_])StudySession\.fromJson(String)?\s*\(');

      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        if (allowed.contains(path)) continue;

        final match = decoderPattern.firstMatch(entity.readAsStringSync());
        if (match != null) {
          offenders.add('$path → ${match.group(0)!.trim()}');
        }
      }

      expect(offenders, isEmpty,
          reason: 'Hãy đọc phiên học qua StudySessionRepository:\n'
              '${offenders.join('\n')}');
    });
  });
}

