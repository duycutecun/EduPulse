import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/sync/change_outbox.dart';
import 'package:edupulse/core/sync/sync_state.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/core/utils/supabase_service.dart';
import 'package:edupulse/features/exams/domain/exam_repository.dart';
import 'package:edupulse/features/exams/domain/models/exam_model.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';
import 'package:edupulse/shared/widgets/sync_status_bar.dart';

/// P0-1 / kế hoạch 7.2 — nối hàng đợi thay đổi vào đường ghi thật và vào UI.
///
/// Test này trả lời đúng câu hỏi mà trước đây không ai trả lời được: sau khi
/// học sinh sửa dữ liệu lúc đang offline, app có **biết** là còn thay đổi chưa
/// lên cloud không, và có **nói được** cho học sinh biết không?
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    ChangeOutbox.reset();
    ChangeOutbox.deviceIdProvider = () => 'dev_test';
    SupabaseService.setConfiguredOverride(null);
    // Trạng thái sync là static — đưa về mặc định đã đồng bộ trước mỗi test.
    SyncStateService.state.value = const SyncState(status: SyncStatus.synced);
  });

  tearDown(() {
    ChangeOutbox.deviceIdProvider = null;
    SupabaseService.setConfiguredOverride(null);
  });

  group('Đường ghi thật ghi nhận thay đổi (7.2)', () {
    TodayTask task(String id) => TodayTask(
          id: id,
          title: 'Ôn tập $id',
          subject: '📐 Toán',
          priority: 'medium',
          estimateMinutes: 45,
        );

    test('tạo nhiệm vụ → một dòng chờ đồng bộ, gộp khi sửa nhiều lần',
        () async {
      final repo = TaskRepository.instance;

      await repo.createTask(task('t1'));
      expect(ChangeOutbox.pendingCount, 1);
      expect(ChangeOutbox.outstanding.single.entity, 'task');
      expect(ChangeOutbox.outstanding.single.deviceId, 'dev_test');

      await repo.toggleTaskDone('t1');
      await repo.updateTask(task('t1'));
      expect(ChangeOutbox.pendingCount, 1,
          reason: 'sửa cùng một nhiệm vụ không được nhân dòng');
    });

    test('xoá nhiệm vụ → dòng mang ý định xoá', () async {
      final repo = TaskRepository.instance;
      await repo.createTask(task('t1'));
      ChangeOutbox.markAllSynced();

      await repo.deleteTask('t1');

      expect(ChangeOutbox.pendingCount, 1);
      expect(ChangeOutbox.outstanding.single.op, PendingChange.opDelete);
    });

    test('lưu phiên học → dòng chờ; xoá phiên → dòng xoá', () async {
      final repo = StudySessionRepository.instance;
      final session = StudySession(
        id: 's1',
        completedAt: DateTime(2026, 3, 18, 9),
        subject: '📐 Toán',
        plannedMinutes: 25,
        actualMinutes: 25,
      );

      await repo.save(session);
      expect(ChangeOutbox.outstanding.single.entity, 'session');
      expect(ChangeOutbox.outstanding.single.entityId, 's1');

      ChangeOutbox.markAllSynced();
      repo.delete('s1');
      expect(ChangeOutbox.outstanding.single.op, PendingChange.opDelete);
    });

    test('lưu và xoá kỳ thi → dòng upsert rồi dòng xoá', () {
      final repo = ExamRepository.instance;
      repo.save(ExamModel(
        id: 'e1',
        name: 'THPTQG 2026',
        dateTime: DateTime(2026, 6, 11),
      ));

      expect(ChangeOutbox.outstanding.single.entity, 'exam');
      expect(ChangeOutbox.outstanding.single.op, PendingChange.opUpsert);

      repo.delete('e1');
      expect(ChangeOutbox.outstanding.single.op, PendingChange.opDelete);
    });

    test('dữ liệu khôi phục từ cloud KHÔNG tạo dòng chờ (không đẩy ngược)',
        () async {
      TaskRepository.instance.notifyExternalChange();

      expect(ChangeOutbox.pendingCount, 0);
    });
  });

  group('Nhãn trạng thái nói được còn gì chưa lên cloud', () {
    test('cloud chưa cấu hình → giấu con số, giữ câu nhẹ nhàng như cũ', () {
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      ChangeOutbox.enqueue(entity: 'task', entityId: 't2');

      const state = SyncState(status: SyncStatus.syncing);
      expect(state.visiblePending, 0,
          reason: 'máy chưa đăng nhập thì "chờ đồng bộ" là câu vô nghĩa');
      expect(state.label, 'Đang đồng bộ…');
    });

    test('đã cấu hình cloud → nhãn nói rõ số thay đổi còn trên máy', () {
      SupabaseService.setConfiguredOverride(true);
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      ChangeOutbox.enqueue(entity: 'exam', entityId: 'e1');

      expect(const SyncState(status: SyncStatus.synced).label,
          '2 thay đổi chờ đồng bộ');
      expect(const SyncState(status: SyncStatus.offline).label,
          contains('2 thay đổi'));
      expect(const SyncState(status: SyncStatus.syncing).label,
          'Đang đồng bộ 2 thay đổi…');
    });

    test('có thay đổi gửi lỗi → nhãn mời thử lại', () {
      SupabaseService.setConfiguredOverride(true);
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      ChangeOutbox.markFailedForEntity('task', 'network');

      expect(const SyncState(status: SyncStatus.synced).label,
          '1 thay đổi chưa gửi được — chạm để thử lại');
    });

    test('đồng bộ xong hết → quay lại câu "đã đồng bộ lúc nào"', () {
      SupabaseService.setConfiguredOverride(true);
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      ChangeOutbox.markAllSynced();

      final state = SyncState(
        status: SyncStatus.synced,
        lastSyncedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      expect(state.label, 'Đã đồng bộ vừa xong');
    });
  });

  group('Chip trạng thái', () {
    Future<void> pumpChip(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: SyncStatusBar())),
      ));
      await tester.pump();
    }

    testWidgets('còn thay đổi chờ → chip hiện số và bấm được để thử lại',
        (tester) async {
      SupabaseService.setConfiguredOverride(true);
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      ChangeOutbox.enqueue(entity: 'session', entityId: 's1');
      SyncStateService.updateConnectivity(isOnline: true);

      await pumpChip(tester);

      expect(find.text('2 thay đổi chờ đồng bộ'), findsOneWidget);
      final tappable = find.ancestor(
        of: find.text('2 thay đổi chờ đồng bộ'),
        matching: find.byType(InkWell),
      );
      expect(tappable, findsOneWidget,
          reason: 'phải có đường thử lại ngay tại chỗ, không bắt người dùng '
              'mò vào cài đặt');

      await tester.tap(find.text('2 thay đổi chờ đồng bộ'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('không có thay đổi nào chờ → chip tĩnh như trước',
        (tester) async {
      SupabaseService.setConfiguredOverride(true);
      SyncStateService.updateConnectivity(isOnline: true);

      await pumpChip(tester);

      expect(find.byType(InkWell), findsNothing);
      expect(find.text('Chưa đồng bộ'), findsOneWidget);
    });

    testWidgets('ngoại tuyến mà còn thay đổi → nói rõ dữ liệu vẫn an toàn',
        (tester) async {
      SupabaseService.setConfiguredOverride(true);
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      SyncStateService.updateConnectivity(isOnline: false);

      await pumpChip(tester);

      expect(find.text('Ngoại tuyến — 1 thay đổi chờ gửi'), findsOneWidget);
    });
  });

  group('Mở lại app sau khi tắt giữa lúc sync (7.2)', () {
    test('recoverAfterRestart trả thay đổi bỏ dở về hàng chờ', () {
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      ChangeOutbox.markAllSyncing();
      ChangeOutbox.reloadForTest();

      SyncStateService.recoverAfterRestart();

      expect(ChangeOutbox.pendingCount, 1);
      expect(ChangeOutbox.items.single.status, ChangeStatus.pending);
      expect(SyncStateService.state.value.status, isNot(SyncStatus.syncing));
    });
  });

  group('Thẻ trạng thái đồng bộ ở tab Tôi (7.2)', () {
    Future<void> pumpCard(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SyncStatusCard()),
      ));
      await tester.pump();
    }

    testWidgets('còn thay đổi chờ → nói rõ số và có nút đồng bộ ngay',
        (tester) async {
      SupabaseService.setConfiguredOverride(true);
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      ChangeOutbox.enqueue(entity: 'task', entityId: 't2');
      SyncStateService.updateConnectivity(isOnline: true);

      await pumpCard(tester);

      expect(find.text('2 thay đổi chờ đồng bộ'), findsOneWidget);
      expect(find.byKey(const Key('account-sync-retry')), findsOneWidget);
      expect(find.text('Đồng bộ ngay'), findsOneWidget);

      await tester.tap(find.byKey(const Key('account-sync-retry')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('có thay đổi gửi lỗi → mời thử lại', (tester) async {
      SupabaseService.setConfiguredOverride(true);
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      ChangeOutbox.markFailedForEntity('task', 'network');
      SyncStateService.updateConnectivity(isOnline: true);

      await pumpCard(tester);

      expect(find.text('1 thay đổi chưa gửi được'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('chưa bật cloud → thẻ nói dữ liệu lưu trên máy, giấu số',
        (tester) async {
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      SyncStateService.updateConnectivity(isOnline: true);

      await pumpCard(tester);

      expect(find.text('Dữ liệu lưu trên máy này'), findsOneWidget);
      expect(find.byKey(const Key('account-sync-retry')), findsNothing);
      expect(find.textContaining('thay đổi'), findsNothing);
    });

    testWidgets('mất mạng mà còn thay đổi → vẫn trấn an dữ liệu an toàn',
        (tester) async {
      SupabaseService.setConfiguredOverride(true);
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      SyncStateService.updateConnectivity(isOnline: false);

      await pumpCard(tester);

      expect(find.text('Ngoại tuyến — dữ liệu lưu an toàn trên máy'),
          findsOneWidget);
      expect(find.text('1 thay đổi sẽ tự gửi khi có mạng trở lại.'),
          findsOneWidget);
    });
  });
}
