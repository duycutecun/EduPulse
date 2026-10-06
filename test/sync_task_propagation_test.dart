import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';
import 'package:edupulse/core/sync/backup_service.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mở rộng tính năng: đồng bộ nhiệm vụ giữa thiết bị theo thời gian gần thực.
///
/// Hai hành vi cần kiểm tra ở tầng repository + backup:
///  1. Thêm task trên thiết bị A → revision và local storage được bảo đảm.
///  2. Thiết bị B khi pull bản snapshot từ cloud phải nhận task mới đó và
///     bắn revision để UI vẽ lại — tức là "nhảy qua" mà không chờ người dùng
///     bấm đồng bộ.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('Sync toàn thiết bị — gốc của yêu cầu desktop→phone', () {
    test('thêm task trên A bắn revision + lưu đủ field để chụp snapshot', () async {
      final repo = TaskRepository.instance;

      final before = repo.revision.value;
      final task = TodayTask(
        id: 't-new',
        title: 'Ôn Toán',
        subject: 'Toán',
        priority: 'medium',
        estimateMinutes: 45,
        scheduledAt: DateTime.now(),
        status: 'scheduled',
        isDone: false,
      );

      await repo.createTask(task);

      expect(repo.revision.value, greaterThan(before),
          reason: 'mọi mutation phải bắn tín hiệu cho UI');

      final snapshot = BackupSnapshot.capture();
      expect(snapshot.containsKey('task_t-new'), isTrue,
          reason: 'task mới phải nằm trong snapshot để đẩy lên cloud');

      final saved = repo.getTaskById('t-new');
      expect(saved, isNotNull);
      // `saved!` ở dòng đầu cũng đưa `saved` về non-nullable cho hai dòng sau
      // (Dart 3 promotion), nên các dòng sau không cần `!` nữa.
      expect(saved!.title, 'Ôn Toán');
      expect(saved.createdAt, isNotNull);
      expect(saved.updatedAt, isNotNull);
    });

    test('máy B áp snapshot máy A thì thấy task vừa thêm + bắn revision', () async {
      final repoA = TaskRepository.instance;

      final taskA = TodayTask(
        id: 't-cross',
        title: 'Làm từ máy A',
        subject: 'Văn',
        priority: 'high',
        estimateMinutes: 30,
        scheduledAt: DateTime.now(),
        status: 'scheduled',
        isDone: false,
      );
      await repoA.createTask(taskA);

      final snapshotFromA = BackupSnapshot.capture();

      // Máy B cài mới: dọn prefs thật + init lại để không giữ dữ liệu cũ.
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      final repoB = TaskRepository.instance;

      // Lấy mốc revision trước khi áp — sau apply repository phải bật tín hiệu
      // để UI vẽ lại, dù dữ liệu được ghi thẳng qua StorageService.
      final beforeB = repoB.revision.value;
      BackupSnapshot.apply(snapshotFromA);

      expect(repoB.getTaskById('t-cross'), isNotNull,
          reason: 'thay đổi trên A phải xuất hiện ở B');
      expect(repoB.getTaskById('t-cross')!.title, 'Làm từ máy A');

      expect(repoB.revision.value, greaterThan(beforeB),
          reason: 'khôi phục từ cloud phải báo UI biết có thay đổi');
    });

    test('đồng bộ hai chiều: B thêm task rồi đẩy ngược, A nhận được', () async {
      final repoA = TaskRepository.instance;

      final taskA = TodayTask(
        id: 't-a',
        title: 'Việc của A',
        subject: 'Toán',
        priority: 'medium',
        estimateMinutes: 20,
        scheduledAt: DateTime.now(),
        status: 'scheduled',
        isDone: false,
      );
      await repoA.createTask(taskA);
      final snapA = BackupSnapshot.capture();

      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      final repoB = TaskRepository.instance;
      BackupSnapshot.apply(snapA);

      final taskB = TodayTask(
        id: 't-b',
        title: 'Việc của B',
        subject: 'Lý',
        priority: 'low',
        estimateMinutes: 25,
        scheduledAt: DateTime.now(),
        status: 'scheduled',
        isDone: false,
      );
      await repoB.createTask(taskB);
      final snapB = BackupSnapshot.capture();

      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      final repoANew = TaskRepository.instance;
      BackupSnapshot.apply(snapB);

      expect(repoANew.getTaskById('t-b'), isNotNull);
      expect(repoANew.getTaskById('t-a'), isNotNull);
    });

    test('thay đổi trên A không làm mất task của B khi đẩy bản mới nhất', () async {
      // Máy A tạo t-only-a rồi lưu snapshot làm cơ sở.
      final repoA = TaskRepository.instance;
      final taskA = TodayTask(
        id: 't-only-a',
        title: 'Chỉ có ở A',
        subject: 'Toán',
        priority: 'medium',
        estimateMinutes: 15,
        scheduledAt: DateTime.now(),
        status: 'scheduled',
        isDone: false,
      );
      await repoA.createTask(taskA);
      final snapA = BackupSnapshot.capture();

      // Máy B cài mới, tạo t-only-b, đẩy snapshot sang máy A.
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      final repoB = TaskRepository.instance;
      // Thành lập bản phụ liệu cho B để snapshot của B có danh sách xoá (rỗng)
      // và máy A áp vào sẽ merge thay vì ghi đè.
      BackupSnapshot.apply(BackupSnapshot.capture());
      final taskB = TodayTask(
        id: 't-only-b',
        title: 'Chỉ có ở B',
        subject: 'Văn',
        priority: 'medium',
        estimateMinutes: 15,
        scheduledAt: DateTime.now(),
        status: 'scheduled',
        isDone: false,
      );
      await repoB.createTask(taskB);
      final snapB = BackupSnapshot.capture();

      // Máy A nhận snapshot của B: khôi phụ dữ liệu của A rồi merge B vào.
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      final repoANew = TaskRepository.instance;
      BackupSnapshot.apply(snapA); // khôi phục t-only-a
      BackupSnapshot.apply(snapB); // merge t-only-b

      expect(repoANew.getTaskById('t-only-a'), isNotNull,
          reason: 'máy A không được mất việc mình đã làm');
      expect(repoANew.getTaskById('t-only-b'), isNotNull,
          reason: 'bản mới nhất vẫn giữ cả việc của B');
    });
  });
}
