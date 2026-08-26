import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../core/utils/supabase_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../study/domain/models/study_models.dart';

class AccountScreen extends StatefulWidget {
  final VoidCallback onThemeChanged;
  final VoidCallback onDataChanged;

  const AccountScreen({
    super.key,
    required this.onThemeChanged,
    required this.onDataChanged,
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  int _activeSegment = 0; // 0: Hồ sơ & Cài đặt, 1: Bảng vàng Sĩ tử

  late String _userName;
  late String _userTarget;
  late String _apiKey;
  late String _supabaseUrl;
  late String _supabaseAnonKey;
  late bool _isDark;
  bool _isSyncing = false;

  // Leaderboard data
  String _selectedFilter = 'Tất cả';
  final List<String> _filters = ['Tất cả', 'THPTQG', 'TSA', 'HSA'];
  late List<CommunityUser> _users;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initLeaderboard();
  }

  void _loadData() {
    _userName = StorageService.getUserName();
    _userTarget = StorageService.getUserTarget();
    _apiKey = StorageService.getGeminiApiKey();
    _supabaseUrl = StorageService.getSupabaseUrl();
    _supabaseAnonKey = StorageService.getSupabaseAnonKey();
    _isDark = StorageService.isDarkMode();
  }

  void _initLeaderboard() async {
    _users = [];

    if (SupabaseService.isConfigured) {
      final cloudUsers = await SupabaseService.fetchLeaderboard();
      if (cloudUsers != null && cloudUsers.isNotEmpty) {
        setState(() {
          _users = cloudUsers;
        });
      }
    }
  }

  void _updateProfile(String name, String target) {
    StorageService.setUserName(name);
    StorageService.setUserTarget(target);
    setState(() {
      _userName = name;
      _userTarget = target;
    });
    widget.onDataChanged();
    SupabaseService.syncProfile();
  }

  void _updateApiKey(String key) {
    StorageService.setGeminiApiKey(key);
    setState(() {
      _apiKey = key;
    });
  }

  void _updateSupabase(String url, String key) async {
    StorageService.setSupabaseUrl(url);
    StorageService.setSupabaseAnonKey(key);
    setState(() {
      _supabaseUrl = url;
      _supabaseAnonKey = key;
    });

    final success = await SupabaseService.init(customUrl: url, customKey: key);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '🟢 Đã kết nối Supabase Cloud Database thành công!'
                : '⚠️ Không thể kết nối. Vui lòng kiểm tra lại URL & Key!',
          ),
        ),
      );
    }
  }

  Future<void> _manualSync() async {
    if (!SupabaseService.isConfigured) {
      _showSupabaseDialog(Theme.of(context).brightness == Brightness.dark);
      return;
    }

    setState(() => _isSyncing = true);
    final ok = await SupabaseService.syncAll();
    setState(() => _isSyncing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '☁️ Đồng bộ đám mây Supabase hoàn tất!'
                : '⚠️ Đồng bộ thất bại. Kiểm tra kết nối mạng!',
          ),
        ),
      );
    }
  }

  void _toggleTheme(bool val) {
    StorageService.setDarkMode(val);
    setState(() {
      _isDark = val;
    });
    widget.onThemeChanged();
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

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented Switcher
          _buildSegmentSwitcher(isDark),
          const SizedBox(height: 16),

          if (_activeSegment == 0) ...[
            _buildProfileAndSettings(isDark),
          ] else ...[
            _buildLeaderboardView(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentSwitcher(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E28).withValues(alpha: 0.7)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeSegment = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: _activeSegment == 0
                      ? const LinearGradient(
                          colors: [AppColors.appleIndigo, AppColors.appleBlue],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _activeSegment == 0
                      ? [
                          BoxShadow(
                            color: AppColors.appleIndigo.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.person_crop_circle_fill,
                      size: 16,
                      color: _activeSegment == 0
                          ? Colors.white
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Hồ sơ & Cài đặt',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _activeSegment == 0
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeSegment = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: _activeSegment == 1
                      ? const LinearGradient(
                          colors: [AppColors.appleIndigo, AppColors.appleBlue],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _activeSegment == 1
                      ? [
                          BoxShadow(
                            color: AppColors.appleIndigo.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.star_fill,
                      size: 16,
                      color: _activeSegment == 1
                          ? Colors.white
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Bảng Vàng Sĩ Tử',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _activeSegment == 1
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAndSettings(bool isDark) {
    final hasSupabase = SupabaseService.isConfigured;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Card
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.appleIndigo, AppColors.appleBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.appleIndigo.withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🎓', style: TextStyle(fontSize: 30)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _userTarget.isNotEmpty ? '🎯 Mục tiêu: $_userTarget' : 'Chưa đặt mục tiêu trường',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.appleGreen.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '⚡ Sĩ tử EduPulse 2026',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.appleGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showEditProfileDialog(isDark),
                icon: const Icon(CupertinoIcons.pencil_circle_fill, color: AppColors.appleBlue, size: 28),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Section: Cloud Database & AI
        _sectionTitle('ĐÁM MÂY & TRÍ TUỆ NHÂN TẠO', isDark),
        const SizedBox(height: 8),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildSettingTile(
                icon: CupertinoIcons.cloud_fill,
                iconColor: AppColors.appleBlue,
                title: 'Supabase Cloud Database',
                subtitle: hasSupabase
                    ? '🟢 Đã kết nối PostgreSQL Cloud'
                    : '⚠️ Chưa kết nối (Bấm để thiết lập)',
                trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.textMutedDark),
                onTap: () => _showSupabaseDialog(isDark),
                isDark: isDark,
              ),
              _divider(isDark),
              _buildSettingTile(
                icon: CupertinoIcons.arrow_2_circlepath,
                iconColor: AppColors.neonCyan,
                title: 'Đồng bộ đám mây ngay',
                subtitle: _isSyncing ? 'Đang tải dữ liệu...' : 'Đẩy tiến độ & mục tiêu lên máy chủ',
                trailing: _isSyncing
                    ? const CupertinoActivityIndicator()
                    : const Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.textMutedDark),
                onTap: _isSyncing ? null : _manualSync,
                isDark: isDark,
              ),
              _divider(isDark),
              _buildSettingTile(
                icon: CupertinoIcons.sparkles,
                iconColor: AppColors.appleOrange,
                title: 'Cấu hình Gemini API Key',
                subtitle: _apiKey.isNotEmpty ? '🟢 Đã liên kết API Key' : '⚠️ Chưa nhập (Cần cho AI Coach)',
                trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.textMutedDark),
                onTap: () => _showApiKeyDialog(isDark),
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Section: Preferences
        _sectionTitle('TÙY CHỈNH & GIAO DIỆN', isDark),
        const SizedBox(height: 8),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildSettingTile(
                icon: CupertinoIcons.moon_fill,
                iconColor: AppColors.appleIndigo,
                title: 'Giao diện Tối (Dark Mode)',
                subtitle: 'Bảo vệ mắt khi cày đêm',
                trailing: CupertinoSwitch(
                  value: _isDark,
                  onChanged: _toggleTheme,
                ),
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Section: Storage & About
        _sectionTitle('DỮ LIỆU & HỆ THỐNG', isDark),
        const SizedBox(height: 8),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildSettingTile(
                icon: CupertinoIcons.device_phone_portrait,
                iconColor: AppColors.appleGreen,
                title: 'Lưu trữ cục bộ Offline',
                subtitle: 'Dữ liệu ôn thi luôn được lưu an toàn trên máy',
                isDark: isDark,
              ),
              _divider(isDark),
              _buildSettingTile(
                icon: CupertinoIcons.globe,
                iconColor: AppColors.applePurple,
                title: 'Phiên bản Web / Vercel',
                subtitle: 'EduPulse Web Ready • Single Page App',
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardView(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.appleIndigo
                          : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? AppColors.appleIndigo : (isDark ? Colors.white12 : Colors.black12),
                      ),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                        color: sel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),

        // Podium Top 3
        _buildPodium(isDark),
        const SizedBox(height: 18),

        // Full Leaderboard
        Text(
          'Bảng Xếp Hạng Toàn Quốc',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 10),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _users.length,
          separatorBuilder: (c, i) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final user = _users[index];
            final isMe = user.name.contains('(Bạn)');

            return GlassCard(
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              borderColor: isMe ? AppColors.neonCyan.withValues(alpha: 0.5) : null,
              child: Row(
                children: [
                  // Rank
                  SizedBox(
                    width: 28,
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
                                    : (isDark ? Colors.white54 : Colors.black45))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Emoji
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                    child: Center(child: Text(user.emoji, style: const TextStyle(fontSize: 19))),
                  ),
                  const SizedBox(width: 10),
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
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isMe ? AppColors.neonCyan : null,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.neonCyan.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  'BẠN',
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
                            color: isDark ? Colors.white54 : Colors.black45,
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
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Text(
                        '${user.weeklyHours}h/tuần',
                        style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white38 : Colors.black38),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  // Cheer
                  GestureDetector(
                    onTap: () => _cheerUser(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: user.hasCheered
                            ? AppColors.appleRed.withValues(alpha: 0.2)
                            : (isDark ? Colors.white10 : Colors.black12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Text(user.hasCheered ? '❤️' : '🤍', style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            '${user.cheers}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: user.hasCheered ? AppColors.appleRed : (isDark ? Colors.white60 : Colors.black54),
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
        Expanded(
          child: _buildPodiumColumn(
            user: top2,
            rank: 2,
            height: 95,
            medal: '🥈',
            color: AppColors.neonCyan,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildPodiumColumn(
            user: top1,
            rank: 1,
            height: 125,
            medal: '👑',
            color: AppColors.appleOrange,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildPodiumColumn(
            user: top3,
            rank: 3,
            height: 85,
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
        Text(medal, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 3),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [color.withValues(alpha: 0.7), color]),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Center(child: Text(user.emoji, style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(height: 4),
        Text(
          user.name.split(' ').last,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${user.weeklyHours}h',
          style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white60 : Colors.black54),
        ),
        const SizedBox(height: 5),
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.08)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    required bool isDark,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 19),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
              ),
            )
          : null,
      trailing: trailing,
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 52,
      color: isDark ? AppColors.iosSeparator : Colors.black12,
    );
  }

  void _showEditProfileDialog(bool isDark) {
    final nameCtrl = TextEditingController(text: _userName);
    final targetCtrl = TextEditingController(text: _userTarget);

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Chỉnh Sửa Hồ Sơ Sĩ Tử'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              CupertinoTextField(
                controller: nameCtrl,
                placeholder: 'Họ và tên hoặc biệt danh',
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: targetCtrl,
                placeholder: 'Mục tiêu trường & điểm số',
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                _updateProfile(nameCtrl.text.trim(), targetCtrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showSupabaseDialog(bool isDark) {
    final urlCtrl = TextEditingController(text: _supabaseUrl);
    final keyCtrl = TextEditingController(text: _supabaseAnonKey);

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Cấu Hình Supabase Database'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              const Text(
                'Nhập Project URL và Anon Key từ Supabase Dashboard (Settings > API) để kích hoạt cơ sở dữ liệu đám mây PostgreSQL.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: urlCtrl,
                placeholder: 'https://xxxx.supabase.co',
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: keyCtrl,
                placeholder: 'eyJhbGciOiJIUzI1NiIsInR5cCI...',
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              _updateSupabase(urlCtrl.text.trim(), keyCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Lưu & Kết Nối'),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(bool isDark) {
    final keyCtrl = TextEditingController(text: _apiKey);

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Cấu Hình Gemini API Key'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              const Text(
                'Nhập khóa Gemini API (miễn phí tại aistudio.google.com) để kích hoạt AI Coach giải đề & phân tích OCR.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: keyCtrl,
                placeholder: 'AIzaSy...',
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              _updateApiKey(keyCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
