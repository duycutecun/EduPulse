import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../core/utils/supabase_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
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
  bool _isRestoring = false;

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
      if (cloudUsers != null && cloudUsers.isNotEmpty && mounted) {
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

  Future<void> _manualBackup() async {
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
          content: Row(
            children: [
              Text(ok ? '✅ ' : '⚠️ '),
              Expanded(
                child: Text(
                  ok
                      ? '☁️ Đã sao lưu toàn bộ dữ liệu (Nhiệm vụ, Kỳ thi, Streak) lên đám mây!'
                      : '⚠️ Sao lưu thất bại. Kiểm tra kết nối mạng!',
                ),
              ),
            ],
          ),
          backgroundColor: ok ? AppColors.appleGreen : AppColors.appleRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _manualRestore() async {
    if (!SupabaseService.isConfigured) {
      _showSupabaseDialog(Theme.of(context).brightness == Brightness.dark);
      return;
    }

    setState(() => _isRestoring = true);
    final ok = await SupabaseService.restoreAll();
    setState(() => _isRestoring = false);

    if (ok) {
      _loadData();
      widget.onDataChanged();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(ok ? '✅ ' : '⚠️ '),
              Expanded(
                child: Text(
                  ok
                      ? '📥 Đã khôi phục dữ liệu từ đám mây về thiết bị!'
                      : '⚠️ Khôi phục thất bại hoặc chưa có bản sao lưu trên đám mây.',
                ),
              ),
            ],
          ),
          backgroundColor: ok ? AppColors.appleBlue : AppColors.appleRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openAuthScreen() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (ctx) => AuthScreen(
          onAuthSuccess: () {
            Navigator.pop(ctx);
            _loadData();
            _manualBackup(); // Tự động backup ngay khi đăng nhập
            setState(() {});
          },
          onSkip: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _handleSignOut() async {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Đăng xuất tài khoản?'),
        content: const Text(
          'Dữ liệu cục bộ trên máy này vẫn được giữ nguyên. Hãy đảm bảo bạn đã bấm "Sao lưu" trước khi đăng xuất.',
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: false,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await SupabaseService.signOut();
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('👋 Đã đăng xuất khỏi tài khoản.')),
                );
              }
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  void _toggleTheme(bool val) {
    StorageService.setDarkMode(val);
    setState(() {
      _isDark = val;
    });
    widget.onThemeChanged();
  }

  void _cheerUser(int index) {
    if (index >= _users.length) return;
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
    final isLoggedIn = SupabaseService.isLoggedIn;
    final user = SupabaseService.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. AUTH CARD (Đăng nhập / Đăng ký hoặc Trạng thái tài khoản)
        if (isLoggedIn && user != null) ...[
          // Logged in Banner
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.appleGreen.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.shield_fill, color: AppColors.appleGreen, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'TÀI KHOẢN ĐÁM MÂY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.appleGreen,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.appleGreen.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '🟢 ĐÃ KẾT NỐI',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.appleGreen),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.email ?? 'Tài khoản EduPulse',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _handleSignOut,
                      icon: const Icon(CupertinoIcons.square_arrow_right, color: AppColors.appleRed, size: 22),
                      tooltip: 'Đăng xuất',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Backup & Restore Actions
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _isSyncing ? null : _manualBackup,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.appleIndigo, AppColors.appleBlue],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: _isSyncing
                                ? const CupertinoActivityIndicator(color: Colors.white)
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.cloud_upload_fill, color: Colors.white, size: 15),
                                      SizedBox(width: 6),
                                      Text(
                                        'Sao lưu ngay',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _isRestoring ? null : _manualRestore,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          child: Center(
                            child: _isRestoring
                                ? const CupertinoActivityIndicator()
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        CupertinoIcons.cloud_download,
                                        size: 15,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Khôi phục',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          // Guest Mode Prompt Card
          GestureDetector(
            onTap: _openAuthScreen,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF261D4C).withValues(alpha: 0.9),
                          const Color(0xFF161E38).withValues(alpha: 0.9),
                        ]
                      : [
                          const Color(0xFF5E5CE6).withValues(alpha: 0.12),
                          const Color(0xFF0A84FF).withValues(alpha: 0.08),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: AppColors.appleIndigo.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.appleIndigo.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.person_badge_plus_fill, color: AppColors.appleIndigo, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tạo tài khoản & Sao lưu',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Đăng nhập để đồng bộ tiến độ học tập trên nhiều thiết bị',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_right, color: AppColors.appleIndigo, size: 18),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),

        // 2. PROFILE CARD (Tên & Mục tiêu)
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
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
                  child: Text('🎓', style: TextStyle(fontSize: 28)),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _userTarget.isNotEmpty ? '🎯 Mục tiêu: $_userTarget' : 'Chưa đặt mục tiêu trường',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.appleGreen.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '⚡ Sĩ tử EduPulse 2026',
                        style: TextStyle(
                          fontSize: 10,
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
                icon: const Icon(CupertinoIcons.pencil_circle_fill, color: AppColors.appleBlue, size: 26),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 3. Section: Cloud Database & AI
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
                    : '⚠️ Chưa kết nối (Bấm để thiết lập URL & Key)',
                trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.textMutedDark),
                onTap: () => _showSupabaseDialog(isDark),
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

        // 4. Section: Preferences
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
                subtitle: 'Bảo vệ mắt khi cày đề đêm',
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

        // 5. Section: Storage & System
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

        // Podium Top 3 (nếu có dữ liệu)
        if (_users.length >= 3) ...[
          _buildPodium(isDark),
          const SizedBox(height: 18),
        ],

        // Leaderboard title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Bảng Xếp Hạng Toàn Quốc',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            IconButton(
              onPressed: _initLeaderboard,
              icon: const Icon(CupertinoIcons.arrow_clockwise, size: 18),
              tooltip: 'Làm mới',
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_users.isNotEmpty) ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _users.length,
            separatorBuilder: (c, i) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final user = _users[index];
              return GlassCard(
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
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
        ] else ...[
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 10),
                  Text(
                    'Bảng vàng đang chờ sĩ tử!',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Đăng nhập và tích cực duy trì chuỗi Streak mỗi ngày để xuất hiện trên bảng vinh danh toàn quốc.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
