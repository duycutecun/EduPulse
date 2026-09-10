import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Mẹo học hàng ngày — dòng chữ gọn trong card phẳng, không icon tròn to màu.
class SmartNudgeCard extends StatelessWidget {
  const SmartNudgeCard({super.key});

  @override
  Widget build(BuildContext context) {
    const nudges = [
      'Ôn tập 25 phút ngắt quãng (Active Recall) giúp nhớ lâu hơn 70%.',
      'Làm đề thi thử trong khung giờ thật giúp não bộ quen áp lực.',
      'Pomodoro: 25 phút tập trung, 5 phút nghỉ — thử ngay!',
      'Chia nhỏ mục tiêu: 3 nhiệm vụ/ngày = tiến độ bền vững.',
      'Ôn định kỳ mỗi ngày quan trọng hơn học dồn trước kỳ thi.',
    ];
    final tip = nudges[DateTime.now().day % nudges.length];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.yellow.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
