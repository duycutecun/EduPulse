import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Skeleton loading procedural — không dùng gradient sweep linear sẵn.
///
/// - Nền shimmer là sóng hình sin: `sin(x·freq + t)` chạy ngang theo thời gian,
///   tô bằng [ui.Gradient] dạng tuyến tính trượt, dẫn đều bằng controller 2000ms.
/// - Mỗi block skeleton "thở" riêng (scale 1.0→1.02) bằng controller 1800ms.
/// - Có các hạt ✨ nhỏ trôi ngang qua theo sin, tạo chiều sâu.
class WaveShimmer extends StatefulWidget {
  final double width;
  final double height;
  final int blockCount;
  final double blockHeight;
  final double blockRadius;
  final Color? tint;
  final bool showParticles;

  const WaveShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 90,
    this.blockCount = 3,
    this.blockHeight = 14,
    this.blockRadius = 7,
    this.tint,
    this.showParticles = true,
  });

  @override
  State<WaveShimmer> createState() => _WaveShimmerState();
}

class _WaveShimmerState extends State<WaveShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveCtrl;
  late final AnimationController _breatheCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _breatheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = widget.tint ?? AppColors.green.withValues(alpha: 0.10);
    return AnimatedBuilder(
      animation: Listenable.merge([_waveCtrl, _breatheCtrl]),
      builder: (context, _) {
        final breathe = 1.0 + _breatheCtrl.value * 0.02;
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: CustomPaint(
            painter: _WaveShimmerPainter(
              progress: _waveCtrl.value,
              breathe: breathe,
              tint: tint,
              blockCount: widget.blockCount,
              blockHeight: widget.blockHeight,
              blockRadius: widget.blockRadius,
              showParticles: widget.showParticles,
            ),
          ),
        );
      },
    );
  }
}

class _WaveShimmerPainter extends CustomPainter {
  final double progress;
  final double breathe;
  final Color tint;
  final int blockCount;
  final double blockHeight;
  final double blockRadius;
  final bool showParticles;

  _WaveShimmerPainter({
    required this.progress,
    required this.breathe,
    required this.tint,
    required this.blockCount,
    required this.blockHeight,
    required this.blockRadius,
    required this.showParticles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final base = Color.lerp(tint, Colors.white, 0.25)!;

    // Sóng ánh sáng di chuyển — vẽ các dải gradient dọc dịch theo sin
    final bandWidth = size.width * 0.4;
    const bands = 3;
    for (int b = 0; b < bands; b++) {
      final phase = progress + b / bands;
      final x =
          (phase * size.width * 1.4) % (size.width + bandWidth) - bandWidth / 2;
      final light = ui.Gradient.linear(
        Offset(x - bandWidth / 2, 0),
        Offset(x + bandWidth / 2, 0),
        [
          tint.withValues(alpha: 0.0),
          base.withValues(alpha: 0.55),
          tint.withValues(alpha: 0.0),
        ],
      );
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..shader = light,
      );
    }

    // Nền block nhạt
    final blockPaint = Paint()..color = tint;

    // Các block skeleton (nằm ngang) + thở
    final gap = blockHeight * 0.9;
    final totalH = blockCount * blockHeight * breathe + (blockCount - 1) * gap;
    final originY = (size.height - totalH) / 2;
    double y = originY;
    for (int i = 0; i < blockCount; i++) {
      final w = size.width * (i == blockCount - 1 ? 0.55 : 1.0);
      final h = blockHeight * breathe;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, y, w, h),
          Radius.circular(blockRadius),
        ),
        blockPaint,
      );
      y += h + gap;
    }

    // Hạt ✨ trôi ngang — chuỗi (phase, y-norm) precompute 1 lần, không blur.
    if (showParticles) {
      for (final (phase, yN) in _sparkleTrail) {
        final ph = (progress + phase) % 1.0;
        final px = ph * size.width * 1.2 - size.width * 0.1;
        final py = yN * size.height;
        final twinkle =
            0.5 + 0.5 * math.sin(progress * math.pi * 2 + phase * 9.5);
        _dot.color = Colors.white.withValues(alpha: 0.55 * twinkle);
        canvas.drawCircle(Offset(px, py), 2.5, _dot);
        _dot.color = Colors.white.withValues(alpha: 0.18 * twinkle);
        canvas.drawCircle(Offset(px, py), 4.5, _dot);
      }
    }
  }

  static final List<(double, double)> _sparkleTrail = [
    for (var p = 0; p < 4; p++)
      (
        p * 0.21,
        (math.Random(7).nextInt(100)) / 100,
      ),
  ];

  final Paint _dot = Paint();

  @override
  bool shouldRepaint(covariant _WaveShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.breathe != breathe ||
      oldDelegate.tint != tint;
}
