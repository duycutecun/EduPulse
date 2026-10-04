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
  final List<BoxShadow>? shadows;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.borderRadius = 20,
    this.customColor,
    this.borderColor,
    this.borderWidth = 1,
    this.onTap,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = customColor ?? AppColors.cardWhite;
    final bColor = borderColor ?? AppColors.border;

    // Material trong suốt để ListTile/SwitchListTile bên trong card vẽ được
    // ink splash đúng chỗ (không bị DecoratedBox nền màu che mất).
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: bColor, width: borderWidth),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );

    if (onTap == null) return card;
    return GestureDetector(
        behavior: HitTestBehavior.opaque, onTap: onTap, child: card);
  }
}
