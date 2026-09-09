import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class SmartNudgeCard extends StatelessWidget {
  const SmartNudgeCard({super.key});

  @override
  Widget build(BuildContext context) {
    const nudges = [
      'Ôn tập 25 phút ngắt quãng (Active Recall) giúp nhớ lâu hơn 70%.',
      'Làm đề thi thử trong khung giờ thật giúp não bộ quen áp lực.',
      'Pomodoro: 25 phút tập trung, 5 phút nghỉ — thử ngay!',
      'Chia nhỏ mục tiêu: 3 nhiệm vụ/ngày = vượt 80% thí sinh.',
      'Kiên định từng ngày — bền bỉ tạo nên thủ khoa.',
    ];
    final today = DateTime.now().day % nudges.length;
    final tip = nudges[today];

    return GlassLikeCard(
      color: AppColors.yellow.withValues(alpha: 0.14),
      borderColor: AppColors.yellow,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.yellow,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_objects_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mẹo học hôm nay',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tip,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassLikeCard extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final Widget child;

  const GlassLikeCard({
    super.key,
    required this.color,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: child,
    );
  }
}