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
///
/// Tối ưu hiệu năng: glow thay bằng sprite tròn 2 lớp (không `MaskFilter.blur`),
/// tham số hạt precompute một lần, tái dùng [Paint] → ít GC + GPU mỗi frame.
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
            child: RepaintBoundary(
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

  // --- Bộ tham số tuyết precompute một lần (không allocate mỗi frame). ---
  static const int _flakeCount = 22;
  static final List<double> _flakeY0 = List.generate(
    _flakeCount,
    (i) => (i * 0.37) % 1.0,
    growable: false,
  );
  static final List<double> _flakeSpeed = List.generate(
    _flakeCount,
    (i) => 0.05 + (i % 5) * 0.012,
    growable: false,
  );
  static final List<double> _flakeX0 = List.generate(
    _flakeCount,
    (i) => (i * 0.61) % 1.0,
    growable: false,
  );
  static final List<double> _flakeRadius = List.generate(
    _flakeCount,
    (i) => 1.5 + (i % 3),
    growable: false,
  );

  static const List<double> _burstStarts = <double>[0.14, 0.38, 0.62, 0.86];
  static const double _burstDur = 0.22;
  static const int _sparks = 10;
  static const double _sparkArc = 0.6283185307179586; // 2π / 10
  static const List<Color> _colors = <Color>[
    AppColors.yellow,
    AppColors.blue,
    AppColors.purple,
    AppColors.green,
  ];

  // Tái dùng Paint, chỉ đổi màu mỗi lần vẽ.
  final Paint _flake = Paint();
  final Paint _glow = Paint();
  final Paint _ring = Paint()..style = PaintingStyle.stroke;
  final Paint _spark = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (snow) _paintSnow(canvas, size);
    if (fireworks) _paintFireworks(canvas, size);
  }

  void _paintSnow(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    for (int i = 0; i < _flakeCount; i++) {
      final y = ((_flakeY0[i] + t * _flakeSpeed[i] * 1.8) % 1.0) * h;
      final x = _flakeX0[i] * w + math.sin(t * 2 * math.pi * 1.4 + i) * 8.0;
      final r = _flakeRadius[i];
      _flake.color = _flakeMain;
      canvas.drawCircle(Offset(x, y), r, _flake);
      if (i % 3 == 0) {
        _flake.color = _flakeSub;
        canvas.drawCircle(Offset(x + 5, y + r * 2), r * 0.55, _flake);
      }
    }
  }

  void _paintFireworks(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h * 0.22;

    for (int i = 0; i < _burstStarts.length; i++) {
      final p = (t - _burstStarts[i]) / _burstDur;
      if (p < 0 || p > 1) continue;

      final bx = cx + math.sin(i * 2.61) * w * 0.42;
      final by = cy + math.cos(i * 1.3) * h * 0.14;
      final base = Color.lerp(_colors[i], Colors.white, 0.25)!;
      final fade = (1.0 - p) * 0.45;

      // Glow sprite 2 vòng tròn (thay cho MaskFilter.blur — rẻ hơn nhiều).
      final haloR = 6 + p * 40;
      _glow.color = base.withValues(alpha: fade * 0.35);
      canvas.drawCircle(Offset(bx, by), haloR, _glow);
      _glow.color = base.withValues(alpha: fade);
      canvas.drawCircle(Offset(bx, by), haloR * 0.45, _glow);

      _ring.strokeWidth = 2.5;
      _ring.color = base.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(bx, by), p * 46, _ring);

      _spark.color = base;
      for (int s = 0; s < _sparks; s++) {
        final ang = s * _sparkArc;
        final dist = p * 52 + (s % 3) * 14 * (1 - p);
        canvas.drawCircle(
          Offset(bx + math.cos(ang) * dist, by + math.sin(ang) * dist),
          1.6,
          _spark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SeasonalPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.snow != snow ||
      oldDelegate.fireworks != fireworks;
}

const Color _flakeMain = Color(0xD9FFFFFF);
const Color _flakeSub = Color(0x66FFFFFF);
