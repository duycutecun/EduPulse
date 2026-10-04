import 'package:flutter/material.dart';

import '../../../../core/constants/app_tokens.dart';
import '../../../../shared/widgets/confirmation_dialog.dart';
import '../../../study/domain/models/study_models.dart';

/// Xác nhận xóa nhiệm vụ (FE-2.5).
///
/// Bắt buộc theo đặc tả: nêu **đích danh tên nhiệm vụ** để người dùng không xóa
/// nhầm, và nói rõ có thể hoàn tác — vì sau khi xóa, lịch sử phiên học liên kết
/// tới nhiệm vụ này cũng mất theo.
Future<bool?> showConfirmDelete(BuildContext context, TodayTask task) {
  return ConfirmationDialog.show(
    context,
    title: 'Xóa nhiệm vụ?',
    content: 'Bạn sẽ không còn thấy nhiệm vụ này trong kế hoạch hôm nay.',
    highlightedItem: task.title,
    confirmLabel: 'Xóa',
    cancelLabel: 'Giữ lại',
    isDestructive: true,
  );
}

/// SnackBar xác nhận + nút Hoàn tác trong 5 giây (FE-2.5).
///
/// Dùng chung cho mọi thao tác hoàn tác được để thời lượng và hành vi nhất
/// quán, tránh mỗi nơi tự chế một kiểu snackbar khác nhau.
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 5),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Hoàn tác',
          textColor: Colors.white,
          onPressed: onUndo,
        ),
      ),
    );
}

/// Chip trạng thái nhỏ dùng chung cho TaskCard / TaskDetailSheet để cùng một
/// cách hiển thị (trước đây mỗi widget tự chọn màu riêng).
class TaskStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const TaskStatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space8,
        vertical: AppTokens.space4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppTokens.brSm,
      ),
      child: Text(
        label,
        style: AppTokens.caption.copyWith(
          fontWeight: FontWeight.w800,
          color: color,
        ),
        // Nhãn chip có thể dài (tên môn, trạng thái): co lại thay vì làm vỡ
        // hàng chứa nó.
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
