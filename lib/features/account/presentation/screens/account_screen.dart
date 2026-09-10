import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../core/utils/supabase_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/leaderboard_view.dart';
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
  late List<CommunityUser> _users;

  // Nhắc học hằng ngày
  bool _reminderEnabled = false;
  int _reminderHour = 19;
  int _reminderMinute = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initLeaderboard();
    // Supabase được khởi tạo sau frame đầu — khi xong sẽ tự nạp lại Bảng vàng.
    SupabaseService.readyNotifier.addListener(_onSupabaseReady);
  }

  @override
  void dispose() {
    SupabaseService.readyNotifier.removeListener(_onSupabaseReady);
    super.dispose();
  }

  void _onSupabaseReady() {
    if (mounted && SupabaseService.isConfigured) {
      _initLeaderboard();
    }
  }

  void _loadData() {
    _userName = StorageService.getUserName();
    _userTarget = StorageService.getUserTarget();
    _reminderEnabled = StorageService.getBool('reminder_enabled') ?? false;
    _reminderHour = StorageService.getInt('reminder_hour') ?? 19;
    _reminderMinute = StorageService.getInt('reminder_minute') ?? 0;
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
    _syncProfileFireAndForget();
  }

  Future<void> _syncProfileFireAndForget() async {
    try {
      await SupabaseService.syncProfile();
    } catch (_) {
      // Đồng bộ hồ sơ là background — lỗi không chặn thao tác của người dùng.
    }
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
        onAuthSuccess: () async {
          Navigator.pop(ctx);
          _loadData();
          await _manualBackup();
          if (mounted) setState(() {});
        },
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
        child: Container(
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
        _buildReminderCard(),
        const SizedBox(height: 18),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppIcon(
                    Icons.dark_mode_rounded,
                    tileSize: 36,
                    iconSize: 18,
                    color: AppColors.purple,
                    bg: AppColors.purpleSoft,
                  ),
                  const SizedBox(width: 10),
                  Text('Giao diện', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.mode,
                builder: (context, mode, _) => Row(
                  children: [
                    _themeOption(ThemeMode.system, 'Hệ thống', Icons.settings_brightness_rounded),
                    const SizedBox(width: 8),
                    _themeOption(ThemeMode.light, 'Sáng', Icons.light_mode_rounded),
                    const SizedBox(width: 8),
                    _themeOption(ThemeMode.dark, 'Tối', Icons.dark_mode_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
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
      ],
    );
  }

  Widget _buildLeaderboardView() {
    return LeaderboardView(
      users: _users,
    );
  }

  /// Thẻ cài đặt nhắc học hằng ngày — chỉ trên mobile native.
  Widget _buildReminderCard() {
    if (!NotificationService.isSupported) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const AppIcon(
              Icons.notifications_active_rounded,
              tileSize: 36,
              iconSize: 18,
              color: AppColors.orange,
              bg: AppColors.orangeSoft,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nhắc học hằng ngày chỉ khả dụng trên ứng dụng Android/iOS.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final timeLabel =
        '${_reminderHour.toString().padLeft(2, '0')}:${_reminderMinute.toString().padLeft(2, '0')}';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(
                Icons.notifications_active_rounded,
                tileSize: 36,
                iconSize: 18,
                color: AppColors.orange,
                bg: AppColors.orangeSoft,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Nhắc học hằng ngày',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ),
              Switch(
                value: _reminderEnabled,
                activeTrackColor: AppColors.green,
                onChanged: (v) => _setReminderEnabled(v),
              ),
            ],
          ),
          if (_reminderEnabled) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickReminderTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.bgPage,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 18, color: AppColors.orange),
                          const SizedBox(width: 10),
                          Text(
                            'Nhắc lúc: $timeLabel',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                          ),
                          const Spacer(),
                          Icon(Icons.edit_calendar_rounded,
                              size: 18, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () async {
                    await NotificationService.cancel();
                    _setReminderEnabled(false);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.red, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Giữ vững thói quen — một nhắc nhở nhỏ mỗi ngày, streak không bao giờ đứt! 🔥',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  void _setReminderEnabled(bool v) {
    setState(() => _reminderEnabled = v);
    StorageService.setBool('reminder_enabled', v);
    if (v) {
      NotificationService.scheduleDaily(
        hour: _reminderHour,
        minute: _reminderMinute,
      );
    } else {
      NotificationService.cancel();
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              Theme.of(context).colorScheme.copyWith(primary: AppColors.orange),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _reminderHour = picked.hour;
      _reminderMinute = picked.minute;
    });
    StorageService.setInt('reminder_hour', picked.hour);
    StorageService.setInt('reminder_minute', picked.minute);
    if (_reminderEnabled) {
      NotificationService.scheduleDaily(hour: picked.hour, minute: picked.minute);
    }
  }

  Widget _themeOption(ThemeMode mode, String label, IconData icon) {
    final selected = ThemeController.mode.value == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ThemeController.set(mode);
          setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.green : AppColors.bgPage,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.green : AppColors.border,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
}
