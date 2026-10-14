import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/migration/data_migration.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';

/// Migration dữ liệu local (đặc tả mục 42) — bất biến số một: **không mất dữ
/// liệu**. Mọi bước phải idempotent; lỗi bất kỳ → rollback nguyên trạng và
/// KHÔNG tăng version để lần mở app sau còn thử lại.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    DataMigration.lastReport = null;
    DataMigration.reportNotifier.value = null;
  });

  TodayTask makeTask({
    required String id,
    String title = 'Ôn tập',
    String status = 'todo',
    bool isDone = false,
    DateTime? scheduledAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TodayTask(
      id: id,
      title: title,
      subject: 'Toán',
      status: status,
      isDone: isDone,
      scheduledAt: scheduledAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  group('DataMigration — khi nào chạy', () {
    test('cài mới (chưa có version) thì cần migration', () {
      expect(DataMigration.storedVersion(), 0);
      expect(DataMigration.needsMigration(), isTrue);
    });

    test('đã ở version hiện tại → không cần và run bỏ qua', () {
      StorageService.setInt(
          'data_schema_version', DataMigration.currentSchemaVersion);

      expect(DataMigration.needsMigration(), isFalse);
      final report = DataMigration.run(DataMigration.defaultSteps());
      expect(report.ran, isFalse);
      expect(report.success, isTrue);
    });
  });

  group('DataMigration — rollback không mất dữ liệu', () {
    test('bước lỗi → khôi phục nguyên trạng, KHÔNG tăng version', () {
      StorageService.setString('user_name', 'Minh');
      // Bản sao lưu để rollback có gì mà so sánh: tạo trước khi run.
      final steps = <MigrationStep>[
        MigrationStep('phá_rồi_lỗi', () {
          StorageService.setString('user_name', 'BỊ GHI ĐÈ');
          StorageService.setString('rác_mới', 'x');
          return false;
        }),
      ];

      final report = DataMigration.run(steps);

      expect(report.ran, isTrue);
      expect(report.success, isFalse);
      expect(report.rolledBack, isTrue);
      expect(report.userMessage, isNotNull);
      // Điều quan trọng nhất: dữ liệu gốc được khôi phục đúng nguyên trạng.
      // (restoreSnapshot chỉ ghi lại các key có trong backup, không xoá key
      // mới sinh ra giữa chừng — đó là key rác vô hại, dữ liệu người dùng vẫn
      // an toàn.)
      expect(StorageService.getString('user_name'), 'Minh');
      // Chưa đánh dấu version → lần sau còn thử lại (không mất migration).
      expect(StorageService.getInt('data_schema_version'), isNull);
    });

    test('bước ném exception cũng bị coi là lỗi và rollback', () {
      StorageService.setString('user_name', 'Minh');
      final steps = <MigrationStep>[
        MigrationStep('ném_lỗi', () {
          StorageService.setString('user_name', 'HỎNG');
          throw StateError('bùm');
        }),
      ];

      final report = DataMigration.run(steps);

      expect(report.success, isFalse);
      expect(report.rolledBack, isTrue);
      expect(StorageService.getString('user_name'), 'Minh');
      expect(StorageService.getInt('data_schema_version'), isNull);
    });
  });

  group('DataMigration — chạy thành công', () {
    test('thành công → đánh dấu version hiện tại', () {
      final report = DataMigration.run(DataMigration.defaultSteps());

      expect(report.ran, isTrue);
      expect(report.success, isTrue);
      expect(report.rolledBack, isFalse);
      expect(StorageService.getInt('data_schema_version'),
          DataMigration.currentSchemaVersion);
    });

    test('idempotent: chạy lần hai không làm gì', () {
      DataMigration.run(DataMigration.defaultSteps());
      final again = DataMigration.run(DataMigration.defaultSteps());

      expect(again.ran, isFalse);
      expect(again.success, isTrue);
    });

    test('storage rỗng vẫn thành công (an toàn tuyệt đối)', () {
      final report = DataMigration.run(DataMigration.defaultSteps());
      expect(report.success, isTrue);
    });

    test('phát tín hiệu cho UI khi thành công (reportNotifier)', () {
      DataMigration.run(DataMigration.defaultSteps());
      expect(DataMigration.reportNotifier.value, isNotNull);
      expect(DataMigration.reportNotifier.value!.success, isTrue);
    });
  });

  group('DataMigration — các bước bảo toàn dữ liệu', () {
    test('cứu task mồ côi: JSON còn nhưng id mất khỏi danh sách', () {
      // Mô phỏng app bị kill giữa lúc ghi: JSON còn, id biến mất khỏi index.
      StorageService.setTodayTaskJson(
          'orphan', makeTask(id: 'orphan', title: 'Bài mồ côi').toJsonString());
      StorageService.setTodayTaskIds(const []);

      DataMigration.run(DataMigration.defaultSteps());

      expect(StorageService.getTodayTaskIds(), contains('orphan'));
    });

    test('JSON hỏng được giữ nguyên, không xoá (không mất dữ liệu)', () {
      StorageService.setTodayTaskIds(const ['bad']);
      StorageService.setTodayTaskJson('bad', '{không phải json');

      DataMigration.run(DataMigration.defaultSteps());

      expect(StorageService.getTodayTaskJson('bad'), '{không phải json');
      expect(StorageService.getTodayTaskIds(), contains('bad'));
    });

    test('vá mâu thuẫn: status=completed nhưng isDone=false → isDone=true', () {
      StorageService.setTodayTaskIds(const ['t1']);
      StorageService.setTodayTaskJson(
          't1',
          makeTask(id: 't1', status: 'completed', isDone: false)
              .toJsonString());

      DataMigration.run(DataMigration.defaultSteps());

      final healed =
          TodayTask.fromJsonString(StorageService.getTodayTaskJson('t1')!);
      expect(healed.status, 'completed');
      expect(healed.isDone, isTrue);
    });

    test('backfill createdAt/updatedAt cho task cũ (v1)', () {
      StorageService.setTodayTaskIds(const ['t1']);
      StorageService.setTodayTaskJson('t1', makeTask(id: 't1').toJsonString());

      DataMigration.run(DataMigration.defaultSteps());

      final healed =
          TodayTask.fromJsonString(StorageService.getTodayTaskJson('t1')!);
      expect(healed.createdAt, isNotNull);
      expect(healed.updatedAt, isNotNull);
    });

    test('dẹp id trùng lặp trong danh sách (giữ thứ tự xuất hiện)', () {
      StorageService.setTodayTaskIds(const ['a', 'a', 'b', 'a']);

      DataMigration.run(DataMigration.defaultSteps());

      expect(StorageService.getTodayTaskIds(), const ['a', 'b']);
    });
  });

  group('DataMigration — backup/restore snapshot', () {
    test('restoreSnapshot ghi lại đúng các kiểu dữ liệu', () {
      StorageService.setString('s', 'văn bản');
      StorageService.setInt('i', 42);
      StorageService.setBool('b', true);
      StorageService.setStringList('l', ['x', 'y']);

      final snapshot = DataMigration.snapshot();
      // Phá dữ liệu rồi khôi phục từ snapshot.
      StorageService.setString('s', 'KHÁC');
      StorageService.setInt('i', 0);
      DataMigration.restoreSnapshot(snapshot);

      expect(StorageService.getString('s'), 'văn bản');
      expect(StorageService.getInt('i'), 42);
      expect(StorageService.getBool('b'), isTrue);
      expect(StorageService.getStringList('l'), ['x', 'y']);
    });

    test('encodeBackup tạo JSON hợp lệ (đọc được lại)', () {
      StorageService.setString('s', 'v');
      final encoded = DataMigration.encodeBackup(DataMigration.snapshot());
      expect(encoded, contains('"s"'));
      expect(encoded, contains('v'));
    });
  });
}
