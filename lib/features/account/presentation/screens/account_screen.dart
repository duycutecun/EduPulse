import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../core/utils/supabase_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
import '../../../study/domain/models/study_models.dart';

class AccountScreen extends StatefulWidget {
  final VoidCallback onDataChanged;

  const AccountScreen({
    super.key,
    required this.onDataChanged,
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  int _activeSegment = 0;
  late String _userName;
  late String _userTarget;
  bool _isSyncing = false;
  bool _isRestoring = false;
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
  }

  void _initLeaderboard() async {
    _users = [];
    if (SupabaseService.isConfigured) {
      final cloudUsers = await SupabaseService.fetchLeaderboard();
      if (cloudUsers != null && cloudUsers.isNotEmpty && mounted) {
        setState(() => _users = cloudUsers);
      }
    }
  }

  void _updateProfile(String name, String target) {
    StorageService.setUserName(name);
    StorageService.setUserTarget(target);
    setState(() { _userName = name; _userTarget = target; });
    widget.onDataChanged();
    SupabaseService.syncProfile();
  }

  Future<void> _manualBackup() async {
    if (!SupabaseService.isConfigured) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cloud chưa sẵn sàng'))); } return; }
    setState(() => _isSyncing = true);
    final ok = await SupabaseService.syncAll();
    setState(() => _isSyncing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Đã sao lưu!' : 'Sao lưu thất bại!'),
        backgroundColor: ok ? AppColors.green : AppColors.red,
      ));
    }
  }

  Future<void> _manualRestore() async {
    if (!SupabaseService.isConfigured) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cloud chưa sẵn sàng'))); } return; }
    setState(() => _isRestoring = true);
    final ok = await SupabaseService.restoreAll();
    setState(() => _isRestoring = false);
    if (ok) { _loadData(); widget.onDataChanged(); }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Đã khôi phục!' : 'Khôi phục thất bại!'),
        backgroundColor: ok ? AppColors.blue : AppColors.red,
      ));
    }
  }

  void _openAuthScreen() {
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (ctx) => AuthScreen(
        onAuthSuccess: () { Navigator.pop(ctx); _loadData(); _manualBackup(); setState(() {}); },
        onSkip: () => Navigator.pop(ctx),
      ),
    ));
  }

  void _handleSignOut() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.border, width: 2)),
        title: const Text('Đăng xuất?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Dữ liệu cục bộ vẫn được giữ. Hãy sao lưu trước khi đăng xuất.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),           child: Text('Hủy', style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () async { Navigator.pop(ctx); await SupabaseService.signOut(); if (mounted) { setState(() {}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đăng xuất'))); } },
            child: const Text('Đăng xuất', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _cheerUser(int index) {
    if (index >= _users.length) return;
    setState(() {
      final u = _users[index];
      if (!u.hasCheered) { u.cheers += 1; u.hasCheered = true; }
      else { u.cheers -= 1; u.hasCheered = false; }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSegmentSwitcher(),
          const SizedBox(height: 16),
          if (_activeSegment == 0) _buildProfileAndSettings() else _buildLeaderboardView(),
        ],
      ),
    );
  }

  Widget _buildSegmentSwitcher() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Row(
        children: [
          _segmentBtn(0, Icons.person_rounded, 'Hồ sơ'),
          _segmentBtn(1, Icons.workspace_premium_rounded, 'Bảng vàng'),
        ],
      ),
    );
  }

  Widget _segmentBtn(int index, IconData icon, String label) {
    final active = _activeSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeSegment = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.green : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? Colors.white : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: active ? Colors.white : AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAndSettings() {
    final isLoggedIn = SupabaseService.isLoggedIn;
    final user = SupabaseService.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isLoggedIn && user != null) ...[
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    const AppIcon(
                      Icons.cloud_done_rounded,
                      tileSize: 44,
                      iconSize: 24,
                      color: AppColors.green,
                      bg: AppColors.greenSoft,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.email ?? 'EduPulse', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          Text('Đã kết nối đám mây', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: _handleSignOut, icon: const Icon(Icons.logout, color: AppColors.red, size: 22)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _isSyncing ? null : _manualBackup,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [BoxShadow(color: AppColors.greenDark, blurRadius: 0, offset: Offset(0, 3))],
                          ),
                          child: Center(
                            child: _isSyncing
                                ? const CupertinoActivityIndicator(color: Colors.white)
                                : const Text('Sao lưu ngay', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
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
                            color: AppColors.cardWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border, width: 2),
                          ),
                          child: Center(
                            child: _isRestoring
                                ? const CupertinoActivityIndicator()
                                : Text('Khôi phục', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
          GestureDetector(
            onTap: _openAuthScreen,
            child: GlassCard(
              padding: const EdgeInsets.all(18),
              borderColor: AppColors.green,
              borderWidth: 3,
              child: Row(
                children: [
                  const AppIcon(
                    Icons.person_add_rounded,
                    tileSize: 44,
                    iconSize: 24,
                    color: AppColors.green,
                    bg: AppColors.greenSoft,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tạo tài khoản & Sao lưu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        SizedBox(height: 2),
                        Text('Đăng nhập để đồng bộ trên nhiều thiết bị', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.green, size: 18),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.green,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.greenDark, blurRadius: 0, offset: Offset(0, 4))],
                ),
                child: const Center(child: Text('🎓', style: TextStyle(fontSize: 28))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_userName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      _userTarget.isNotEmpty ? 'Mục tiêu: $_userTarget' : 'Chưa đặt mục tiêu',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                      child: const Text('⚡ Sĩ tử 2026', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.green)),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _showEditProfileDialog,
                child: AppIcon(
                  Icons.edit_rounded,
                  tileSize: 40,
                  iconSize: 20,
                  color: AppColors.blue,
                  bg: AppColors.blueSoft,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionTitle('HỆ THỐNG'),
        const SizedBox(height: 8),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _settingTile(
                Icons.auto_awesome_rounded,
                AppColors.blue,
                'Gemini API Key',
                StorageService.getGeminiApiKey().isEmpty
                    ? 'Chưa cấu hình'
                    : 'Đã cấu hình',
                _showGeminiKeyDialog,
              ),
              _divider(),
              _settingTile(Icons.phone_android, AppColors.green, 'Lưu trữ Offline', 'Dữ liệu an toàn trên máy', null),
              _divider(),
              _settingTile(Icons.language, AppColors.purple, 'Phiên bản Web', 'EduPulse Web Ready', null),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        if (_users.length >= 3) ...[_buildPodium(), const SizedBox(height: 18)],
        if (_users.isNotEmpty)
          ..._users.map((user) => GlassCard(
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
                  onTap: () => _cheerUser(_users.indexOf(user)),
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
            padding: EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Text('🏆', style: TextStyle(fontSize: 36)),
                  SizedBox(height: 10),
                  Text('Bảng vàng đang chờ!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('Đăng nhập & duy trì streak để xuất hiện trên bảng xếp hạng.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPodium() {
    if (_users.length < 3) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _podiumColumn(_users[1], 2, 95, '🥈', AppColors.blue)),
        const SizedBox(width: 8),
        Expanded(child: _podiumColumn(_users[0], 1, 125, '👑', AppColors.orange)),
        const SizedBox(width: 8),
        Expanded(child: _podiumColumn(_users[2], 3, 85, '🥉', AppColors.purple)),
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMuted)),
    );
  }

  Widget _settingTile(IconData icon, Color iconColor, String title, String? subtitle, VoidCallback? onTap, {Widget? trailing}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: AppIcon(
        icon,
        tileSize: 40,
        iconSize: 22,
        color: iconColor,
        bg: iconColor.withValues(alpha: 0.15),
      ),
      title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.textMuted)) : null,
      trailing: trailing ?? Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
    );
  }

  Widget _divider() {
    return Divider(height: 1, thickness: 2, indent: 56, color: AppColors.border);
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _userName);
    final targetCtrl = TextEditingController(text: _userTarget);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.border, width: 2)),
        title: const Text('Chỉnh sửa hồ sơ', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Họ tên')),
            const SizedBox(height: 10),
            TextField(controller: targetCtrl, decoration: const InputDecoration(hintText: 'Mục tiêu trường')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),           child: Text('Hủy', style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () { if (nameCtrl.text.trim().isNotEmpty) _updateProfile(nameCtrl.text.trim(), targetCtrl.text.trim()); Navigator.pop(ctx); },
            child: const Text('Lưu', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showGeminiKeyDialog() {
    final ctrl = TextEditingController(text: StorageService.getGeminiApiKey());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.border, width: 2)),
        title: const Text('Gemini API Key', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dán key để AI Coach gọi trực tiếp Gemini (model "Gemini 3.7 Flash (Key)"). Lấy key miễn phí tại aistudio.google.com/apikey.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'AIza...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy', style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () {
              StorageService.setGeminiApiKey(ctrl.text.trim());
              Navigator.pop(ctx);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu Gemini API Key')));
            },
            child: const Text('Lưu', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
