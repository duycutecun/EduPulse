import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';

/// Phần dùng chung cho các trang con của tab "Tôi" (drill-down kiểu iOS
/// Settings): hằng số phiên bản, cách lề hàng List và hai building block
/// tiêu đề nhóm / hàng nhóm. Tách riêng để 3 trang con (Hồ sơ, Cài đặt,
/// Thông tin app) giữ cùng một ngôn ngữ hiển thị như trang cũ.

/// Phiên bản app — phải khớp `version` trong pubspec.yaml (không có
/// package_info trong dependencies nên đọc trực tiếp được; khi nâng cấp
/// version nhớ đổi cả đây).
const String accountAppVersion = '2.0.0+1';

/// Cách lề chuẩn của hàng List trong nhóm (iOS inset grouped): 16 trái/phải.
const EdgeInsets accountTilePadding = EdgeInsets.symmetric(horizontal: 16);

/// Tiêu đề nhóm kiểu iOS Settings: nhãn chữ nhỏ, màu muted — chỉ là nhãn
/// tĩnh, KHÔNG nhấn được và không đóng/mở gì cả (khác accordion cũ).
class AccountSectionHeader extends StatelessWidget {
  final String title;

  /// Dòng mô tả nhỏ dưới tiêu đề (tùy chọn).
  final String? subtitle;

  const AccountSectionHeader(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: AppColors.iosTextMuted)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.iosTextMuted)),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Một hàng List bọc trong thẻ inset — cùng ngôn ngữ GlassCard của app.
/// Tile tự cách hai lề 16 như các ListTile cũ.
class AccountSectionRow extends StatelessWidget {
  final Widget child;

  const AccountSectionRow({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: child,
    );
  }
}
