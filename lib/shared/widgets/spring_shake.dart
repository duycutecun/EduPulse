import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Rung lỗi đa trục với nhiều đỉnh suy giảm + trở về spring.
///
/// Kích hoạt qua [controller] bên ngoài (forward từ 0):
///  - 5 đỉnh rung suy giảm: translateX giảm ±12→±2, rotate giảm ±2°→±0.5°,
///    scale biến thiên quanh 1.0. Mỗi đỉnh kèm haptic + flash màu đỏ.
///  - Sau đỉnh cuối, vị trí trở về 0 theo phương trình dao động tắt dần.
class SpringShake extends StatefulWidget {
  final AnimationController controller;
  final Widget child;
  final VoidCallback? onShakeComplete;

  const SpringShake({
    super.key,
    required this.controller,
    required this.child,
    this.onShakeComplete,
  });

  @override
  State<SpringShake> createState() => _SpringShakeState();
}

class _SpringShakeState extends State<SpringShake> {
  double x = 0.0;
  double rot = 0.0;
  double sc = 1.0;
  double flash = 0.0;
  int _lastPeak = -1;

  // 5 đỉnh rock: [t, ampX, ampRot]
  static const peaks = <(double, double, double)>[
    (0.10, 12, 0.035),
    (0.28, 8, 0.025),
    (0.46, 5, 0.017),
    (0.62, 2.5, 0.009),
    (0.78, 1.0, 0.004),
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
    widget.controller.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(covariant SpringShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTick);
      oldWidget.controller.removeStatusListener(_onStatus);
      widget.controller.addListener(_onTick);
      widget.controller.addStatusListener(_onStatus);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    widget.controller.removeStatusListener(_onStatus);
    super.dispose();
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) {
      x = 0.0;
      rot = 0.0;
      sc = 1.0;
      flash = 0.0;
      _lastPeak = -1;
      widget.onShakeComplete?.call();
    }
  }

  void _onTick() {
    final t = widget.controller.value;

    // Tìm đỉnh hiện tại theo vùng — đỉnh 1 và 3 lệch trái, 2 và 4 lệch phải
    int active = -1;
    for (int i = 0; i < peaks.length; i++) {
      if (t >= peaks[i].$1 && (i == peaks.length - 1 || t < peaks[i + 1].$1)) {
        active = i;
        break;
      }
    }

    final peakX = active >= 0 ? peaks[active].$2 : 0.0;
    final peakR = active >= 0 ? peaks[active].$3 : 0.0;

    if (active >= 0 && active != _lastPeak) {
      _lastPeak = active;
      HapticFeedback.vibrate();
      flash = 1.0;
    } else {
      flash = math.max(0.0, flash - 0.06);
    }

    // Trong mỗi đỉnh, dao động hình sin nhiều lần với biên độ peakX
    if (active >= 0) {
      final start = peaks[active].$1;
      final phase = math.max(0.0, t - start);
      x = math.sin(phase * math.pi * 18) * peakX;
      rot = math.sin(phase * math.pi * 17) * peakR;
      sc = 1.0 - (math.cos(phase * math.pi * 16) * 0.02).abs();
    } else {
      x = 0;
      rot = 0;
      sc = 1.0;
      if (t > 0.85) {
        // Spring return về 0, khử dần
        final st = (t - 0.85) / 0.15;
        final k = math.exp(-3.0 * st) * math.cos(4.0 * st);
        x = 2.0 * k;
        rot = 0.006 * k;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body = widget.child;

    if (flash > 0) {
      body = DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.55 * flash),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: body,
      );
    }

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(x, 0),
          child: Transform.rotate(
            angle: rot,
            child: Transform.scale(
              scale: sc.clamp(0.9, 1.1),
              child: body,
            ),
          ),
        );
      },
    );
  }
}