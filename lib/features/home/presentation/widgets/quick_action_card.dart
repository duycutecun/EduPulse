import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Các hành động nhanh trên trang chủ — hàng icon phẳng, không card to.
class QuickActionCard extends StatelessWidget {
  final VoidCallback onOpenStudy;
  final VoidCallback onOpenAiCoach;
  final VoidCallback onOpenAiPlan;

  const QuickActionCard({
    super.key,
    required this.onOpenStudy,
    required this.onOpenAiCoach,
    required this.onOpenAiPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildAction(
          icon: Icons.timer_outlined,
          label: 'Tập trung',
          onTap: onOpenStudy,
        ),
        _buildAction(
          icon: Icons.route_outlined,
          label: 'Lộ trình AI',
          onTap: onOpenAiPlan,
        ),
        _buildAction(
          icon: Icons.auto_awesome_outlined,
          label: 'Hỏi AI',
          onTap: onOpenAiCoach,
        ),
      ],
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: AppColors.green),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
