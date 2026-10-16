import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Lưới 5 Quick Actions của màn AI (FE-4.1).
///
/// Thay vì để màn chat trống trơn, người dùng được định hướng vào các việc thực
/// tế: hỏi nên học gì, giải thích bài, lập kế hoạch, phân tích điểm yếu.
class AiQuickActions extends StatelessWidget {
  final VoidCallback onRecommend;
  final VoidCallback onExplain;
  final VoidCallback onPlan;
  final VoidCallback onWeakness;

  /// AI-4.7 — "Điều chỉnh lịch" (rule engine, không gọi LLM).
  final VoidCallback onReschedule;

  const AiQuickActions({
    super.key,
    required this.onRecommend,
    required this.onExplain,
    required this.onPlan,
    required this.onWeakness,
    required this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, Color, VoidCallback)>[
      (
        Icons.lightbulb_outline_rounded,
        'Tôi nên học gì?',
        AppColors.iosSuccess,
        onRecommend
      ),
      (
        Icons.menu_book_rounded,
        'Giải thích bài này',
        AppColors.iosInfoDark,
        onExplain
      ),
      (
        Icons.calendar_month_rounded,
        'Lập kế hoạch',
        AppColors.iosSecondaryDark,
        onPlan
      ),
      (
        Icons.insights_rounded,
        'Phân tích điểm yếu',
        AppColors.iosWarningDark,
        onWeakness
      ),
      (
        Icons.balance_rounded,
        'Điều chỉnh lịch',
        AppColors.iosInfoDark,
        onReschedule
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final half = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (icon, label, color, onTap) in items)
              SizedBox(
                width: half,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
