import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/platform/platform_capabilities.dart';
import '../../../../core/share/share_service.dart';
import '../../../../core/share/share_text.dart';
import '../../../../core/utils/feedback_service.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/glass_card.dart';

/// Thẻ "Trải nghiệm riêng trên app" — trả lời trực tiếp câu hỏi "app khác web
/// ở chỗ nào?".
///
/// Mỗi dòng lấy trạng thái từ [PlatformCapabilities] (nguồn sự thật duy nhất)
/// và nói luôn bản web thay thế bằng gì, thay vì chỉ khoe tính năng. Hai nút ở
/// cuối là hai tính năng **không thể có trên web**: gửi thông báo thật bằng
/// hệ thống và mở bảng chia sẻ của hệ điều hành.
class NativeExperienceCard extends StatelessWidget {
  const NativeExperienceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(
                Icons.smartphone_rounded,
                tileSize: 36,
                iconSize: 18,
                color: AppColors.blue,
                bg: AppColors.blueSoft,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Trải nghiệm riêng trên app',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      'Đang chạy trên: ${PlatformCapabilities.platformLabel}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final feature in PlatformCapabilities.nativeOnlyFeatures)
            _featureRow(feature),
          if (!PlatformCapabilities.isNativeApp) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.blueLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Bạn đang dùng bản web. Cài app EduPulse để có nhắc học offline, '
                'widget màn hình chính và rung phản hồi.',
                style: TextStyle(
                    fontSize: 11.5, height: 1.35, color: AppColors.blueDark),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (PlatformCapabilities.supports(NativeFeature.notifications))
                Expanded(
                  child: _OutlineButton(
                    key: const Key('native-test-notification'),
                    icon: Icons.notifications_active_rounded,
                    label: 'Gửi thử thông báo',
                    onTap: () => _sendTestNotification(context),
                  ),
                ),
              if (PlatformCapabilities.supports(NativeFeature.notifications))
                const SizedBox(width: 10),
              Expanded(
                child: _OutlineButton(
                  key: const Key('native-share-invite'),
                  icon: Icons.ios_share_rounded,
                  label: 'Giới thiệu EduPulse',
                  onTap: () => _shareInvite(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featureRow(NativeFeature feature) {
    final availability = PlatformCapabilities.availability(feature);
    final (label, color) = _statusOf(availability);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconOf(feature), size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _titleOf(feature),
                        maxLines: 2,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: color),
                      ),
                    ),
                  ],
                ),
                // "Trên web thì sao?" — nói thẳng phần web không có được, để
                // người dùng hiểu vì sao nên cài app chứ không chỉ thấy nhãn.
                if (availability != FeatureAvailability.available)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      PlatformCapabilities.webAlternative(feature),
                      style: const TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static (String, Color) _statusOf(FeatureAvailability availability) {
    switch (availability) {
      case FeatureAvailability.available:
        return ('Đang chạy', AppColors.primary);
      case FeatureAvailability.webFallback:
        return ('Bản web', AppColors.blue);
      case FeatureAvailability.comingSoon:
        return ('Sắp có', AppColors.orange);
      case FeatureAvailability.unavailable:
        return ('Chỉ trên app', AppColors.purple);
    }
  }

  static IconData _iconOf(NativeFeature feature) {
    switch (feature) {
      case NativeFeature.systemShare:
        return Icons.ios_share_rounded;
      case NativeFeature.notifications:
        return Icons.notifications_active_rounded;
      case NativeFeature.homeWidget:
        return Icons.widgets_rounded;
      case NativeFeature.haptics:
        return Icons.vibration_rounded;
    }
  }

  static String _titleOf(NativeFeature feature) {
    switch (feature) {
      case NativeFeature.systemShare:
        return 'Chia sẻ qua Zalo, Messenger, SMS…';
      case NativeFeature.notifications:
        return 'Nhắc học & tóm tắt cuối ngày (offline)';
      case NativeFeature.homeWidget:
        return 'Widget màn hình chính';
      case NativeFeature.haptics:
        return 'Rung & âm thanh phản hồi';
    }
  }

  /// Gửi một thông báo thật qua hệ thống — cách duy nhất để người dùng biết
  /// chắc máy mình đã cho phép thông báo (trên web không có bước này).
  static Future<void> _sendTestNotification(BuildContext context) async {
    // `null` = nền tảng không cần quyền runtime (Android cũ) → vẫn gửi thử.
    final granted = await NotificationService.requestPermission();
    if (!context.mounted) return;
    if (granted == false) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Máy đang chặn thông báo. Mở Cài đặt hệ thống → EduPulse → Thông báo để bật nhé.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final shown = await NotificationService.showNow(
      title: 'EduPulse hoạt động tốt! ✅',
      body: 'Đây là nhắc học thật, chạy offline ngay cả khi app đã đóng.',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(shown
          ? 'Đã gửi — kéo thanh thông báo xuống để xem nhé!'
          : 'Không gửi được thông báo trên máy này.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  static Future<void> _shareInvite(BuildContext context) async {
    FeedbackService.selection();
    final shared = await ShareService.shareText(
      ShareText.appInvite(),
      subject: 'EduPulse — Trợ lý sĩ tử & đếm ngược kỳ thi',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(shared
          ? 'Chọn ứng dụng để gửi lời mời nhé!'
          : 'Không chia sẻ được lúc này — thử lại sau nhé.'),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

/// Nút viền mảnh dùng trong thẻ — giữ nguyên phong cách "hard shadow" của app.
class _OutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OutlineButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
