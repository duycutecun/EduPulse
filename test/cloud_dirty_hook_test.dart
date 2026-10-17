import 'package:edupulse/core/sync/backup_service.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yêu cầu "luôn luôn sync gần như ngay tức thì": mọi hành động người dùng
/// ghi thẳng vào [StorageService] (điểm thi thử, nhật ký học, hồ sơ, XP,
/// streak, linh vật…) phải được đánh dấu để đẩy lên cloud trong ~2 giây
/// (debounce của BackupService) thay vì chờ poll 20s hoặc vòng sync nền.
///
/// Cơ chế: [StorageService.cloudDirtyHook] — một điểm chốt duy nhất do
/// BackupService gắn lúc `start()`. StorageService KHÔNG được import
/// BackupService (tạo vòng phụ thuộc), chỉ gọi hook qua cuống an toàn:
/// hook ném lỗi thì lần ghi chính vẫn thành công.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  tearDown(() {
    // Static — phải dọn sạch để không rỉ sang test khác trong cùng isolate.
    BackupService.stop();
    StorageService.cloudDirtyHook = null;
  });

  /// Gắn hook đếm số lần bắn, trả về danh sách nhãn được bắn để assert entity.
  final fired = <String>[];
  void installHook() {
    fired.clear();
    StorageService.cloudDirtyHook = () => fired.add('hit');
  }

  group('Ghi điểm thi thử bắn hook', () {
    test('setMockScoreJson → hook bắn đúng một lần', () {
      installHook();

      StorageService.setMockScoreJson('m1', '{"id":"m1","score":8.0}');

      // Sai ở bản cũ: không có hook → thay đổi chỉ lên cloud nhờ poll 20s.
      expect(fired, hasLength(1),
          reason: 'điểm thi thử vừa ghi phải được đánh dấu đồng bộ ngay');
      expect(StorageService.getMockScoreJson('m1'), contains('score'));
    });

    test('removeMockScore → hook bắn (tombstone phải đi lên cloud)', () {
      StorageService.setMockScoreIds(['m1']);
      installHook();

      StorageService.removeMockScore('m1');

      expect(fired, hasLength(1),
          reason: 'bản xoá cũng phải được đánh dấu, nếu không bản xoá sẽ '
              '"sống lại" từ cloud');
      expect(StorageService.getMockScoreJson('m1'), isNull);
    });
  });

  group('Ghi nhật ký học bắn hook', () {
    test('setStudyLogJson → hook bắn', () {
      installHook();

      StorageService.setStudyLogJson('l1', '{"id":"l1","hours":2.5}');

      expect(fired, hasLength(1));
      expect(StorageService.getStudyLogJson('l1'), contains('2.5'));
    });

    test('removeStudyLog → hook bắn', () {
      StorageService.setStudyLogIds(['l1']);
      installHook();

      StorageService.removeStudyLog('l1');

      expect(fired, hasLength(1));
    });
  });

  group('Ghi hồ sơ bắn hook', () {
    test('setUserName + setUserTarget → hook bắn cho từng ghi', () {
      installHook();

      StorageService.setUserName('Minh mới');
      StorageService.setUserTarget('Đại học Bách Khoa');

      expect(fired, hasLength(2),
          reason: 'cả tên lẫn mục tiêu đều là dữ liệu đồng bộ, đổi cái nào '
              'cái đó phải được đánh dấu');
      expect(StorageService.getUserName(), 'Minh mới');
      expect(StorageService.getUserTarget(), 'Đại học Bách Khoa');
    });
  });

  group('Ghi XP / streak bắn hook', () {
    test('addXp bắn hook và XP được ghi đúng', () {
      installHook();

      StorageService.addXp(50);

      expect(fired, hasLength(1),
          reason: 'cộng XP là hành động xảy ra quanh task/Pomodoro liên tục — '
              'không được chờ poll');
      expect(StorageService.getXp(), 50);
    });

    test('setStreak/setStreakRecord/setStreakFreezes bắn hook', () {
      installHook();

      StorageService.setStreak(7);
      StorageService.setStreakRecord(9);
      StorageService.setStreakFreezes(2);

      expect(fired, hasLength(3));
      expect(StorageService.getStreak(), 7);
    });
  });

  group('registerStudyActivity bắn hook', () {
    test('ngày học đầu tiên → streak lên 1 và hook bắn qua các ghi bên trong',
        () {
      installHook();

      StorageService.registerStudyActivity();

      // registerStudyActivity tự ghi qua setStreak/setStreakRecord — mỗi ghi
      // bên trong đều phải được đánh dấu (debounce của BackupService gộp lại).
      expect(fired, isNotEmpty,
          reason: 'học xong ngày mới phải được đánh dấu đồng bộ ngay — đây '
              'chính là dữ liệu streak đang được đồng bộ chậm nhất');
      expect(StorageService.getStreak(), 1);
      expect(StorageService.getStreakRecord(), 1);
    });

    test('học tiếp hôm cùng ngày → không có ghi mới, không bắn thừa', () {
      StorageService.registerStudyActivity();
      installHook();

      StorageService.registerStudyActivity();

      expect(fired, isEmpty,
          reason: 'không có thay đổi thì không được đánh dấu (tránh đẩy lô '
              'khi không cần)');
      expect(StorageService.getStreak(), 1);
    });
  });

  group('Ghi linh vật bắn hook', () {
    test('addMascotBondExp / setMascotAccessory bắn hook', () {
      installHook();

      StorageService.addMascotBondExp(25);
      StorageService.setMascotAccessory('crown');

      expect(fired, hasLength(2));
      expect(StorageService.getMascotAccessory(), 'crown');
    });

    test('mua lá bùa thành công bắn hook cho cả hai ghi (XP gắn kết + bùa)',
        () {
      // Mặc định mascot_bond_exp = 120 ≥ 100 thành tiền.
      StorageService.setStreakFreezes(0);
      installHook();

      final bought = StorageService.buyStreakFreeze();

      expect(bought, isTrue);
      expect(fired.length, greaterThanOrEqualTo(2),
          reason: 'chi phí gắn kết và số lá bùa đều thay đổi — cả hai phải '
              'được đánh dấu');
      expect(StorageService.getStreakFreezes(), 1);
    });
  });

  group('Hook an toàn — lỗi hook không làm hỏng dữ liệu', () {
    test('hook ném lỗi → lần ghi vẫn thành công', () {
      StorageService.cloudDirtyHook = () => throw StateError('giả lập lỗi');

      expect(() => StorageService.setMockScoreJson('m1', '{"score":7}'),
          returnsNormally,
          reason: 'lỗi kênh sync không được phép nuốt mất dữ liệu người dùng '
              'vừa ghi — poll 20s vẫn là lưới an toàn');
      expect(StorageService.getMockScoreJson('m1'), contains('score'));
    });

    test('chưa gắn hook → ghi bình thường, không ném', () {
      expect(
        () => StorageService.setStudyLogJson('l1', '{"id":"l1","hours":1}'),
        returnsNormally,
      );
      expect(StorageService.getStudyLogJson('l1'), isNotNull);
    });
  });

  group('BackupService gắn hook thật lúc start, dọn lúc stop', () {
    test('start() → hook được gắn và có thể gọi an toàn khi chưa đăng nhập',
        () {
      expect(BackupService.isActive, isFalse,
          reason: 'test chạy không có Firebase — chưa đăng nhập');

      BackupService.start();

      final hook = StorageService.cloudDirtyHook;
      expect(hook, isNotNull,
          reason: 'BackupService.start() phải gắn hook ngay — không bắt '
              'các đường ghi thẳng chờ poll');
      // Gọi hook khi chưa đăng nhập phải là no-op an toàn (không ném, không
      // tạo vòng đồng bộ rác).
      expect(() => hook!(), returnsNormally);
    });

    test('stop() → hook được dọn sạch (không rò rỉ giữa các phiên test/app)',
        () {
      BackupService.start();
      expect(StorageService.cloudDirtyHook, isNotNull);

      BackupService.stop();

      expect(StorageService.cloudDirtyHook, isNull);
    });
  });

  group('Mở app trên máy trống — chuỗi pull khi start', () {
    test(
        'máy B mới cài mở app: start() gắn hook và snapshot thật của cloud '
        'về đầy đủ (mô phỏng GET như backup_service_test)', () async {
      // Máy A làm việc — bao gồm dữ liệu ghi thẳng StorageService.
      StorageService.setUserName('Minh');
      StorageService.setMockScoreJson('m1', '{"id":"m1","score":8.0}');
      StorageService.setStudyLogJson('l1', '{"id":"l1","hours":2.5}');
      StorageService.setXp(1420);
      StorageService.setStreak(12);
      StorageService.setMascotBondExp(640);
      final cloudSnapshot = BackupSnapshot.capture(); // = phản hồi GET
      expect(BackupService.hasRealData(cloudSnapshot), isTrue);

      // Máy B cài mới thật sự: sạch prefs + init lại.
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      expect(StorageService.getUserName(), isNot('Minh'));

      // Mở app: BackupService.start() là điểm vào (main.dart gọi sau khi
      // khởi tạo auth) — máy trống → vòng đầu adopt snapshot cloud.
      BackupService.start();
      expect(StorageService.cloudDirtyHook, isNotNull,
          reason: 'ngay cả khi adopt còn chưa xong, các hành động tiếp theo '
              'của người dùng phải được đánh dấu ngay');

      // Phản hồi GET đủ → bản cloud áp về máy (đúng luồng _pullAndApply →
      // BackupSnapshot.apply mà _adopt mở ra).
      BackupSnapshot.apply(
        Map<String, dynamic>.from(cloudSnapshot),
      );

      expect(StorageService.getUserName(), 'Minh');
      expect(StorageService.getMockScoreJson('m1'), contains('8'));
      expect(StorageService.getStudyLogJson('l1'), contains('2.5'));
      expect(StorageService.getXp(), 1420);
      expect(StorageService.getStreak(), 12);
      expect(StorageService.getMascotBondExp(), 640);

      BackupService.stop();
    });
  });
}
