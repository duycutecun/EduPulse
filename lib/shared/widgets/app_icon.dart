import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Standard icon scale used across the app for consistent proportions.
class AppIconSize {
  /// Small icons inside compact controls / segmented toggles.
  static const double xs = 14;

  /// Icon in a small 28px tile (list rows, header chips).
  static const double sm = 18;

  /// Icon in a standard 36px tile (settings, actions).
  static const double md = 22;

  /// Icon in a large 44px tile (hero actions, bottom CTA).
  static const double lg = 28;
}

/// Dimensional, consistent icon built the Duolingo way:
/// a clear filled Material glyph on a colored rounded tile with a hard
/// offset shadow so every icon looks "raised" instead of flat.
class AppIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final Color? bg;
  final double tileSize;
  final double iconSize;
  final bool shadow;
  final EdgeInsets? padding;

  const AppIcon(
    this.icon, {
    super.key,
    this.color,
    this.bg,
    this.tileSize = 36,
    this.iconSize = AppIconSize.md,
    this.shadow = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tileSize,
      height: tileSize,
      padding: padding,
      decoration: BoxDecoration(
        color: bg ?? AppColors.bgPage,
        borderRadius: BorderRadius.circular(tileSize * 0.28),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: AppColors.borderDark.withValues(alpha: 0.5),
                  blurRadius: 0,
                  offset: Offset(0, tileSize * 0.11),
                ),
              ]
            : null,
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: color ?? AppColors.textPrimary,
      ),
    );
  }
}
