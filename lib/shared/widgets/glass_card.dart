import 'dart:ui';
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
    this.borderRadius = 22,
    this.blur = 20,
    this.customColor,
    this.borderColor,
    this.borderWidth = 0.8,
    this.onTap,
    this.shadows,
    this.borderGradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultBg = isDark
        ? (customColor ?? const Color(0xFF1E1E26).withValues(alpha: 0.65))
        : (customColor ?? Colors.white.withValues(alpha: 0.75));

    final defaultBorder = isDark
        ? (borderColor ?? Colors.white.withValues(alpha: 0.12))
        : (borderColor ?? Colors.black.withValues(alpha: 0.08));

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: defaultBg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: borderGradient == null
                ? Border.all(color: defaultBorder, width: borderWidth)
                : null,
          ),
          child: child,
        ),
      ),
    );

    Widget container = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : AppColors.iosBlue.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
      ),
      child: borderGradient == null
          ? content
          : Container(
              padding: EdgeInsets.all(borderWidth),
              decoration: BoxDecoration(
                gradient: borderGradient,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: content,
            ),
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
