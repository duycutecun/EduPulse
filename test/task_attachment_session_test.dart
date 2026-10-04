import 'dart:convert';

import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';
import 'package:edupulse/features/tasks/domain/models/task_attachment.dart';
import 'package:edupulse/features/tasks/domain/models/task_state.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';
import 'package:edupulse/features/tasks/presentation/widgets/task_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FE-2.2 — tài liệu đính kèm + lịch sử phiên học trong màn chi tiết.
void main() {
  late TaskRepository repo;
  late StudySessionRepository sessions;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    repo = TaskRepository.instance;
    sessions = StudySessionRepository.instance;
  });

  TodayTask makeTask({String id = 't1', String title = 'Ôn hàm số'}) => TodayTask(
        id: id,
        title: title,
        subject: '📐 Toán',
        priority: 'medium',
        estimateMinutes: 45,
      );

  Future<TodayTask> seedTask({String id = 't1'}) async {
    final result = await repo.createTask(makeTask(id: id));
    return result.task!;
  }

  List<int> pngBytes([int size = 1024]) => List<int>.filled(size, 7);

  group('Tài liệu đính kèm', () {
    test('gắn tài liệu rồi đọc lại được nội dung', () async {
      final task = await seedTask();

      final added = repo.addAttachment(
        task.id,
        name: 'bài-tập-3.png',
        bytes: pngBytes(2048),
      );

      expect(added.success, isTrue);
      final attachments = repo.listAttachments(task.id);
      expect(attachments, hasLength(1));
      expect(attachments.single.name, 'bài-tập-3.png');
      expect(attachments.single.sizeBytes, 2048);
      expect(base64Decode(attachments.single.base64), pngBytes(2048));
    });

    test('ảnh vượt 250KB bị chặn kèm thông báo nói rõ giới hạn', () async {
      final task = await seedTask();

      final added = repo.addAttachment(
        task.id,
        name: 'lon.png',
        bytes: pngBytes(TaskAttachment.maxBytes + 1),
      );

      expect(added.failed, isTrue);
      expect(added.error, contains('250KB'));
      expect(repo.listAttachments(task.id), isEmpty);
    });

    test('tệp rỗng bị chặn', () async {
      final task = await seedTask();
      final added = repo.addAttachment(task.id, name: 'rong.png', bytes: []);
      expect(added.failed, isTrue);
    });

    test('tối đa 3 tài liệu, tệp thứ 4 bị chặn', () async {
      final task = await seedTask();
      for (var i = 0; i < TaskAttachment.maxCount; i++) {
        expect(
          repo
              .addAttachment(task.id, name: 'a$i.png', bytes: pngBytes())
              .success,
          isTrue,
        );
      }

      final extra = repo.addAttachment(task.id, name: 'a3.png', bytes: pngBytes());
      expect(extra.failed, isTrue);
      expect(extra.error, contains('3'));
      expect(repo.listAttachments(task.id), hasLength(TaskAttachment.maxCount));
    });

    test('tệp mới thêm lên đầu danh sách', () async {
      final task = await seedTask();
      repo.addAttachment(task.id, name: 'cũ.png', bytes: pngBytes(),
          addedAt: DateTime(2026, 1, 1));
      repo.addAttachment(task.id, name: 'mới.png', bytes: pngBytes(),
          addedAt: DateTime(2026, 5, 1));

      expect(repo.listAttachments(task.id).first.name, 'mới.png');
    });

    test('tệp JSON hỏng bị bỏ qua, không làm hỏng cả danh sách', () async {
      final task = await seedTask();
      repo.addAttachment(task.id, name: 'ok.png', bytes: pngBytes());
      StorageService.setTaskAttachmentJson(task.id, 'bad', '{không phải json');

      final attachments = repo.listAttachments(task.id);
      expect(attachments, hasLength(1));
      expect(attachments.single.name, 'ok.png');
    });

    test('gỡ tài liệu rồi hoàn tác thì giữ nguyên id và thứ tự', () async {
      final task = await seedTask();
      repo.addAttachment(task.id, name: 'a.png', bytes: pngBytes(),
          addedAt: DateTime(2026, 3, 1));
      final second = repo
          .addAttachment(task.id, name: 'b.png', bytes: pngBytes(),
              addedAt: DateTime(2026, 4, 1))
          .success;

      expect(second, isTrue);
      final target = repo.listAttachments(task.id).first;
      expect(repo.removeAttachment(task.id, target.id).success, isTrue);
      expect(repo.listAttachments(task.id), hasLength(1));

      expect(repo.restoreAttachment(task.id, target).success, isTrue);
      final restored = repo.listAttachments(task.id).first;
      expect(restored.id, target.id);
      expect(restored.name, 'b.png');
    });

    test('gắn tài liệu lên task không tồn tại thì báo lỗi, không ghi rác',
        () async {
      final added = repo.addAttachment('khong-ton-tai',
          name: 'x.png', bytes: pngBytes());
      expect(added.failed, isTrue);
      expect(added.error, contains('Không tìm thấy'));
    });

    test('tài liệu của task khác không lẫn sang', () async {
      final a = await seedTask(id: 'a');
      final b = await seedTask(id: 'b');
      repo.addAttachment(a.id, name: 'cua-a.png', bytes: pngBytes());

      expect(repo.listAttachments(b.id), isEmpty);
    });
  });

  group('Tài liệu đính kèm đi theo vòng đời task', () {
    test('xoá task thì ảnh không còn mồ côi, Undo trả lại nguyên vẹn',
        () async {
      final task = await seedTask();
      repo.addAttachment(task.id, name: 'a.png', bytes: pngBytes(512));
      repo.addAttachment(task.id, name: 'b.png', bytes: pngBytes(512));

      final ref = await repo.deleteTask(task.id);
      expect(repo.listAttachments(task.id), isEmpty);
      expect(ref.attachments, hasLength(2));

      await repo.restoreTask(ref);
      final back = repo.listAttachments(task.id);
      expect(back, hasLength(2));
      expect(back.map((a) => a.name).toSet(), {'a.png', 'b.png'});
    });

    test('chia nhỏ thì tài liệu theo task cha và Undo trả lại', () async {
      final task = await seedTask();
      repo.addAttachment(task.id, name: 'goc.png', bytes: pngBytes());

      final split = await repo.splitTask(task.id);
      expect(split.success, isTrue);
      expect(repo.listAttachments(task.id), isEmpty);
      expect(
        repo.listAttachments(split.parts.first.id),
        isEmpty,
        reason: 'phần con không tự mang tài liệu của cả bài',
      );

      await repo.undoSplit(split);
      expect(repo.listAttachments(task.id), hasLength(1));
      expect(repo.listAttachments(task.id).single.name, 'goc.png');
    });
  });

  group('Lịch sử phiên học của nhiệm vụ', () {
    StudySession makeSession({
      required String id,
      String? taskId,
      required DateTime completedAt,
      int actual = 45,
      int planned = 45,
    }) =>
        StudySession(
          id: id,
          completedAt: completedAt,
          taskId: taskId,
          subject: '📐 Toán',
          plannedMinutes: planned,
          actualMinutes: actual,
        );

    test('chỉ lấy phiên gắn với đúng task, mới nhất trước', () async {
      final task = await seedTask();
      final other = await seedTask(id: 'other');

      await sessions.save(makeSession(
        id: 's1',
        taskId: task.id,
        completedAt: DateTime(2026, 1, 1),
      ));
      await sessions.save(makeSession(
        id: 's2',
        taskId: task.id,
        completedAt: DateTime(2026, 3, 1),
      ));
      await sessions.save(makeSession(
        id: 's3',
        taskId: other.id,
        completedAt: DateTime(2026, 2, 1),
      ));
      // Phiên Pomodoro rời rạc không thuộc task nào.
      await sessions.save(makeSession(
        id: 's4',
        completedAt: DateTime(2026, 4, 1),
      ));

      final history = sessions.getForTask(task.id);
      expect(history.map((s) => s.id), ['s2', 's1']);
    });

    test('tổng phút chỉ tính phần thực tế', () async {
      final task = await seedTask();
      await sessions.save(makeSession(
        id: 's1',
        taskId: task.id,
        completedAt: DateTime(2026, 1, 1),
        actual: 30,
        planned: 45,
      ));
      await sessions.save(makeSession(
        id: 's2',
        taskId: task.id,
        completedAt: DateTime(2026, 1, 2),
        actual: 15,
        planned: 45,
      ));

      expect(sessions.totalMinutesForTask(task.id), 45);
    });

    test('task chưa có phiên nào → danh sách rỗng, không lỗi', () async {
      final task = await seedTask();
      expect(sessions.getForTask(task.id), isEmpty);
      expect(sessions.getForTask('khong-ton-tai'), isEmpty);
      expect(sessions.getForTask(''), isEmpty);
      expect(sessions.totalMinutesForTask(task.id), 0);
    });

    test('phiên JSON hỏng bị bỏ qua, phiên tốt vẫn hiện', () async {
      final task = await seedTask();
      await sessions.save(makeSession(
        id: 's1',
        taskId: task.id,
        completedAt: DateTime(2026, 1, 1),
      ));
      StorageService.setStudySessionJson('bad', '{hỏng');
      StorageService.setStudySessionIds(
          [...StorageService.getStudySessionIds(), 'bad']);

      expect(sessions.getForTask(task.id), hasLength(1));
      expect(sessions.getAll(), hasLength(1));
    });

    test('cập nhật phản hồi chỉ đổi trường được yêu cầu', () async {
      final task = await seedTask();
      await sessions.save(makeSession(
        id: 's1',
        taskId: task.id,
        completedAt: DateTime(2026, 1, 1),
      ));

      expect(await sessions.updateFeedback('s1', focus: 4), isTrue);
      final updated = sessions.getForTask(task.id).single;
      expect(updated.focus, 4);
      expect(updated.difficulty, isNull);
      expect(updated.reflectionNote, isNull);
    });

    test('xoá phiên thật sự mất khỏi storage', () async {
      final task = await seedTask();
      await sessions.save(makeSession(
        id: 's1',
        taskId: task.id,
        completedAt: DateTime(2026, 1, 1),
      ));

      sessions.delete('s1');
      expect(sessions.getForTask(task.id), isEmpty);
      expect(StorageService.getStudySessionIds(), isNot(contains('s1')));
    });

    test('lưu cùng một phiên hai lần không nhân bản', () async {
      final task = await seedTask();
      final session = makeSession(
        id: 's1',
        taskId: task.id,
        completedAt: DateTime(2026, 1, 1),
      );
      await sessions.save(session);
      await sessions.save(session);

      expect(StorageService.getStudySessionIds().where((id) => id == 's1'),
          hasLength(1));
    });
  });

  group('Trạng thái task sau khi có tài liệu', () {
    test('đánh dấu hoàn thành không đụng tới tài liệu', () async {
      final task = await seedTask();
      repo.addAttachment(task.id, name: 'a.png', bytes: pngBytes());

      await repo.toggleTaskDone(task.id);

      expect(repo.listAttachments(task.id), hasLength(1));
      expect(repo.getTaskById(task.id)!.status, TaskStatus.completed.value);
    });

    test('sửa tiêu đề không đụng tới tài liệu', () async {
      final task = await seedTask();
      repo.addAttachment(task.id, name: 'a.png', bytes: pngBytes());

      task.title = 'Ôn hàm số nâng cao';
      await repo.updateTask(task);

      expect(repo.listAttachments(task.id), hasLength(1));
    });
  });

  group('Màn chi tiết hiện 2 khối mới', () {
    Future<void> pumpSheet(WidgetTester tester, TodayTask task) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TaskDetailSheet(
            task: task,
            onTaskUpdated: (_) {},
            onStartStudy: (_) {},
            onEdit: (_) {},
            onReschedule: (_) {},
            onDelete: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('task mới: hiện empty state của cả tài liệu và lịch sử',
        (tester) async {
      final task = await seedTask();
      await pumpSheet(tester, task);

      expect(find.text('Tài liệu kèm theo'), findsOneWidget);
      expect(find.textContaining('Chưa có tài liệu'), findsOneWidget);
      expect(find.text('Lịch sử phiên học'), findsOneWidget);
      expect(find.textContaining('Chưa có phiên học nào'), findsOneWidget);
    });

    testWidgets('có tài liệu và phiên học thì hiện dữ liệu thật',
        (tester) async {
      final task = await seedTask();
      repo.addAttachment(task.id, name: 'bài-tập-3.png', bytes: pngBytes());
      await sessions.save(StudySession(
        id: 's1',
        completedAt: DateTime(2026, 1, 5),
        taskId: task.id,
        subject: '📐 Toán',
        plannedMinutes: 45,
        actualMinutes: 30,
      ));

      await pumpSheet(tester, task);

      expect(find.text('bài-tập-3.png'), findsOneWidget);
      expect(find.textContaining('1 KB'), findsOneWidget);
      expect(find.textContaining('Đã học 30 phút trong 1 phiên'), findsOneWidget);
      expect(find.textContaining('30/45 phút'), findsOneWidget);
    });

    testWidgets('đạt giới hạn thì nút gắn tài liệu bị khoá', (tester) async {
      final task = await seedTask();
      for (var i = 0; i < TaskAttachment.maxCount; i++) {
        repo.addAttachment(task.id, name: 'a$i.png', bytes: pngBytes());
      }

      await pumpSheet(tester, task);

      expect(find.text('3/3'), findsOneWidget);
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.block_rounded),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('BE-3.1 — lưu đủ đầu/cuối/trạng thái phiên học', () {
    StudySession makeSession({
      String id = 's1',
      String subject = '📐 Toán',
      int actual = 25,
      DateTime? at,
      DateTime? startedAt,
      String? status,
      String? taskId,
    }) {
      final end = at ?? DateTime.now();
      return StudySession(
        id: id,
        completedAt: end,
        taskId: taskId,
        subject: subject,
        plannedMinutes: 25,
        actualMinutes: actual,
        startedAt: startedAt,
        endedAt: end,
        status: status,
      );
    }

    test('giữ startedAt, endedAt và status qua vòng ghi/đọc', () {
      final end = DateTime(2026, 3, 14, 21, 5);
      final start = end.subtract(const Duration(minutes: 25));

      final restored = StudySession.fromJsonString(
        makeSession(at: end, startedAt: start, status: StudySession.statusCompleted)
            .toJsonString(),
      );

      expect(restored.startedAt, start);
      expect(restored.endedAt, end);
      expect(restored.status, StudySession.statusCompleted);
      expect(restored.isCompleted, isTrue);
      expect(restored.elapsed, const Duration(minutes: 25));
    });

    test('phiên cũ chỉ có completedAt vẫn đọc được, mặc định là hoàn thành',
        () {
      // Đây là dữ liệu đã nằm trên máy người dùng, không có `startedAt`.
      final legacy = StudySession.fromJsonString(jsonEncode({
        'id': 'old-1',
        'completedAt': '2026-01-02T07:00:00.000',
        'subject': '📐 Toán',
        'plannedMinutes': 25,
        'actualMinutes': 24,
      }));

      expect(legacy.startedAt, isNull);
      expect(legacy.endedAt, isNull);
      expect(legacy.status, isNull);
      expect(legacy.isCompleted, isTrue);
      expect(legacy.actualMinutes, 24);
    });

    test('phiên dừng giữa chừng đánh dấu cancelled, không phải hoàn thành', () {
      final session = makeSession(status: StudySession.statusCancelled);

      expect(session.isCompleted, isFalse);
      expect(
        StudySession.fromJsonString(session.toJsonString()).isCompleted,
        isFalse,
      );
    });

    test('feedbackRating tính từ các thang chi tiết, không lưu trùng', () {
      expect(StudySession(id: 'x', completedAt: DateTime.now(), subject: '', plannedMinutes: 0, actualMinutes: 0).feedbackRating,
          isNull);

      final rated = makeSession()
        ..mood = 5
        ..focus = 4
        ..understanding = 5;
      expect(rated.feedbackRating, 5);

      final mixed = makeSession(id: 's2')
        ..mood = 2
        ..focus = 3;
      expect(mixed.feedbackRating, 3);

      // Trường phái sinh không được ghi xuống JSON để không tạo nguồn sự thật thứ hai.
      expect(rated.toJson().containsKey('feedbackRating'), isFalse);
    });

    test('minutesOn chỉ tính phiên trong ngày được yêu cầu', () {
      sessions.save(makeSession(id: 'd1', at: DateTime(2026, 3, 14, 8), actual: 25));
      sessions.save(makeSession(id: 'd2', at: DateTime(2026, 3, 14, 21), actual: 25));
      sessions.save(makeSession(id: 'd3', at: DateTime(2026, 3, 15, 8), actual: 50));

      expect(sessions.minutesOn(DateTime(2026, 3, 14)), 50);
      expect(sessions.minutesOn(DateTime(2026, 3, 15)), 50);
      expect(sessions.minutesOn(DateTime(2026, 3, 16)), 0);
    });

    test('minutesForSubject gộp được môn ghi có/không emoji', () {
      sessions.save(makeSession(id: 'm1', subject: '📐 Toán', actual: 25));
      sessions.save(makeSession(id: 'm2', subject: 'Toán', actual: 25));
      sessions.save(makeSession(id: 'm3', subject: '⚡ Lý', actual: 25));

      // '📐 Toán' và 'Toán' là hai cách ghi của cùng một môn (xem subject_catalog).
      expect(sessions.minutesForSubject('Toán'), 50);
      expect(sessions.minutesForSubject('📐 Toán'), 50);
      expect(sessions.minutesForSubject('Ly'), 25);
      expect(sessions.minutesForSubject('  '), 0);
    });

    test('tổng phút theo ngày và theo môn dùng chung một nguồn', () {
      final at = DateTime(2026, 3, 14, 20);
      sessions.save(makeSession(id: 's', at: at, actual: 25, taskId: 't1'));

      expect(sessions.totalMinutesForTask('t1'), 25);
      expect(sessions.minutesOn(at), 25);
      expect(sessions.minutesForSubject('📐 Toán', day: at), 25);
      expect(sessions.minutesForSubject('📐 Toán', day: at.add(const Duration(days: 1))), 0);
    });
  });
}