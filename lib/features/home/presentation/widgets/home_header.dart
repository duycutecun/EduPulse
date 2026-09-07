import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/animated_count_up.dart';
import '../../../../shared/widgets/heartbeat_combo.dart';
import '../../../../shared/widgets/mascot_avatar.dart';

class HomeHeader extends StatelessWidget {
  final String userName;
  final int streak;
  final int? daysLeft;
  final int? remainingTasks;
  final bool? isAllTasksCompleted;

  const HomeHeader({
    super.key,
    required this.userName,
    required this.streak,
    this.daysLeft,
    this.remainingTasks,
    this.isAllTasksCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isLateNight = now.hour >= 23 || now.hour < 5;
    final mood = isAllTasksCompleted == true
        ? MascotMood.celebrate
        : (isLateNight ? MascotMood.sleepy : MascotMood.idle);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            MascotAvatar(
              size: 56,
              mood: mood,
              userName: userName,
              streak: streak,
              daysLeft: daysLeft,
              remainingTasks: remainingTasks,
              isAllTasksCompleted: isAllTasksCompleted,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chào $userName!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hôm nay là ngày tuyệt vời để học',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        HeartbeatCombo(
          value: streak.toDouble(),
          peakScale: 0.12,
          glowColor: AppColors.orange,
          glowRadius: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.orange, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                AnimatedCountUp(
                  value: streak.toDouble(),
                  duration: const Duration(milliseconds: 700),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
