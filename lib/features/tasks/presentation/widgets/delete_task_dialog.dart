import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../shared/widgets/confirmation_dialog.dart';
import '../../../study/domain/models/study_models.dart';

/// Lựa chọn của người học sau khi xem hộp thoại xác nhận xoá.
enum DeleteConfirmChoice {
  /// Giữ lại (đóng hộp thoại, không xoá gì).
  cancel,

  /// Ừ, xoá đúng **lượt này** của nhiệm vụ.
  onlyThis,

  /// Nhiệm vụ lặp: xoá **cả chuỗi** còn chưa hoàn thành.
  wholeSeries,
}

/// Xác nhận xóa nhiệm vụ (FE-2.5).
///
/// Bắt buộc theo đặc tả: nêu **đích danh tên nhiệm vụ** để người dùng không xóa
/// nhầm, và nói rõ có thể hoàn tác — vì sau khi xóa, lịch sử phiên học liên kết
/// tới nhiệm vụ này cũng mất theo.
///
/// Trả `true` chỉ khi người dạy chốt "Xóa" (luồng cũ 2 lựa chọn). Với nhiệm vụ
/// lặp, dùng [showConfirmDeleteChoice] để phân biệt "chỉ lượt này" / "cả chuỗi".
Future<bool?> showConfirmDelete(BuildContext context, TodayTask task) async {
  final choice = await showConfirmDeleteChoice(context, task);
  return choice == DeleteConfirmChoice.onlyThis;
}

/// Hộp thoại xác nhận xoá **đầy đủ ngữ cảnh**: hiển thị ngày giờ học + môn của
/// đúng bản sắp xoá (dù trùng tên, bản "hôm nay" và bản "mai" phải phân biệt
/// được). Nhiệm vụ lặp thêm lựa chọn dứt cả chuỗi.
Future<DeleteConfirmChoice> showConfirmDeleteChoice(
  BuildContext context,
  TodayTask task,
) async {
  final recurring =
      task.recurrence != null && task.recurrence!.trim().isNotEmpty;

  // Nhiệm vụ thường: đúng hộp thoại 2 nút như người dùng vẫn dùng (FE-2.5).
  if (!recurring) {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Xóa nhiệm vụ?',
      content: 'Bạn sẽ không còn thấy nhiệm vụ này trong kế hoạch hôm nay.',
      highlightedItem: task.title,
      detailText: describeTaskForDelete(task),
      confirmLabel: 'Xóa',
      cancelLabel: 'Giữ lại',
      isDestructive: true,
    );
    return ok == true
        ? DeleteConfirmChoice.onlyThis
        : DeleteConfirmChoice.cancel;
  }

  // Nhiệm vụ lặp: một lượt bỏ không tắt được chuỗi — hỏi rõ ý người học.
  final picked = await showDialog<DeleteConfirmChoice>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.brXl),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Row(
        children: [
          Icon(Icons.event_repeat_rounded, color: AppColors.iosError),
          SizedBox(width: AppTokens.space12),
          Expanded(child: Text('Xoá nhiệm vụ lặp?', style: AppTokens.heading2)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Đây là nhiệm vụ lặp. Chọn mức độ xoá mong muốn:',
            style: AppTokens.body,
          ),
          const SizedBox(height: AppTokens.space8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space12,
              vertical: AppTokens.space8,
            ),
            decoration: BoxDecoration(
              color: AppColors.iosErrorSoft,
              borderRadius: AppTokens.brMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: AppTokens.heading3.copyWith(
                    color: AppColors.iosErrorDark,
                  ),
                ),
                const SizedBox(height: AppTokens.space4),
                Text(
                  describeTaskForDelete(task),
                  style: AppTokens.caption.copyWith(
                    color: AppColors.iosTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.start,
      actionsPadding: const EdgeInsets.all(AppTokens.space16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(DeleteConfirmChoice.cancel),
          child: const Text('Giữ lại'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(DeleteConfirmChoice.onlyThis),
          child: const Text('Chỉ xoá lượt này'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(ctx).pop(DeleteConfirmChoice.wholeSeries),
          child: const Text(
            'Xoá cả chuỗi',
            style: TextStyle(
              color: AppColors.iosError,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );

  // Chạm ngoài hộp thoại (barrier) coi như giữ lại — không xoá gì cả.
  return picked ?? DeleteConfirmChoice.cancel;
}

/// Mô tả bản nhiệm vụ sắp bị tác động: "mai, 8 tối · 📐 Toán · lặp hằng ngày".
///
/// Mọi hộp thoại xác nhận xoá đều phải hiện dòng này — trùng tên là bị xóa
/// nhầm bản "hôm nay" trong khi người học muốn bỏ bản của ngày khác.
String describeTaskForDelete(TodayTask task) {
  final parts = <String>[];
  final when = task.scheduledAt ?? task.deadline;
  parts.add(when == null ? 'chưa lên lịch' : describeWhenVi(when));
  final subject = task.subject.trim();
  if (subject.isNotEmpty) parts.add(subject);
  final recurrence = task.recurrence?.trim();
  if (recurrence != null && recurrence.isNotEmpty) {
    switch (recurrence.toLowerCase()) {
      case 'daily':
        parts.add('lặp hằng ngày');
        break;
      case 'weekly':
        parts.add('lặp hằng tuần');
        break;
      default:
        parts.add(recurrence);
    }
  }
  return parts.join(' · ');
}

/// Ngày giờ dạng ngắn tiếng Việt: "hôm nay", "mai", "thứ 5, 19/6" kèm giờ
/// thân thuộc "8 tối" nếu có hẹn giờ (0:00 coi như "chỉ cả ngày").
String describeWhenVi(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = day.difference(today).inDays;

  String dayLabel;
  if (diff == 0) {
    dayLabel = 'hôm nay';
  } else if (diff == 1) {
    dayLabel = 'mai';
  } else {
    const weekdays = [
      'thứ 2',
      'thứ 3',
      'thứ 4',
      'thứ 5',
      'thứ 6',
      'thứ 7',
      'chủ nhật',
    ];
    final d = t.day.toString().padLeft(2, '0');
    final m = t.month.toString().padLeft(2, '0');
    dayLabel = '${weekdays[t.weekday - 1]}, $d/$m';
  }

  final hasTime = t.hour != 0 || t.minute != 0;
  return hasTime ? '$dayLabel, ${clockLabelVi(t)}' : dayLabel;
}

/// Giờ dạng thân thuộc tiếng Việt: "8 sáng", "12 trưa", "2:30 chiều", "8 tối".
String clockLabelVi(DateTime t) {
  final h = t.hour;
  final m = t.minute;
  final mm = m == 0 ? '' : ':${m.toString().padLeft(2, '0')}';
  if (h == 0) return 'nửa đêm';
  if (h < 12) return '$h$mm sáng';
  if (h == 12) return '12$mm trưa';
  if (h < 18) return '${h - 12}$mm chiều';
  return '${h - 12}$mm tối';
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
