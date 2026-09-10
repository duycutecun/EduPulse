import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Header trang chủ tối giản: lời chào + streak, không mascot/avatar.
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chào $userName 👋',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Chip streak — chỉ hiện khi có streak để header luôn sạch.
        if (streak > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  '$streak',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
