import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../study/domain/models/study_models.dart';

/// Modal dời lịch nhiệm vụ thông minh theo đặc tả Sprint 2 (FE-2.4)
class RescheduleDialog extends StatefulWidget {
  final TodayTask task;

  /// Ngày học sinh chọn. Được gọi kèm [RescheduleDialog.show] trả về kết quả.
  final ValueChanged<DateTime>? onRescheduled;
  final VoidCallback? onSplitWithAi;

  /// Chia nhỏ thủ công (mở [SplitTaskDialog]) — không phụ thuộc AI.
  final VoidCallback? onSplit;

  const RescheduleDialog({
    super.key,
    required this.task,
    this.onRescheduled,
    this.onSplitWithAi,
    this.onSplit,
  });

  /// Mở hộp dời lịch. Trả về ngày được chọn, hoặc `null` nếu huỷ —
  /// gọi [onRescheduled] kèm theo để hai kiểu dùng đều được.
  static Future<DateTime?> show(
    BuildContext context, {
    required TodayTask task,
    ValueChanged<DateTime>? onRescheduled,
    VoidCallback? onSplitWithAi,
    VoidCallback? onSplit,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RescheduleDialog(
        task: task,
        onRescheduled: onRescheduled,
        onSplitWithAi: onSplitWithAi,
        onSplit: onSplit,
      ),
    );
  }

  @override
  State<RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<RescheduleDialog> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));

  @override
  Widget build(BuildContext context) {
    final isFrequent = widget.task.rescheduleCount >= 3;
    final deadline = widget.task.deadline;
    final isAfterDeadline = deadline != null &&
        DateUtils.dateOnly(_selectedDate).isAfter(DateUtils.dateOnly(deadline));

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTokens.space24,
        top: AppTokens.space16,
        left: AppTokens.space20,
        right: AppTokens.space20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.vertical(top: AppTokens.rXl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: AppTokens.brFull,
              ),
            ),
          ),
          const SizedBox(height: AppTokens.space16),

          Text(
            'Dời lịch nhiệm vụ',
            style: AppTokens.heading2,
          ),
          const SizedBox(height: AppTokens.space4),
          Text(
            widget.task.title,
            style: AppTokens.bodySubtle.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTokens.space16),

          // Cảnh báo dời nhiều lần (Đặc tả mục 7.10)
          if (isFrequent) ...[
            Container(
              padding: const EdgeInsets.all(AppTokens.space12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: AppTokens.brMd,
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.warning,
                        size: 18,
                      ),
                      const SizedBox(width: AppTokens.space8),
                      Expanded(
                        child: Text(
                          'Nhiệm vụ này đã dời ${widget.task.rescheduleCount} lần',
                          style: AppTokens.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space6),
                  Text(
                    'Bài học có thể đang hơi dài (${widget.task.estimateMinutes} phút). Bạn có muốn chia nhỏ bài học thành các phần 25 phút để dễ hoàn thành hơn không?',
                    style: AppTokens.bodySubtle.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (widget.onSplitWithAi != null ||
                      widget.onSplit != null) ...[
                    const SizedBox(height: AppTokens.space8),
                    Row(
                      children: [
                        if (widget.onSplit != null) ...[
                          Expanded(
                            child: SecondaryButton(
                              label: 'Chia nhỏ',
                              icon: Icons.call_split_rounded,
                              onPressed: () {
                                Navigator.of(context).pop();
                                widget.onSplit!();
                              },
                            ),
                          ),
                          if (widget.onSplitWithAi != null)
                            const SizedBox(width: AppTokens.space8),
                        ],
                        if (widget.onSplitWithAi != null)
                          Expanded(
                            child: SecondaryButton(
                              label: 'Gợi ý từ AI',
                              icon: Icons.auto_awesome_rounded,
                              onPressed: () {
                                Navigator.of(context).pop();
                                widget.onSplitWithAi!();
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space16),
          ],

          // Cảnh báo dời vượt quá deadline
          if (isAfterDeadline) ...[
            Container(
              padding: const EdgeInsets.all(AppTokens.space10),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.1),
                borderRadius: AppTokens.brMd,
                border: Border.all(
                  color: AppColors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.red, size: 18),
                  const SizedBox(width: AppTokens.space8),
                  Expanded(
                    child: Text(
                      'Ngày chọn sau hạn chót (${deadline.day}/${deadline.month}). Vui lòng cân nhắc!',
                      style: AppTokens.caption.copyWith(
                        color: AppColors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space12),
          ],

          // Lựa chọn nhanh
          Text('Chọn ngày chuyển đến:', style: AppTokens.heading3),
          const SizedBox(height: AppTokens.space10),

          Row(
            children: [
              _buildQuickDateChip(
                label: 'Hôm nay',
                targetDate: DateUtils.dateOnly(DateTime.now()),
              ),
              const SizedBox(width: AppTokens.space8),
              _buildQuickDateChip(
                label: 'Ngày mai',
                targetDate: DateTime.now().add(const Duration(days: 1)),
              ),
              const SizedBox(width: AppTokens.space8),
              _buildQuickDateChip(
                label: 'Cuối tuần',
                targetDate: _getNextWeekend(),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space10),

          // Chọn ngày tùy chỉnh
          InkWell(
            onTap: _pickCustomDate,
            borderRadius: AppTokens.brMd,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.space12,
                vertical: AppTokens.space10,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: AppTokens.brMd,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: AppTokens.space8),
                  Expanded(
                    child: Text(
                      'Ngày đã chọn: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style:
                          AppTokens.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Text('Đổi',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTokens.space24),

          // Actions
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Hủy',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: PrimaryButton(
                  label: 'Xác nhận dời',
                  onPressed: () {
                    widget.onRescheduled?.call(_selectedDate);
                    Navigator.of(context).pop(_selectedDate);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDateChip({
    required String label,
    required DateTime targetDate,
  }) {
    final isSelected = DateUtils.dateOnly(_selectedDate)
        .isAtSameMomentAs(DateUtils.dateOnly(targetDate));

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedDate = targetDate;
          });
        },
        borderRadius: AppTokens.brMd,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppTokens.space10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryLight.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: AppTokens.brMd,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: AppTokens.caption.copyWith(
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  DateTime _getNextWeekend() {
    final now = DateTime.now();
    final daysUntilSaturday = (DateTime.saturday - now.weekday + 7) % 7;
    return now
        .add(Duration(days: daysUntilSaturday == 0 ? 7 : daysUntilSaturday));
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
}
