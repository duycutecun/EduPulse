import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/constants/subject_catalog.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../study/domain/models/study_models.dart';

/// Xem trước khi chia nhỏ nhiệm vụ (FE-2.1 "Chia nhỏ", đặc tả mục 5.5).
///
/// Nguyên tắc "AI must suggest, not silently modify" của đặc tả được áp dụng ở
/// đây theo cách đơn giản nhất: **luôn xem trước rồi mới xác nhận**, và luôn có
/// nút Hoàn tác ở màn cha. Người dùng chọn số phần, không AI tự quyết.
class SplitTaskDialog extends StatefulWidget {
  final TodayTask task;
  final int targetMinutes;

  const SplitTaskDialog({
    super.key,
    required this.task,
    this.targetMinutes = 25,
  });

  /// Mở hộp chia nhỏ. Trả về số phần đã chọn, hoặc `null` nếu huỷ.
  static Future<int?> show(
    BuildContext context, {
    required TodayTask task,
    int targetMinutes = 25,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SplitTaskDialog(
        task: task,
        targetMinutes: targetMinutes,
      ),
    );
  }

  @override
  State<SplitTaskDialog> createState() => _SplitTaskDialogState();
}

class _SplitTaskDialogState extends State<SplitTaskDialog> {
  late int _parts = (widget.task.estimateMinutes / widget.targetMinutes)
      .ceil()
      .clamp(2, 4);

  /// Chia đều, phần dư dồn vào phần đầu — tổng phút không đổi.
  List<int> get _minutes => [
        for (var i = 0; i < _parts; i++)
          widget.task.estimateMinutes ~/ _parts +
              (i < widget.task.estimateMinutes % _parts ? 1 : 0),
      ];

  @override
  Widget build(BuildContext context) {
    final task = widget.task;

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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

            Row(
              children: [
                const Icon(Icons.call_split_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: AppTokens.space8),
                Text('Chia nhỏ nhiệm vụ', style: AppTokens.heading2),
              ],
            ),
            const SizedBox(height: AppTokens.space4),
            Text(
              task.title,
              style: AppTokens.body.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppTokens.space2),
            Text(
              '${AppSubjects.displayName(task.subject)} · ${task.estimateMinutes} phút'
              '${task.rescheduleCount >= 3 ? ' · đã dời ${task.rescheduleCount} lần' : ''}',
              style: AppTokens.caption.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppTokens.space12),

            Text('Chia thành mấy phần?', style: AppTokens.heading3),
            const SizedBox(height: AppTokens.space10),
            Row(
              children: [
                for (final n in [2, 3, 4])
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: n == 4 ? 0 : AppTokens.space8),
                      child: _PartChip(
                        label: '$n phần',
                        selected: _parts == n,
                        onTap: () => setState(() => _parts = n),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.space16),

            // Xem trước — không xác nhận thì không ghi gì cả.
            Text('Sẽ thành', style: AppTokens.heading3),
            const SizedBox(height: AppTokens.space8),
            for (var i = 0; i < _parts; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.space6),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.2),
                        borderRadius: AppTokens.brFull,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: AppTokens.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.space8),
                    Expanded(
                      child: Text(
                        '${task.title} (${i + 1}/$_parts)',
                        style: AppTokens.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${_minutes[i]}p',
                      style: AppTokens.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: AppTokens.space12),
            Container(
              padding: const EdgeInsets.all(AppTokens.space10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: AppTokens.brMd,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 15, color: AppColors.textMuted),
                  const SizedBox(width: AppTokens.space6),
                  Expanded(
                    child: Text(
                      'Nhiệm vụ cũ sẽ được thay bằng $_parts phần nhỏ. '
                      'Bạn có thể Hoàn tác ngay sau khi chia.',
                      style: AppTokens.caption.copyWith(
                          color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space20),

            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Huỷ',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: 'Chia nhỏ',
                    icon: Icons.call_split_rounded,
                    onPressed: () => Navigator.of(context).pop(_parts),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PartChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PartChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTokens.brMd,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.space10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryLight.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: AppTokens.brMd,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTokens.caption.copyWith(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? AppColors.primaryDark : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}