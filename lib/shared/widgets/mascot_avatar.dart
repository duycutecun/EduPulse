import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

/// Avatar linh vật Cú Sĩ tử tương tác:
/// - Idle: Bồng bềnh nhẹ nhàng có chủ đích (float 3px, 3.2s)
/// - Tap: Nảy lò xo vui tươi (spring pop) + rung haptic + xuất hiện bóng thoại động viên sĩ tử
class MascotAvatar extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;

  const MascotAvatar({
    super.key,
    this.size = 56,
    this.onTap,
  });

  @override
  State<MascotAvatar> createState() => _MascotAvatarState();
}

class _MascotAvatarState extends State<MascotAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  late final AnimationController _tapCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _rotateAnim;

  String? _currentQuote;
  Timer? _quoteTimer;

  static const _quotes = [
    'Hôm nay tập trung 25 phút nhé sĩ tử! 🎯',
    'Từng mục tiêu nhỏ tạo nên kỳ tích! ✨',
    'Cố lên, cánh cổng mơ ước đang chờ bạn! 🎓',
    'Kiên trì mỗi ngày là chìa khóa đỗ đạt! 🌟',
    'Nghỉ ngơi đôi mắt xíu rồi tiếp tục nhé! ☕',
    'Bạn đang tiến gần hơn đến mục tiêu rồi đấy! 🚀',
  ];

  int _quoteIndex = 0;

  @override
  void initState() {
    super.initState();

    // 1. Idle breathing float animation (3.2s)
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _floatAnim = Tween<double>(begin: 0.0, end: -3.5).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOutSine),
    );
    _floatCtrl.repeat(reverse: true);

    // 2. Tap spring pop animation
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.18, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 55,
      ),
    ]).animate(_tapCtrl);

    _rotateAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.06)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.06, end: 0.05)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.05, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
    ]).animate(_tapCtrl);
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _floatCtrl.dispose();
    _tapCtrl.dispose();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.lightImpact();

    _tapCtrl.forward(from: 0.0);

    setState(() {
      _currentQuote = _quotes[_quoteIndex % _quotes.length];
      _quoteIndex++;
    });

    _quoteTimer?.cancel();
    _quoteTimer = Timer(const Duration(milliseconds: 3600), () {
      if (mounted) {
        setState(() => _currentQuote = null);
      }
    });

    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.centerLeft,
      children: [
        // Mascot avatar button
        GestureDetector(
          onTap: _onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: Listenable.merge([_floatCtrl, _tapCtrl]),
            builder: (context, child) {
              final dy = reducedMotion ? 0.0 : _floatAnim.value;
              final scale = reducedMotion ? 1.0 : _scaleAnim.value;
              final rot = reducedMotion ? 0.0 : _rotateAnim.value;

              return Transform.translate(
                offset: Offset(0, dy),
                child: Transform.rotate(
                  angle: rot,
                  child: Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                ),
              );
            },
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.greenDark,
                    blurRadius: 0,
                    offset: Offset(0, 3.5),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(5.5),
                child: Image.asset(
                  'assets/images/mascot.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),

        // Motivational speech bubble
        if (_currentQuote != null)
          Positioned(
            left: widget.size + 14,
            top: -6,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              builder: (context, val, child) {
                return Transform.scale(
                  scale: val,
                  alignment: Alignment.centerLeft,
                  child: Opacity(
                    opacity: val.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: Container(
                constraints: const BoxConstraints(maxWidth: 210),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.green, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withValues(alpha: 0.16),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _currentQuote!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
