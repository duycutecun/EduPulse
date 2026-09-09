import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
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
                    Text(
                      '$streak',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.orange,
                      ),
                    ),
                  ],
                ),
            ),
            const SizedBox(height: 6),
            _buildXpChip(),
          ],
        ),
      ],
    );
  }

  Widget _buildXpChip() {
    final (cur, need) = StorageService.getLevelProgress();
    final level = StorageService.getLevel();
    final pct = (cur / need).clamp(0.0, 1.0);

    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏅', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 3),
              Text(
                'Cấp $level',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.greenDark,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$cur/$need',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.green),
            ),
          ),
        ],
      ),
    );
  }
}
