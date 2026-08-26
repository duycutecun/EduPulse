import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class TypingDotsIndicator extends StatefulWidget {
  const TypingDotsIndicator({super.key});

  @override
  State<TypingDotsIndicator> createState() => _TypingDotsIndicatorState();
}

class _TypingDotsIndicatorState extends State<TypingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (ctx, child) {
            final delay = i * 0.2;
            final progress = (_ctrl.value - delay) % 1.0;
            final scale = 0.5 + 0.5 * (1 - (progress - 0.5).abs() * 2).clamp(0.0, 1.0);
            final opacity = 0.4 + 0.6 * scale;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.iosIndigo.withValues(alpha: opacity),
              ),
              transform: Matrix4.diagonal3Values(scale, scale, 1.0),
            );
          },
        );
      }),
    );
  }
}

class PulsingGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double maxBlur;

  const PulsingGlow({
    super.key,
    required this.child,
    this.glowColor = AppColors.iosIndigo,
    this.maxBlur = 24,
  });

  @override
  State<PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<PulsingGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: _anim.value * 0.5),
                blurRadius: widget.maxBlur * _anim.value,
                spreadRadius: 2,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
