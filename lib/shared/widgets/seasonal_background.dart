import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Nền theo mùa: tuyết rơi (Noel/mùa đông) + pháo hoa (dịp Tết/đầu năm).
///
/// - Tự nhận diện mùa theo ngày hiện tại:
///   - **Tết Âm lịch** (lan can 20/1 – 20/2): pháo hoa bắn rải rác.
///   - **Noel** (15/12 – 5/1) & mùa đông: tuyết rơi nhẹ.
/// - Lớp phủ không chặn gesture, vẽ mờ nhẹ để không ảnh hưởng đọc nội dung.
/// - Nếu `MediaQuery.disableAnimations` → bỏ qua toàn bộ (không tốn pin/frame).
/// - Ngoài mùa: trả về nguyên [child] (không controller → zero cost).
class SeasonalBackground extends StatefulWidget {
  const SeasonalBackground({super.key, required this.child});

  final Widget child;

  @override
  State<SeasonalBackground> createState() => _SeasonalBackgroundState();
}

class _SeasonalBackgroundState extends State<SeasonalBackground>
    with SingleTickerProviderStateMixin {
  late final bool _snow;
  late final bool _fireworks;
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _snow = _isWinter(now);
    _fireworks = _isTetSeason(now);
    if (_snow || _fireworks) {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 7),
      )..repeat();
    }
  }

  static bool _isWinter(DateTime d) {
    return (d.month == 12 && d.day >= 15) ||
        (d.month == 1 && d.day <= 5) ||
        d.month == 2 && d.day <= 20;
  }

  static bool _isTetSeason(DateTime d) {
    return (d.month == 1 && d.day >= 20) || (d.month == 2 && d.day <= 20);
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return widget.child;
    }
    final ctrl = _ctrl;
    if (ctrl == null) return widget.child;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: ctrl,
              builder: (context, _) => CustomPaint(
                painter: _SeasonalPainter(
                  t: ctrl.value,
                  snow: _snow,
                  fireworks: _fireworks,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SeasonalPainter extends CustomPainter {
  _SeasonalPainter({
    required this.t,
    required this.snow,
    required this.fireworks,
  });

  final double t;
  final bool snow;
  final bool fireworks;

  @override
  void paint(Canvas canvas, Size size) {
    if (snow) _paintSnow(canvas, size);
    if (fireworks) _paintFireworks(canvas, size);
  }

  void _paintSnow(Canvas canvas, Size size) {
    final paint = Paint();
    const flakes = 34;
    for (int i = 0; i < flakes; i++) {
      final seed = (i * 0.37) % 1.0;
      final speed = 0.05 + (i % 5) * 0.012;
      final y = ((seed + t * speed * 1.8) % 1.0) * size.height;
      final baseX = ((i * 0.61) % 1.0) * size.width;
      final sway = math.sin(t * 2 * math.pi * 1.4 + i) * 8.0;
      final x = baseX + sway;
      final r = 1.5 + (i % 3);
      paint.color = Colors.white.withValues(alpha: 0.85);
      canvas.drawCircle(Offset(x, y), r, paint);
      if (i % 3 == 0) {
        paint.color = Colors.white.withValues(alpha: 0.4);
        canvas.drawCircle(Offset(x + 5, y + r * 2), r * 0.55, paint);
      }
    }
  }

  void _paintFireworks(Canvas canvas, Size size) {
    const starts = <double>[0.14, 0.38, 0.62, 0.86];
    const burstDur = 0.22;
    final cx = size.width / 2;
    final cy = size.height * 0.22;

    for (int i = 0; i < starts.length; i++) {
      final local = (t - starts[i]) / burstDur;
      if (local < 0 || local > 1) continue;
      final p = local;

      final baseX = cx + math.sin(i * 2.61) * size.width * 0.42;
      final baseY = cy + math.cos(i * 1.3) * size.height * 0.14;

      final glow = Paint()
        ..color = AppColors.yellow.withValues(alpha: (1 - p) * 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(
        Offset(baseX, baseY),
        4 + p * 32,
        glow,
      );

      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = _fireColor(i).withValues(alpha: (1 - p).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(baseX, baseY), p * 46, ring);

      final spark = Paint()..color = _fireColor(i);
      for (int s = 0; s < 10; s++) {
        final ang = s / 10 * math.pi * 2;
        final dist = p * 52 + (s % 3) * 14 * (1 - p);
        canvas.drawCircle(
          Offset(baseX + math.cos(ang) * dist, baseY + math.sin(ang) * dist),
          1.6,
          spark,
        );
      }
    }
  }

  Color _fireColor(int i) {
    const colors = <Color>[
      AppColors.yellow,
      AppColors.blue,
      AppColors.purple,
      AppColors.green,
    ];
    return colors[i % colors.length];
  }

  @override
  bool shouldRepaint(covariant _SeasonalPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.snow != snow ||
      oldDelegate.fireworks != fireworks;
}
