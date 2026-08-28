import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../../core/constants/app_colors.dart';

class LatexWidget extends StatelessWidget {
  const LatexWidget({super.key, required this.latex, required this.textColor});

  final String latex;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: textColor == Colors.white
            ? Colors.white.withValues(alpha: 0.15)
            : AppColors.bgPage,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: textColor == Colors.white
              ? Colors.white.withValues(alpha: 0.3)
              : AppColors.border,
          width: 1,
        ),
      ),
      child: Math.tex(
        latex,
        textStyle: TextStyle(fontSize: 15, color: textColor),
        onErrorFallback: (error) {
          return Text(
            '\$$latex\$',
            style: TextStyle(fontSize: 14, color: textColor, fontStyle: FontStyle.italic),
          );
        },
      ),
    );
  }
}
