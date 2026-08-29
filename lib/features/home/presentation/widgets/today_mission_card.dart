import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../study/domain/models/study_models.dart';

class TodayMissionCard extends StatelessWidget {
  final List<TodayTask> tasks;
  final VoidCallback onAddTask;
  final ValueChanged<TodayTask> onToggle;
  final ValueChanged<TodayTask> onDelete;

  const TodayMissionCard({
    super.key,
    required this.tasks,
    required this.onAddTask,
    required this.onToggle,
    required this.onDelete,
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
              Row(
                children: [
                  const Text('📋', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'Nhiệm vụ hôm nay',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$done/${tasks.length}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.green),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onAddTask,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(color: AppColors.greenDark, blurRadius: 0, offset: Offset(0, 3)),
                        ],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
              ),
            ),
            const SizedBox(height: 12),
            ...tasks.map((task) => _buildTaskItem(task)),
          ] else ...[
            const SizedBox(height: 14),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Chưa có nhiệm vụ. Nhấn nút + để thêm!',
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
    Color priorityColor = AppColors.green;
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
        onTap: () => onToggle(task),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: task.isDone ? AppColors.greenLight.withValues(alpha: 0.4) : AppColors.cardWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: task.isDone ? AppColors.green : AppColors.border,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: task.isDone ? AppColors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: task.isDone ? AppColors.green : AppColors.textMuted,
                    width: 2,
                  ),
                ),
                child: task.isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 15)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${task.subject} ${task.title}',
                      style: TextStyle(
                        fontSize: 14,
                        color: task.isDone ? AppColors.textMuted : AppColors.textPrimary,
                        decoration: task.isDone ? TextDecoration.lineThrough : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '⏱ ${task.estimateMinutes} phút',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          priorityText,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: priorityColor),
                        ),
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
