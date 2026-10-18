import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/feedback_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../core/utils/supabase_service.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../widgets/account_page_shared.dart';
import 'about_screen.dart';
import 'profile_detail_screen.dart';
import 'settings_screen.dart';

/// Tab "Tôi" — trang chính kiểu drill-down iOS Settings thật:
///
/// - Card hồ sơ lớn trên đầu (avatar + tên + badge "Sĩ tử 2026" + trạng thái
///   đăng nhập) — bấm mở trang con **Hồ sơ** (push, có nút back/vuốt quay lại).
/// - 2 row nhóm kiểu iOS Settings: **Cài đặt** và **Thông tin app** — bấm mở
///   trang con tương ứng.
///
/// Nội dung chi tiết nằm ở 3 trang con riêng
/// (profile_detail_screen / settings_screen / about_screen) — trang này chỉ
/// đóng vai "menu gốc" gọn nhẹ như màn chính của Settings trên iOS.
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

  /// Mở một trang con của tab "Tôi" (drill-down — push màn, iOS có sẵn
  /// swipe-back). Khi quay lại, tên/mục tiêu/đăng nhập có thể đã đổi trong
  /// trang con → nạp lại dữ liệu cho card hồ sơ.
  Future<void> _openChild(WidgetBuilder builder) async {
    FeedbackService.selection();
    await Navigator.of(context).push(MaterialPageRoute(builder: builder));
    if (mounted) setState(_loadData);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileCard(),
          const SizedBox(height: 16),
          _buildGroupRows(),
        ],
      ),
    );
  }

  /// Card hồ sơ lớn trên đầu — như row "Apple ID" trên đầu iOS Settings.
  /// Bấm vào mở trang con "Hồ sơ" chi tiết (đăng nhập, đồng bộ, học tập,
  /// gia đình).
  Widget _buildProfileCard() {
    final loggedIn =
        SupabaseService.isLoggedIn && SupabaseService.currentUser != null;

    return GestureDetector(
      key: const Key('account-profile-card'),
      onTap: () => _openChild(
        (_) => ProfileDetailScreen(onDataChanged: widget.onDataChanged),
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            // Avatar tròn như iOS — dùng chính emoji 🎓 của app (không có
            // service đổi ảnh nên giữ nguyên tính trung thực).
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
              child: const Center(
                  child: Text('🎓', style: TextStyle(fontSize: 28))),
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
                  // Badge "Sĩ tử 2026" + trạng thái tài khoản (email khi đã
                  // đăng nhập, "chưa đăng nhập" khi chưa).
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.iosPrimarySoft,
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: AppColors.iosPrimary, width: 1),
                        ),
                        child: const Text('⚡ Sĩ tử 2026',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.iosPrimary)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loggedIn
                              ? (SupabaseService.currentUser!.email ??
                                  'Đã đăng nhập')
                              : 'Chưa đăng nhập · dữ liệu lưu trên máy',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.iosTextMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Chevron phải như iOS Settings — hàng này có trang con.
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.iosTextMuted, size: 20),
          ],
        ),
      ),
    );
  }

  /// Nhóm 2 row drill-down (Cài đặt | Thông tin app) trong cùng một thẻ —
  /// đúng dạng inset grouped của iOS Settings: chevron phải, phụ đề ngắn.
  Widget _buildGroupRows() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          ListTile(
            key: const Key('account-row-settings'),
            contentPadding: accountTilePadding,
            leading: const AppIcon(
              Icons.settings_rounded,
              tileSize: 36,
              iconSize: 18,
              color: AppColors.iosTextSecondary,
              bg: AppColors.iosFill,
            ),
            title: const Text('Cài đặt',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Cỡ chữ, nhắc học, quyền AI & dữ liệu',
                style: TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.iosTextMuted, size: 20),
            onTap: () => _openChild((_) => const SettingsScreen()),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            key: const Key('account-row-about'),
            contentPadding: accountTilePadding,
            leading: const AppIcon(
              Icons.info_rounded,
              tileSize: 36,
              iconSize: 18,
              color: AppColors.iosInfo,
              bg: AppColors.iosInfoSoft,
            ),
            title: const Text('Thông tin app',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Phiên bản, giới thiệu & hỗ trợ',
                style: TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.iosTextMuted, size: 20),
            onTap: () => _openChild((_) => const AboutScreen()),
          ),
        ],
      ),
    );
  }
}
