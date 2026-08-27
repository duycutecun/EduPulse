import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class MeshBackground extends StatelessWidget {
  final Widget child;

  const MeshBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Sync fallback so AppColors static getters stay correct for any widget
    // in the subtree that still uses them without a context.
    AppColors.darkFallback = AppColors.isDark(context);
    return ColoredBox(
      color: AppColors.bgPage,
      child: child,
    );
  }
}
