import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'ai_copilot_service.dart';

/// Parser khối hành động có cấu trúc trong câu trả lời của AI Coach.
///
/// Vì sao parser thay vì function-calling: các model `:free` trên OpenRouter
/// không hỗ trợ đồng nhất tool-call, nhưng JSON/khối văn bản thì mọi model
/// đều làm được. Format dòng `key: value | key: value` vừa gọn vừa khoan
/// dung với sai sót nhỏ của model free.
///
/// Format AI được yêu cầu chèn ở cuối câu trả lời KHI đang khuyên học sinh
/// làm gì đó cụ thể:
/// ```
/// <<<ACTIONS>>>
/// - label: Luyện 5 câu Hóa | type: quiz | subject: Hóa học | topic: Điện phân
/// - label: Focus 25p ngay | type: focus | subject: Hóa học | minutes: 25
/// - label: Lưu vào ghi chú | type: note | title: Công thức điện phân | subject: Hóa học
/// - label: Thêm task ôn | type: task | title: Ôn điện phân | subject: Hóa học | minutes: 30 | priority: high
/// - label: Dời ôn điện phân sang mai | type: reschedule_task | title: Ôn điện phân | days: 1
/// - label: Xoá task ôn tối qua | type: delete_task | title: Ôn điện phân
/// <<<END>>>
/// ```
///
/// Khối này bị **tách khỏi phần text** hiển thị (học sinh không thấy cú pháp
/// machine) và chuyển thành các nút bấm thật thực thi trong app qua
/// [AiCopilotService.executeAction] — chat trở thành trung tâm điều khiển.
class AiChatActionParser {
  AiChatActionParser._();

  static const String blockStart = '<<<ACTIONS>>>';
  static const String blockEnd = '<<<END>>>';

  /// Tách câu trả lời thô thành phần hiển thị + danh sách hành động.
  /// Không có khối → trả về nguyên văn và danh sách rỗng.
  static ({String text, List<AiCopilotAction> actions}) parse(String raw) {
    final text = raw;
    final startIdx = text.indexOf(blockStart);
    if (startIdx == -1) return (text: text, actions: const []);

    var head = text.substring(0, startIdx).trimRight();

    var body = text.substring(startIdx + blockStart.length);
    final endIdx = body.indexOf(blockEnd);
    if (endIdx != -1) {
      body = body.substring(0, endIdx);
    }
    // AI đôi khi để khối ngay sau dấu `---` hoặc tiêu đề — cắt gọn phần đuôi
    // trống để bubble tròn trịa.
    head = head.replaceAll(RegExp(r'\n+-{3,}\s*$'), '').trimRight();

    final actions = <AiCopilotAction>[];
    for (final line in body.split('\n')) {
      final action = _parseLine(line);
      if (action != null && actions.length < 4) actions.add(action);
    }
    return (text: head, actions: actions);
  }

  static AiCopilotAction? _parseLine(String line) {
    var l = line.trim();
    if (l.isEmpty) return null;
    l = l.replaceFirst(RegExp(r'^[-*•\d.)\s]+'), '').trim();
    if (l.isEmpty || !l.contains(':')) return null;

    final parts = l.split('|');
    final kv = <String, String>{};
    for (final part in parts) {
      final idx = part.indexOf(':');
      if (idx <= 0) continue;
      final key = part.substring(0, idx).trim().toLowerCase();
      final value = part.substring(idx + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) kv[key] = value;
    }

    final label = kv['label'];
    final type = (kv['type'] ?? '').toLowerCase();
    if (label == null || label.isEmpty) return null;

    switch (type) {
      case 'quiz':
        return AiCopilotAction(
          type: AiActionType.takeQuiz,
          label: '⚡ $label',
          icon: Icons.quiz_rounded,
          color: AppColors.purple,
          payload: {
            'subject': kv['subject'] ?? 'Toán',
            'topic': kv['topic'] ?? kv['title'] ?? 'Trắc nghiệm tổng hợp',
          },
        );
      case 'focus':
        final minutes = int.tryParse(kv['minutes'] ?? '') ?? 25;
        return AiCopilotAction(
          type: AiActionType.startFocus,
          label: '▶ $label',
          icon: Icons.play_arrow_rounded,
          color: AppColors.primary,
          payload: {
            'subject': kv['subject'] ?? 'Toán',
            'minutes': minutes,
          },
        );
      case 'note':
        return AiCopilotAction(
          type: AiActionType.saveNote,
          label: '📝 $label',
          icon: Icons.sticky_note_2_rounded,
          color: AppColors.blue,
          payload: {
            'title': kv['title'] ?? label,
            'subject': kv['subject'] ?? 'Tổng hợp',
          },
        );
      case 'task':
        final minutes = int.tryParse(kv['minutes'] ?? '') ?? 30;
        return AiCopilotAction(
          type: AiActionType.addTask,
          label: '+ $label',
          icon: Icons.add_task_rounded,
          color: AppColors.orangeDark,
          payload: {
            'title': kv['title'] ?? label,
            'subject': kv['subject'] ?? 'Toán',
            'minutes': minutes,
            'priority': kv['priority'] ?? 'medium',
          },
        );

      // AI-2.1 — sửa / dời / xoá nhiệm vụ đang có. Môn `subject` và ngày
      // `date` là tuỳ chọn: thiếu thì AI vẫn gợi ý được, app tự dò theo tên.
      case 'edit_task':
        return AiCopilotAction(
          type: AiActionType.editTask,
          label: '✏️ $label',
          icon: Icons.edit_rounded,
          color: AppColors.primary,
          payload: {
            if (kv['title'] != null) 'title': kv['title'],
            if (kv['subject'] != null) 'subject': kv['subject'],
          },
        );
      case 'reschedule_task':
        return AiCopilotAction(
          type: AiActionType.rescheduleTask,
          label: '📅 $label',
          icon: Icons.event_repeat_rounded,
          color: AppColors.orangeDark,
          payload: {
            if (kv['title'] != null) 'title': kv['title'],
            if (kv['subject'] != null) 'subject': kv['subject'],
            if (kv['date'] != null) 'date': kv['date'],
            if (kv['days'] != null) 'days': int.tryParse(kv['days']!),
          },
        );
      case 'delete_task':
        // Nhãn ghi rõ sẽ hỏi lại — xoá luôn phải có xác nhận.
        return AiCopilotAction(
          type: AiActionType.deleteTask,
          label: '🗑 $label',
          icon: Icons.delete_outline_rounded,
          color: AppColors.red,
          payload: {
            if (kv['title'] != null) 'title': kv['title'],
            if (kv['subject'] != null) 'subject': kv['subject'],
          },
        );
      default:
        return null;
    }
  }
}
