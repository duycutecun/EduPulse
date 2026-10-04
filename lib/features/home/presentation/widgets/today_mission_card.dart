import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../study/domain/models/study_models.dart';
import '../../../tasks/presentation/widgets/task_card.dart';

class TodayMissionCard extends StatelessWidget {
  final List<TodayTask> tasks;
  final VoidCallback onAddTask;
  final ValueChanged<TodayTask> onToggle;
  final ValueChanged<TodayTask> onDelete;
  final ValueChanged<TodayTask> onSkip;
  final ValueChanged<TodayTask> onReschedule;

  /// Chia nhỏ nhiệm vụ dài (FE-2.1 "Chia nhỏ").
  final ValueChanged<TodayTask>? onSplit;

  /// Hiện danh sách nhiệm vụ mẫu theo kỳ thi.
  final VoidCallback? onAddSample;

  /// Mở lộ trình AI — nhánh "AI lập kế hoạch" của empty state (đặc tả 11).
  final VoidCallback? onOpenAiPlan;

  /// Quick Add ngôn ngữ tự nhiên (đặc tả mục 25).
  final VoidCallback? onQuickAdd;

  /// Bắt đầu phiên học trực tiếp từ task (FE-1.2, FE-2.1).
  final ValueChanged<TodayTask>? onStartStudy;

  /// Nhịp học cá nhân: gợi ý xếp môn khó lên trước (Giai đoạn "AI hiểu bạn").
  final VoidCallback? onSuggestOrder;

  /// Mở form chỉnh sửa nhiệm vụ (FE-2.3).
  final ValueChanged<TodayTask>? onEdit;

  /// Mở màn chi tiết nhiệm vụ (FE-2.2).
  final ValueChanged<TodayTask>? onOpenDetail;

  const TodayMissionCard({
    super.key,
    required this.tasks,
    required this.onAddTask,
    required this.onToggle,
    required this.onDelete,
    required this.onSkip,
    required this.onReschedule,
    this.onSplit,
    this.onAddSample,
    this.onQuickAdd,
    this.onOpenAiPlan,
    this.onSuggestOrder,
    this.onStartStudy,
    this.onEdit,
    this.onOpenDetail,
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
                    const Text('📋',
                        style: TextStyle(
                            fontSize:
                                18)), // icon, kh\u00f3ng ph\u1ea3i typography
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Nhiệm vụ hôm nay',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTokens.sectionTitle,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    '$done/${tasks.length}',
                    style: AppTokens.bodySubtle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                  // Nhịp học cá nhân: gợi ý thứ tự (môn khó lên trước).
                  // Chỉ hiện khi còn >= 2 nhiệm vụ chưa xong và học sinh
                  // chưa tắt AI cá nhân hoá.
                  if (onSuggestOrder != null &&
                      tasks.where((t) => !t.isDone).length >= 2 &&
                      StorageService.getBool('ai_permission_analyze') !=
                          false) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onSuggestOrder,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.greenSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.low_priority_rounded,
                            color: AppColors.primary, size: 18),
                      ),
                    ),
                  ],
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
                      child:
                          const Icon(Icons.add, color: Colors.white, size: 20),
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
            const SizedBox(height: 10),
            ...tasks.map(
              (task) => TaskCard(
                key: ValueKey(task.id),
                task: task,
                onToggle: onToggle,
                onStartStudy: onStartStudy,
                onEdit: onEdit,
                onReschedule: onReschedule,
                onSkip: onSkip,
                onSplit: onSplit,
                onDelete: onDelete,
                onTap: onOpenDetail == null ? null : () => onOpenDetail!(task),
              ),
            ),
          ] else ...[
            // Empty state đúng đặc tả mục 11 — ba câu hỏi bắt buộc: đang thiếu
            // gì, vì sao quan trọng, và làm gì tiếp theo.
            const SizedBox(height: 4),
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Text(
                      'Hôm nay chưa có nhiệm vụ.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tạo kế hoạch để biết mình nên học gì.',
                      textAlign: TextAlign.center,
                      style: AppTokens.caption,
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAddTask,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: AppColors.primary),
                      foregroundColor: AppColors.primaryDark,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(
                      '+ Thêm nhiệm vụ',
                      style: AppTokens.labelSmall,
                    ),
                  ),
                ),
                if (onOpenAiPlan != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onOpenAiPlan,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        side: const BorderSide(color: AppColors.blue),
                        foregroundColor: AppColors.blueDark,
                      ),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                      label: const Text(
                        'AI lập kế hoạch',
                        style: AppTokens.labelSmall,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (onAddSample != null) ...[
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  onPressed: onAddSample,
                  icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
                  label: const Text(
                    'Gợi ý sẵn từ kỳ thi mục tiêu',
                    style: AppTokens.labelSmall,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
