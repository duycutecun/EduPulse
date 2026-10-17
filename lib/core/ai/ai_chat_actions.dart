import 'dart:convert';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'ai_copilot_service.dart';

/// Parser khối hành động có cấu trúc trong câu trả lời của AI Coach.
///
/// Vì sao parser thay vì function-calling: các model `:free` trên OpenRouter
/// không hỗ trợ đồng nhất tool-call, nhưng khối văn bản thì mọi model đều làm
/// được — protocol này provider-agnostic (Groq/OpenRouter/Gemini đều chạy).
///
/// Format (AI-2.2 — payload JSON array trong khối `<<<ACTIONS>>>`):
/// ```
/// <<<ACTIONS>>>
/// [{"type":"addTask","title":"Toán ch5","subject":"Toán","minutes":45,
///   "scheduledAt":"2026-10-17T20:00:00","priority":"high"},
///  {"type":"saveNote","title":"Định lý Pytago","body":"..."}]
/// <<<END>>>
/// ```
///
/// Chia lỗi (code fence, thụt dòng, khoảng trắng thừa) miễn là còn bọc được
/// `[` … `]` là parse được; JSON decode thất bại → chạy lại parser cũ dạng
/// `key: value | key: value` — lịch sử chat cũ vẫn đọc được (back-compat).
///
/// Khối này bị **tách khỏi phần text** hiển thị (học sinh không thấy cú pháp
/// máy) và chuyển thành nút / chip kết quả thật trong app — chat trở thành
/// trung tâm điều khiển của trợ lý tự thực thi.
class AiChatActionParser {
  AiChatActionParser._();

  static const String blockStart = '<<<ACTIONS>>>';
  static const String blockEnd = '<<<END>>>';

  /// Giới hạn số hành động mỗi lượt — AI hay lặp ý nên cứ để tràn chip sẽ
  /// tràn bubble. Kế hoạch nhiều ngày đi riêng qua type `plan` nên 6 là đủ.
  static const int maxActions = 6;

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
    } else {
      // AI quên khối kết: nhận luôn phần sau khối mở nếu nhìn thấy `[`.
      final open = body.indexOf('[');
      final close = body.lastIndexOf(']');
      if (open != -1 && close > open) {
        body = body.substring(open, close + 1);
      } else if (open == -1) {
        body = '';
      } else {
        body = '';
      }
    }
    // AI đôi khi để khối ngay sau dấu `---` hoặc tiêu đề — cắt gọn phần đuôi
    // trống để bubble tròn trịa.
    head = head.replaceAll(RegExp(r'\n+-{3,}\s*$'), '').trimRight();

    final actions = _parseJsonActions(body) ?? _parseLegacyActions(body);
    return (text: head, actions: actions);
  }

  // ─── JSON protocol (AI-2.2) ──────────────────────────────────────────────

  /// Bóc mảng JSON trong khối. Trả `null` nếu không decode được để fallback
  /// parser legacy; mỗi phần tử hỏng được bỏ qua, tối đa [maxActions] hành động.
  static List<AiCopilotAction>? _parseJsonActions(String body) {
    var s = body.trim();
    if (s.isEmpty) return const [];

    // Dọn code fence + chữ "json" nhiều model hay chèn quanh mảng.
    s = s.replaceAll('```', ' ').trim();
    if (s.toLowerCase().startsWith('json')) s = s.substring(4).trim();

    final open = s.indexOf('[');
    final close = s.lastIndexOf(']');
    if (open == -1 || close <= open) return null;
    s = s.substring(open, close + 1);

    final Object? decoded;
    try {
      decoded = jsonDecode(s);
    } catch (_) {
      return null;
    }

    List<dynamic>? items;
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map) {
      // Một vài model bọc lẫn: {"actions":[...]} hoặc {"tasks": [...]}.
      final nested = decoded['actions'] ?? decoded['tasks'];
      if (nested is List) items = nested;
    }
    if (items == null) return null;

    final actions = <AiCopilotAction>[];
    for (final e in items) {
      if (actions.length >= maxActions) break;
      if (e is! Map) continue;
      final action = _actionFromJson(Map<String, dynamic>.from(e));
      if (action != null) actions.add(action);
    }
    return actions;
  }

  static AiCopilotAction? _actionFromJson(Map<String, dynamic> e) {
    final rawType = (e['type'] ?? e['action'] ?? '').toString();
    final typeKey = rawType.toLowerCase().replaceAll(RegExp(r'[_\-\s]+'), '');
    final label = (e['label'] ?? '').toString().trim();

    switch (typeKey) {
      case 'addtask':
      case 'task':
        final payload = <String, dynamic>{
          if (str(e['title']) != null) 'title': str(e['title']),
          if (str(e['subject']) != null) 'subject': str(e['subject']),
          if (numOr(e['minutes'] ?? e['duration']) != null)
            'minutes': numOr(e['minutes'] ?? e['duration']),
          if (str(e['priority']) != null) 'priority': str(e['priority']),
          if (e['scheduledAt'] != null) 'scheduledAt': e['scheduledAt'],
          if (str(e['when']) != null) 'when': str(e['when']),
        };
        if (str(e['title']) == null) return null;
        return _action(AiActionType.addTask, payload, label);

      case 'savenote':
      case 'note':
        final payload = <String, dynamic>{
          if (str(e['title']) != null) 'title': str(e['title']),
          if (str(e['body'] ?? e['content'] ?? e['text']) != null)
            'body': str(e['body'] ?? e['content'] ?? e['text']),
          if (str(e['subject']) != null) 'subject': str(e['subject']),
        };
        if (str(e['title'] ?? e['body'] ?? e['content'] ?? e['text']) == null) {
          return null;
        }
        return _action(AiActionType.saveNote, payload, label);

      case 'startfocus':
      case 'focus':
        final payload = <String, dynamic>{
          if (str(e['subject']) != null) 'subject': str(e['subject']),
          if (numOr(e['minutes']) != null) 'minutes': numOr(e['minutes']),
        };
        return _action(AiActionType.startFocus, payload, label);

      case 'takequiz':
      case 'quiz':
        final payload = <String, dynamic>{
          'subject': str(e['subject']) ?? 'Toán',
          'topic': str(e['topic'] ?? e['title']) ?? 'Trắc nghiệm tổng hợp',
        };
        return _action(AiActionType.takeQuiz, payload, label);

      case 'openexams':
      case 'exams':
        return _action(AiActionType.openExams, const {}, label);

      case 'opennotes':
      case 'notes':
        return _action(AiActionType.openNotes, const {}, label);

      case 'edittask':
      case 'updatetask':
        final payload = <String, dynamic>{
          if (str(e['title'] ?? e['task']) != null)
            'title': str(e['title'] ?? e['task']),
          if (str(e['newTitle']) != null) 'newTitle': str(e['newTitle']),
          if (str(e['subject']) != null) 'subject': str(e['subject']),
          if (numOr(e['minutes']) != null) 'minutes': numOr(e['minutes']),
          if (str(e['priority']) != null) 'priority': str(e['priority']),
          if (e['scheduledAt'] != null) 'scheduledAt': e['scheduledAt'],
          if (str(e['newDate']) != null) 'newDate': str(e['newDate']),
          if (str(e['deadline']) != null) 'deadline': str(e['deadline']),
        };
        if (str(e['title'] ?? e['task']) == null) return null;
        return _action(AiActionType.editTask, payload, label);

      case 'rescheduletask':
        final payload = <String, dynamic>{
          if (str(e['title'] ?? e['task']) != null)
            'title': str(e['title'] ?? e['task']),
          if (str(e['subject']) != null) 'subject': str(e['subject']),
          if (numOr(e['days']) != null) 'days': numOr(e['days']),
          if (str(e['date'] ?? e['newDate']) != null)
            'date': str(e['date'] ?? e['newDate']),
        };
        if (str(e['title'] ?? e['task']) == null) return null;
        return _action(AiActionType.rescheduleTask, payload, label);

      case 'deletetask':
        final payload = <String, dynamic>{
          if (str(e['title'] ?? e['task']) != null)
            'title': str(e['title'] ?? e['task']),
          if (str(e['subject']) != null) 'subject': str(e['subject']),
          // AI xác nhận "có ý muốn xoá thật" → app vẫn hiện dialog (FE-2.5).
          if (e['confirm'] == true) 'confirm': true,
        };
        if (str(e['title'] ?? e['task']) == null) return null;
        return _action(AiActionType.deleteTask, payload, label);

      case 'plan':
      case 'studyplan':
        final rawTasks = e['tasks'];
        if (rawTasks is! List || rawTasks.isEmpty) return null;
        final tasks = <Map<String, dynamic>>[];
        for (final t in rawTasks) {
          if (t is! Map) continue;
          final m = Map<String, dynamic>.from(t);
          if (str(m['title']) == null) continue;
          tasks.add(m);
        }
        if (tasks.isEmpty) return null;
        final payload = <String, dynamic>{'tasks': tasks};
        if (str(e['summary'] ?? e['title']) != null) {
          payload['summary'] = str(e['summary'] ?? e['title']);
        }
        return _action(AiActionType.plan, payload, label);

      default:
        return null;
    }
  }

  /// Dựng action với nhãn / icon / màu chuẩn của loại; nhãn AI đưa (~30 ký
  /// tự) nếu có thì ưu tiên vì thân thiện hơn với người học.
  static AiCopilotAction _action(
    AiActionType type,
    Map<String, dynamic> payload,
    String label,
  ) {
    final defaults = AiCopilotAction.defaultVisuals(type);
    return AiCopilotAction(
      type: type,
      label: label.isEmpty ? defaults.$3 : label,
      icon: defaults.$1,
      color: defaults.$2,
      payload: payload,
    );
  }

  static String? str(Object? value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? numOr(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  // ─── Legacy parser (`key: value | key: value`) — back-compat ────────────

  static List<AiCopilotAction> _parseLegacyActions(String body) {
    final actions = <AiCopilotAction>[];
    for (final line in body.split('\n')) {
      if (actions.length >= maxActions) break;
      final action = _parseLine(line);
      if (action != null) actions.add(action);
    }
    return actions;
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
          color: AppColors.iosSecondary,
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
          color: AppColors.iosPrimary,
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
          color: AppColors.iosInfo,
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
          color: AppColors.iosWarningDark,
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
          color: AppColors.iosPrimary,
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
          color: AppColors.iosWarningDark,
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
          color: AppColors.iosError,
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
