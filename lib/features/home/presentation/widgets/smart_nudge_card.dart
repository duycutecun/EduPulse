import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';

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

    return GlassCard(
      padding: const EdgeInsets.all(16),
      customColor: AppColors.yellow.withValues(alpha: 0.1),
      borderColor: AppColors.yellow,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.yellow,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lightbulb, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nudges[today],
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
