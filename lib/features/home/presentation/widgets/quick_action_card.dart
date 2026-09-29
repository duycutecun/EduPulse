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
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            children: [
              // Icon nền xanh lá nhỏ kiểu Duolingo.
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, size: 22, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
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
