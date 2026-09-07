import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Vòng tròn tiến trình dạng "sweep" với glow — dùng làm vòng điểm/ở giữa
/// hiển thị con số. Tiến trình animate bằng [TweenAnimationBuilder] mỗi khi
/// [progress] đổi (đếm lên thì vòng chạy theo).
///
/// Hỗ trợ:
/// - Gradient dọc theo cung (SweepGradient) nếu truyền [gradientColors].
/// - Vệt glow phía sau cung tiến trình (MaskFilter.blur).
/// - [child] đặt chính giữa vòng (số điểm, %, avatar...).
/// - `hitTest` bị tắt nên vòng không nuốt gesture của các widget bên dưới.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    this.progress = 0.0,
    this.size = 72,
    this.strokeWidth = 9,
    this.trackColor = const Color(0xFFE5E5E5),
    this.color = const Color(0xFF58CC02),
    this.gradientColors,
    this.glow = true,
    this.glowColor,
    this.startAngle = -math.pi / 2,
    this.duration = const Duration(milliseconds: 700),
    this.curve = Curves.easeOutCubic,
    this.child,
  });

  /// Tiến trình 0.0 → 1.0.
  final double progress;

  /// Đường kính vòng (px).
  final double size;

  /// Độ dày nét của cung tiến trình.
  final double strokeWidth;

  /// Màu đường tròn nền (track).
  final Color trackColor;

  /// Màu cung tiến trình (dùng khi [gradientColors] null).
  final Color color;

  /// Gradient dọc theo cung (đầu → cuối theo chiều kim đồng hồ).
  final List<Color>? gradientColors;

  /// Khi true, vẽ vệt glow mờ phía sau cung tiến trình.
  final bool glow;

  /// Màu riêng cho glow (mặc định lấy màu đầu của gradient / [color]).
  final Color? glowColor;

  /// Góc bắt đầu vẽ cung (mặc định 12 giờ).
  final double startAngle;

  /// Thời lượng animate khi [progress] đổi.
  final Duration duration;

  final Curve curve;

  /// Nội dung đặt ở giữa vòng.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: progress.clamp(0.0, 1.0)),
        duration: duration,
        curve: curve,
        builder: (context, value, _) => IgnorePointer(
          child: CustomPaint(
            painter: _RingPainter(
              progress: value,
              strokeWidth: strokeWidth,
              trackColor: trackColor,
              color: color,
              gradientColors: gradientColors,
              glow: glow,
              glowColor: glowColor,
              startAngle: startAngle,
            ),
            child: child == null ? null : Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.color,
    required this.gradientColors,
    required this.glow,
    required this.glowColor,
    required this.startAngle,
  });

  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color color;
  final List<Color>? gradientColors;
  final bool glow;
  final Color? glowColor;
  final double startAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2.0;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const tau = math.pi * 2.0;
    final sweep = tau * progress;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0 && glow) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = (glowColor ?? gradientColors?.first ?? color)
            .withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth);
      canvas.drawArc(rect, startAngle, sweep, false, glowPaint);
    }

    if (progress > 0) {
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      if (gradientColors != null && gradientColors!.length > 1) {
        progressPaint.shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + tau,
          colors: gradientColors!,
        ).createShader(rect);
      } else {
        progressPaint.color = color;
      }
      canvas.drawArc(rect, startAngle, sweep, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.color != color ||
        oldDelegate.gradientColors != gradientColors ||
        oldDelegate.glow != glow ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.startAngle != startAngle;
  }
}
