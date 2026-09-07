import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Bộ item xuất hiện lần lượt dùng phương trình dao động tắt dần thật
/// x(t) = A·e^(−ζωt)·cos(ωd·t + φ), không dùng curve có sẵn.
///
/// Mỗi con [child] là một [state] được khởi tạo unique để mỗi item tự "tick"
/// controller của riêng nó — cho phép stagger true spring physics.
class SpringStagger extends StatelessWidget {
  final int count;
  final IndexedWidgetBuilder itemBuilder;
  final Duration stepDelay;
  final SpringConfig spring;
  final Axis direction;

  const SpringStagger({
    super.key,
    required this.count,
    required this.itemBuilder,
    this.stepDelay = const Duration(milliseconds: 110),
    this.spring = const SpringConfig(),
    this.direction = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Column(
      children: [
        for (int i = 0; i < count; i++)
          _SpringItem(
            key: ValueKey('stagger-$i'),
            index: i,
            stepDelay: stepDelay,
            spring: spring,
            direction: direction,
            reduce: reduce,
            child: itemBuilder(context, i),
          ),
      ],
    );
  }
}

/// Cấu hình phương trình dao động tắt dần.
class SpringConfig {
  final double amplitude;
  final double zeta;
  final double omega;
  final double maxDuration;
  final double entranceOffset;

  const SpringConfig({
    this.amplitude = 1.0,
    this.zeta = 0.55,
    this.omega = 11.0,
    this.maxDuration = 700,
    this.entranceOffset = 46.0,
  });
}

class _SpringItem extends StatefulWidget {
  final int index;
  final Duration stepDelay;
  final SpringConfig spring;
  final Axis direction;
  final bool reduce;
  final Widget child;

  const _SpringItem({
    super.key,
    required this.index,
    required this.stepDelay,
    required this.spring,
    required this.direction,
    required this.reduce,
    required this.child,
  });

  @override
  State<_SpringItem> createState() => _SpringItemState();
}

class _SpringItemState extends State<_SpringItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Timer _timer;
  double _clock = 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds:
            widget.spring.maxDuration.round() + widget.spring.maxDuration.round(),
      ),
    )..addListener(() {
        _clock = _ctrl.value * widget.spring.maxDuration / 1000.0;
      });
    if (widget.reduce) {
      _clock = 99.0;
    } else {
      final delay = widget.index * widget.stepDelay.inMilliseconds;
      _timer = Timer(Duration(milliseconds: delay), () => _ctrl.forward(from: 0.0));
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  /// Giá trị vị trí theo phương trình dao động tắt dần từ 0→1.
  double get _position {
    final t = _clock;
    if (t <= 0.0) return 0.0;
    final A = widget.spring.amplitude;
    final z = widget.spring.zeta;
    final w = widget.spring.omega;
    final wd = w * math.sqrt(math.max(0.0, 1.0 - z * z));
    final env = A * math.exp(-z * w * t);
    final osc = math.cos(wd * t);
    return 1.0 - env * osc; // 0 → settle về 1
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.reduce ? 1.0 : _position;
    final s = widget.spring;

    // Phase-based:
    //  - Phase 1: opacity + "giải nén" (scale tăng nhẹ vượt)
    //  - Phase 2: dịch chuyển từ offset về 0 với overshoot
    //  - Phase 3: settle
    final opacity = pos.clamp(0.0, 1.0);
    final scale = 0.92 + 0.10 * math.sin(math.min(pos, 1.0) * math.pi / 2);
    final overshoot = (pos - 0.6).clamp(0.0, 0.4) * 6.0;
    final travel = (1.0 - pos) * s.entranceOffset - overshoot;

    Widget child = Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale.clamp(0.9, 1.06),
        child: widget.direction == Axis.vertical
            ? Transform.translate(offset: Offset(0, travel), child: widget.child)
            : Transform.translate(offset: Offset(travel, 0), child: widget.child),
      ),
    );

    return child;
  }
}