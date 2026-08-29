import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../features/study/domain/models/study_models.dart';
import 'glass_card.dart';

/// Bảng Xếp Hạng Sĩ Tử dùng chung (bảng vàng).
///
/// Widget thuần hiển thị (presentational): nhận dữ liệu + callback, không tự
/// quản lý state để tái sử dụng được ở nhiều màn hình (Tài khoản, Community).
class LeaderboardView extends StatelessWidget {
  final List<CommunityUser> users;
  final List<String> filters;
  final String selectedFilter;
  final ValueChanged<String> onFilterSelected;
  final ValueChanged<CommunityUser> onCheer;

  const LeaderboardView({
    super.key,
    required this.users,
    required this.filters,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.onCheer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((f) {
              final sel = selectedFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onFilterSelected(f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.green : AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: sel ? AppColors.green : AppColors.border, width: 2),
                    ),
                    child: Text(f, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w800 : FontWeight.w600, color: sel ? Colors.white : AppColors.textPrimary)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),
        if (users.length >= 3) ...[_buildPodium(), const SizedBox(height: 18)],
        if (users.isNotEmpty)
          ...users.map((user) => GlassCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                SizedBox(width: 28, child: Text('#${user.rank}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: user.rank <= 3 ? AppColors.orange : AppColors.textMuted))),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: AppColors.bgPage, shape: BoxShape.circle),
                  child: Center(child: Text(user.emoji, style: const TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text(user.target, style: TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 12)),
                    Text('${user.streak}d', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => onCheer(user),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: user.hasCheered ? AppColors.red.withValues(alpha: 0.15) : AppColors.bgPage,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: user.hasCheered ? AppColors.red : AppColors.border, width: 2),
                    ),
                    child: Text(user.hasCheered ? '❤️ ${user.cheers}' : '🤍 ${user.cheers}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ))
        else
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 10),
                  Text('Bảng vàng đang chờ!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Đăng nhập & duy trì streak để xuất hiện trên bảng xếp hạng.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPodium() {
    if (users.length < 3) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _podiumColumn(users[1], 2, 95, '🥈', AppColors.blue)),
        const SizedBox(width: 8),
        Expanded(child: _podiumColumn(users[0], 1, 125, '👑', AppColors.orange)),
        const SizedBox(width: 8),
        Expanded(child: _podiumColumn(users[2], 3, 85, '🥉', AppColors.purple)),
      ],
    );
  }

  Widget _podiumColumn(CommunityUser user, int rank, double height, String medal, Color color) {
    return Column(
      children: [
        Text(medal, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 3),
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 0, offset: const Offset(0, 3))],
          ),
          child: Center(child: Text(user.emoji, style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(height: 4),
        Text(user.name.split(' ').last, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Container(
          height: height, width: double.infinity,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(child: Text('#$rank', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color))),
        ),
      ],
    );
  }
}
