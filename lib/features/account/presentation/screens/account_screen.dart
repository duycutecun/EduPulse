import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../../../../core/utils/data_transfer.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/sync/sync_state.dart';
import '../../../../shared/widgets/sync_status_bar.dart';
import '../../../../core/notifications/adaptive_policy.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/pwa/pwa_service.dart';
import '../../../../core/theme/appearance_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../core/utils/feedback_service.dart';
import '../../../../core/ai/ai_models.dart';
import '../../../../core/utils/supabase_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/leaderboard_view.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
import '../widgets/family_report_sheet.dart';
import 'learning_profile_screen.dart';
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
  bool _digestEnabled = false;
  bool _aiMayRead = true;
  bool _aiMayAnalyze = true;
  bool _mascotEnabled = true;
  bool _reduceMotion = false;

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
    _digestEnabled = StorageService.getBool('notif_digest_enabled') ?? false;
    _aiMayRead = StorageService.getBool('ai_permission_read') ?? true;
    _aiMayAnalyze = StorageService.getBool('ai_permission_analyze') ?? true;
    _mascotEnabled = StorageService.getBool('mascot_enabled') ?? true;
    _reduceMotion = StorageService.getBool('reduce_motion') ?? false;
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
    SyncStateService.markSyncing();
    final ok = await SupabaseService.syncAll();
    setState(() => _isSyncing = false);
    // Cập nhật chip sync ở mọi nơi (sidebar, footer) theo kết quả thật.
    if (ok) {
      SyncStateService.markSynced();
    } else {
      SyncStateService.markError();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Đã sao lưu!' : 'Sao lưu thất bại!'),
        backgroundColor: ok ? AppColors.primary : AppColors.red,
      ));
    }
  }

  Future<void> _manualRestore() async {
    if (!SupabaseService.isConfigured) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cloud chưa sẵn sàng'))); } return; }
    setState(() => _isRestoring = true);
    SyncStateService.markSyncing();
    final ok = await SupabaseService.restoreAll();
    setState(() => _isRestoring = false);
    if (ok) {
      SyncStateService.markSynced();
      _loadData();
      widget.onDataChanged();
    } else {
      SyncStateService.markError();
    }
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
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? Colors.white : AppColors.textMuted),
              const SizedBox(width: 6),
              // Flexible + ellipsis: nhãn dài không đẩy tràn nút segment khi
              // màn hẹp (320px).
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: active ? Colors.white : AppColors.textPrimary)),
              ),
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
                      color: AppColors.primary,
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
                    IconButton(
                      tooltip: 'Đăng xuất',
                      onPressed: _handleSignOut,
                      icon: const Icon(Icons.logout, color: AppColors.red, size: 22),
                    ),
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
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [BoxShadow(color: AppColors.primaryDark, blurRadius: 0, offset: Offset(0, 3))],
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
              borderColor: AppColors.primary,
              borderWidth: 3,
              child: Row(
                children: [
                  const AppIcon(
                    Icons.person_add_rounded,
                    tileSize: 44,
                    iconSize: 24,
                    color: AppColors.primary,
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
                  const Icon(Icons.chevron_right, color: AppColors.primary, size: 18),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        _buildLearningProfileEntry(),
        const SizedBox(height: 18),
        _buildFamilyReportEntry(),
        const SizedBox(height: 18),
        _buildSyncStateCard(),
        const SizedBox(height: 18),
        _buildAppearanceCard(),
        const SizedBox(height: 18),
        _buildReminderCard(),
        const SizedBox(height: 18),
        _buildPreferencesCard(),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(child: Text('🎓', style: TextStyle(fontSize: 28))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_userName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      _userTarget.isNotEmpty ? 'Mục tiêu: $_userTarget' : 'Chưa đặt mục tiêu',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary, width: 1),
                      ),
                      child: const Text('⚡ Sĩ tử 2026', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _showEditProfileDialog,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.cardLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: const Icon(Icons.edit_rounded, color: AppColors.blue, size: 18),
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

  Widget _buildPreferencesCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quyền riêng tư & trải nghiệm',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('AI chỉ sử dụng dữ liệu khi bạn cho phép.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('AI đọc nhiệm vụ và phiên học'),
            subtitle: const Text('Dùng để trả lời theo ngữ cảnh', style: TextStyle(fontSize: 11)),
            value: _aiMayRead,
            onChanged: (value) => setState(() { _aiMayRead = value; StorageService.setBool('ai_permission_read', value); }),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('AI phân tích tiến độ'),
            subtitle: const Text('Tạo insight và đề xuất, không tự sửa kế hoạch', style: TextStyle(fontSize: 11)),
            value: _aiMayAnalyze,
            onChanged: _aiMayRead ? (value) => setState(() { _aiMayAnalyze = value; StorageService.setBool('ai_permission_analyze', value); }) : null,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hiện linh vật'),
            value: _mascotEnabled,
            onChanged: (value) => setState(() { _mascotEnabled = value; StorageService.setBool('mascot_enabled', value); }),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Giảm chuyển động'),
            value: _reduceMotion,
            onChanged: (value) => setState(() { _reduceMotion = value; StorageService.setBool('reduce_motion', value); }),
          ),
          // Đặc tả 5.14 — hai mục cài đặt này phải tắt được thật, nên mọi rung /
          // âm thanh đều đi qua FeedbackService thay vì gọi thẳng platform.
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Rung'),
            subtitle: const Text('Rung nhẹ khi bấm nút, tick nhiệm vụ, hết giờ',
                style: TextStyle(fontSize: 11)),
            value: FeedbackService.hapticsEnabled,
            onChanged: (value) => setState(() => FeedbackService.setHaptics(value)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Âm thanh'),
            subtitle: const Text('Âm báo hoàn thành phiên và tương tác linh vật',
                style: TextStyle(fontSize: 11)),
            value: FeedbackService.soundEnabled,
            onChanged: (value) => setState(() => FeedbackService.setSound(value)),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune_rounded, color: AppColors.purple),
            title: const Text('AI nâng cao'),
            subtitle: const Text('Chọn model, quyền AI, lịch sử hội thoại',
                style: TextStyle(fontSize: 11)),
            onTap: _openAiAdvancedSheet,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.ios_share_rounded, color: AppColors.blue),
            title: const Text('Xuất / nhập dữ liệu'),
            subtitle: const Text('JSON đầy đủ, CSV nhật ký, Markdown ghi chú', style: TextStyle(fontSize: 11)),
            onTap: _openDataSheet,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_sweep_outlined, color: AppColors.red),
            title: const Text('Xóa lịch sử trò chuyện AI'),
            onTap: _clearAiHistory,
          ),
        ],
      ),
    );
  }

  /// Đặc tả UX 5.11 — "AI nâng cao": chọn model, hành vi AI, lịch sử hội thoại.
  ///
  /// Mặc định app tự chọn model phù hợp (Auto); chỉ khi học sinh chủ động ghim
  /// model ở đây thì màn AI mới dùng model đó. Không lộ tên nhà cung cấp /
  /// thông số kỹ thuật ra UI chính (UX 5.11 "Never show").
  void _openAiAdvancedSheet() {
    final runtime = AIModel.runtimeDefinitions;
    final models =
        (runtime != null && runtime.isNotEmpty) ? runtime : AIModel.definitions;

    Widget modelRow(AIModel? model, {required bool isAuto}) {
      final slug = isAuto ? '' : model!.slug;
      final selected = StorageService.getAiModel() == slug;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: Icon(
          isAuto ? Icons.auto_awesome_rounded : aiModelIcon(model!.slug),
          color: selected ? AppColors.primary : AppColors.textMuted,
          size: 20,
        ),
        title: Text(
          isAuto ? 'Tự động (khuyên dùng)' : model!.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          isAuto
              ? 'Tự chuyển model theo độ khó câu hỏi.'
              : (model!.description.isEmpty ? model.slug : model.description),
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded,
                color: AppColors.primary, size: 20)
            : null,
        onTap: () {
          StorageService.setAiModel(slug);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isAuto
                  ? 'Đã chuyển AI về chế độ tự động chọn model.'
                  : 'Đã ghim model ${model!.label}.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) => ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                const Text('AI nâng cao',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'EduPulse tự chọn model phù hợp với từng câu hỏi. Bạn có thể '
                  'ghin một model nếu muốn.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                modelRow(null, isAuto: true),
                const Divider(),
                for (final m in models) modelRow(m, isAuto: false),
                const Divider(),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tự phân tích ảnh kèm theo'),
                  subtitle: const Text(
                      'Gửi ảnh chụp bài/đề vào AI ngay khi chọn, không cần gõ prompt.',
                      style: TextStyle(fontSize: 11)),
                  value: StorageService.getAiAutoReadImage(),
                  onChanged: (v) {
                    StorageService.setAiAutoReadImage(v);
                    setSheetState(() {});
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_sweep_outlined,
                      color: AppColors.red),
                  title: const Text('Xóa lịch sử trò chuyện AI',
                      style: TextStyle(color: AppColors.red)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _clearAiHistory();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Sheet Xuất / nhập / xóa dữ liệu cục bộ (đặc tả mục 19).
  void _openDataSheet() {
    final c = DataTransfer.counts();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dữ liệu của bạn',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                '${c.tasks} nhiệm vụ • ${c.notes} ghi chú • ${c.sessions} phiên focus • ${c.exams} kỳ thi • ${c.logs} nhật ký',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.data_object_rounded, color: AppColors.blue),
                title: const Text('Xuất JSON (đầy đủ — dùng để nhập lại)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Clipboard.setData(ClipboardData(text: DataTransfer.exportJson()));
                  ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(
                      content: Text('Đã sao chép JSON đầy đủ vào clipboard.')));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.table_chart_rounded, color: AppColors.primary),
                title: const Text('Xuất nhật ký học (CSV)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Clipboard.setData(ClipboardData(text: DataTransfer.exportStudyLogCsv()));
                  ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(
                      content: Text('Đã sao chép CSV nhật ký vào clipboard.')));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_rounded, color: AppColors.orange),
                title: const Text('Xuất ghi chú (Markdown)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Clipboard.setData(ClipboardData(text: DataTransfer.exportNotesMarkdown()));
                  ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(
                      content: Text('Đã sao chép Markdown ghi chú vào clipboard.')));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.download_rounded, color: AppColors.purple),
                title: const Text('Nhập từ JSON'),
                subtitle: const Text('Chỉ thêm bản ghi mới, không ghi đè dữ liệu hiện có.',
                    style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final picked = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['json'],
                  );
                  if (picked.isEmpty) return;
                  final bytes = await picked.first.readAsBytes();
                  final text = utf8.decode(bytes, allowMalformed: true);
                  if (!mounted) return;
                  final result = DataTransfer.importJson(text);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result.error.isNotEmpty
                        ? result.error
                        : 'Đã nhập ${result.imported} bản ghi, bỏ qua ${result.skipped} bản trùng.'),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_forever_rounded, color: AppColors.red),
                title: const Text('Xóa dữ liệu học cục bộ',
                    style: TextStyle(color: AppColors.red)),
                subtitle: const Text('Nhiệm vụ, ghi chú, phiên, kỳ thi, nhật ký. Cài đặt và lịch sử AI giữ nguyên.',
                    style: TextStyle(fontSize: 11)),
                onTap: () => _confirmDeleteStudyData(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteStudyData(BuildContext sheetContext) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa dữ liệu học?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hành động này không thể hoàn tác. Xuất JSON trước nếu muốn giữ lại.'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Gõ XÓA để xác nhận',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(
                dialogContext, controller.text.trim().toUpperCase() == 'XÓA'),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    DataTransfer.deleteAllStudyData();
    if (!sheetContext.mounted) return;
    Navigator.pop(sheetContext);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Đã xóa dữ liệu học cục bộ.')));
  }

  /// Xóa AI memory (mục 19 — Delete): lịch sử chat + feedback + nháp
  /// note — toàn bộ thứ AI dùng để cá nhân hóa. Có backup trong phiên
  /// để Undo ngay (undo window).
  Future<void> _clearAiHistory() async {
    final accepted = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Xóa bộ nhớ AI?'),
      content: const Text('Lịch sử trò chuyện, phản hồi 👍/👎 và bản nháp ghi chú '
          'trên thiết bị này sẽ bị xóa. AI sẽ quay về trạng thái như mới cài.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800)))],
    ));
    if (accepted != true) return;

    // Backup để Undo trong phiên (undo window — mục 19).
    final chatBackup = StorageService.getAiChatHistory();
    final feedbackIds = StorageService.prefs.getStringList('ai_feedback_ids') ?? [];
    final feedbackBackup = <String, String?>{
      for (final id in feedbackIds) 'ai_feedback_$id': StorageService.getString('ai_feedback_$id'),
      'ai_feedback_ids': feedbackIds.isNotEmpty ? feedbackIds.join(',') : null,
    };
    final draftBackup = StorageService.getString('note_draft_v1');

    // Xóa toàn bộ AI memory.
    StorageService.clearAiChatHistory();
    for (final id in feedbackIds) {
      StorageService.prefs.remove('ai_feedback_$id');
    }
    StorageService.prefs.remove('ai_feedback_ids');
    StorageService.prefs.remove('note_draft_v1');

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Đã xóa bộ nhớ AI.'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Hoàn tác',
          onPressed: () {
            // Undo: khôi phục nguyên trạng.
            if (chatBackup != null) {
              StorageService.setAiChatHistory(chatBackup);
            }
            feedbackBackup.forEach((key, value) {
              if (value != null && key != 'ai_feedback_ids') {
                StorageService.setString(key, value);
              }
            });
            final ids = feedbackBackup['ai_feedback_ids'];
            if (ids != null) {
              StorageService.prefs.setStringList('ai_feedback_ids', ids.split(','));
            }
            if (draftBackup != null) {
              StorageService.setString('note_draft_v1', draftBackup);
            }
          },
        ),
      ));
  }

  /// Thẻ trạng thái đồng bộ (đặc tả mục 19 — Sync states): hiển thị
  /// Online/Syncing/Synced/Offline nhẹ nhàng, nút đồng bộ ngay.
  Widget _buildSyncStateCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Expanded(child: SyncStatusBar()),
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: (!PwaService.isOnline || !SupabaseService.isConfigured)
                ? null
                : () async {
                    setState(() => _isSyncing = true);
                    SyncStateService.markSyncing();
                    final ok = await SupabaseService.syncAll();
                    if (mounted) setState(() => _isSyncing = false);
                    if (ok) {
                      SyncStateService.markSynced();
                    } else {
                      SyncStateService.markError();
                    }
                  },
            icon: _isSyncing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CupertinoActivityIndicator(),
                  )
                : const Icon(Icons.sync_rounded, size: 16),
            label: const Text('Đồng bộ ngay',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Thẻ Hiển thị (đặc tả mục 20): font size adaptive S/M/L toàn app.
  /// Dark mode chưa cung cấp — palette tối chưa đạt chuẩn production,
  /// không fake switch (nguyên tắc trung thực với người dùng).
  Widget _buildAppearanceCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              AppIcon(
                Icons.format_size_rounded,
                tileSize: 36,
                iconSize: 18,
                color: AppColors.blue,
                bg: AppColors.blueSoft,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text('Cỡ chữ',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Áp dụng cho toàn app. Cỡ chữ hệ thống vẫn được tôn trọng.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final choice in const [
                ('small', 'S', 'Nhỏ'),
                ('normal', 'M', 'Vừa'),
                ('large', 'L', 'Lớn'),
              ]) ...[
                Expanded(child: _fontChoice(choice.$1, choice.$2, choice.$3)),
                if (choice.$1 != 'large') const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 14),
          // High contrast (mục 21 — Accessibility): viền đậm hơn,
          // chữ phụ tối hơn — giúp người dùng nhìn yếu dễ đọc hơn.
          Row(children: [
            const Expanded(
              child: Text('Tương phản cao',
                  style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: AppearanceService.highContrast,
              builder: (context, value, _) => Switch(
                value: value,
                activeThumbColor: AppColors.primary,
                onChanged: (v) =>
                    setState(() => AppearanceService.setHighContrast(v)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _fontChoice(String key, String letter, String label) {
    final selected = AppearanceService.fontScaleKey == key;
    return GestureDetector(
      onTap: () => setState(() => AppearanceService.setFontScaleByKey(key)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.blueSoft : AppColors.bgPage,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.blue : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(letter,
                style: TextStyle(
                    fontSize: key == 'small'
                        ? 14
                        : key == 'large'
                            ? 20
                            : 17,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? AppColors.blueDark
                        : AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppColors.blueDark
                        : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  /// "Cửa sổ tin cậy" — học sinh chủ động chia sẻ tiến độ với gia đình
  /// (Giai đoạn 3, bước 1). Không tài khoản phụ huynh, không ép chia sẻ.
  Widget _buildFamilyReportEntry() {
    return GlassCard(
      onTap: () => FamilyReportSheet.show(context),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const AppIcon(
            Icons.family_restroom_rounded,
            tileSize: 36,
            iconSize: 18,
            color: AppColors.green,
            bg: AppColors.greenSoft,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cửa sổ tin cậy',
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                SizedBox(height: 2),
                Text('Tự tạo báo cáo tuần gửi ba mẹ — con chọn gì, gia đình thấy nấy',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }

  /// Entry mở Hồ sơ học tập (đặc tả mục 17) — suy luận + cho phép sửa.
  Widget _buildLearningProfileEntry() {
    return GlassCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const LearningProfileScreen(),
      )),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const AppIcon(
            Icons.person_search_rounded,
            tileSize: 36,
            iconSize: 18,
            color: AppColors.purple,
            bg: AppColors.purpleSoft,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hồ sơ học tập',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  'Nhịp học EduPulse đã hiểu về bạn — và bạn có thể chỉnh lại.',
                  style: TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted, size: 20),
        ],
      ),
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
                activeTrackColor: AppColors.primary,
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
              'Giữ vững thói quen — nhắc nhẹ nhàng mỗi ngày, thưa dần nếu bạn ít mở app. Không dùng để tạo áp lực.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
            const Divider(height: 18),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tóm tắt cuối ngày (Digest)',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              subtitle: const Text(
                  'Một thông báo duy nhất lúc 20:30: nhiệm vụ còn lại, phút focus và đếm ngược kỳ thi.',
                  style: TextStyle(fontSize: 11)),
              value: _digestEnabled,
              onChanged: (v) async {
                setState(() => _digestEnabled = v);
                StorageService.setBool('notif_digest_enabled', v);
                if (v) {
                  await AdaptivePolicy.scheduleDigest(
                    tasks: _digestTasks(),
                    sessions: const [],
                    primaryExam: null,
                  );
                } else {
                  await NotificationService.cancelId(NotificationService.digestId);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  List<TodayTask> _digestTasks() => StorageService.getTodayTaskIds()
      .map(StorageService.getTodayTaskJson)
      .whereType<String>()
      .map((json) {
        try {
          return TodayTask.fromJsonString(json);
        } catch (_) {
          return null;
        }
      })
      .whereType<TodayTask>()
      .toList();

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
            child: const Text('Lưu', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
