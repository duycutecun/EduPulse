import 'package:edupulse/core/ai/ai_chat_actions.dart';
import 'package:edupulse/core/ai/ai_context.dart';
import 'package:edupulse/core/ai/ai_copilot_service.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chặn hồi quy bug "AI thêm nhiệm vụ cho NGÀY MAI nhưng task rơi vào HÔM NAY"
/// (báo cáo 17/10/2026). Ba lớp phải cùng đúng:
/// 1. Ngữ cảnh học sinh phải có dòng mốc "Hôm nay: ..." để AI tính ngày tương đối.
/// 2. Parser phải GIỮ NGUYÊN chuỗi ISO scheduledAt AI trả về (không cắt/chỉnh).
/// 3. Executor phải dùng đúng scheduledAt — không lặng lẽ rơi về DateTime.now().
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('AiStudyContext — dòng mốc "Hôm nay"', () {
    test('dòng đầu context đúng thứ + ngày/tháng/năm của mốc now', () {
      // 17/10/2026 là thứ 7 — mốc được báo trong bug report.
      final now = DateTime(2026, 10, 17, 8, 0);
      final ctx = AiStudyContext.build(now: now);
      expect(ctx, startsWith('Hôm nay: thứ 7, 17/10/2026'));
    });

    test('buildFor(level full) cũng mang mốc "Hôm nay" — đường chat dùng', () {
      final now = DateTime(2026, 1, 3, 22, 0); // 3/1/2026 = thứ 7
      final ctx = AiStudyContext.buildFor(
        AiContextLevel.full,
        now: now,
      );
      expect(ctx, startsWith('Hôm nay: thứ 7, 3/1/2026'));
    });

    test('dòng mốc giữ nguyên cả khi học sinh chưa có dữ liệu nào', () {
      final now = DateTime(2026, 10, 17, 8, 0);
      final ctx = AiStudyContext.build(now: now);
      expect(ctx, startsWith('Hôm nay:'));
    });
  });

  group('AiChatActionParser — giữ nguyên scheduledAt', () {
    test('ISO đầy đủ yyyy-MM-ddTHH:mm:ss không bị đổi', () {
      final r = AiChatActionParser.parse('Đã thêm nhé 👍\n<<<ACTIONS>>>\n'
          '[{"type":"addTask","title":"Toán","scheduledAt":"2026-10-18T19:00:00"}]'
          '\n<<<END>>>');
      expect(r.actions.single.type, AiActionType.addTask);
      expect(r.actions.single.payload['scheduledAt'], '2026-10-18T19:00:00');
    });

    test('ISO chỉ có ngày (yyyy-MM-dd) cũng giữ nguyên — executor auto-add giờ',
        () {
      final r = AiChatActionParser.parse(
          '<<<ACTIONS>>>\n[{"type":"addTask","title":"Văn","scheduledAt":"2026-10-18"}]\n<<<END>>>');
      expect(r.actions.single.payload['scheduledAt'], '2026-10-18');
    });
  });

  group('performAddTask — task phải rơi đúng ngày AI hẹn', () {
    DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

    TodayTask storedTask(String id) =>
        TodayTask.fromJsonString(StorageService.getTodayTaskJson(id)!);

    test('scheduledAt NGÀY MAI → task thuộc ngày mai, không lùi về hôm nay',
        () async {
      // NOT dùng mock time: kết quả so trực tiếp với "ngày mai" của mốc test
      // (ngang cùng mốc, không lệch nhau dù suite chạy lúc 23:59).
      final today = dateOnly(DateTime.now());
      final tomorrow = today.add(const Duration(days: 1));
      final iso =
          '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-'
          '${tomorrow.day.toString().padLeft(2, '0')}T19:00:00';

      final outcome = await AiCopilotService.performAddTask({
        'title': 'Toán 45 phút',
        'scheduledAt': iso,
      });

      expect(outcome.kind, AiActionResultKind.done);
      final ids = StorageService.getTodayTaskIds();
      expect(ids, hasLength(1));
      final stored = storedTask(ids.single);
      expect(stored.scheduledAt, isNotNull);
      // Đúng NGÀY MAI: trường hợp lỗi cũ "ngày mai → hôm nay" sẽ fail ở đây.
      expect(
        dateOnly(stored.scheduledAt!),
        tomorrow,
        reason: 'scheduledAt=$iso nhưng task nằm ở ${stored.scheduledAt}',
      );
      // Không nhảy ngược lên danh sách hôm nay.
      // (Bộ lọc "thuộc ngày" duy nhất của app là TaskRepository.getTasksForDay.)
      final repo = TaskRepository.instance;
      final inToday = repo.getTasksForDay(today).any((t) => t.id == ids.single);
      final inTomorrow =
          repo.getTasksForDay(tomorrow).any((t) => t.id == ids.single);
      expect(inToday, isFalse,
          reason: 'task hẹn ngày mai không được hiện ở hôm nay');
      expect(inTomorrow, isTrue);
    });

    test('scheduledAt chỉ có ngày → tạo task ngày đó (giờ để executor quyết)',
        () async {
      final today = dateOnly(DateTime.now());
      final tomorrow = today.add(const Duration(days: 1));
      final iso =
          '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-'
          '${tomorrow.day.toString().padLeft(2, '0')}';

      await AiCopilotService.performAddTask({
        'title': 'Ôn Toán',
        'scheduledAt': iso,
      });
      final stored = storedTask(StorageService.getTodayTaskIds().single);
      expect(dateOnly(stored.scheduledAt!), tomorrow);
    });

    test(
        'scheduledAt KHÔNG đọc được → thất bại có giải thích, KHÔNG lặng lẽ '
        'xếp task vào hôm nay', () async {
      final outcome = await AiCopilotService.performAddTask({
        'title': 'Hóa cho mốt',
        'scheduledAt': 'mai 19h', // dạng tự do model hay trượt ra
      });
      expect(outcome.kind, AiActionResultKind.failed);
      expect(outcome.message, contains('không đọc được'));
      // Không có task nào bị tạo — tránh "thêm xong" ảo ở sai ngày.
      expect(StorageService.getTodayTaskIds(), isEmpty);
    });

    test(
        'không có scheduledAt → giữ hành vi cũ: hôm nay (user không nhắc ngày)',
        () async {
      final outcome =
          await AiCopilotService.performAddTask({'title': 'Đọc bài'});
      expect(outcome.kind, AiActionResultKind.done);
      final stored = storedTask(StorageService.getTodayTaskIds().single);
      expect(dateOnly(stored.scheduledAt!), dateOnly(DateTime.now()));
    });
  });
}
