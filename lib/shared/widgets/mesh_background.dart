import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class MeshBackground extends StatelessWidget {
  final Widget child;

  const MeshBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgPage,
      child: child,
    );
  }
}
