import 'package:edupulse/core/ai/ai_chat_actions.dart';
import 'package:edupulse/core/ai/ai_copilot_service.dart';
import 'package:edupulse/core/constants/subject_catalog.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI-2.1 — AI và người dùng phải dùng **cùng một** đường ghi Task, và AI
/// không được tạo ra task trùng.
void main() {
  late TaskRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    repo = TaskRepository.instance;
  });

  TodayTask makeTask({
    String id = 't1',
    String title = 'Ôn hàm số',
    String subject = '📐 Toán',
    DateTime? scheduledAt,
  }) {
    return TodayTask(
      id: id,
      title: title,
      subject: subject,
      priority: 'medium',
      estimateMinutes: 45,
      scheduledAt: scheduledAt ?? DateTime.now(),
    );
  }

  group('createTaskIfMissing — chặn task trùng', () {
    test('task mới vẫn tạo bình thường', () async {
      final result = await repo.createTaskIfMissing(makeTask());
      expect(result.success, isTrue);
      expect(StorageService.getTodayTaskIds(), ['t1']);
    });

    test('AI gợi ý y hệt lần 2 → chặn, không tạo bản sao', () async {
      await repo.createTaskIfMissing(makeTask(id: 'a'));
      final result = await repo.createTaskIfMissing(makeTask(id: 'b'));

      expect(result.isDuplicate, isTrue);
      expect(result.failed, isTrue);
      expect(StorageService.getTodayTaskIds(), ['a']);
      expect(result.task!.id, 'a');
    });

    test('trùng tên nhưng khác môn → vẫn tạo', () async {
      await repo.createTaskIfMissing(makeTask(id: 'a', subject: '📐 Toán'));
      final result =
          await repo.createTaskIfMissing(makeTask(id: 'b', subject: '📖 Văn'));

      expect(result.success, isTrue);
      expect(StorageService.getTodayTaskIds().length, 2);
    });

    test('trùng tên, cùng môn nhưng khác ngày → vẫn tạo', () async {
      final now = DateTime.now();
      await repo.createTaskIfMissing(makeTask(id: 'a', scheduledAt: now));
      final result = await repo.createTaskIfMissing(makeTask(
        id: 'b',
        scheduledAt: now.add(const Duration(days: 1)),
      ));

      expect(result.success, isTrue);
      expect(StorageService.getTodayTaskIds().length, 2);
    });

    test('tên khác chữ hoa/thường và dấu câu vẫn bị coi là trùng', () async {
      await repo.createTaskIfMissing(makeTask(id: 'a', title: 'Ôn hàm số'));
      final result =
          await repo.createTaskIfMissing(makeTask(id: 'b', title: 'on HAM SO'));

      expect(result.isDuplicate, isTrue);
      expect(StorageService.getTodayTaskIds(), ['a']);
    });

    test('môn ghi kiểu cũ (không emoji) vẫn khớp môn chuẩn', () async {
      await repo.createTaskIfMissing(makeTask(id: 'a', subject: '📐 Toán'));
      final result =
          await repo.createTaskIfMissing(makeTask(id: 'b', subject: 'Toán'));

      expect(result.isDuplicate, isTrue);
      expect(StorageService.getTodayTaskIds(), ['a']);
    });

    test('task đã hoàn thành vẫn chặn trùng trong ngày', () async {
      await repo.createTaskIfMissing(makeTask(id: 'a'));
      await repo.toggleTaskDone('a');
      final result = await repo.createTaskIfMissing(makeTask(id: 'b'));

      expect(result.isDuplicate, isTrue);
      expect(StorageService.getTodayTaskIds(), ['a']);
    });

    test('tên rỗng thì không chặn — không đoán bừa', () async {
      await repo.createTaskIfMissing(makeTask(id: 'a'));
      final result =
          await repo.createTaskIfMissing(makeTask(id: 'b', title: '   '));

      expect(result.success, isTrue);
    });

    test('findDuplicate bỏ qua chính task đang sửa (ignoreId)', () async {
      await repo.createTaskIfMissing(makeTask(id: 'a'));

      final self = repo.findDuplicate(
        title: 'Ôn hàm số',
        subject: '📐 Toán',
        ignoreId: 'a',
      );
      expect(self, isNull);
    });
  });

  group('Parser hành động AI — nhận diện đủ 3 hành động mới', () {
    test('edit_task → AiActionType.editTask', () {
      final r = AiChatActionParser.parse('''
Được rồi.
<<<ACTIONS>>>
- label: Sửa task ôn hàm số | type: edit_task | title: Ôn hàm số
<<<END>>>''');
      expect(r.actions.length, 1);
      expect(r.actions.first.type, AiActionType.editTask);
      expect(r.actions.first.payload['title'], 'Ôn hàm số');
    });

    test('reschedule_task → kèm số ngày dời', () {
      final r = AiChatActionParser.parse('''
<<<ACTIONS>>>
- label: Dời ôn hàm số sang mai | type: reschedule_task | title: Ôn hàm số | days: 1
<<<END>>>''');
      expect(r.actions.single.type, AiActionType.rescheduleTask);
      expect(r.actions.single.payload['days'], 1);
    });

    test('delete_task → kèm tên nhiệm vụ cụ thể', () {
      final r = AiChatActionParser.parse('''
<<<ACTIONS>>>
- label: Xoá task tối qua | type: delete_task | title: Ôn hàm số | subject: Toán
<<<END>>>''');
      expect(r.actions.single.type, AiActionType.deleteTask);
      expect(r.actions.single.payload['title'], 'Ôn hàm số');
      expect(r.actions.single.payload['subject'], 'Toán');
    });

    test('nhãn xoá luôn ghi rõ sẽ hỏi lại', () {
      final r = AiChatActionParser.parse(
          '<<<ACTIONS>>>\n- label: Xoá task | type: delete_task | title: A\n<<<END>>>');
      expect(r.actions.single.label, contains('🗑'));
    });

    test('type lạ bị bỏ qua, không sinh hành động rác', () {
      final r = AiChatActionParser.parse(
          '<<<ACTIONS>>>\n- label: Hủy hết | type: destroy_everything\n<<<END>>>');
      expect(r.actions, isEmpty);
    });

    test('hành động cũ (task/focus/note/quiz) vẫn parse như trước', () {
      final r = AiChatActionParser.parse('''
<<<ACTIONS>>>
- label: Thêm task | type: task | title: Ôn điện phân | subject: Hóa học | minutes: 30
- label: Focus 25p | type: focus | subject: Hóa học | minutes: 25
<<<END>>>''');
      expect(r.actions.map((a) => a.type),
          [AiActionType.addTask, AiActionType.startFocus]);
      expect(r.actions.first.payload['minutes'], 30);
    });
  });

  group('Chuẩn hoá môn cho AI (AI-2.1)', () {
    test('AI gõ tên môn không emoji vẫn ra đúng môn chuẩn', () {
      expect(AppSubjects.normalize('Toán'), '📐 Toán');
      // Danh mục quy ước tên môn là "Hóa" (không kèm "học") — "hoa hoc" vẫn
      // phải ra đúng môn đó, không rơi vào môn khác.
      expect(AppSubjects.normalize('hoa hoc'), '🧪 Hóa');
      expect(AppSubjects.normalize('Vật lí'), '⚡ Lý');
      expect(AppSubjects.normalize('ngu van'), '📖 Văn');
    });

    test('môn lạ giữ nguyên, không bị bịa thành môn khác', () {
      expect(AppSubjects.normalize('Kỹ năng thêu'), 'Kỹ năng thêu');
    });
  });
}
