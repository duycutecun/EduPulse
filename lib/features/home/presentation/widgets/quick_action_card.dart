import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/duo_hover_button.dart';

class QuickActionCard extends StatelessWidget {
  final VoidCallback onOpenStudy;
  final VoidCallback onOpenAiCoach;

  const QuickActionCard({
    super.key,
    required this.onOpenStudy,
    required this.onOpenAiCoach,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildActionButton(
          icon: Icons.timer_rounded,
          label: 'TẬP TRUNG NGAY',
          subtitle: 'Đồng hồ Pomodoro',
          onTap: onOpenStudy,
        ),
        const SizedBox(height: 10),
        _buildActionButton(
          icon: Icons.auto_awesome_rounded,
          label: 'HỎI AI BÀI TẬP',
          subtitle: 'Giải đề qua ảnh OCR',
          onTap: onOpenAiCoach,
          isSecondary: true,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    bool isSecondary = false,
  }) {
    return DuoHoverButton(
      onTap: onTap,
      normalColor: isSecondary ? AppColors.cardWhite : AppColors.green,
      hoverColor: isSecondary ? AppColors.bgPage : AppColors.greenLight,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSecondary ? AppColors.cardWhite : AppColors.green,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSecondary ? AppColors.border : AppColors.greenDark,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSecondary ? AppColors.borderDark : AppColors.greenDark,
              blurRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSecondary ? AppColors.green : Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isSecondary ? AppColors.green : Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSecondary ? AppColors.textSecondary : Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isSecondary ? AppColors.textMuted : Colors.white.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
