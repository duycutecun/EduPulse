import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../shared/widgets/mascot_avatar.dart';

/// Header trang chủ kiểu Duolingo: chào + streak + mascot.
///
/// **Thiết kế 1 hàng (~48px)** — trước đây header chiếm ~80px và đẩy task
/// đầu tiên xuống dưới fold trên iPhone SE (375×667). Nguyên tắc của tài liệu
/// UI: *"Mở app là biết mình phải làm gì"* — nên phần tử thứ tự phải là
/// **nhiệm vụ**, không phải lời chào.
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
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (mascotVisible != false) ...[
            MascotAvatar(size: 36, mood: MascotMood.idle),
            const SizedBox(width: 10),
          ],
          // Tên dài không được đẩy mascot ra ngoài khung: co lại bằng ellipsis.
          Expanded(
            child: Text(
              'Chào $userName 👋',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTokens.heading2,
            ),
          ),
          if (streak > 0) ...[
            const SizedBox(width: 8),
            _StreakChip(streak: streak),
          ],
        ],
      ),
    );
  }
}

/// Chip streak kiểu Duolingo: nền vàng, icon lửa, số đậm — thu nhỏ cho header
/// 1 hàng (trước 20px cao, nay 26px) nhưng vẫn đủ tương phản để đọc nhanh.
class _StreakChip extends StatelessWidget {
  final int streak;

  const _StreakChip({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.streakBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.yellow, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥',
              style: TextStyle(
                  fontSize: 13)), // icon, kh\u00f3ng ph\u1ea3i typography
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: AppTokens.body.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.yellow,
            ),
          ),
          const SizedBox(width: 2),
          Text('ngày', style: AppTokens.caption),
        ],
      ),
    );
  }
}
