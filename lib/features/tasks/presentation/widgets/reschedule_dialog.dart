import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../study/domain/models/study_models.dart';

/// Kết quả dời lịch: ngày mới kèm lý do ngắn (có thể rỗng).
///
/// Đặc tả 5.2: đổi lịch nên hỏi lý do ngắn để cải thiện kế hoạch — nhưng không
/// bắt buộc, người dùng bận vẫn dời được trong một thao tác.
class RescheduleRequest {
  final DateTime date;
  final String? reason;

  const RescheduleRequest({required this.date, this.reason});
}

/// Modal dời lịch nhiệm vụ thông minh theo đặc tả Sprint 2 (FE-2.4)
class RescheduleDialog extends StatefulWidget {
  final TodayTask task;

  /// Được gọi kèm khi xác nhận; cũng là giá trị [RescheduleDialog.show] trả về.
  final ValueChanged<RescheduleRequest>? onRescheduled;
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

  /// Mở hộp dời lịch. Trả về ngày + lý do được chọn, hoặc `null` nếu huỷ —
  /// gọi [onRescheduled] kèm theo để hai kiểu dùng đều được.
  static Future<RescheduleRequest?> show(
    BuildContext context, {
    required TodayTask task,
    ValueChanged<RescheduleRequest>? onRescheduled,
    VoidCallback? onSplitWithAi,
    VoidCallback? onSplit,
  }) {
    return showModalBottomSheet<RescheduleRequest>(
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

  /// Lý do ngắn (không bắt buộc) — ghi vào `task.skipReason` để AI/insight học
  /// được vì sao người dùng cứ dời việc.
  String? _reason;

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
        color: AppColors.iosCard,
        borderRadius: BorderRadius.vertical(top: AppTokens.rXl),
      ),
      child: SingleChildScrollView(
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
                  color: AppColors.iosSeparator,
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
                color: AppColors.iosTextPrimary,
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
                  color: AppColors.iosWarning.withValues(alpha: 0.1),
                  borderRadius: AppTokens.brMd,
                  border: Border.all(
                    color: AppColors.iosWarning.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.iosWarning,
                          size: 18,
                        ),
                        const SizedBox(width: AppTokens.space8),
                        Expanded(
                          child: Text(
                            'Nhiệm vụ này đã dời ${widget.task.rescheduleCount} lần',
                            style: AppTokens.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.iosWarning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space6),
                    Text(
                      'Bài học có thể đang hơi dài (${widget.task.estimateMinutes} phút). Bạn có muốn chia nhỏ bài học thành các phần 25 phút để dễ hoàn thành hơn không?',
                      style: AppTokens.bodySubtle.copyWith(
                        color: AppColors.iosTextPrimary,
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
                  color: AppColors.iosError.withValues(alpha: 0.1),
                  borderRadius: AppTokens.brMd,
                  border: Border.all(
                    color: AppColors.iosError.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.iosError, size: 18),
                    const SizedBox(width: AppTokens.space8),
                    Expanded(
                      child: Text(
                        'Ngày chọn sau hạn chót (${deadline.day}/${deadline.month}). Vui lòng cân nhắc!',
                        style: AppTokens.caption.copyWith(
                          color: AppColors.iosError,
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
                  border: Border.all(color: AppColors.iosSeparator),
                  borderRadius: AppTokens.brMd,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 16, color: AppColors.iosPrimary),
                    const SizedBox(width: AppTokens.space8),
                    Expanded(
                      child: Text(
                        'Ngày đã chọn: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: AppTokens.body
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Text('Đổi',
                        style: TextStyle(
                            color: AppColors.iosPrimary,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTokens.space24),

            // Đặc tả 5.2: hỏi lý do ngắn (không bắt buộc) để cải thiện kế hoạch.
            Text('Lý do dời (không bắt buộc)', style: AppTokens.heading3),
            const SizedBox(height: AppTokens.space8),
            Wrap(
              spacing: AppTokens.space8,
              runSpacing: AppTokens.space8,
              children: [
                for (final reason in const [
                  'Chưa đủ thời gian',
                  'Chưa sẵn sàng',
                  'Bận đột xuất',
                  'Ưu tiên việc khác',
                ])
                  ChoiceChip(
                    label: Text(reason, style: AppTokens.caption),
                    selected: _reason == reason,
                    onSelected: (_) => setState(
                        () => _reason = _reason == reason ? null : reason),
                    selectedColor:
                        AppColors.iosPrimarySoft.withValues(alpha: 0.2),
                    side: BorderSide(
                      color: _reason == reason
                          ? AppColors.iosPrimary
                          : AppColors.iosSeparator,
                    ),
                  ),
              ],
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
                      final request = RescheduleRequest(
                        date: _selectedDate,
                        reason: _reason,
                      );
                      widget.onRescheduled?.call(request);
                      Navigator.of(context).pop(request);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
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
                ? AppColors.iosPrimarySoft.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: AppTokens.brMd,
            border: Border.all(
              color: isSelected ? AppColors.iosPrimary : AppColors.iosSeparator,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: AppTokens.caption.copyWith(
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? AppColors.iosPrimaryDark
                  : AppColors.iosTextPrimary,
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
