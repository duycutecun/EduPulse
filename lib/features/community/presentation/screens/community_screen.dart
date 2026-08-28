import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/supabase_service.dart';
import '../../../../shared/widgets/glass_card.dart';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _users = [];
    _initLeaderboard();
  }

  Future<void> _initLeaderboard() async {
    setState(() => _loading = true);
    final cloudUsers = await SupabaseService.fetchLeaderboard();
    if (mounted) {
      setState(() {
        _users = cloudUsers ?? [];
        _loading = false;
      });
    }
  }

  void _cheerUser(int index) {
    setState(() {
      final u = _users[index];
      if (!u.hasCheered) { u.cheers += 1; u.hasCheered = true; }
      else { u.cheers -= 1; u.hasCheered = false; }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bảng Vàng Sĩ Tử', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      SizedBox(height: 4),
                      Text(
                        _users.isEmpty
                            ? 'Bảng xếp hạng sĩ tử'
                            : 'Thi đua cùng ${_users.length} sĩ tử',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((f) {
                    final sel = _selectedFilter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedFilter = f),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.green : AppColors.cardWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: sel ? AppColors.green : AppColors.border, width: 2),
                          ),
                          child: Text(f, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w800 : FontWeight.w600, color: sel ? Colors.white : AppColors.textPrimary)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              _buildPodium(),
              const SizedBox(height: 24),
              GlassCard(
                padding: const EdgeInsets.all(16),
                borderColor: AppColors.yellow,
                borderWidth: 2,
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(14)),
                      child: const Center(child: Text('💌', style: TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Thông điệp hôm nay', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                          SizedBox(height: 3),
                          Text(
                            '"Cố gắng thêm 1 câu Toán hôm nay là tiến gần thêm 1 bước đến cánh cổng trường mơ ước!"',
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Bảng Xếp Hạng Toàn Quốc', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator(color: AppColors.green)),
                )
              else if (_users.isEmpty)
                GlassCard(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text('🏆', style: TextStyle(fontSize: 36)),
                      SizedBox(height: 10),
                      Text('Bảng vàng đang chờ!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      SizedBox(height: 4),
                      Text('Hãy là người đầu tiên xuất hiện trên bảng xếp hạng.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _users.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final isMe = user.name.contains('(Bạn)');
                    return GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      borderColor: isMe ? AppColors.green : AppColors.border,
                      borderWidth: isMe ? 3 : 2,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text('#${user.rank}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: user.rank == 1 ? AppColors.orange : (user.rank == 2 ? AppColors.blue : (user.rank == 3 ? AppColors.purple : AppColors.textMuted)))),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: AppColors.bgPage, shape: BoxShape.circle),
                            child: Center(child: Text(user.emoji, style: const TextStyle(fontSize: 20))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isMe ? AppColors.green : AppColors.textPrimary)),
                                const SizedBox(height: 2),
                                Text(user.target, style: TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                const Text('🔥', style: TextStyle(fontSize: 12)),
                                Text('${user.streak}d', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                              ]),
                              Text('${user.weeklyHours}h/tuần', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ],
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _cheerUser(index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodium() {
    if (_users.length < 3) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _podiumColumn(_users[1], 2, 110, '🥈', AppColors.blue)),
        const SizedBox(width: 8),
        Expanded(child: _podiumColumn(_users[0], 1, 140, '👑', AppColors.orange)),
        const SizedBox(width: 8),
        Expanded(child: _podiumColumn(_users[2], 3, 95, '🥉', AppColors.purple)),
      ],
    );
  }

  Widget _podiumColumn(CommunityUser user, int rank, double height, String medal, Color color) {
    return Column(
      children: [
        Text(medal, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 0, offset: const Offset(0, 3))],
          ),
          child: Center(child: Text(user.emoji, style: const TextStyle(fontSize: 24))),
        ),
        const SizedBox(height: 6),
        Text(user.name.split(' ').last, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Container(
          height: height, width: double.infinity,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(child: Text('#$rank', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color))),
        ),
      ],
    );
  }
}
