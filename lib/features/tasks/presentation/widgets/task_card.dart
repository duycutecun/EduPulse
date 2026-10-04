import 'package:flutter/material.dart';
import '../../../../core/utils/feedback_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/constants/subject_catalog.dart';
import '../../../study/domain/models/study_models.dart';

/// Component thẻ nhiệm vụ tiêu chuẩn theo đặc tả Sprint 2 (FE-2.1)
class TaskCard extends StatelessWidget {
  final TodayTask task;
  final ValueChanged<TodayTask> onToggle;
  final ValueChanged<TodayTask>? onStartStudy;
  final ValueChanged<TodayTask>? onEdit;
  final ValueChanged<TodayTask>? onReschedule;
  final ValueChanged<TodayTask>? onSkip;
  final ValueChanged<TodayTask>? onSplit;
  final ValueChanged<TodayTask>? onDelete;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    this.onStartStudy,
    this.onEdit,
    this.onReschedule,
    this.onSkip,
    this.onSplit,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSkipped = task.status == 'skipped';
    final isOverdue = task.deadline != null &&
        DateUtils.dateOnly(task.deadline!)
            .isBefore(DateUtils.dateOnly(DateTime.now())) &&
        !task.isDone;

    final isFrequentReschedule = task.rescheduleCount >= 3 && !task.isDone;

    // G2-A — badge khẩn cấp ngay cạnh tiêu đề. Tính từ deadline nếu có,
    // không có thì lùi về ngày được xếp (scheduledAt) — đó mới là ngày học
    // sinh thực sự phải làm bài.
    final urgency = _urgencyOf(task);

    return Semantics(
      container: true,
      button: true,
      enabled: true,
      label: 'Nhiệm vụ ${task.title}, môn ${_subjectLabel(task.subject)}, '
          '${task.isDone ? 'đã hoàn thành' : 'chưa hoàn thành'}. '
          '${onTap == null ? 'Chạm để đánh dấu hoàn thành.' : 'Chạm để mở chi tiết.'}',
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTokens.space8),
        decoration: BoxDecoration(
          color: task.isDone
              ? AppColors.cardWhite.withValues(alpha: 0.7)
              : AppColors.cardWhite,
          borderRadius: AppTokens.brLg,
          border: Border.all(
            color: isFrequentReschedule
                ? AppColors.warning.withValues(alpha: 0.6)
                : (task.isDone
                    ? AppColors.border.withValues(alpha: 0.5)
                    : AppColors.border),
          ),
          boxShadow: task.isDone ? null : AppTokens.shadowSubtle,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppTokens.brLg,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppTokens.brLg,
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.space12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Checkbox hoàn thành tròn tinh tế
                      Semantics(
                        container: true,
                        button: true,
                        label: task.isDone
                            ? 'Bỏ đánh dấu hoàn thành'
                            : 'Đánh dấu hoàn thành',
                        child: InkWell(
                          onTap: () {
                            FeedbackService.selection();
                            onToggle(task);
                          },
                          borderRadius: AppTokens.brFull,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: task.isDone
                                  ? AppColors.progressDone
                                  : (isSkipped
                                      ? AppColors.textMuted
                                      : Colors.transparent),
                              border: Border.all(
                                color: task.isDone || isSkipped
                                    ? Colors.transparent
                                    : AppColors.border,
                                width: 1.5,
                              ),
                            ),
                            child: task.isDone || isSkipped
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTokens.space12),

                      // Nội dung chính
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Dòng 1: Môn học + Tên nhiệm vụ
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTokens.space6,
                                    vertical: AppTokens.space2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getSubjectColor(task.subject)
                                        .withValues(alpha: 0.12),
                                    borderRadius: AppTokens.brSm,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getSubjectIcon(task.subject),
                                        size: 11,
                                        color: _getSubjectColor(task.subject),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        _subjectLabel(task.subject),
                                        style: AppTokens.caption.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: _getSubjectColor(task.subject),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    task.title,
                                    style: AppTokens.heading3.copyWith(
                                      fontSize: 15,
                                      color: task.isDone || isSkipped
                                          ? AppColors.textMuted
                                          : AppColors.textPrimary,
                                      decoration: task.isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            // Chủ đề (Topic) nếu có
                            if (task.topic != null &&
                                task.topic!.trim().isNotEmpty) ...[
                              const SizedBox(height: AppTokens.space4),
                              Text(
                                task.topic!,
                                style: AppTokens.bodySubtle.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],

                            // Lý do bỏ qua — dữ liệu AI cần dùng ở Sprint 4
                            // (AI-4.5), không được làm mất khi đổi TaskCard.
                            if (isSkipped) ...[
                              const SizedBox(height: AppTokens.space4),
                              Text(
                                task.skipReason == null ||
                                        task.skipReason!.isEmpty
                                    ? 'Đã bỏ qua'
                                    : 'Đã bỏ qua: ${task.skipReason}',
                                style: AppTokens.bodySubtle.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],

                            // Dòng thông tin phụ: Thời lượng, Deadline, Ưu tiên, Cảnh báo dời lịch
                            const SizedBox(height: AppTokens.space8),
                            Wrap(
                              spacing: AppTokens.space8,
                              runSpacing: AppTokens.space4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // G2-A: badge khẩn cấp đứng ĐẦU dòng chip phụ.
                                // Đặt ở Wrap (không phải Row tiêu đề) để không
                                // tràn khi tiêu đề dài ở 320px; luôn có ICON +
                                // CHỮ nên không phụ thuộc màu sắc.
                                if (urgency != null)
                                  _UrgencyBadge(urgency: urgency),
                                // Giờ hẹn học
                                if (task.scheduledAt != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.schedule_rounded,
                                        size: 13,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(width: AppTokens.space4),
                                      Text(
                                        '${task.scheduledAt!.hour.toString().padLeft(2, '0')}:${task.scheduledAt!.minute.toString().padLeft(2, '0')}',
                                        style: AppTokens.caption.copyWith(
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),

                                // Thời lượng
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.access_time_rounded,
                                      size: 13,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: AppTokens.space4),
                                    Text(
                                      '${task.estimateMinutes}p',
                                      style: AppTokens.caption.copyWith(
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),

                                // Deadline
                                if (task.deadline != null) ...[
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isOverdue
                                            ? Icons.error_outline_rounded
                                            : Icons.event_outlined,
                                        size: 13,
                                        color: isOverdue
                                            ? AppColors.red
                                            : AppColors.textMuted,
                                      ),
                                      const SizedBox(width: AppTokens.space4),
                                      Text(
                                        isOverdue
                                            ? 'Quá hạn'
                                            : '${task.deadline!.day.toString().padLeft(2, '0')}/${task.deadline!.month.toString().padLeft(2, '0')}',
                                        style: AppTokens.caption.copyWith(
                                          fontWeight: isOverdue
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: isOverdue
                                              ? AppColors.red
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                // Ưu tiên cao
                                if (task.priority == 'high') ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppTokens.space6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.red.withValues(alpha: 0.1),
                                      borderRadius: AppTokens.brSm,
                                    ),
                                    child: Text(
                                      'Quan trọng',
                                      style: AppTokens.caption.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.red,
                                      ),
                                    ),
                                  ),
                                ],

                                // Cảnh báo dời lịch nhiều lần (Mục 7.10 đặc tả)
                                if (isFrequentReschedule) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppTokens.space6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning
                                          .withValues(alpha: 0.12),
                                      borderRadius: AppTokens.brSm,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.sync_problem_rounded,
                                          size: 11,
                                          color: AppColors.warning,
                                        ),
                                        const SizedBox(width: AppTokens.space2),
                                        Text(
                                          'Dời ${task.rescheduleCount} lần',
                                          style: AppTokens.caption.copyWith(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.warning,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Nút Start Study & Menu hành động
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!task.isDone && onStartStudy != null) ...[
                            IconButton(
                              onPressed: () {
                                FeedbackService.light();
                                onStartStudy!(task);
                              },
                              icon:
                                  const Icon(Icons.play_circle_filled_rounded),
                              color: AppColors.primary,
                              iconSize: 32,
                              tooltip: 'Bắt đầu học ngay',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                          ],
                          PopupMenuButton<_TaskOption>(
                            tooltip: 'Tùy chọn nhiệm vụ',
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onSelected: (option) {
                              switch (option) {
                                case _TaskOption.detail:
                                  onTap?.call();
                                  break;
                                case _TaskOption.edit:
                                  onEdit?.call(task);
                                  break;
                                case _TaskOption.reschedule:
                                  onReschedule?.call(task);
                                  break;
                                case _TaskOption.skip:
                                  onSkip?.call(task);
                                  break;
                                case _TaskOption.split:
                                  onSplit?.call(task);
                                  break;
                                case _TaskOption.delete:
                                  onDelete?.call(task);
                                  break;
                              }
                            },
                            itemBuilder: (_) => [
                              if (onTap != null)
                                const PopupMenuItem(
                                  value: _TaskOption.detail,
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded,
                                          size: 16),
                                      SizedBox(width: 8),
                                      Text('Chi tiết'),
                                    ],
                                  ),
                                ),
                              if (onEdit != null)
                                const PopupMenuItem(
                                  value: _TaskOption.edit,
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 16),
                                      SizedBox(width: 8),
                                      Text('Chỉnh sửa'),
                                    ],
                                  ),
                                ),
                              if (onReschedule != null && !task.isDone)
                                const PopupMenuItem(
                                  value: _TaskOption.reschedule,
                                  child: Row(
                                    children: [
                                      Icon(Icons.schedule_rounded, size: 16),
                                      SizedBox(width: 8),
                                      Text('Dời lịch'),
                                    ],
                                  ),
                                ),
                              if (onSkip != null && !task.isDone)
                                const PopupMenuItem(
                                  value: _TaskOption.skip,
                                  child: Row(
                                    children: [
                                      Icon(Icons.skip_next_rounded, size: 16),
                                      SizedBox(width: 8),
                                      Text('Bỏ qua hôm nay'),
                                    ],
                                  ),
                                ),
                              if (onSplit != null && !task.isDone)
                                const PopupMenuItem(
                                  value: _TaskOption.split,
                                  child: Row(
                                    children: [
                                      Icon(Icons.call_split_rounded, size: 16),
                                      SizedBox(width: 8),
                                      Text('Chia nhỏ'),
                                    ],
                                  ),
                                ),
                              if (onDelete != null)
                                const PopupMenuItem(
                                  value: _TaskOption.delete,
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded,
                                          size: 16, color: AppColors.red),
                                      SizedBox(width: 8),
                                      Text('Xóa nhiệm vụ',
                                          style:
                                              TextStyle(color: AppColors.red)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Nhãn môn hiển thị: bỏ emoji để chip gọn, màu lấy từ danh mục chuẩn.
  static String _subjectLabel(String subject) =>
      AppSubjects.displayName(subject);

  Color _getSubjectColor(String subject) => AppSubjects.colorOf(subject);

  IconData _getSubjectIcon(String subject) => AppSubjects.iconOf(subject);
}

/// Mức khẩn cấp của một nhiệm vụ — dùng để vẽ badge.
///
/// `null` = không gấp, không cần badge. Ngày lấy từ `deadline`, thiếu thì từ
/// `scheduledAt`; nhiệm vụ xong hoặc bỏ qua thì không gấp nữa.
_TaskUrgency? _urgencyOf(TodayTask task) {
  if (task.isDone || task.status == 'skipped') return null;
  final date = task.deadline ?? task.scheduledAt;
  if (date == null) return null;

  final now = DateUtils.dateOnly(DateTime.now());
  final target = DateUtils.dateOnly(date);
  final days = target.difference(now).inDays;
  if (days < 0) return _TaskUrgency.overdue;
  if (days == 0) return _TaskUrgency.today;
  if (days == 1) return _TaskUrgency.tomorrow;
  return null;
}

/// Ba mức khẩn cấp thật sự đáng báo — quá xa thì nhìn thấy cũng không làm
/// được gì, chỉ gây nhiễu.
enum _TaskUrgency { overdue, today, tomorrow }

extension on _TaskUrgency {
  String get label => switch (this) {
        _TaskUrgency.overdue => 'Quá hạn',
        _TaskUrgency.today => 'HÔM NAY',
        _TaskUrgency.tomorrow => 'Mai',
      };

  IconData get icon => switch (this) {
        _TaskUrgency.overdue => Icons.error_rounded,
        _TaskUrgency.today => Icons.priority_high_rounded,
        _TaskUrgency.tomorrow => Icons.event_rounded,
      };

  Color get color => switch (this) {
        _TaskUrgency.overdue => AppColors.redDark,
        _TaskUrgency.today => AppColors.red,
        _TaskUrgency.tomorrow => AppColors.orangeDark,
      };
}

/// Badge khẩn cấp: icon + CHỮ + màu — ba kênh tín hiệu, không chỉ dựa vào
/// màu nên vẫn đọc được với người mù màu.
class _UrgencyBadge extends StatelessWidget {
  final _TaskUrgency urgency;

  const _UrgencyBadge({required this.urgency});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: urgency.color.withValues(alpha: 0.12),
        borderRadius: AppTokens.brSm,
        border: Border.all(color: urgency.color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(urgency.icon, size: 11, color: urgency.color),
          const SizedBox(width: 2),
          Text(
            urgency.label,
            style: AppTokens.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: urgency.color,
            ),
          ),
        ],
      ),
    );
  }
}

enum _TaskOption { detail, edit, reschedule, skip, split, delete }
