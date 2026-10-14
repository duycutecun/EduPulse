import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../study/domain/models/study_models.dart';
import '../../../tasks/presentation/widgets/task_card.dart';
import '../../domain/services/today_service.dart';

class TodayMissionCard extends StatefulWidget {
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
  State<TodayMissionCard> createState() => _TodayMissionCardState();
}

class _TodayMissionCardState extends State<TodayMissionCard> {
  /// Đặc tả 5.2 — mặc định chỉ mở "việc quan trọng nhất" + tối đa 3 việc kế
  /// tiếp; phần còn lại thu gọn để CTA học không bị danh sách dài che khuất.
  bool _expanded = false;

  /// Số nhiệm vụ hiển thị khi thu gọn: 1 ưu tiên + 3 kế tiếp.
  static const int _collapsedCount = 4;

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    final done = tasks.where((t) => t.isDone).length;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;

    final hasCollapse = tasks.length > _collapsedCount;
    final visible = (_expanded || !hasCollapse)
        ? tasks
        : tasks.take(_collapsedCount).toList();
    final priority = tasks.where((t) => !t.isDone).isEmpty
        ? null
        : tasks.firstWhere((t) => !t.isDone);
    final priorityReason =
        priority == null ? '' : TodayService.priorityReason(priority);

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
                            fontSize: 18)), // icon, không phải typography
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
                  if (widget.onSuggestOrder != null &&
                      tasks.where((t) => !t.isDone).length >= 2 &&
                      StorageService.getBool('ai_permission_analyze') !=
                          false) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onSuggestOrder,
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
                  if (widget.onQuickAdd != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onQuickAdd,
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
                  if (widget.onAddSample != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onAddSample,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.greenSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.lightbulb_outline_rounded,
                            color: AppColors.primary, size: 18),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onAddTask,
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
            if (priority != null) ...[
              const SizedBox(height: 10),
              _PriorityHeader(task: priority, reason: priorityReason),
            ],
            const SizedBox(height: 10),
            ...visible.map(
              (task) => TaskCard(
                key: ValueKey(task.id),
                task: task,
                onToggle: widget.onToggle,
                onStartStudy: widget.onStartStudy,
                onEdit: widget.onEdit,
                onReschedule: widget.onReschedule,
                onSkip: widget.onSkip,
                onSplit: widget.onSplit,
                onDelete: widget.onDelete,
                onTap: widget.onOpenDetail == null
                    ? null
                    : () => widget.onOpenDetail!(task),
              ),
            ),
            if (hasCollapse)
              Center(
                child: TextButton.icon(
                  key: const ValueKey('toggle-more-tasks'),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _expanded
                        ? 'Thu gọn'
                        : 'Xem thêm ${tasks.length - _collapsedCount} việc',
                    style: AppTokens.labelSmall,
                  ),
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
                    onPressed: widget.onAddTask,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.comfortable,
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
                if (widget.onOpenAiPlan != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onOpenAiPlan,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.comfortable,
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
            if (widget.onAddSample != null) ...[
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  onPressed: widget.onAddSample,
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

/// Đặc tả 5.2 — thẻ "việc quan trọng nhất": nêu rõ nhiệm vụ, LÝ DO ưu tiên và
/// thời lượng ước tính. Nút bắt đầu nằm ngay trong hàng nhiệm vụ bên dưới.
class _PriorityHeader extends StatelessWidget {
  final TodayTask task;
  final String reason;

  const _PriorityHeader({required this.task, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.greenSoft.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Việc quan trọng nhất',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTokens.labelSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '~${task.estimateMinutes} phút',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    reason,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
