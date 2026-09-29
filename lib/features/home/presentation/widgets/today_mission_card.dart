import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../study/domain/models/study_models.dart';

class TodayMissionCard extends StatelessWidget {
  final List<TodayTask> tasks;
  final VoidCallback onAddTask;
  final ValueChanged<TodayTask> onToggle;
  final ValueChanged<TodayTask> onDelete;
  final ValueChanged<TodayTask> onSkip;
  final ValueChanged<TodayTask> onReschedule;

  /// Hiện danh sách nhiệm vụ mẫu theo kỳ thi.
  final VoidCallback? onAddSample;

  /// Quick Add ngôn ngữ tự nhiên (đặc tả mục 25).
  final VoidCallback? onQuickAdd;

  const TodayMissionCard({
    super.key,
    required this.tasks,
    required this.onAddTask,
    required this.onToggle,
    required this.onDelete,
    required this.onSkip,
    required this.onReschedule,
    this.onAddSample,
    this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.isDone).length;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text('📋', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Nhiệm vụ hôm nay',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    '$done/${tasks.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (onQuickAdd != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onQuickAdd,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.blueSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.bolt_rounded,
                            color: AppColors.blue, size: 18),
                      ),
                    ),
                  ],
                  if (onAddSample != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onAddSample,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.purpleLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.auto_awesome,
                            color: AppColors.purple, size: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  GestureDetector(
                    onTap: onAddTask,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDark.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.progressBg,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.progressDone),
              ),
            ),
            const SizedBox(height: 8),
            ...tasks.map((task) => _buildTaskItem(task)),
          ] else ...[
            const SizedBox(height: 8),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Chưa có nhiệm vụ. Nhấn + để thêm!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskItem(TodayTask task) {
    String priorityText = 'Quan trọng';
    if (task.priority == 'high') {
      priorityText = 'Quan trọng';
    } else if (task.priority == 'medium') {
      priorityText = 'Vừa';
    }

    final isOverdue = task.deadline != null &&
        DateUtils.dateOnly(task.deadline!).isBefore(DateUtils.dateOnly(DateTime.now())) &&
        !task.isDone;
    final isSkipped = task.status == 'skipped';

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(task),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.red, size: 18),
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onToggle(task);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 3),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Checkbox xanh lá khi done.
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: task.isDone
                      ? AppColors.progressDone
                      : (isSkipped ? AppColors.textMuted : Colors.transparent),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: task.isDone || isSkipped
                        ? (task.isDone ? AppColors.progressDone : AppColors.textMuted)
                        : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: task.isDone || isSkipped
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 15,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${task.subject} ${task.title}',
                      style: TextStyle(
                        fontSize: 14,
                        color: task.isDone || isSkipped
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        decoration: task.isDone
                            ? TextDecoration.lineThrough
                            : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (task.topic != null && task.topic!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        task.topic!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (isSkipped) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Đã bỏ qua${task.skipReason == null ? '' : ': ${task.skipReason}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        Text(
                          '${task.estimateMinutes} phút',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                        ),
                        if (task.deadline != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            isOverdue
                                ? Icons.error_outline_rounded
                                : Icons.event_outlined,
                            size: 13,
                            color: isOverdue
                                ? AppColors.red
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isOverdue
                                ? 'Quá hạn'
                                : '${task.deadline!.day.toString().padLeft(2, '0')}/${task.deadline!.month.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isOverdue
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isOverdue
                                  ? AppColors.red
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                        if (task.priority == 'high') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              priorityText,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.red),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!task.isDone)
                PopupMenuButton<_TaskAction>(
                  tooltip: 'Tùy chọn nhiệm vụ',
                  icon: const Icon(Icons.more_horiz_rounded,
                      color: AppColors.textMuted),
                  onSelected: (action) {
                    if (action == _TaskAction.reschedule) onReschedule(task);
                    if (action == _TaskAction.skip) onSkip(task);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _TaskAction.reschedule,
                      child: Text('Đổi lịch'),
                    ),
                    PopupMenuItem(
                      value: _TaskAction.skip,
                      child: Text('Bỏ qua'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TaskAction { reschedule, skip }
