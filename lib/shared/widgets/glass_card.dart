import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? customColor;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  /// Danh bóng tùy chọn. Mặc định **không có bóng** — thẻ dùng viền mỏng
  /// (phẳng như Duolingo), tránh bóng dày làm chậm render trên máy yếu và
  /// cạnh tranh với nội dung. Khi cần bóng, truyền [AppTokens.shadowSubtle].
  final List<BoxShadow>? shadows;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 16,
    this.customColor,
    this.borderColor,
    this.borderWidth = 1,
    this.onTap,
    this.shadows = const [],
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = customColor ?? AppColors.iosCard;
    final bColor = borderColor ?? AppColors.iosSeparator;

    // Material trong suốt để ListTile/SwitchListTile bên trong card vẽ được
    // ink splash đúng chỗ (không bị DecoratedBox nền màu che mất).
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: bColor, width: borderWidth),
        boxShadow: shadows,
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );

    if (onTap == null) return card;
    return GestureDetector(
        behavior: HitTestBehavior.opaque, onTap: onTap, child: card);
  }
}
