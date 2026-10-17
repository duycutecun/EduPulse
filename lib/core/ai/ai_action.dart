import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Các loại hành động AI có thể can thiệp và thực thi trực tiếp trong app.
///
/// Nhánh "agentic" (AI-2.2): [plan] là hành động **bắt buộc xem trước** — một
/// lệnh của AI thi tạo 10–30 task nên UI luôn mở `AiPlanPreviewSheet` cho người
/// dùng xác nhận 1 chạm, không tự áp dụng.
enum AiActionType {
  startFocus,
  addTask,
  saveNote,
  takeQuiz,
  openExams,
  openNotes,

  /// Sửa nhiệm vụ đang có (AI-2.1) — tự áp dụng khi AI đưa đủ giá trị mới.
  editTask,

  /// Dời lịch nhiệm vụ (AI-2.1) — tự áp dụng, luôn hoàn tác được.
  rescheduleTask,

  /// Xoá nhiệm vụ (AI-2.1) — **bắt buộc xác nhận** trước khi xoá.
  deleteTask,

  /// Kế hoạch nhiều ngày (AI-2.2) — mở sheet xem trước, áp dụng 1 chạm.
  plan,
}

/// Một hành động cụ thể có thể bấm để thực thi ngay (1-click actionable).
class AiCopilotAction {
  final AiActionType type;
  final String label;
  final IconData icon;
  final Color? color;
  final Map<String, dynamic> payload;

  const AiCopilotAction({
    required this.type,
    required this.label,
    required this.icon,
    this.color,
    this.payload = const {},
  });

  /// Xoá callback rác sau khi thực thi để payload thuần dữ liệu lại.
  void clearUiCallbacks() {
    payload
      ..remove('onTasksChanged')
      ..remove('onStreakChanged');
  }

  // ─── Serialize phục vụ lịch sử chat (`ai_chat_history_v1`) ────────────────

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'label': label,
        'payload': payload,
      };

  /// Đọc lại từ lịch sử: icon / màu luôn dùng bộ mặc định theo loại (icon
  /// runtime không dựng được `const` an toàn, và màu là chi tiết cosmetic).
  /// Trả `null` nếu dữ liệu hỏng hoặc loại không còn tồn tại.
  static AiCopilotAction? fromJson(Map<String, dynamic> j) {
    final typeName = (j['type'] ?? '').toString().trim().toLowerCase();
    AiActionType? type;
    for (final t in AiActionType.values) {
      if (t.name.toLowerCase() == typeName) {
        type = t;
        break;
      }
    }
    if (type == null) return null;
    final defaults = AiCopilotAction.defaultVisuals(type);
    final payload = j['payload'];
    return AiCopilotAction(
      type: type,
      label: (j['label'] ?? '').toString(),
      icon: defaults.$1,
      color: defaults.$2,
      payload: payload is Map ? Map<String, dynamic>.from(payload) : const {},
    );
  }

  /// Bộ nhãn / icon / màu mặc định để JSON từ AI thiếu nhãn vẫn chip đẹp.
  static (IconData, Color, String) defaultVisuals(AiActionType type) =>
      switch (type) {
        AiActionType.startFocus => (
            Icons.play_arrow_rounded,
            AppColors.iosPrimary,
            '▶ Phiên tập trung'
          ),
        AiActionType.addTask => (
            Icons.add_task_rounded,
            AppColors.iosWarningDark,
            '+ Thêm nhiệm vụ'
          ),
        AiActionType.saveNote => (
            Icons.sticky_note_2_rounded,
            AppColors.iosInfo,
            '📝 Lưu ghi chú'
          ),
        AiActionType.takeQuiz => (
            Icons.quiz_rounded,
            AppColors.iosSecondary,
            '⚡ Luyện quiz'
          ),
        AiActionType.openExams => (
            Icons.flag_rounded,
            AppColors.iosSecondary,
            '🎯 Mở Mục tiêu'
          ),
        AiActionType.openNotes => (
            Icons.menu_book_rounded,
            AppColors.iosInfo,
            '📔 Mở Ghi chú'
          ),
        AiActionType.editTask => (
            Icons.edit_rounded,
            AppColors.iosPrimary,
            '✏️ Sửa nhiệm vụ'
          ),
        AiActionType.rescheduleTask => (
            Icons.event_repeat_rounded,
            AppColors.iosWarningDark,
            '📅 Dời lịch nhiệm vụ'
          ),
        AiActionType.deleteTask => (
            Icons.delete_outline_rounded,
            AppColors.iosError,
            '🗑 Xoá nhiệm vụ'
          ),
        AiActionType.plan => (
            Icons.calendar_month_rounded,
            AppColors.iosSecondary,
            '🗓 Xem kế hoạch'
          ),
      };
}

/// Trạng thái một lần tự thực thi hành động AI trong chat (AI-2.2).
enum AiActionResultKind {
  /// Đã làm xong (đối chiếu chip ✅ xanh).
  done,

  /// Bị chặn trùng (⚠️) — dữ liệu đã có sẵn, không ghi đè.
  duplicate,

  /// Lỗi thực thi (❌).
  failed,

  /// Đang chờ người dùng xác nhận xoá (card trong chat).
  pendingDelete,

  /// Người dùng bỏ qua / từ chối đề nghị.
  rejected,

  /// Kế hoạch nhiều ngày — chờ mở sheet xem trước (1 chạm "Áp dụng").
  plan,

  /// Đã hoàn tác — chip chuyển trạng thái, nút Hoàn tác biến mất.
  undone,
}

/// Sự kiện chip tác vụ gửi ngược về màn chat (AI quyết, người dùng chốt).
enum AiChipEvent {
  /// Bấm "Hoàn tác" trên chip kết quả.
  undo,

  /// Bấm "Xác nhận xoá" trên card đề nghị xoá.
  confirmDelete,

  /// Bấm "Bỏ qua" trên card đề nghị xoá.
  skipAction,
}

/// Kết quả một hành động tự thực thi — hiển thị thành chip dưới bubble AI.
///
/// Chỉ dữ liệu mới được serialize vào lịch sử chat; closure [undo] là
/// tài nguyên phiên hiện tại và **không** đi qua [toJson] — nạp lại lịch sử
/// vẫn thấy đúng trạng thái nhưng không còn nút Hoàn tác (đúng đặc tả).
class AiActionResult {
  /// Vị trí của hành động tương ứng trong `ChatMessage.actions`.
  final int actionIndex;
  final AiActionResultKind kind;
  final String message;

  /// Hoàn tác phiên hiện tại (null = không hoàn tác được).
  final Future<void> Function()? undo;

  const AiActionResult({
    required this.actionIndex,
    required this.kind,
    required this.message,
    this.undo,
  });

  Map<String, dynamic> toJson() => {
        'a': actionIndex,
        'k': kind.name,
        'm': message,
      };

  static AiActionResult? fromJson(Map<String, dynamic> j) {
    final rawKind = (j['k'] ?? '').toString().trim();
    AiActionResultKind? kind;
    for (final k in AiActionResultKind.values) {
      if (k.name == rawKind) {
        kind = k;
        break;
      }
    }
    if (kind == null) return null;
    return AiActionResult(
      actionIndex: (j['a'] as num?)?.toInt() ?? 0,
      kind: kind,
      message: (j['m'] ?? '').toString(),
    );
  }
}

/// Kết quả nội bộ của một phép ghi dữ liệu tự thực thi (không cần context).
///
/// Ở tầng executor: [undo] là closure phiên hiện tại, còn [message] là câu
/// chip hiển thị cho người học.
class AiMutationOutcome {
  final AiActionResultKind kind;
  final String message;
  final Future<void> Function()? undo;

  const AiMutationOutcome(
    this.kind,
    this.message, {
    this.undo,
  });
}
