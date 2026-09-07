import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Một "chùm pháo giấy" nổ một lần, non-modal (không che cả màn hình như
/// CelebrationOverlay) — thích hợp bắn ngay trên một thẻ/khu vực khi đạt
/// thành tích (vd hoàn thành hết nhiệm vụ hôm nay).
///
/// - Bật [active] = true để kích nổ một lần; tự chạy ~1.6s rồi dừng.
/// - Gọi [onComplete] khi màn trình diễn kết thúc.
/// - Không chặn gesture (IgnorePointer) nên vẫn thao tác bình thường.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    required this.active,
    this.onComplete,
    this.particles = 26,
    this.colors,
    this.gravity = 420.0,
    this.spread = 0.75,
    this.duration = const Duration(milliseconds: 1600),
  });

  final bool active;
  final VoidCallback? onComplete;

  /// Số mảnh pháo.
  final int particles;

  /// Màu các mảnh (mặc định dùng bảng màu EduPulse).
  final List<Color>? colors;

  /// Gia tốc trọng trường (px/s²) làm pháo rơi dần.
  final double gravity;

  /// Độ trải theo chiều ngang (0..1; 1 = nổ ngang toàn bề rộng).
  final double spread;

  final Duration duration;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _fired = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted && !_done) {
          _done = true;
          widget.onComplete?.call();
        }
      });
    if (widget.active) {
      _fire();
    }
  }

  void _fire() {
    if (_fired) return;
    _fired = true;
    _done = false;
    _ctrl.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant ConfettiBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _fire();
      } else {
        _fired = false;
        _done = false;
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          if (!_fired) return const SizedBox.shrink();
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiBurstPainter(
              t: _ctrl.value,
              colors: widget.colors,
              gravity: widget.gravity,
              spread: widget.spread,
              count: widget.particles,
            ),
          );
        },
      ),
    );
  }
}

class _ConfettiBurstPainter extends CustomPainter {
  _ConfettiBurstPainter({
    required this.t,
    required this.colors,
    required this.gravity,
    required this.spread,
    required this.count,
  });

  final double t;
  final List<Color>? colors;
  final double gravity;
  final double spread;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = colors ??
        const [AppColors.yellow, AppColors.blue, AppColors.purple, Colors.white, AppColors.green, AppColors.orange];
    final center = Offset(size.width * 0.5, size.height * 0.35);
    final rand = math.Random(7);

    for (int i = 0; i < count; i++) {
      final color = palette[i % palette.length];
      final angle = -math.pi / 2 + (rand.nextDouble() - 0.5) * math.pi * spread;
      final speed = 140.0 + rand.nextDouble() * 260.0;
      final vx = math.cos(angle) * speed;
      final vy = math.sin(angle) * speed;
      final sizeP = 5.0 + rand.nextDouble() * 5.0;

      final dx = center.dx + vx * t;
      final dy = center.dy + vy * t + 0.5 * gravity * t * t;
      final spin = rand.nextDouble() * 4.0 * math.pi * t;

      final paint = Paint()..color = color;
      final rect = Rect.fromCenter(
        center: Offset(dx, dy),
        width: sizeP,
        height: sizeP * 1.7,
      );
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(spin);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.translate(-dx, -dy), const Radius.circular(2.5)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiBurstPainter oldDelegate) =>
      oldDelegate.t != t;
}