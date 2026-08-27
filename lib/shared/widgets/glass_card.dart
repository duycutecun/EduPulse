import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color? customColor;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadows;
  final Gradient? borderGradient;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.borderRadius = 16,
    this.blur = 0,
    this.customColor,
    this.borderColor,
    this.borderWidth = 2,
    this.onTap,
    this.shadows,
    this.borderGradient,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = customColor ?? AppColors.cardWhite;
    final bColor = borderColor ?? AppColors.border;

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: bColor, width: borderWidth),
      ),
      child: child,
    );

    Widget container = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: AppColors.borderDark.withValues(alpha: 0.5),
                blurRadius: 0,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
      ),
      child: content,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: container,
      );
    }
    return container;
  }
}
