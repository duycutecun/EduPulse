import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class DuoHoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isEnabled;
  final BorderRadius borderRadius;
  final Color? normalColor;
  final Color? hoverColor;

  const DuoHoverButton({
    super.key,
    required this.child,
    this.onTap,
    this.isEnabled = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.normalColor,
    this.hoverColor,
  });

  @override
  State<DuoHoverButton> createState() => _DuoHoverButtonState();
}

class _DuoHoverButtonState extends State<DuoHoverButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.normalColor ?? AppColors.green;
    final hColor = widget.hoverColor ?? Color.lerp(baseColor, Colors.white, 0.08)!;

    return MouseRegion(
      cursor: widget.isEnabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: widget.isEnabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: widget.isEnabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: widget.isEnabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.isEnabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _hovered ? hColor : baseColor,
              borderRadius: widget.borderRadius,
              boxShadow: _hovered
                  ? const [BoxShadow(color: AppColors.greenDark, blurRadius: 0, offset: Offset(0, 4))]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
