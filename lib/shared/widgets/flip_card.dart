import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Thẻ lật 3D (rotateY) kiểu flashcard.
///
/// - Chạm vào thẻ để lật [front] ↔ [back] với hiệu ứng perspective.
/// - Hỗ trợ chế độ "controlled" (bật [isFlipped], gọi [onToggle] từ ngoài).
/// - Dùng một [AnimationController] hữu hạn, không tự lặp → an toàn test.
///
/// Hai mặt được xếp trong [Stack] với [IntrinsicHeight] để tự doàn theo
/// chiều cao của mặt cao nhất; mỗi mặt được [IgnorePointer] + fade khi ẩn.
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    this.duration = const Duration(milliseconds: 450),
    this.curve = Curves.easeInOutCubic,
    this.isFlipped,
    this.onToggle,
    this.interactive = true,
  });

  final Widget front;
  final Widget back;

  /// Tổng thời lượng lật một nửa vòng.
  final Duration duration;

  final Curve curve;

  /// Chế độ điều khiển từ ngoài: khi khác null, thẻ phản chiếu đúng giá trị này.
  final bool? isFlipped;

  /// Gọi khi người dùng chạm để lật (dùng trong chế độ controlled).
  final VoidCallback? onToggle;

  /// Khi false, chạm vào thẻ không tự lật (chỉ điều khiển từ ngoài).
  final bool interactive;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _internalFlipped = false;

  @override
  void initState() {
    super.initState();
    final startFlipped = widget.isFlipped ?? false;
    _internalFlipped = startFlipped;
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: startFlipped ? 1.0 : 0.0,
    );
    _ctrl.addStatusListener((status) {
      if ((status == AnimationStatus.completed ||
              status == AnimationStatus.dismissed) &&
          widget.isFlipped == null &&
          mounted) {
        setState(() => _internalFlipped = _ctrl.value >= 0.5);
      }
    });
  }

  bool get _flipped => widget.isFlipped ?? _internalFlipped;

  void _toggle() {
    if (!_flipped) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
    if (widget.onToggle != null) widget.onToggle!();
  }

  @override
  void didUpdateWidget(covariant FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != null && oldWidget.isFlipped != widget.isFlipped) {
      if (widget.isFlipped!) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
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
    return GestureDetector(
      onTap: widget.interactive ? _toggle : null,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final value = widget.curve.transform(_ctrl.value);
          final frontAngle = math.pi * value;
          final backAngle = math.pi * (1.0 - value);
          final showFront = value < 0.5;

          return IntrinsicHeight(
            child: Stack(
              children: [
                _flipFace(
                  angle: frontAngle,
                  opacity: showFront ? (1.0 - value * 2.0).clamp(0.0, 1.0) : 0.0,
                  ignore: !showFront,
                  child: widget.front,
                ),
                _flipFace(
                  angle: backAngle,
                  opacity: showFront ? 0.0 : ((value - 0.5) * 2.0).clamp(0.0, 1.0),
                  ignore: showFront,
                  child: widget.back,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _flipFace({
    required double angle,
    required double opacity,
    required bool ignore,
    required Widget child,
  }) {
    return IgnorePointer(
      ignoring: ignore,
      child: Opacity(
        opacity: opacity,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: child,
        ),
      ),
    );
  }
}