import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/sync/change_outbox.dart';
import 'package:edupulse/core/utils/storage_service.dart';

/// P0-1 / kế hoạch 7.2 — hàng đợi thay đổi cục bộ.
///
/// Những gì test này khoá lại là những gì trước đây **không có gì** đảm bảo:
/// mỗi thay đổi có id/mốc thời gian/thiết bị/schema, gộp theo bản ghi, sống
/// sót qua lần app bị tắt giữa lúc sync, và không bao giờ làm mất dữ liệu
/// người dùng khi payload hỏng.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    ChangeOutbox.reset();
  });

  tearDown(() => ChangeOutbox.deviceIdProvider = null);

  group('Ghi nhận thay đổi (7.2)', () {
    test('mỗi thay đổi có id, entity, mốc thời gian, thiết bị và schema', () {
      ChangeOutbox.deviceIdProvider = () => 'dev_A';

      final change = ChangeOutbox.enqueue(
        entity: 'task',
        entityId: 't1',
        at: DateTime(2026, 3, 18, 9, 30),
      );

      expect(change.entity, 'task');
      expect(change.entityId, 't1');
      expect(change.op, PendingChange.opUpsert);
      expect(change.status, ChangeStatus.pending);
      expect(change.attempts, 0);
      expect(change.deviceId, 'dev_A');
      expect(change.schemaVersion, ChangeOutbox.schema);
      expect(change.updatedAt, DateTime(2026, 3, 18, 9, 30).millisecondsSinceEpoch);
      expect(ChangeOutbox.pendingCount, 1);
    });

    test('sửa cùng một bản ghi nhiều lần → chỉ một dòng, giữ id đầu tiên', () {
      final first =
          ChangeOutbox.enqueue(entity: 'task', entityId: 't1', at: DateTime(2026, 1, 1));
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1', at: DateTime(2026, 1, 2));
      final last =
          ChangeOutbox.enqueue(entity: 'task', entityId: 't1', at: DateTime(2026, 1, 3));

      expect(ChangeOutbox.items.length, 1);
      expect(ChangeOutbox.pendingCount, 1);
      expect(last.id, first.id, reason: 'gộp theo bản ghi, không nhân dòng');
      expect(last.updatedAt, DateTime(2026, 1, 3).millisecondsSinceEpoch);
    });

    test('upsert rồi xoá → dòng duy nhất mang ý định xoá mới nhất', () {
      ChangeOutbox.enqueue(entity: 'exam', entityId: 'e1');
      ChangeOutbox.enqueue(
        entity: 'exam',
        entityId: 'e1',
        op: PendingChange.opDelete,
      );

      expect(ChangeOutbox.items.length, 1);
      expect(ChangeOutbox.items.single.op, PendingChange.opDelete);
    });

    test('khác bản ghi → khác dòng', () {
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      ChangeOutbox.enqueue(entity: 'task', entityId: 't2');
      ChangeOutbox.enqueue(entity: 'session', entityId: 's1');

      expect(ChangeOutbox.pendingCount, 3);
    });
  });

  group('Sống sót qua lần mở app sau (7.2)', () {
    test('hàng đợi được ghi xuống máy và đọc lại nguyên vẹn', () {
      ChangeOutbox.deviceIdProvider = () => 'dev_A';
      ChangeOutbox.enqueue(
        entity: 'task',
        entityId: 't1',
        at: DateTime(2026, 3, 18, 9, 30),
      );
      ChangeOutbox.enqueue(entity: 'session', entityId: 's1');

      // Mô phỏng app bị tắt rồi mở lại: quên RAM, đọc lại từ storage.
      ChangeOutbox.reloadForTest();

      expect(ChangeOutbox.pendingCount, 2);
      final task = ChangeOutbox.items.firstWhere((c) => c.entityId == 't1');
      expect(task.deviceId, 'dev_A');
      expect(task.updatedAt, DateTime(2026, 3, 18, 9, 30).millisecondsSinceEpoch);
    });

    test('dòng còn "đang gửi" khi app bị tắt → trả về hàng chờ, không kẹt', () {
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      ChangeOutbox.enqueue(entity: 'exam', entityId: 'e1');
      ChangeOutbox.markAllSyncing();
      expect(ChangeOutbox.failedCount, 0);

      ChangeOutbox.reloadForTest();
      final recovered = ChangeOutbox.recoverInterrupted();

      expect(recovered, 2);
      expect(ChangeOutbox.pendingCount, 2);
      expect(
        ChangeOutbox.items.every((c) => c.status == ChangeStatus.pending),
        isTrue,
        reason: 'không thay đổi nào được phép nằm mãi ở trạng thái đang gửi',
      );
    });

    test('recoverInterrupted không đụng dòng đã đồng bộ xong', () {
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      ChangeOutbox.markSyncedForEntity('task');
      ChangeOutbox.enqueue(entity: 'exam', entityId: 'e1');
      ChangeOutbox.markAllSyncing();

      expect(ChangeOutbox.recoverInterrupted(), 1);
      expect(ChangeOutbox.outstanding.single.entity, 'exam');
      expect(ChangeOutbox.pendingCount, 1);
    });
  });

  group('Dọn hàng đợi theo kết quả sync', () {
    test('một nhánh đồng bộ xong → chỉ dọn dòng của nhánh đó', () {
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      ChangeOutbox.enqueue(entity: 'exam', entityId: 'e1');

      ChangeOutbox.markSyncedForEntity('task');

      expect(ChangeOutbox.pendingCount, 1);
      expect(ChangeOutbox.outstanding.single.entity, 'exam');
      expect(ChangeOutbox.syncedCount, 1);
    });

    test('gửi lỗi → giữ lại, đếm số lần thử và lưu lý do', () {
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      ChangeOutbox.markFailedForEntity('task', 'network');
      ChangeOutbox.markFailedForEntity('task');

      final change = ChangeOutbox.items.single;
      expect(change.status, ChangeStatus.failed);
      expect(change.attempts, 2);
      expect(change.lastError, 'network');
      expect(ChangeOutbox.failedCount, 1);
      expect(ChangeOutbox.pendingCount, 1,
          reason: 'dòng lỗi vẫn là thay đổi chưa lên cloud');
    });

    test('thử lại thành công → hết lỗi và hết chờ', () {
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      ChangeOutbox.markFailedForEntity('task', 'network');

      ChangeOutbox.markSyncedForEntity('task');

      expect(ChangeOutbox.failedCount, 0);
      expect(ChangeOutbox.pendingCount, 0);
    });

    test('cả vòng syncAll thành công → sạch hàng đợi', () {
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      ChangeOutbox.enqueue(entity: 'session', entityId: 's1');
      ChangeOutbox.markAllSynced();

      expect(ChangeOutbox.pendingCount, 0);
      expect(ChangeOutbox.syncedCount, 2);
    });

    test('clearSynced chỉ bỏ dòng đã xong', () {
      ChangeOutbox.enqueue(entity: 'task', entityId: 't1');
      ChangeOutbox.enqueue(entity: 'exam', entityId: 'e1');
      ChangeOutbox.markSyncedForEntity('task');

      ChangeOutbox.clearSynced();

      expect(ChangeOutbox.items.length, 1);
      expect(ChangeOutbox.items.single.entity, 'exam');
    });
  });

  group('Không bao giờ làm mất dữ liệu vì hàng đợi hỏng (7.1)', () {
    test('payload hỏng → cách ly, hàng đợi mới rỗng, dữ liệu khác còn nguyên',
        () async {
      SharedPreferences.setMockInitialValues({
        ChangeOutbox.storageKey: '{không phải json',
        'today_task_ids': ['t1'],
        'task_t1': '{"id":"t1"}',
      });
      await StorageService.init();
      ChangeOutbox.reloadForTest();

      expect(ChangeOutbox.items, isEmpty);
      expect(StorageService.getString(ChangeOutbox.quarantineKey),
          '{không phải json',
          reason: 'giữ lại bản hỏng để tra cứu, không xoá thẳng');
      expect(StorageService.getString(ChangeOutbox.storageKey), isNull);
      // Dữ liệu học của người dùng không bị đụng tới.
      expect(StorageService.getTodayTaskIds(), ['t1']);
      expect(StorageService.getTodayTaskJson('t1'), '{"id":"t1"}');
    });

    test('schema lạ (bản mới hơn app) → cách ly thay vì đoán bừa', () async {
      SharedPreferences.setMockInitialValues({
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
    });

    test('một dòng hỏng không làm hỏng cả hàng đợi', () async {
      SharedPreferences.setMockInitialValues({
        ChangeOutbox.storageKey: jsonEncode({
          'schema': ChangeOutbox.schema,
          'items': [
            {'không': 'hợp lệ'},
            {
              'id': 'ok',
              'entity': 'task',
              'entityId': 't1',
              'op': 'upsert',
              'updatedAt': 1,
              'deviceId': 'dev_A',
              'schemaVersion': 1,
              'status': 'pending',
            },
          ],
        }),
      });
      await StorageService.init();
      ChangeOutbox.reloadForTest();

      expect(ChangeOutbox.items.length, 1);
      expect(ChangeOutbox.items.single.id, 'ok');
    });

    test('vượt trần → gộp bớt dòng cũ nhất, không phình vô hạn', () {
      for (var i = 0; i < ChangeOutbox.maxEntries + 25; i++) {
        ChangeOutbox.enqueue(entity: 'task', entityId: 't$i');
      }

      expect(ChangeOutbox.items.length, ChangeOutbox.maxEntries);
      // Dòng mới nhất vẫn còn (thay đổi vừa xảy ra không bị cắt).
      expect(
        ChangeOutbox.items.any(
            (c) => c.entityId == 't${ChangeOutbox.maxEntries + 24}'),
        isTrue,
      );
    });
  });

  test('payload ghi xuống có schema version để lần sau đọc đúng cách', () {
    ChangeOutbox.enqueue(entity: 'task', entityId: 't1');

    final raw = StorageService.getString(ChangeOutbox.storageKey);
    final data = jsonDecode(raw!) as Map<String, dynamic>;

    expect(data['schema'], ChangeOutbox.schema);
    expect((data['items'] as List).single['schemaVersion'], ChangeOutbox.schema);
  });
}
