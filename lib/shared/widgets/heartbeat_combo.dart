import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Hiệu ứng "heartbeat" (nhịp tim đôi) cho một widget chứa con số/icon.
///
/// - Khi mount lần đầu HOẶC [value] thay đổi → phát một nhịp tim kép
///   (co-giãn 2 nhịp theo đường cong [HeartbeatCurve]) kèm glow phía sau.
/// - Giống cảm giác "combo" dâng lên: streak dâng +1, hoàn thành thêm 1
///   nhiệm vụ... con số "đập" một cái.
/// - Không tự lặp vô hạn → an toàn với test (không treo pumpAndSettle).
class HeartbeatCombo extends StatefulWidget {
  const HeartbeatCombo({
    super.key,
    required this.value,
    required this.child,
    this.peakScale = 0.10,
    this.duration = const Duration(milliseconds: 900),
    this.glowColor,
    this.glowRadius = 14.0,
  });

  /// Giá trị "combo". Khi đổi → phát nhịp tim.
  final double value;

  /// Widget cần phóng to/thu lại (con số, badge, icon...).
  final Widget child;

  /// Biên độ phóng to tối đa (0.10 = phóng 110% ở đỉnh nhịp).
  final double peakScale;

  /// Tổng thời lượng một nhịp tim đôi.
  final Duration duration;

  /// Màu glow phía sau; null → không vẽ glow.
  final Color? glowColor;

  /// Bán kính blur của glow.
  final double glowRadius;

  @override
  State<HeartbeatCombo> createState() => _HeartbeatComboState();
}

class _HeartbeatComboState extends State<HeartbeatCombo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant HeartbeatCombo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (oldWidget.duration != widget.duration) {
        _ctrl.duration = widget.duration;
      }
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.glowColor;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = HeartbeatCurve().transform(_ctrl.value);
        final scale = 1.0 + widget.peakScale * t;
        final glowOpacity = t * 0.55;

        Widget content = Transform.scale(
          scale: scale,
          child: widget.child,
        );

        if (glow != null && glowOpacity > 0) {
          content = DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: glow.withValues(alpha: glowOpacity),
                  blurRadius: widget.glowRadius,
                  spreadRadius: t * 2.0,
                ),
              ],
            ),
            child: content,
          );
        }
        return content;
      },
    );
  }
}

/// Đường cong nhịp tim kép: 2 đỉnh systolic (một nhịp "lub-dub").
///
/// - Nhịp 1: t ∈ [0, 0.45] (đỉnh ở ~0.225)
/// - Nhịp 2: t ∈ [0.5, 1.0] (đỉnh ở ~0.75)
/// - Trả về 0 ở điểm nghỉ → scale trở về 1 giữa 2 nhịp.
class HeartbeatCurve extends Curve {
  const HeartbeatCurve();

  @override
  double transformInternal(double t) {
    double pulse(double p) {
      final x = p.clamp(0.0, 1.0);
      return math.sin(math.pi * x);
    }

    double first = t <= 0.45 ? pulse(t / 0.45) : 0.0;
    double second = t >= 0.5 ? pulse((t - 0.5) / 0.5) : 0.0;
    final base = first + second;
    // Damping: hai nhịp sau nhẹ hơn nhịp trước (cảm giác tim thật).
    return base > 1.0 ? 1.0 : base * 0.9;
  }
}
