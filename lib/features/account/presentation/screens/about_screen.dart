import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/feedback_service.dart';
import '../../../../core/share/share_text.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../widgets/account_page_shared.dart';
import '../widgets/beta_feedback_sheet.dart';
import '../widgets/cloud_ai_card.dart';
import '../../../../core/feedback/beta_feedback.dart';

/// Trang con **Thông tin app** của tab "Tôi" — mở bằng cách bấm row "Thông
/// tin app" trên trang chính (drill-down kiểu iOS Settings).
///
/// Các mục information/tĩnh: phiên bản, về app, liên kết, hỗ trợ — và nhóm
/// "Chủ app" ẨN mặc định (bấm 7 lần vào hàng "Phiên bản" để mở, chỉ trong
/// session này). Unlock là State của trang con: quay về trang chính rồi mở
/// lại trang này, hoặc restart app, đều tự khóa lại.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  /// Số lần bấm liên tục vào hàng "Phiên bản" để mở nhóm "Chủ app".
  static const int _ownerUnlockTaps = 7;

  /// Đếm bấm hàng "Phiên bản" — chỉ trong SESSION này, không lưu prefs.
  int _versionTaps = 0;

  /// Nhóm "Chủ app" đã mở khoá chưa (unlock chỉ sống đến khi restart app).
  bool _ownerUnlocked = false;

  /// Bấm hàng "Phiên bản": 7 lần liên tục → mở nhóm "Chủ app" kèm haptic.
  /// Trước khi đạt ngưỡng, mỗi lần bấm chỉ haptic nhẹ kiểu chọn (selection).
  void _handleVersionTap() {
    if (_ownerUnlocked) return;
    _versionTaps++;
    if (_versionTaps >= _ownerUnlockTaps) {
      FeedbackService.heavy();
      setState(() => _ownerUnlocked = true);
    } else {
      FeedbackService.selection();
    }
  }

  /// Sheet "Về EduPulse" — thông tin tổng quan của app.
  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'EduPulse',
      applicationVersion: accountAppVersion,
      applicationIcon: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: AppColors.iosPrimary,
          shape: BoxShape.circle,
        ),
        child: const Center(child: Text('🎓', style: TextStyle(fontSize: 28))),
      ),
      applicationLegalese:
          'Trợ lý Sĩ tử & Đếm ngược Kỳ thi — học cùng mục tiêu, thi tự tin.',
    );
  }

  /// Sao chép link bản web để gửi bạn bè (không có url_launcher trong
  /// dependencies nên chỉ chép vào clipboard + snackbar xác nhận).
  void _copyWebLink() {
    Clipboard.setData(ClipboardData(text: ShareText.appLink));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Đã sao chép liên kết bản web vào clipboard.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.iosBackground,
      appBar: AppBar(
        title: const Text('Thông tin app',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ══════════════ Nhóm PHIÊN BẢN ══════════════
            const AccountSectionHeader('PHIÊN BẢN'),
            // Hàng bấm 7 lần để mở nhóm "Chủ app" (easter egg của chủ app).
            GestureDetector(
              key: const Key('account-version-row'),
              behavior: HitTestBehavior.opaque,
              onTap: _handleVersionTap,
              child: GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: ListTile(
                  contentPadding: accountTilePadding,
                  leading: const AppIcon(
                    Icons.school_rounded,
                    tileSize: 36,
                    iconSize: 18,
                    color: AppColors.iosPrimary,
                    bg: AppColors.iosPrimarySoft,
                  ),
                  title: const Text('Phiên bản'),
                  subtitle: const Text(
                      'EduPulse — Trợ lý học tập cho Sĩ tử THPT',
                      style: TextStyle(fontSize: 11)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(accountAppVersion,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.iosTextSecondary)),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.iosTextMuted, size: 20),
                    ],
                  ),
                ),
              ),
            ),

            // ══════════════ Nhóm GIỚI THIỆU & LIÊN KẾT ══════════════
            const SizedBox(height: 28),
            const AccountSectionHeader('GIỚI THIỆU & LIÊN KẾT'),
            AccountSectionRow(
              child: ListTile(
                contentPadding: accountTilePadding,
                leading: const Icon(Icons.help_outline_rounded,
                    color: AppColors.iosSecondary),
                title: const Text('Về EduPulse'),
                subtitle: const Text(
                    'Trợ lý Sĩ tử & Đếm ngược Kỳ thi (THPTQG, TSA, HSA, HSG)',
                    style: TextStyle(fontSize: 11)),
                onTap: () => _showAboutDialog(),
              ),
            ),
            const SizedBox(height: 10),
            AccountSectionRow(
              child: ListTile(
                contentPadding: accountTilePadding,
                leading:
                    const Icon(Icons.link_rounded, color: AppColors.iosInfo),
                title: const Text('Liên kết bản web'),
                subtitle: Text(ShareText.appLink,
                    style: const TextStyle(fontSize: 11)),
                onTap: _copyWebLink,
              ),
            ),

            // ══════════════ Nhóm HỖ TRỢ ══════════════
            const SizedBox(height: 28),
            const AccountSectionHeader('HỖ TRỢ'),
            AccountSectionRow(
              child: ListTile(
                contentPadding: accountTilePadding,
                leading: const Icon(Icons.feedback_outlined,
                    color: AppColors.iosSecondary),
                title: const Text('Gửi phản hồi beta'),
                subtitle: Text(
                    BetaFeedbackService.instance.count > 0
                        ? '${BetaFeedbackService.instance.count} phản hồi đã lưu trên máy này'
                        : 'Báo lỗi, góp ý trải nghiệm cho nhóm phát triển',
                    style: const TextStyle(fontSize: 11)),
                onTap: () => showBetaFeedbackSheet(context),
              ),
            ),

            // ══════════════ Nhóm CHỦ APP (ẨN) ══════════════
            // Mở bằng cách bấm liên tục 7 lần vào hàng "Phiên bản" ở trên.
            // Unlock KHÔNG lưu preference — restart app tự khóa lại.
            if (_ownerUnlocked) ...[
              const SizedBox(height: 28),
              // Anim nhẹ: phần hiện ra trượt nở từ 0 theo kích thước nội dung.
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: _buildOwnerToolsSection(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Nhóm "Chủ app" — các công cụ cấu hình/chuẩn đoán chỉ dành cho người vận
  /// hành app, ẩn khỏi người dùng phổ thông.
  Widget _buildOwnerToolsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      key: const Key('account-owner-section'),
      children: [
        const AccountSectionHeader('CHỦ APP',
            subtitle: 'Cấu hình nâng cao — chỉ dành cho chủ app.'),
        const CloudAiCard(),
      ],
    );
  }
}
