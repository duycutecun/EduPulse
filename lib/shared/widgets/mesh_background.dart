import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class MeshBackground extends StatelessWidget {
  final Widget child;

  const MeshBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Base solid background
        Positioned.fill(
          child: Container(
            color: isDark ? const Color(0xFF090A10) : const Color(0xFFF4F5FB),
          ),
        ),

        // Glowing Ambient Orb 1 (Top-Left Indigo)
        Positioned(
          top: -80,
          left: -80,
          width: 320,
          height: 320,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: isDark
                    ? [
                        AppColors.iosIndigo.withValues(alpha: 0.28),
                        AppColors.iosIndigo.withValues(alpha: 0.0),
                      ]
                    : [
                        AppColors.iosIndigo.withValues(alpha: 0.12),
                        AppColors.iosIndigo.withValues(alpha: 0.0),
                      ],
              ),
            ),
          ),
        ),

        // Glowing Ambient Orb 2 (Top-Right Blue)
        Positioned(
          top: 100,
          right: -100,
          width: 340,
          height: 340,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: isDark
                    ? [
                        AppColors.iosBlue.withValues(alpha: 0.22),
                        AppColors.iosBlue.withValues(alpha: 0.0),
                      ]
                    : [
                        AppColors.iosBlue.withValues(alpha: 0.10),
                        AppColors.iosBlue.withValues(alpha: 0.0),
                      ],
              ),
            ),
          ),
        ),

        // Glowing Ambient Orb 3 (Bottom Violet)
        Positioned(
          bottom: 40,
          left: -40,
          width: 300,
          height: 300,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: isDark
                    ? [
                        AppColors.iosPurple.withValues(alpha: 0.18),
                        AppColors.iosPurple.withValues(alpha: 0.0),
                      ]
                    : [
                        AppColors.iosPurple.withValues(alpha: 0.08),
                        AppColors.iosPurple.withValues(alpha: 0.0),
                      ],
              ),
            ),
          ),
        ),

        // Content
        Positioned.fill(child: child),
      ],
    );
  }
}
