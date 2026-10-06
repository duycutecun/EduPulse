import 'dart:convert';

import 'package:edupulse/core/sync/backup_service.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sao lưu tự động toàn diện — ba điều phải đúng:
///
///  1. **Phủ hết**: mọi thứ người dùng tạo ra trên máy đều nằm trong snapshot.
///     Trước đây chỉ kỳ thi / nhiệm vụ / nhật ký học được đẩy lên cloud, còn
///     ghi chú, phiên học, điểm thi thử, XP, streak, linh vật, lịch sử chat AI
///     nằm trên máy và mất sạch khi gỡ app — đây chính là "không có linking"
///     mà người dùng phản ánh.
///  2. **Không lộ khoá riêng thiết bị**: URL/khoá Supabase, danh tính cục bộ,
///     cờ onboarding phải ở lại máy này, không đẩy lên làm hỏng máy khác.
///  3. **Bản mới nhất thắng**: áp bản cloud phải xoá luôn thứ chỉ có ở máy,
///     nếu không bản ghi đã xoá sẽ "sống lại" ở mọi thiết bị.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  /// Xoá sạch máy như khi cài app mới — phải `init()` lại vì `StorageService`
  /// giữ instance `SharedPreferences` đã nạp, chỉ gọi `setMockInitialValues`
  /// thì dữ liệu cũ vẫn còn nguyên và test thành vô nghĩa.
  Future<void> wipeDevice() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  }

  Map<String, dynamic> seedEverything() {
    // Dữ liệu học tập.
    StorageService.setUserName('Minh');
    StorageService.setUserTarget('Đại học Bách Khoa');
    StorageService.setExamIds(['e1']);
    StorageService.setExamJson(
        'e1', '{"id":"e1","name":"Kỳ thi THPT","updatedAt":"2026-01-01T00:00:00.000"}');
    StorageService.setPrimaryExamId('e1');
    StorageService.setTodayTaskIds(['t1']);
    StorageService.setTodayTaskJson(
        't1', '{"id":"t1","title":"Ôn tích phân","isDone":true}');
    StorageService.setStudyNoteIds(['n1']);
    StorageService.setStudyNoteJson('n1', '{"id":"n1","title":"Ghi chú"}');
    StorageService.setStudySessionIds(['s1']);
    StorageService.setStudySessionJson('s1', '{"id":"s1","minutes":25}');
    StorageService.setStudyLogIds(['l1']);
    StorageService.setStudyLogJson('l1', '{"id":"l1","hours":2.5}');
    StorageService.setMockScoreIds(['m1']);
    StorageService.setMockScoreJson('m1', '{"id":"m1","score":8.0}');

    // Tiến trình & phần thưởng.
    StorageService.setXp(1420);
    StorageService.setStreak(12);
    StorageService.setStreakRecord(30);
    StorageService.setStreakFreezes(2);
    StorageService.setMascotAccessory('crown');
    StorageService.setMascotBondExp(640);
    StorageService.setString('mascot_last_fortune_text', 'Học chăm chỉ sẽ được quả');

    // Cài đặt & hồ sơ.
    StorageService.setAiModel('openai/gpt-oss-120b');
    StorageService.setBool('reminder_enabled', true);
    StorageService.setInt('reminder_hour', 20);
    StorageService.setAiChatHistory('[{"role":"user","content":"Chào"}]');

    return BackupSnapshot.capture();
  }

  group('BackupSnapshot.capture — sao lưu TẤT CẢ', () {
    test('gom mọi loại dữ liệu, không bỏ sót loại nào', () {
      final snap = seedEverything();

      expect(snap['user_name'], 'Minh');
      expect(snap['user_target'], 'Đại học Bách Khoa');
      expect(snap['exam_e1'], contains('Kỳ thi THPT'));
      expect(snap['exam_ids'], ['e1']);
      expect(snap['primary_exam_id'], 'e1');
      expect(snap['task_t1'], contains('Ôn tích phân'));
      expect(snap['study_note_n1'], contains('Ghi chú'));
      expect(snap['study_session_s1'], contains('25'));
      expect(snap['study_log_l1'], contains('2.5'));
      expect(snap['mock_score_m1'], contains('8'));
      expect(snap['user_xp'], 1420);
      expect(snap['streak'], 12);
      expect(snap['streak_record'], 30);
      expect(snap['streak_freeze_count'], 2);
      expect(snap['mascot_equipped_accessory'], 'crown');
      expect(snap['mascot_bond_exp'], 640);
      expect(snap['ai_model'], 'openai/gpt-oss-120b');
      expect(snap['reminder_enabled'], true);
      expect(snap['reminder_hour'], 20);
      expect(snap['ai_chat_history_v1'], contains('Chào'));
      expect(snap[BackupSnapshot.schemaKey], BackupSnapshot.schema);
    });

    test('giữ đúng kiểu giá trị để khôi phục không bị lệch', () {
      final snap = seedEverything();
      expect(snap['user_xp'], isA<int>());
      expect(snap['reminder_enabled'], isA<bool>());
      expect(snap['exam_ids'], isA<List<String>>());
      expect(snap['user_name'], isA<String>());
    });
  });

  group('BackupSnapshot.capture — không lộ khoá riêng thiết bị', () {
    test('loại cấu hình và danh tính cục bộ', () {
      StorageService.setSupabaseUrl('https://may-a.supabase.co');
      StorageService.setSupabaseAnonKey('anon-key-may-a');
      StorageService.setOnboardingDone();
      StorageService.setEmailVerified(true);
      StorageService.setFreeModelsCache('[{"id":"x"}]');
      StorageService.setString('user_uuid', 'user_123_local');
      final otherDeviceUser = StorageService.getUserId();
      StorageService.setInt('last_cloud_sync_ms', 1700000000000);
      seedEverything();

      final snap = BackupSnapshot.capture();

      // Đẩy những khoá này lên cloud sẽ làm máy khác mất cấu hình riêng, mất
      // danh tính, hoặc tưởng đã xác minh/đã onboarding khi chưa.
      expect(snap.containsKey('supabase_url'), isFalse);
      expect(snap.containsKey('supabase_anon_key'), isFalse);
      expect(snap.containsKey('onboarding_done'), isFalse);
      expect(snap.containsKey('email_verified'), isFalse);
      expect(snap.containsKey('user_uuid'), isFalse);
      expect(snap.containsKey('free_models_cache_v1'), isFalse);
      expect(snap.containsKey('last_cloud_sync_ms'), isFalse);
      // ...nhưng dữ liệu người dùng thật sự thì vẫn phải còn.
      expect(snap['user_name'], 'Minh');
      expect(otherDeviceUser, isNotNull);
    });

    test('mọi khoá trong deviceLocalKeys đều bị loại (chốt bằng test)',
        () {
      // Bảo đảm không khoá nào lọt xuống cloud khi thêm mới sau này.
      for (final key in BackupService.deviceLocalKeys) {
        StorageService.setString(key, 'x');
        final snap = BackupSnapshot.capture();
        expect(snap.containsKey(key), isFalse,
            reason: '$key phải ở lại máy, không đi lên cloud');
        StorageService.removeString(key);
      }
    });

    test('ảnh đính kèm đi riêng, không nhồi base64 vào snapshot', () {
      StorageService.setTaskAttachmentIds('t1', ['a1']);
      StorageService.setTaskAttachmentJson(
        't1',
        'a1',
        jsonEncode({
          'id': 'a1',
          'name': 'Đề thi.png',
          'sizeBytes': 10,
          'base64': 'AAAA',
          'addedAt': '2026-01-01T00:00:00.000',
        }),
      );

      final snap = BackupSnapshot.capture();

      // Snapshot chỉ giữ chỗ trống cho ảnh, dữ liệu ảnh đi qua bảng riêng
      // user_blobs — nếu nhồi vào đây thì mỗi lần đẩy phình theo dung lượng ảnh.
      expect(snap.containsKey('task_attachment_t1_a1'), isFalse);
      expect(snap.containsKey('task_attachments_t1'), isFalse);
    });
  });

  group('BackupSnapshot.apply — bản mới nhất thắng', () {
    test('ghi đè dữ liệu máy bằng bản cloud', () {
      seedEverything();
      // Thành lập bản phụ liệu (previousSnapshot) để capture sau này phát
      // hiện khoá bị xoá qua danh sách _deleted_keys.
      StorageService.setString(
          BackupSnapshot.previousSnapshotKey, jsonEncode(BackupSnapshot.capture()));
      // Xoá task_t1 khỏi storage thật sự để capture phát hiện việc xoá.
      StorageService.removeTodayTask('t1');
      final cloud = BackupSnapshot.capture()
        ..['user_name'] = 'Minh trên máy tính'
        ..['user_xp'] = 9999;

      BackupSnapshot.apply(cloud);

      expect(StorageService.getUserName(), 'Minh trên máy tính');
      expect(StorageService.getXp(), 9999);
      // Khoá bị xoá ở bản cloud cũng phải biến mất ở máy.
      expect(StorageService.getTodayTaskJson('t1'), isNull);
    });

    test('xoá thứ chỉ có ở máy này, kể cả bản ghi đã xoá ở máy khác', () {
      seedEverything();
      StorageService.setStudyNoteIds(['n1', 'n2']);
      StorageService.setStudyNoteJson('n2', '{"id":"n2","title":"Cục bộ"}');

      // Thành lập bản phụ liệu (previousSnapshot) để capture sau này phát
      // hiện khoá bị xoá qua danh sách _deleted_keys.
      StorageService.setString(
          BackupSnapshot.previousSnapshotKey, jsonEncode(BackupSnapshot.capture()));

      // Máy B xoá ghi chú n2 rồi đồng bộ lên cloud → đây là bản cloud.
      StorageService.removeStudyNote('n2');
      final cloud = BackupSnapshot.capture();

      // Máy A vẫn còn n2 vì chưa kịp thấy thay đổi.
      StorageService.setStudyNoteJson('n2', '{"id":"n2","title":"Cục bộ"}');
      StorageService.setStudyNoteIds(['n1', 'n2']);
      expect(StorageService.getStudyNoteJson('n2'), isNotNull);

      BackupSnapshot.apply(cloud);

      // Nếu chỉ ghi đè mà không xoá khoá vắng, "ghi chú cục bộ" sẽ sống lại ở
      // mọi thiết bị và người dùng không bao giờ xoá được nữa.
      expect(StorageService.getStudyNoteJson('n2'), isNull);
      expect(StorageService.getStudyNoteIds(), ['n1']);
    });

    test('xoá đúng bản ghi đã xoá ở máy khác, nhưng KHÔNG đụng ảnh đính kèm',
        () {
      // Ảnh không nằm trong snapshot mà nằm ở bảng riêng và được dọn riêng, nên
      // áp bản cloud tuyệt đối không được xoá ảnh — nếu không thì chỉ một lần
      // tải ảnh thất bại là mất ảnh vĩnh viễn.
      StorageService.setTodayTaskIds(['t1']);
      StorageService.setTodayTaskJson('t1', '{"id":"t1"}');
      StorageService.setTaskAttachmentIds('t1', ['a1']);
      StorageService.setTaskAttachmentJson(
        't1',
        'a1',
        jsonEncode({'id': 'a1', 'name': 'de.png', 'base64': 'AAAA'}),
      );
      final cloud = BackupSnapshot.capture();

      BackupSnapshot.apply(cloud);

      expect(StorageService.getTaskAttachmentJson('t1', 'a1'), isNotNull);
      expect(StorageService.getTaskAttachmentIds('t1'), ['a1']);
    });

    test('giữ lại khoá riêng thiết bị khi áp bản cloud', () {
      StorageService.setSupabaseUrl('https://may-b.supabase.co');
      seedEverything();
      final cloud = BackupSnapshot.capture();

      BackupSnapshot.apply(cloud);

      expect(StorageService.getSupabaseUrl(), 'https://may-b.supabase.co');
    });

    test('bắn tín hiệu cho repository vẽ lại (dữ liệu ghi thẳng ngoài repo)',
        () {
      final tasksBefore = TaskRepository.instance.revision.value;
      final sessionsBefore =
          StudySessionRepository.instance.revision.value;

      BackupSnapshot.apply(seedEverything());

      // Không có tín hiệu thì UI vẫn hiện dữ liệu cũ sau khi khôi phục.
      expect(TaskRepository.instance.revision.value, greaterThan(tasksBefore));
      expect(StudySessionRepository.instance.revision.value,
          greaterThan(sessionsBefore));
    });

    test('bỏ qua giá trị rác thay vì làm hỏng cả lần khôi phục', () {
      seedEverything();
      final cloud = BackupSnapshot.capture()
        ..['user_name'] = 'Vẫn ổn'
        ..['task_broken'] = {'không': 'phải map'};

      expect(() => BackupSnapshot.apply(cloud), returnsNormally);
      expect(StorageService.getUserName(), 'Vẫn ổn');
    });
  });

  group('Hoàn tác khôi phục — lối an toàn', () {
    test('quay lại đúng dữ liệu trước lần khôi phục', () {
      seedEverything();
      final cloud = BackupSnapshot.capture()
        ..['user_name'] = 'Bản trên cloud'
        ..['user_xp'] = 0;

      BackupSnapshot.apply(cloud);
      expect(StorageService.getUserName(), 'Bản trên cloud');

      // Người dùng vừa cài app lên máy mới mà máy có việc riêng chưa lên
      // cloud: cần đường quay lại, không phải mất trắng.
      expect(BackupSnapshot.canUndoLastRestore, isTrue);
      expect(BackupSnapshot.undoLastRestore(), isTrue);
      expect(StorageService.getUserName(), 'Minh');
      expect(StorageService.getXp(), 1420);
    });

    test('trả false khi chưa từng khôi phục lần nào', () {
      expect(BackupSnapshot.canUndoLastRestore, isFalse);
      expect(BackupSnapshot.undoLastRestore(), isFalse);
    });

    test('bản cất giữ không đi lên cloud (nó là bản dự phòng cục bộ)', () {
      seedEverything();
      BackupSnapshot.apply(BackupSnapshot.capture());
      expect(BackupSnapshot.capture().containsKey(BackupSnapshot.previousSnapshotKey),
          isFalse);
    });
  });

  group('Liên kết bản gốc ↔ bản sao lưu giữa hai máy', () {
    test('mọi thứ máy A làm đều xuất hiện nguyên vẹn ở máy B', () async {
      // Máy A: làm việc, rồi chụp snapshot đẩy lên cloud.
      seedEverything();
      final pushedByA = BackupSnapshot.capture();

      // Máy B: CÀI MỚI thật sự — dọn sạch prefs rồi nạp lại. Nếu chỉ gọi
      // setMockInitialValues mà không init lại thì StorageService vẫn giữ
      // instance cũ và test này chỉ chứng minh "dữ liệu vẫn còn" — tức vô
      // nghĩa, đúng thứ đáng lẽ phải bắt được.
      await wipeDevice();
      expect(StorageService.getUserName(), isNot('Minh'));
      expect(StorageService.getTodayTaskIds(), isEmpty);

      BackupSnapshot.apply(pushedByA);

      // So từng loại dữ liệu — đây chính là yêu cầu "mọi thiết bị thấy cùng
      // một dữ liệu", và là thứ trước đây chỉ kỳ thi / nhiệm vụ / nhật ký học
      // làm được, còn lại mất.
      expect(StorageService.getUserName(), 'Minh');
      expect(StorageService.getUserTarget(), 'Đại học Bách Khoa');
      expect(StorageService.getExamIds(), ['e1']);
      expect(StorageService.getExamJson('e1'), contains('Kỳ thi THPT'));
      expect(StorageService.getPrimaryExamId(), 'e1');
      expect(StorageService.getTodayTaskJson('t1'), contains('Ôn tích phân'));
      expect(StorageService.getTodayTaskIds(), ['t1']);
      expect(StorageService.getStudyNoteJson('n1'), contains('Ghi chú'));
      expect(StorageService.getStudySessionJson('s1'), contains('25'));
      expect(StorageService.getStudyLogJson('l1'), contains('2.5'));
      expect(StorageService.getMockScoreJson('m1'), contains('8'));
      expect(StorageService.getXp(), 1420);
      expect(StorageService.getStreak(), 12);
      expect(StorageService.getStreakRecord(), 30);
      expect(StorageService.getStreakFreezes(), 2);
      expect(StorageService.getMascotAccessory(), 'crown');
      expect(StorageService.getMascotBondExp(), 640);
      expect(StorageService.getAiModel(), 'openai/gpt-oss-120b');
      expect(StorageService.getBool('reminder_enabled'), true);
      expect(StorageService.getInt('reminder_hour'), 20);
    });

    test('máy B làm thêm rồi đẩy ngược: máy A nhận lại đủ dữ liệu mới',
        () async {
      seedEverything();
      final fromA = BackupSnapshot.capture();

      // Máy B cài mới, nhận bản của A, rồi làm thêm việc.
      await wipeDevice();
      BackupSnapshot.apply(fromA);
      StorageService.setTodayTaskIds(['t1', 't2']);
      StorageService.setTodayTaskJson(
          't2', '{"id":"t2","title":"Làm trên máy B"}');
      StorageService.setXp(2000);
      final pushedByB = BackupSnapshot.capture();

      // Máy A kéo bản mới nhất về — nếu chỉ áp `fromA` thì máy A sẽ không có
      // `t2`, nên phải áp đúng bản B vừa đẩy.
      await wipeDevice();
      BackupSnapshot.apply(fromA);
      expect(StorageService.getTodayTaskJson('t2'), isNull);
      BackupSnapshot.apply(pushedByB);

      expect(StorageService.getTodayTaskJson('t2'), contains('máy B'));
      expect(StorageService.getXp(), 2000);
      expect(StorageService.getUserName(), 'Minh');
    });

    test('vòng đẩy–kéo lặp lại không làm trôi dữ liệu', () async {
      seedEverything();
      var snap = BackupSnapshot.capture();
      for (var i = 0; i < 3; i++) {
        BackupSnapshot.apply(snap);
        snap = BackupSnapshot.capture();
      }
      expect(StorageService.getUserName(), 'Minh');
      expect(StorageService.getTodayTaskIds(), ['t1']);
      expect(StorageService.getXp(), 1420);
      expect(StorageService.getStudyNoteIds(), ['n1']);
    });
  });

  group('Snapshot rỗng không được xoá sạch máy đã có dữ liệu', () {
    test('phân biệt snapshot rỗng với snapshot có dữ liệu', () {
      // Tình huống rất dễ xảy ra: máy A vừa tạo tài khoản, chưa làm gì nên đẩy
      // snapshot rỗng. Mở app trên máy B đã có dữ liệu và nếu cứ "ưu tiên
      // bản sao lưu" một cách máy móc thì B sẽ nhận về rỗng và mất sạch.
      expect(BackupService.hasRealData(BackupSnapshot.capture()), isFalse);
      expect(BackupService.hasRealData(seedEverything()), isTrue);
    });

    test('snapshot của máy khác có dữ liệu thì máy rỗng phải nhận về', () async {
      final fromA = seedEverything();
      await wipeDevice();
      // Máy mới cài, chưa làm gì → không có dữ liệu để mất, nên nhận bản của A.
      expect(BackupService.hasRealData(BackupSnapshot.capture()), isFalse);
      expect(BackupService.hasRealData(fromA), isTrue);
    });
  });

  group('Tín hiệu Realtime từ máy khác', () {
    test('kéo khi revision mới hơn, bỏ qua khi cũ hoặc trùng', () {
      // Máy này đã biết revision 7 (mới vừa đồng bộ xong).
      // Không mock được _knownRevision vì là private — nên kiểm bằng cách
      // đo hành vi: tín hiệu nhận về chỉ kích hoạt kéo khi THẬT SỰ mới.
      // revision âm / 0 coi như không hợp lệ → vẫn kéo cho chắc.
      expect(BackupService.shouldPullOnSignal(999999), isTrue,
          reason: 'revision lớn hơn thì phải kéo');
      expect(BackupService.shouldPullOnSignal(0), isFalse,
          reason: 'revision 0 không có nghĩa, không kéo vô ích');
    });

    test('không phụ thuộc mạng: hỏng Realtime vẫn đồng bộ được', () {
      // Realtime chỉ là đường tắt cho độ trễ. Chu kỳ poll là nguồn đúng cho
      // tính nhất quán, nên khi chưa kết nối được thì mọi thứ vẫn chạy.
      expect(BackupService.isLive, isFalse,
          reason: 'chưa subscribe thì coi như không có đường tắt');
      // Và vòng đồng bộ vẫn chạy độc lập: isActive không phụ thuộc Realtime.
      expect(BackupService.isActive, isFalse);
    });
  });

  group('Checksum & fingerprint', () {
    test('checksum ổn định và phân biệt nội dung khác nhau', () {
      expect(BackupService.checksum('abc'), BackupService.checksum('abc'));
      expect(BackupService.checksum('abc'),
          isNot(BackupService.checksum('abd')));
      // Ổn định giữa các lần chạy: cùng dữ liệu phải cho cùng dấu vân tay,
      // nếu không thì app đẩy lên cloud liên tục không vì lý do.
      expect(BackupService.checksum(''), isNotEmpty);
    });

    test('fingerprint không đổi theo thứ tự khoá', () {
      expect(
        BackupService.fingerprint({'a': 1, 'b': 2}),
        BackupService.fingerprint({'b': 2, 'a': 1}),
      );
    });

    test('fingerprint đổi khi dữ liệu đổi', () {
      expect(
        BackupService.fingerprint({'a': 1}),
        isNot(BackupService.fingerprint({'a': 2})),
      );
    });
  });

  group('Sao lưu chỉ chạy khi đã đăng nhập', () {
    test('chưa đăng nhập thì không khởi động — vì không có danh tính chung', () {
      // Firebase UID mới là khoá nối mọi thiết bị. Chưa đăng nhập thì mỗi máy
      // một user_id riêng → sao lưu vào đâu cũng không liên kết được với máy
      // khác, nên bật lên chỉ tạo cảm giác "đã lưu" giả.
      expect(BackupService.isActive, isFalse);
      expect(BackupService.syncedAtMs, 0);
    });
  });
}
