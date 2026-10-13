import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/ai/ai_chat_actions.dart';
import 'package:edupulse/core/ai/ai_copilot_service.dart';
import 'package:edupulse/core/ai/ai_sprint4_planner.dart';
import 'package:edupulse/core/ai/weekly_report.dart';
import 'package:edupulse/core/family/live_progress_service.dart';
import 'package:edupulse/core/sync/change_outbox.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/active_study_session.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/tasks/domain/models/task_state.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';

/// Gói test regression P0 (đặc tả mục 11 — "Test regression cho onboarding,
/// task completion, offline recovery, AI action confirmation và family
/// consent").
///
/// Mục tiêu không phải kiểm tra chi tiết từng widget (đã có test riêng) mà
/// khoá lại **những bất biến sống còn**: app không mất dữ liệu, không tự ý
/// sửa/xoá dữ liệu theo phản hồi AI, và không chia sẻ dữ liệu gia đình ngoài
/// phần người dùng đã đồng ý. Mọi test ở đây chạy offline, không gọi mạng.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    ChangeOutbox.reset();
    ChangeOutbox.deviceIdProvider = null;
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 1. ONBOARDING → KẾ HOẠCH ĐẦU TIÊN
  // ─────────────────────────────────────────────────────────────────────────
  group('P0 · Onboarding tạo kế hoạch đầu tiên', () {
    test('parsePlan kẹp thời lượng 10..120 phút và bỏ nhiệm vụ thiếu tiêu đề',
        () {
      final now = DateTime(2026, 5, 1, 8);
      final raw = jsonEncode({
        'summary': 'Tuần khởi đầu',
        'tasks': [
          {'title': 'Ôn hàm số', 'subject': 'Toán', 'day': 1, 'estimateMinutes': 5},
          {'title': 'Đọc lý thuyết', 'subject': 'Lý', 'day': 2, 'estimateMinutes': 999},
          {'title': '', 'subject': 'Hóa', 'day': 3, 'estimateMinutes': 30},
        ],
      });

      final plan = AiStudyPlannerService.parsePlan(raw, now);

      expect(plan.tasks, hasLength(2), reason: 'bỏ task thiếu tiêu đề');
      expect(plan.tasks[0].estimateMinutes, 10, reason: 'kẹp sàn 10 phút');
      expect(plan.tasks[1].estimateMinutes, 120, reason: 'kẹp trần 120 phút');
    });

    test('phản hồi hỏng → kế hoạch rỗng kèm cảnh báo, không crash', () {
      final plan =
          AiStudyPlannerService.parsePlan('{không phải json', DateTime.now());

      expect(plan.isEmpty, isTrue);
      expect(plan.summary, isNotEmpty,
          reason: 'phải có thông điệp dễ hiểu cho người dùng');
    });

    test('applyPlan tạo nhiệm vụ rồi chặn trùng khi chạy lại (idempotent)',
        () async {
      final now = DateTime(2026, 5, 1);
      final plan = AiStudyPlannerService.parsePlan(
        jsonEncode({
          'tasks': [
            {
              'title': 'Ôn hàm số',
              'subject': 'Toán',
              'date': '2026-05-01',
              'estimateMinutes': 45,
            },
          ],
        }),
        now,
      );

      final first = await AiStudyPlannerService.applyPlan(plan.tasks);
      expect(first.created, 1);
      expect(first.skipped, 0);

      final second = await AiStudyPlannerService.applyPlan(plan.tasks);
      expect(second.created, 0);
      expect(second.skipped, 1,
          reason: 'cùng tên + môn + ngày → không tạo trùng');
    });

    test('cờ hoàn tất onboarding được lưu bền', () {
      expect(StorageService.isOnboardingDone(), isFalse);
      StorageService.setOnboardingDone();
      expect(StorageService.isOnboardingDone(), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 2. TASK COMPLETION
  // ─────────────────────────────────────────────────────────────────────────
  group('P0 · Hoàn thành nhiệm vụ', () {
    TodayTask makeTask(String id) => TodayTask(
          id: id,
          title: 'Ôn tập $id',
          subject: 'Toán',
          scheduledAt: DateTime.now(),
        );

    test('toggleTaskDone lật nhiệm vụ sang completed', () async {
      await TaskRepository.instance.createTask(makeTask('t1'));

      final result = await TaskRepository.instance.toggleTaskDone('t1');

      expect(result.success, isTrue);
      final task = TaskRepository.instance.getTaskById('t1')!;
      expect(task.status, TaskStatus.completed.value);
      expect(task.isDone, isTrue);
    });

    test('bỏ tick mở lại nhiệm vụ về trạng thái đã lên lịch', () async {
      await TaskRepository.instance.createTask(makeTask('t2'));
      await TaskRepository.instance.toggleTaskDone('t2');

      await TaskRepository.instance.toggleTaskDone('t2');

      final task = TaskRepository.instance.getTaskById('t2')!;
      expect(task.status, TaskStatus.scheduled.value);
      expect(task.isDone, isFalse);
    });

    test('setTaskStatus completed ghi đúng trạng thái kết thúc', () async {
      await TaskRepository.instance.createTask(makeTask('t3'));

      final result = await TaskRepository.instance
          .setTaskStatus('t3', TaskStatus.completed);

      expect(result.success, isTrue);
      final task = TaskRepository.instance.getTaskById('t3')!;
      expect(task.status, TaskStatus.completed.value);
      expect(TaskStatus.completed.isTerminal, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 3. OFFLINE RECOVERY (outbox + phiên học dang dở)
  // ─────────────────────────────────────────────────────────────────────────
  group('P0 · Khôi phục khi offline', () {
    test('thay đổi khi offline vẫn còn sau khi mở lại app', () {
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      expect(ChangeOutbox.outstanding, hasLength(1));

      // Giả lập app bị tắt rồi mở lại: nạp hàng đợi từ storage.
      ChangeOutbox.reloadForTest();

      expect(ChangeOutbox.outstanding, hasLength(1),
          reason: 'ý định đồng bộ không được mất khi app khởi động lại');
      expect(ChangeOutbox.outstanding.single.entityId, 't1');
    });

    test('lần gửi bị ngắt giữa chừng được đưa về chờ gửi lại', () {
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      ChangeOutbox.markSyncing('task');
      expect(ChangeOutbox.items.single.status, ChangeStatus.syncing);

      ChangeOutbox.recoverInterrupted();

      expect(ChangeOutbox.items.single.status, ChangeStatus.pending,
          reason: 'app chết lúc đang gửi → lần sau phải thử lại, không mất');
    });

    test('hàng đợi hỏng/schema lạ bị cách ly nhưng dữ liệu học còn nguyên',
        () async {
      StorageService.setTodayTaskIds(const ['t1']);
      StorageService.setTodayTaskJson('t1', '{"id":"t1"}');
      SharedPreferences.setMockInitialValues({
        'onboarding_done': true,
        'today_task_ids': ['t1'],
        'task_t1': '{"id":"t1"}',
        ChangeOutbox.storageKey: jsonEncode({
          'schema': ChangeOutbox.schema + 1,
          'items': [
            {'id': 'x', 'entity': 'task', 'entityId': 't1'},
          ],
        }),
      });
      await StorageService.init();
      ChangeOutbox.reloadForTest();

      expect(ChangeOutbox.items, isEmpty);
      expect(StorageService.getString(ChangeOutbox.quarantineKey), isNotNull);
      expect(StorageService.getTodayTaskIds(), contains('t1'),
          reason: 'cách ly hàng đợi không được đụng vào dữ liệu học');
    });

    test('phiên học dang dở khôi phục đúng số giây còn lại', () {
      final now = DateTime(2026, 5, 1, 8);
      final session = ActiveStudySession(
        taskId: 't1',
        subject: 'Toán',
        totalSeconds: 25 * 60,
        remainingAtAnchor: 10 * 60,
        anchorAt: now.subtract(const Duration(minutes: 5)),
        startedAt: now.subtract(const Duration(minutes: 15)),
      );
      StudySessionRepository.instance.saveActive(session);

      final restored = StudySessionRepository.instance.getActive();

      expect(restored, isNotNull);
      expect(restored!.taskId, 't1');
      // 5 phút trôi qua khi app không mở: 10 - 5 = 5 phút còn lại.
      expect(restored.remainingAt(now), 5 * 60);
      expect(restored.elapsedMinutesAt(now), 20);
    });

    test('phiên treo quá 6 giờ không hỏi lại nữa', () {
      final now = DateTime(2026, 5, 1, 8);
      final stale = ActiveStudySession(
        taskId: 't1',
        subject: 'Toán',
        totalSeconds: 25 * 60,
        remainingAtAnchor: 10 * 60,
        anchorAt: now.subtract(const Duration(hours: 7)),
        startedAt: now.subtract(const Duration(hours: 7)),
      );
      expect(stale.isExpiredAt(now), isTrue);
    });

    test('ảnh chụp phiên hỏng → bỏ qua an toàn (null), không crash', () {
      StorageService.setString(
          StudySessionRepository.activeSessionKey, '{không phải json');
      expect(StudySessionRepository.instance.getActive(), isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 4. AI ACTION CONFIRMATION
  // ─────────────────────────────────────────────────────────────────────────
  group('P0 · Xác nhận hành động AI', () {
    test('parser bỏ qua loại hành động lạ (AI không được tự chế thao tác)', () {
      final parsed = AiChatActionParser.parse('''
Đây là lời khuyên.
<<<ACTIONS>>>
- label: Xoá sạch mọi dữ liệu | type: wipe_all | target: everything
- label: Gửi dữ liệu ra ngoài | type: exfiltrate | url: http://x
<<<END>>>''');

      expect(parsed.actions, isEmpty);
    });

    test('parser gắn cờ xoá cho delete_task (phải hỏi lại trước khi xoá)', () {
      final parsed = AiChatActionParser.parse('''
<<<ACTIONS>>>
- label: Xoá task ôn điện phân | type: delete_task | title: Ôn điện phân
<<<END>>>''');

      expect(parsed.actions, hasLength(1));
      expect(parsed.actions.single.type, AiActionType.deleteTask);
      expect(parsed.actions.single.label, contains('🗑'));
    });

    testWidgets('AI không xoá nhiệm vụ nếu người dùng chọn "Giữ lại"',
        (tester) async {
      await TaskRepository.instance.createTask(TodayTask(
        id: 't1',
        title: 'Ôn điện phân',
        subject: 'Toán',
        scheduledAt: DateTime.now(),
      ));

      await tester.pumpWidget(_actionHost(
        AiCopilotAction(
          type: AiActionType.deleteTask,
          label: '🗑 Xoá task ôn điện phân',
          icon: Icons.delete_outline_rounded,
          // Map phải thay đổi được: executeAction gắn callback vào payload.
          payload: {'title': 'Ôn điện phân'},
        ),
      ));

      await tester.tap(find.text('run'));
      await tester.pumpAndSettle();

      expect(find.text('Xóa nhiệm vụ?'), findsOneWidget);
      await tester.tap(find.text('Giữ lại'));
      await tester.pumpAndSettle();

      expect(
        TaskRepository.instance.getAllTasks().any((t) => t.id == 't1'),
        isTrue,
        reason: 'từ chối xác nhận → không thay đổi dữ liệu',
      );
    });

    testWidgets('AI xoá nhiệm vụ sau khi người dùng xác nhận "Xóa"',
        (tester) async {
      await TaskRepository.instance.createTask(TodayTask(
        id: 't9',
        title: 'Ôn điện phân',
        subject: 'Toán',
        scheduledAt: DateTime.now(),
      ));

      await tester.pumpWidget(_actionHost(
        AiCopilotAction(
          type: AiActionType.deleteTask,
          label: '🗑 Xoá task ôn điện phân',
          icon: Icons.delete_outline_rounded,
          // Map phải thay đổi được: executeAction gắn callback vào payload.
          payload: {'title': 'Ôn điện phân'},
        ),
      ));

      await tester.tap(find.text('run'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();

      expect(
        TaskRepository.instance.getAllTasks().any((t) => t.id == 't9'),
        isFalse,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 5. FAMILY CONSENT
  // ─────────────────────────────────────────────────────────────────────────
  group('P0 · Đồng thuận chia sẻ dữ liệu gia đình', () {
    test('tắt hết mọi mục → không dựng báo cáo (không chia sẻ gì)', () {
      final report = WeeklyReport.build(enabled: const {
        'study_time': false,
        'readiness': false,
        'mock_score': false,
        'exam_countdown': false,
      });

      expect(report, isNull);
    });

    test('báo cáo chỉ chứa mục con đã bật', () {
      final report = WeeklyReport.build(enabled: const {
        'study_time': true,
        'readiness': false,
        'mock_score': false,
        'exam_countdown': false,
      });

      expect(report, isNotNull);
      expect(report!.items.map((i) => i.key).toList(), const ['study_time']);
    });

    test('vân tay nội dung bỏ qua thời điểm dựng (không đẩy lại vô ích)', () {
      final a = WeeklyReport.build(enabled: WeeklyReport.defaultChoices)!;
      final b = WeeklyReport.build(enabled: WeeklyReport.defaultChoices)!;

      expect(LiveProgressService.fingerprintOf(a),
          LiveProgressService.fingerprintOf(b));
    });

    test('thu hồi chia sẻ (tắt công tắc) → xoá vân tay đã gửi', () async {
      StorageService.setString('family_live_fingerprint', 'vân-tay-cũ');

      final ok = await LiveProgressService.setEnabled(false);

      expect(ok, isTrue);
      expect(LiveProgressService.enabled, isFalse);
      expect(StorageService.getString('family_live_fingerprint'), isNull,
          reason: 'thu hồi → bật lại phải đẩy bản mới, không coi là đã gửi');
    });
  });
}

/// Widget tối giản có sẵn context để gọi [AiCopilotService.executeAction]
/// trong widget test (mô phỏng đúng đường đi khi người dùng bấm nút hành động).
Widget _actionHost(AiCopilotAction action) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => AiCopilotService.executeAction(context, action),
            child: const Text('run'),
          ),
        ),
      ),
    ),
  );
}
