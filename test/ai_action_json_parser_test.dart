import 'package:edupulse/core/ai/ai_action.dart';
import 'package:edupulse/core/ai/ai_chat_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// AI-2.2 — protocol hành động JSON trong khối `<<<ACTIONS>>>`: biến câu chữ
/// của AI thành hành động tự thực thi (agentic) trong app.
void main() {
  group('Parser JSON actions', () {
    test('mảng JSON nhiều loại → đúng type + payload', () {
      final r = AiChatActionParser.parse('''
Tôi đã tạo nhiệm vụ Toán 45 phút cho tối nay nhé 👍
<<<ACTIONS>>>
[{"type":"addTask","title":"Toán ch5","subject":"Toán","minutes":45,"scheduledAt":"2026-10-17T20:00:00","priority":"high"},
 {"type":"saveNote","title":"Định lý Pytago","body":"a²+b²=c²","subject":"Toán"}]
<<<END>>>''');
      expect(r.text, contains('Tôi đã tạo nhiệm vụ'));
      expect(r.text, isNot(contains('<<<ACTIONS>>>')));
      expect(r.actions.length, 2);
      expect(r.actions.first.type, AiActionType.addTask);
      expect(r.actions.first.payload['title'], 'Toán ch5');
      expect(r.actions.first.payload['minutes'], 45);
      expect(r.actions.first.payload['priority'], 'high');
      expect(r.actions.first.payload['scheduledAt'], '2026-10-17T20:00:00');
      expect(r.actions[1].type, AiActionType.saveNote);
      expect(r.actions[1].payload['body'], 'a²+b²=c²');
    });

    test('code fence ```json quanh mảng vẫn bóc được', () {
      final r = AiChatActionParser.parse('''
<<<ACTIONS>>>
```json
[{"type":"startFocus","subject":"Hóa","minutes":25}]
```
<<<END>>>''');
      expect(r.actions.single.type, AiActionType.startFocus);
      expect(r.actions.single.payload['subject'], 'Hóa');
      expect(r.actions.single.payload['minutes'], 25);
    });

    test('JSON decode hỏng → fallback parser legacy key: value', () {
      final r = AiChatActionParser.parse('''
<<<ACTIONS>>>
[{"type":"addTask","title":"gãy ở đây
- label: Thêm task | type: task | title: Ôn điện phân | subject: Hóa học | minutes: 30
<<<END>>>''');
      expect(r.actions.length, 1);
      expect(r.actions.single.type, AiActionType.addTask);
      expect(r.actions.single.payload['title'], 'Ôn điện phân');
      expect(r.actions.single.payload['minutes'], 30);
    });

    test('tối đa 6 hành động mỗi lượt', () {
      final items =
          List.generate(8, (i) => '{"type":"startFocus","subject":"T\$i"}');
      final r = AiChatActionParser.parse(
          '<<<ACTIONS>>>[${items.join(',')}]<<<END>>>');
      expect(r.actions.length, 6);
    });

    test('phần tử lỗi bị bỏ qua, phần tử tốt vẫn giữ', () {
      final r = AiChatActionParser.parse('''
<<<ACTIONS>>>
[123,
 {"type":"addTask","title":"Hợp lệ"},
 {"type":"plan","tasks":[]},
 {"type":"loai_la","title":"bỏ luôn"}]
<<<END>>>''');
      expect(r.actions.length, 1);
      expect(r.actions.single.type, AiActionType.addTask);
    });

    test('type lạ bị bỏ qua, không sinh hành động rác', () {
      final r = AiChatActionParser.parse(
          '<<<ACTIONS>>>[{"type":"destroy_everything"}]<<<END>>>');
      expect(r.actions, isEmpty);
    });

    test('deleteTask giữ cờ confirm', () {
      final r = AiChatActionParser.parse(
          '<<<ACTIONS>>>[{"type":"deleteTask","title":"Ôn hàm số","subject":"Toán","confirm":true}]<<<END>>>');
      final a = r.actions.single;
      expect(a.type, AiActionType.deleteTask);
      expect(a.payload['title'], 'Ôn hàm số');
      expect(a.payload['confirm'], isTrue);
    });

    test('plan chèn payload tasks + summary', () {
      final r = AiChatActionParser.parse('''
<<<ACTIONS>>>
[{"type":"plan","summary":"Lộ trình 3 ngày","tasks":[
 {"title":"Ôn hàm số","subject":"Toán","minutes":45,"dayOffset":0},
 {"title":"Luyện đề","subject":"Toán","minutes":60,"dayOffset":1}]}]
<<<END>>>''');
      expect(r.actions.single.type, AiActionType.plan);
      final tasks = r.actions.single.payload['tasks'] as List;
      expect(tasks.length, 2);
      expect(r.actions.single.payload['summary'], 'Lộ trình 3 ngày');
    });

    test('AI quên khối end nhưng có mảng → vẫn parse được', () {
      final r = AiChatActionParser.parse(
          '<<<ACTIONS>>>[{"type":"openNotes"}] (AI quên <<<END>>>)');
      expect(r.actions.single.type, AiActionType.openNotes);
    });

    test('thiếu title ở addTask → bỏ cả phần tử đó', () {
      final r = AiChatActionParser.parse(
          '<<<ACTIONS>>>[{"type":"addTask","subject":"Toán"}]<<<END>>>');
      expect(r.actions, isEmpty);
    });
  });

  group('Parser legacy — không phá vỡ hành vi cũ', () {
    test('các lệnh cũ (task/focus/note/quiz) vẫn parse như trước', () {
      final r = AiChatActionParser.parse('''
<<<ACTIONS>>>
- label: Thêm task ôn | type: task | title: Ôn điện phân | subject: Hóa học | minutes: 30 | priority: high
- label: Focus 25p ngay | type: focus | subject: Hóa học | minutes: 25
- label: Lưu công thức | type: note | title: Công thức điện phân | subject: Hóa học
- label: Luyện 5 câu | type: quiz | subject: Hóa học | topic: Điện phân
<<<END>>>''');
      expect(r.actions.map((a) => a.type).toList(), [
        AiActionType.addTask,
        AiActionType.startFocus,
        AiActionType.saveNote,
        AiActionType.takeQuiz,
      ]);
      expect(r.actions.first.payload['priority'], 'high');
    });

    test('edit/reschedule/delete legacy giữ nguyên (test cũ AI-2.1)', () {
      final r = AiChatActionParser.parse('''
<<<ACTIONS>>>
- label: Dời ôn điện phân sang mai | type: reschedule_task | title: Ôn điện phân | days: 1
- label: Xoá task ôn tối qua | type: delete_task | title: Ôn điện phân
<<<END>>>''');
      expect(r.actions[0].type, AiActionType.rescheduleTask);
      expect(r.actions[0].payload['days'], 1);
      expect(r.actions[1].type, AiActionType.deleteTask);
      expect(r.actions[1].label, contains('🗑'));
    });

    test('không có khối → trả nguyên văn, không hành động', () {
      const text = 'Chỉ là lời khuyên học tập, không có khối hành động.';
      final r = AiChatActionParser.parse(text);
      expect(r.text, text);
      expect(r.actions, isEmpty);
    });
  });

  group('Serialize AiCopilotAction (lịch sử chat)', () {
    test('toJson → fromJson giữ nguyên type, nhãn, payload', () {
      const action = AiCopilotAction(
        type: AiActionType.addTask,
        label: '+ Thêm nhiệm vụ',
        icon: Icons.add_task_rounded,
        color: Color(0xFFFF8A00),
        payload: {'title': 'Toán ch5', 'minutes': 45, 'priority': 'high'},
      );

      final back = AiCopilotAction.fromJson(action.toJson());
      expect(back, isNotNull);
      expect(back!.type, AiActionType.addTask);
      expect(back.label, '+ Thêm nhiệm vụ');
      expect(back.payload['title'], 'Toán ch5');
      // icon/màu dựng lại từ bộ mặc định của loại — đã thống nhất chủ đích.
      expect(
          back.icon, AiCopilotAction.defaultVisuals(AiActionType.addTask).$1);
      expect(
          back.color, AiCopilotAction.defaultVisuals(AiActionType.addTask).$2);
    });

    test('JSON hỏng trả null, không crash khi nạp lịch sử', () {
      expect(AiCopilotAction.fromJson({'type': 'khongTonTai'}), isNull);
      expect(AiCopilotAction.fromJson(const {}), isNull);
    });
  });
}
