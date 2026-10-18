import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../core/utils/supabase_service.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/sync_status_bar.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
import '../../../gamification/presentation/sheets/achievements_sheet.dart';
import '../../../leaderboard/presentation/screens/leaderboard_screen.dart';
import '../../../progress/presentation/screens/deep_report_screen.dart';
import '../widgets/account_family_entries.dart';
import '../widgets/account_page_shared.dart';
import '../widgets/family_report_sheet.dart';
import '../../../../core/privacy/share_audit_log.dart';
import 'learning_profile_screen.dart';

/// Trang con **Hồ sơ** của tab "Tôi" — mở bằng cách bấm card hồ sơ trên
/// trang chính (drill-down kiểu iOS Settings).
///
/// Gom phần "cá nhân" của tab Hồ sơ cũ: đăng nhập/đăng xuất, trạng thái đồng
/// bộ, tóm tắt hồ sơ (tên, mục tiêu, linh vật) và hai nhóm HỌC TẬP & GIA ĐÌNH.
class ProfileDetailScreen extends StatefulWidget {
  final VoidCallback onDataChanged;

  const ProfileDetailScreen({super.key, required this.onDataChanged});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  late String _userName;
  late String _userTarget;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _userName = StorageService.getUserName();
    _userTarget = StorageService.getUserTarget();
  }

  void _updateProfile(String name, String target) {
    StorageService.setUserName(name);
    StorageService.setUserTarget(target);
    setState(() {
      _userName = name;
      _userTarget = target;
    });
    widget.onDataChanged();
  }

  void _openAuthScreen() {
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (ctx) => AuthScreen(
        onAuthSuccess: () async {
          Navigator.pop(ctx);
          _loadData();
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.iosSeparator, width: 2)),
        title: const Text('Đăng xuất?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'Dữ liệu cục bộ vẫn được giữ. Hãy sao lưu trước khi đăng xuất.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Hủy', style: TextStyle(color: AppColors.iosTextMuted))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SupabaseService.signOut();
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã đăng xuất')));
              }
            },
            child: const Text('Đăng xuất',
                style: TextStyle(
                    color: AppColors.iosError, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  /// "Cửa sổ tin cậy" — học sinh chủ động chia sẻ tiến độ với gia đình:
  /// liên kết tài khoản ba mẹ bằng mã mời, gửi báo cáo tuần, tạo ảnh thành tựu.
  void _openParentMode() {
    if (SupabaseService.isLoggedIn) {
      StorageService.setAccountRole(StorageService.roleParent);
      ShareAuditLog.log(ShareAuditKinds.parentMode, 'bật');
      return;
    }
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (ctx) => AuthScreen(
        initialRole: StorageService.roleParent,
        onAuthSuccess: () {
          Navigator.pop(ctx);
          StorageService.setAccountRole(StorageService.roleParent);
          ShareAuditLog.log(ShareAuditKinds.parentMode, 'bật');
        },
        onSkip: () => Navigator.pop(ctx),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.iosBackground,
      appBar: AppBar(
        title:
            const Text('Hồ sơ', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (SupabaseService.isLoggedIn &&
                SupabaseService.currentUser != null) ...[
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const AppIcon(
                      Icons.cloud_done_rounded,
                      tileSize: 44,
                      iconSize: 24,
                      color: AppColors.iosPrimary,
                      bg: AppColors.iosSuccessSoft,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(SupabaseService.currentUser!.email ?? 'EduPulse',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.iosTextPrimary)),
                          Text('Đã đăng nhập · dữ liệu lưu trên máy',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.iosTextMuted)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đăng xuất',
                      onPressed: _handleSignOut,
                      icon: const Icon(Icons.logout,
                          color: AppColors.iosError, size: 22),
                    ),
                  ],
                ),
              ),
            ] else ...[
              GestureDetector(
                onTap: _openAuthScreen,
                child: GlassCard(
                  padding: const EdgeInsets.all(18),
                  borderColor: AppColors.iosPrimary,
                  borderWidth: 3,
                  child: Row(
                    children: [
                      const AppIcon(
                        Icons.person_add_rounded,
                        tileSize: 44,
                        iconSize: 24,
                        color: AppColors.iosPrimary,
                        bg: AppColors.iosSuccessSoft,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tạo tài khoản',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.iosTextPrimary)),
                            SizedBox(height: 2),
                            Text('Quản lý hồ sơ và cài đặt trên thiết bị này',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.iosTextMuted)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.iosPrimary, size: 18),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            // Trạng thái đồng bộ: đây là câu người dùng tự hỏi khi vào hồ sơ
            // ("dữ liệu của tôi đã lên cloud chưa?") — chuyển từ trang chính
            // vào đây cho đúng ngữ cảnh, không bị bỏ đi.
            const SyncStatusCard(),
            const SizedBox(height: 16),
            // Danh tính luôn hiện — khối hồ sơ đầu trang: thấy ngay mình là
            // ai và mục tiêu gì.
            _buildProfileSummary(),

            // ══════════════ Nhóm HỌC TẬP ══════════════
            const SizedBox(height: 28),
            const AccountSectionHeader('HỌC TẬP'),
            // Hồ sơ học tập — mục quan trọng nhất của nhóm (đặc tả mục 17).
            LearningProfileEntry(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LearningProfileScreen(),
              )),
            ),
            const SizedBox(height: 10),
            AccountSectionRow(
              child: ListTile(
                contentPadding: accountTilePadding,
                leading: const Icon(Icons.insights_rounded,
                    color: AppColors.iosSuccess),
                title: const Text('Báo cáo học tập sâu'),
                subtitle: const Text(
                    'Xu hướng điểm, năng lực chủ đề, thời gian học',
                    style: TextStyle(fontSize: 11)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const DeepReportScreen(),
                )),
              ),
            ),
            const SizedBox(height: 10),
            AccountSectionRow(
              child: ListTile(
                contentPadding: accountTilePadding,
                leading: const Icon(Icons.emoji_events_rounded,
                    color: AppColors.iosStreak),
                title: const Text('Bảng vàng kỷ lục'),
                subtitle: const Text(
                    'Phiên dài nhất, tuần học nhiều nhất, điểm cao nhất',
                    style: TextStyle(fontSize: 11)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const LeaderboardScreen(),
                )),
              ),
            ),
            const SizedBox(height: 10),
            AccountSectionRow(
              child: ListTile(
                contentPadding: accountTilePadding,
                leading: const Icon(Icons.emoji_events_outlined,
                    color: AppColors.iosWarning),
                title: const Text('Thành tích & huy hiệu'),
                subtitle: const Text('Cấp độ, chuỗi ngày và bộ huy hiệu đã đạt',
                    style: TextStyle(fontSize: 11)),
                onTap: () => showAchievementsSheet(context),
              ),
            ),

            // ══════════════ Nhóm GIA ĐÌNH ══════════════
            const SizedBox(height: 28),
            const AccountSectionHeader('GIA ĐÌNH'),
            FamilyReportEntry(
              onTap: () => FamilyReportSheet.show(context),
            ),
            const SizedBox(height: 10),
            ParentModeEntry(onEnterParentMode: _openParentMode),
          ],
        ),
      ),
    );
  }

  /// Thẻ tóm tắt hồ sơ (tên, mục tiêu, linh vật) — khối lớn đầu trang.
  Widget _buildProfileSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.iosCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.iosSeparator, width: 1),
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
              color: AppColors.iosPrimary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.iosPrimaryDark.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child:
                const Center(child: Text('🎓', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_userName,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.iosTextPrimary)),
                const SizedBox(height: 2),
                Text(
                  _userTarget.isNotEmpty
                      ? 'Mục tiêu: $_userTarget'
                      : 'Chưa đặt mục tiêu',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.iosTextSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.iosPrimarySoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.iosPrimary, width: 1),
                  ),
                  child: const Text('⚡ Sĩ tử 2026',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.iosPrimary)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showEditProfileDialog,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.iosFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.iosSeparator, width: 1),
              ),
              child: const Icon(Icons.edit_rounded,
                  color: AppColors.iosInfo, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _userName);
    final targetCtrl = TextEditingController(text: _userTarget);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.iosSeparator, width: 2)),
        title: const Text('Chỉnh sửa hồ sơ',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(hintText: 'Họ tên')),
            const SizedBox(height: 10),
            TextField(
              controller: targetCtrl,
              decoration: const InputDecoration(hintText: 'Mục tiêu trường'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Hủy', style: TextStyle(color: AppColors.iosTextMuted))),
          TextButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                _updateProfile(nameCtrl.text.trim(), targetCtrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Lưu',
                style: TextStyle(
                    color: AppColors.iosPrimary, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
