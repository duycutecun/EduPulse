import 'package:flutter/material.dart';

/// Nút bấm phản hồi vật lý kiểu Duolingo:
///
/// - **Nhấn xuống**: co nhanh (~90ms easeOut) + nội dung "chìm" vào bóng 3D
///   (bóng dẹt từ [pressTranslate] → 0.5px) — cảm giác bấm nút cứng cáp.
/// - **Thả ra**: bật trở lại với độ vượt nhẹ (easeOutBack ~260ms) —
///   signature "springy" của các app học tập nổi tiếng.
/// - [shadowColor]: vẽ bóng khối 3D tĩnh phía dưới (chi phí thấp, không blur).
/// - Không controller vô hạn → an toàn hiệu năng trên web/WASM.
/// - Tôn trọng reduce-motion: chỉ nhấn/thả, không scale vượt.
class SpringPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  final double pressScale;
  final double pressTranslate;
  final Color? shadowColor;
  final BorderRadius borderRadius;

  const SpringPress({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressScale = 0.94,
    this.pressTranslate = 3.0,
    this.shadowColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<SpringPress> createState() => _SpringPressState();
}

class _SpringPressState extends State<SpringPress> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  static bool _isReducedMotion() {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    return dispatcher.accessibilityFeatures.disableAnimations;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final reducedMotion = _isReducedMotion();
    final pressed = _pressed;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTapDown: enabled
            ? (_) {
                if (!_pressed) setState(() => _pressed = true);
              }
            : null,
        onTapUp: enabled
            ? (_) {
                if (_pressed) setState(() => _pressed = false);
              }
            : null,
        onTapCancel: enabled
            ? () {
                if (_pressed) setState(() => _pressed = false);
              }
            : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: reducedMotion
            ? _buildContent(pressed: pressed, animate: false)
            // Nhấn: co nhanh; Thả: bật vượng với easeOutBack (overshoot nhẹ)
            // → cảm giác lò xo đúng chất Duolingo.
            : _buildContent(
                pressed: pressed,
                animate: true,
                duration:
                    pressed ? const Duration(milliseconds: 90) : const Duration(milliseconds: 260),
                curve: pressed ? Curves.easeOut : Curves.easeOutBack,
              ),
      ),
    );
  }

  Widget _buildContent({
    required bool pressed,
    bool animate = true,
    Duration duration = const Duration(milliseconds: 90),
    Curve curve = Curves.easeOut,
  }) {
    // Lớp bóng (không transform): dẹt lại khi nhấn (pressTranslate → 0.5px)
    // trong khi nội dung trượt xuống "chìm" vào phần bóng → cảm giác 3D.
    final sink = (widget.pressTranslate - 0.5).clamp(0.0, 100.0);

    final content = AnimatedContainer(
      duration: animate ? duration : Duration.zero,
      curve: curve,
      transform: Matrix4.translationValues(
        0,
        pressed && animate ? sink : (pressed ? widget.pressTranslate * 0.6 : 0.0),
        0,
      ),
      child: AnimatedScale(
        duration: animate ? duration : Duration.zero,
        curve: curve,
        scale: pressed ? widget.pressScale : 1.0,
        child: widget.child,
      ),
    );

    if (widget.shadowColor == null) return content;

    return AnimatedContainer(
      duration: animate ? duration : Duration.zero,
      curve: curve,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        boxShadow: [
          BoxShadow(
            color: widget.shadowColor!,
            blurRadius: 0,
            offset: Offset(0, pressed ? 0.5 : widget.pressTranslate),
          ),
        ],
      ),
      child: content,
    );
  }
}
