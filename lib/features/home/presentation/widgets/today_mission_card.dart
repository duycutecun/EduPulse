import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../study/domain/models/study_models.dart';

class TodayMissionCard extends StatelessWidget {
  final List<TodayTask> tasks;
  final VoidCallback onAddTask;
  final ValueChanged<TodayTask> onToggle;
  final ValueChanged<TodayTask> onDelete;

  /// Hiện danh sách nhiệm vụ mẫu theo kỳ thi (Giai đoạn 1).
  final VoidCallback? onAddSample;

  const TodayMissionCard({
    super.key,
    required this.tasks,
    required this.onAddTask,
    required this.onToggle,
    required this.onDelete,
    this.onAddSample,
  });

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.isDone).length;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;

    return GlassCard(
      padding: const EdgeInsets.all(18),
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
                        style: TextStyle(
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (onAddSample != null) ...[
                    GestureDetector(
                      onTap: onAddSample,
                      child: Icon(Icons.auto_awesome_outlined,
                          color: AppColors.textMuted, size: 22),
                    ),
                    const SizedBox(width: 12),
                  ],
                  GestureDetector(
                    onTap: onAddTask,
                    child: Icon(Icons.add_circle,
                        color: AppColors.primary, size: 26),
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
                minHeight: 4,
                backgroundColor: AppColors.border,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 6),
            ...tasks.map((task) => _buildTaskItem(task)),
          ] else ...[
            const SizedBox(height: 10),
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
    Color priorityColor = AppColors.primary;
    String priorityText = 'Thường';
    if (task.priority == 'high') {
      priorityColor = AppColors.red;
      priorityText = 'Quan trọng';
    } else if (task.priority == 'medium') {
      priorityColor = AppColors.orange;
      priorityText = 'Vừa';
    }

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(task),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.red, size: 20),
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onToggle(task);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: task.isDone ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: task.isDone ? AppColors.primary : AppColors.textMuted,
                    width: 1.5,
                  ),
                ),
                child: task.isDone
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
                        color: task.isDone
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        decoration: task.isDone
                            ? TextDecoration.lineThrough
                            : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${task.estimateMinutes} phút',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                        ),
                        if (task.priority == 'high') ...[
                          const SizedBox(width: 8),
                          Text(
                            priorityText,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: priorityColor),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
