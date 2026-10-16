import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/glass_card.dart';

/// Các mục "Hồ sơ & Gia đình" trong tab Tôi (kế hoạch §6.2 — consent/family
/// sharing). Mỗi mục chỉ *trình bày* và báo hành động qua callback, không tự
/// điều hướng hay đọc/ghi storage — nhờ vậy test được độc lập.

/// Entry mở Hồ sơ học tập (đặc tả mục 17) — suy luận + cho phép sửa.
class LearningProfileEntry extends StatelessWidget {
  const LearningProfileEntry({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const AppIcon(
            Icons.person_search_rounded,
            tileSize: 36,
            iconSize: 18,
            color: AppColors.iosSecondary,
            bg: AppColors.iosSecondarySoft,
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
                        color: AppColors.iosTextPrimary)),
                const SizedBox(height: 2),
                Text(
                  'Nhịp học EduPulse đã hiểu về bạn — và bạn có thể chỉnh lại.',
                  style: TextStyle(
                      fontSize: 11.5, color: AppColors.iosTextSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.iosTextMuted, size: 20),
        ],
      ),
    );
  }
}

/// Mục "Cửa sổ tin cậy" — liên kết ba mẹ, gửi báo cáo tuần và ảnh thành tựu.
class FamilyReportEntry extends StatelessWidget {
  const FamilyReportEntry({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const AppIcon(
            Icons.family_restroom_rounded,
            tileSize: 36,
            iconSize: 18,
            color: AppColors.iosSuccess,
            bg: AppColors.iosSuccessSoft,
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
                        color: AppColors.iosTextPrimary)),
                SizedBox(height: 2),
                Text(
                    'Liên kết tài khoản ba mẹ, gửi báo cáo tuần và ảnh thành tựu — con chọn gì, gia đình thấy nấy',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.iosTextSecondary,
                        height: 1.35)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.iosTextMuted),
        ],
      ),
    );
  }
}

/// Phần CÀI ĐẶT CHẾ ĐỘ PHỤ HUYNH trong tab "Tôi" — hai việc:
///
/// 1. **Công tắc vào chế độ phụ huynh**: bật là `AccountRoleGate` chuyển
///    ngay sang màn phụ huynh. Đã đăng nhập thì đổi vai tức thì; chưa đăng
///    nhập thì đăng nhập vai "Phụ huynh" trước. (Nút thoát nằm ở màn phụ
///    huynh — "Chế độ học sinh".)
/// 2. **Hạng mục chia sẻ cho ba mẹ**: cùng một lựa chọn như Cửa sổ tin cậy,
///    hiện ngay trong Cài đặt — mặc định bật cả 4 mục (kể cả Điểm thi thử
///    mới nhất + Đếm ngược kỳ thi), con tắt mục nào thì ba mẹ không thấy
///    mục đó.
class ParentModeEntry extends StatelessWidget {
  const ParentModeEntry({super.key, required this.onEnterParentMode});

  final VoidCallback onEnterParentMode;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      key: const Key('account-parent-mode'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(
                Icons.supervisor_account_rounded,
                tileSize: 36,
                iconSize: 18,
                color: AppColors.iosSecondary,
                bg: AppColors.iosSecondarySoft,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chế độ phụ huynh',
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.iosTextPrimary)),
                    SizedBox(height: 2),
                    Text(
                        'Bật để chuyển sang màn phụ huynh — xem tiến độ con đã gửi',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.iosTextSecondary)),
                  ],
                ),
              ),
              Switch(
                key: const Key('parent-mode-switch'),
                // Màn này chỉ hiện ở chế độ học sinh, nên công tắc luôn TẮT —
                // bật là chuyển vai ngay (đúng ngữ nghĩa "vào/ra").
                value: false,
                activeThumbColor: AppColors.iosSecondary,
                onChanged: (v) {
                  if (v) onEnterParentMode();
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Text('Ba mẹ đã liên kết sẽ thấy toàn bộ tiến độ học tập',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.iosTextPrimary)),
          ),
          Text(
            'Điểm thi thử, đếm ngược kỳ thi, thời gian tập trung và chỉ số sẵn '
            'sàng — cập nhật liên tục. Mở "Cửa sổ tin cậy" bên dưới để liên kết '
            'hoặc tạm dừng chia sẻ.',
            style: TextStyle(
                fontSize: 11.5, height: 1.35, color: AppColors.iosTextMuted),
          ),
        ],
      ),
    );
  }
}
