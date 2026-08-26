import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/animated_pulse.dart';
import '../../../study/domain/models/study_models.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String _selectedFilter = 'Tất cả';
  final List<String> _filters = ['Tất cả', 'THPTQG', 'TSA', 'HSA'];

  late List<CommunityUser> _users;

  @override
  void initState() {
    super.initState();
    _users = [
      CommunityUser(
        rank: 1,
        name: 'Nguyễn Hoàng Minh',
        target: 'Bách Khoa HN — IT1',
        streak: 48,
        weeklyHours: 42.5,
        emoji: '🦁',
        badge: '👑 Thủ Khoa Tuần',
        cheers: 342,
      ),
      CommunityUser(
        rank: 2,
        name: 'Trần Thảo Linh',
        target: 'ĐH Ngoại Thương — NTH01',
        streak: 42,
        weeklyHours: 38.0,
        emoji: '🦊',
        badge: '🥈 Á Khoa',
        cheers: 289,
      ),
      CommunityUser(
        rank: 3,
        name: 'Lê Quốc Bảo',
        target: 'ĐHQG HN — Khoa học máy tính',
        streak: 35,
        weeklyHours: 36.5,
        emoji: '🐯',
        badge: '🥉 Chiến Thần Cày',
        cheers: 215,
      ),
      CommunityUser(
        rank: 4,
        name: 'Phạm Quỳnh Anh',
        target: 'ĐH Y Hà Nội — Y Đa Khoa',
        streak: 29,
        weeklyHours: 34.0,
        emoji: '🦉',
        badge: '⭐ Siêu Kiên Trì',
        cheers: 178,
      ),
      CommunityUser(
        rank: 5,
        name: 'Đặng Tuấn Kiệt',
        target: 'ĐH Bách Khoa HCM — Điện tử',
        streak: 26,
        weeklyHours: 31.5,
        emoji: '🐼',
        badge: '🔥 Bứt Phá',
        cheers: 145,
      ),
      CommunityUser(
        rank: 6,
        name: 'Sĩ tử 2026 (Bạn)',
        target: 'ĐH Bách Khoa Hà Nội > 27đ',
        streak: 12,
        weeklyHours: 24.5,
        emoji: '🚀',
        badge: '✨ Đang Bứt Phá',
        cheers: 98,
      ),
    ];
  }

  void _cheerUser(int index) {
    setState(() {
      final u = _users[index];
      if (!u.hasCheered) {
        u.cheers += 1;
        u.hasCheered = true;
      } else {
        u.cheers -= 1;
        u.hasCheered = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 18,
            right: 18,
            top: 16,
            bottom: 120,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bảng Vàng Sĩ Tử 🏆',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thi đua ôn luyện & tiếp lửa cùng 12,400+ sĩ tử',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  PulsingGlow(
                    glowColor: AppColors.appleOrange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.appleOrange.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.appleOrange.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Text('🔥', style: TextStyle(fontSize: 14)),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.appleOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((f) {
                    final sel = _selectedFilter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedFilter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.appleIndigo
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sel
                                  ? AppColors.appleIndigo
                                  : (isDark ? Colors.white12 : Colors.black12),
                            ),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  sel ? FontWeight.bold : FontWeight.w500,
                              color: sel
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Top 3 Podium
              _buildPodium(isDark),
              const SizedBox(height: 24),

              // Daily Motivation Card
              GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.applePurple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text('💌', style: TextStyle(fontSize: 22)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thông điệp sĩ tử hôm nay',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.neonCyan,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '"Cố gắng thêm 1 câu Toán hôm nay là tiến gần thêm 1 bước đến cánh cổng trường mơ ước!"',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Full Leaderboard List
              const Text(
                'Bảng Xếp Hạng Toàn Quốc',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _users.length,
                separatorBuilder: (c, i) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final user = _users[index];
                  final isMe = user.name.contains('(Bạn)');

                  return GlassCard(
                    borderRadius: 18,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    borderColor: isMe
                        ? AppColors.neonCyan.withValues(alpha: 0.5)
                        : null,
                    child: Row(
                      children: [
                        // Rank
                        Container(
                          width: 28,
                          alignment: Alignment.center,
                          child: Text(
                            '#${user.rank}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: user.rank == 1
                                  ? AppColors.appleOrange
                                  : (user.rank == 2
                                      ? AppColors.neonCyan
                                      : (user.rank == 3
                                          ? AppColors.applePurple
                                          : (isDark
                                              ? Colors.white54
                                              : Colors.black45))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Emoji Avatar
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                          child: Center(
                            child: Text(
                              user.emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    user.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isMe ? AppColors.neonCyan : null,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.neonCyan.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'YOU',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.neonCyan,
                                        ),
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.target,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Streak & Hours
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🔥', style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 2),
                                Text(
                                  '${user.streak}d',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${user.weeklyHours}h/tuần',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        // Cheer Button
                        GestureDetector(
                          onTap: () => _cheerUser(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: user.hasCheered
                                  ? AppColors.appleRed.withValues(alpha: 0.2)
                                  : (isDark ? Colors.white10 : Colors.black12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: user.hasCheered
                                    ? AppColors.appleRed.withValues(alpha: 0.5)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  user.hasCheered ? '❤️' : '🤍',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${user.cheers}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: user.hasCheered
                                        ? AppColors.appleRed
                                        : (isDark
                                            ? Colors.white60
                                            : Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodium(bool isDark) {
    if (_users.length < 3) return const SizedBox.shrink();
    final top1 = _users[0];
    final top2 = _users[1];
    final top3 = _users[2];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 2nd Place
        Expanded(
          child: _buildPodiumColumn(
            user: top2,
            rank: 2,
            height: 110,
            medal: '🥈',
            color: AppColors.neonCyan,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        // 1st Place
        Expanded(
          child: _buildPodiumColumn(
            user: top1,
            rank: 1,
            height: 140,
            medal: '👑',
            color: AppColors.appleOrange,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        // 3rd Place
        Expanded(
          child: _buildPodiumColumn(
            user: top3,
            rank: 3,
            height: 95,
            medal: '🥉',
            color: AppColors.applePurple,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildPodiumColumn({
    required CommunityUser user,
    required int rank,
    required double height,
    required String medal,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Text(medal, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.7), color],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Center(
            child: Text(user.emoji, style: const TextStyle(fontSize: 24)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          user.name.split(' ').last,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${user.weeklyHours}h',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.3),
                color.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
