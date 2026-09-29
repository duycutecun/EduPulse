import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/mascot_avatar.dart';

/// Header trang chủ kiểu Duolingo: chào + streak flame + mascot avatar
/// gắn bên phải.
class HomeHeader extends StatelessWidget {
  final String userName;
  final int streak;
  final int? daysLeft;
  final int? remainingTasks;
  final bool? isAllTasksCompleted;
  final bool? mascotVisible;

  const HomeHeader({
    super.key,
    required this.userName,
    required this.streak,
    this.daysLeft,
    this.remainingTasks,
    this.isAllTasksCompleted,
    this.mascotVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chào $userName 👋',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (streak > 0) ...[
                      const SizedBox(height: 6),
                      _StreakChip(streak: streak),
                    ],
                  ],
                ),
              ),
              if (mascotVisible != false)
                MascotAvatar(
                  size: 48,
                  mood: MascotMood.idle,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chip streak kiểu Duolingo: nền vàng, icon lửa, số đậm.
class _StreakChip extends StatelessWidget {
  final int streak;

  const _StreakChip({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.streakBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.yellow, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.yellow.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            '$streak',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.yellow,
            ),
          ),
          const SizedBox(width: 2),
          const Text(
            'ngày',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
