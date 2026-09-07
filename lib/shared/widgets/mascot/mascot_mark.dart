import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/anim_tokens.dart';
import 'mascot_painter.dart';
import 'mascot_pose.dart';

export 'mascot_pose.dart' show MascotMood;

/// Bản linh vật nhẹ — chỉ thở + chớp mắt, không tương tác.
///
/// Dùng cho các điểm chạm cần "gương mặt" mascot nhưng không cần hệ thống
/// đầy đủ của `MascotAvatar`: empty state, header AI, loading, hướng dẫn cài
/// đặt... Tái sử dụng chung [MascotPainter] nên luôn đồng nhất với avatar.
class MascotMark extends StatefulWidget {
  final double size;
  final MascotMood mood;

  /// Màu vòng nền; `null` để vẽ mèo trực tiếp không nền (đặt lên nền sẵn có).
  final Color? ringColor;

  const MascotMark({
    super.key,
    this.size = 72,
    this.mood = MascotMood.idle,
    this.ringColor,
  });

  @override
  State<MascotMark> createState() => _MascotMarkState();
}

class _MascotMarkState extends State<MascotMark>
    with TickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final AnimationController _blinkCtrl;
  Timer? _nextBlinkTimer;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: AnimTokens.mascotFloat,
    );
    _floatCtrl.repeat(reverse: true);

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: AnimTokens.mascotBlink * 0.5,
    );
    _blinkCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _blinkCtrl.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _nextBlinkTimer?.cancel();
        _nextBlinkTimer = Timer(
          const Duration(milliseconds: 3400),
          () => _blinkCtrl.forward(from: 0.0),
        );
      }
    });
    _blinkCtrl.forward(from: 0.0);
  }

  @override
  void dispose() {
    _nextBlinkTimer?.cancel();
    _floatCtrl.dispose();
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = AnimTokens.reduceMotion(context);
    final moodColor = widget.ringColor;

    return AnimatedBuilder(
      animation: Listenable.merge([_floatCtrl, _blinkCtrl]),
      builder: (context, _) {
        final dy = reduce ? 0.0 : _floatCtrl.value * -3.0;

        final base = MascotPose.of(widget.mood);
        final pose = reduce
            ? base
            : base.copyWith(
                eyeOpen: (base.eyeOpen * (1.0 - 0.9 * _blinkCtrl.value))
                    .clamp(0.0, 1.0),
              );

        return Transform.translate(
          offset: Offset(0, dy),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (moodColor != null)
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: moodColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                CustomPaint(
                  size: Size.square(widget.size),
                  painter: MascotPainter(pose: pose),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}