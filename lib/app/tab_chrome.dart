import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';

/// Mô tả một mục trong bottom navigation (icon + nhãn) — kiểu hóa tường minh
/// thay vì Map với `as` cast để tránh lỗi runtime.
class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavItem(this.icon, this.activeIcon, this.label);
}

/// Hệ chuyển tab tương tác thủ công:
///
/// - Nội dung tab đi qua [Stack] giữ state (như IndexedStack) nhưng mỗi layer
///   được biến đổi bởi transform multi-property: translate + scale + opacity +
///   gaussian blur, dẫn động bằng [AnimationController] 420ms.
/// - Kéo ngang nội dung sẽ "preview": tab kế bên bị kéo theo ngón tay từ mép,
///   tab hiện tại dịch chuyển + mờ dần (parallax); buông đủ xa sẽ chuyển tab.
/// - Thanh dưới có "quả chạy" vẽ theo đường bezier bậc 2 (vồng lên) di chuyển
///   giữa tâm tab cũ → mới, đồng bộ với cùng controller của nội dung.
class TabChrome extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final List<NavItem> items;
  final ValueChanged<int> onChanged;

  const TabChrome({
    super.key,
    required this.index,
    required this.children,
    required this.items,
    required this.onChanged,
  });

  @override
  State<TabChrome> createState() => _TabChromeState();
}

class _TabChromeState extends State<TabChrome> with TickerProviderStateMixin {
  late final AnimationController _tabCtrl;
  late final CurvedAnimation _tabAnim;
  late final AnimationController _settleCtrl;
  late final CurvedAnimation _settleAnim;

  int _from = 0;
  double _dragOffset = 0.0;
  double _settleStart = 0.0;
  bool _dragging = false;
  double _width = 0.0;

  @override
  void initState() {
    super.initState();
    _from = widget.index;
    _tabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _tabAnim = CurvedAnimation(
      parent: _tabCtrl,
      curve: Curves.easeInOutCubic,
    );
    _tabCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _from = widget.index;
        _settleCtrl.forward(from: 0.0); // orb "pop" khi đáp xuống
      }
    });
    _settleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _settleAnim = CurvedAnimation(
      parent: _settleCtrl,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant TabChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      final prev = oldWidget.index;
      _tabCtrl.forward(from: 0.0).whenComplete(() {
        if (mounted && !_dragging) setState(() => _from = widget.index);
      });
      setState(() {
        _from = prev;
        _dragOffset = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _tabAnim.dispose();
    _settleCtrl.dispose();
    _settleAnim.dispose();
    super.dispose();
  }

  double get _effectiveDrag {
    if (_dragging) return _dragOffset;
    if (!_settleAnim.isCompleted && _settleAnim.value < 1.0) {
      return _settleStart * (1.0 - _settleAnim.value);
    }
    return 0.0;
  }

  double get _motion {
    if (_dragging || _effectiveDrag.abs() > 0.5) return 0.0;
    return _tabAnim.value;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_dragging) {
      _settleCtrl.stop();
      setState(() {
        _dragging = true;
        _dragOffset = 0.0;
      });
    }
    setState(() => _dragOffset += d.delta.dx);
  }

  void _onDragEnd(DragEndDetails d) {
    final w = _width > 0 ? _width : 1.0;
    final travelled =
        (_dragOffset.abs() / w) + (d.velocity.pixelsPerSecond.dx.abs() / 1400);
    if (travelled > 0.28) {
      final dir = _dragOffset < 0 ? 1 : -1;
      final target = (widget.index + dir).clamp(0, widget.children.length - 1);
      HapticFeedback.selectionClick();
      setState(() {
        _dragging = false;
        _dragOffset = 0.0;
        _settleStart = 0.0;
      });
      if (target != widget.index) widget.onChanged(target);
    } else {
      _settleStart = _dragOffset;
      setState(() {
        _dragging = false;
        _dragOffset = 0.0;
      });
      _settleCtrl.forward(from: 0.0);
    }
  }

  void _onDragCancel() {
    _settleStart = _dragOffset;
    setState(() {
      _dragging = false;
      _dragOffset = 0.0;
    });
    _settleCtrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Column(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: Listenable.merge([_tabCtrl, _settleCtrl]),
            builder: (context, _) {
              return GestureDetector(
                onHorizontalDragUpdate: reduced ? null : _onDragUpdate,
                onHorizontalDragEnd: reduced ? null : _onDragEnd,
                onHorizontalDragCancel: reduced ? null : _onDragCancel,
                behavior: HitTestBehavior.opaque,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _width = constraints.maxWidth;
                    return Stack(
                      fit: StackFit.expand,
                      children: List.generate(widget.children.length, (i) {
                        return _buildLayer(
                          context,
                          i,
                          widget.children[i],
                          constraints.maxWidth,
                          reduced,
                        );
                      }),
                    );
                  },
                ),
              );
            },
          ),
        ),
        _buildNav(context, reduced),
      ],
    );
  }

  Widget _buildLayer(
    BuildContext context,
    int i,
    Widget child,
    double w,
    bool reduced,
  ) {
    final current = widget.index;
    final isFrom = i == _from;
    final isTo = i == current;

    double dx = 0.0, sc = 1.0, op = 1.0, blur = 0.0;
    final d = _effectiveDrag;

    if (_dragging || d.abs() > 0.5) {
      final neighbor = d < 0 ? current + 1 : current - 1;
      if (i == current) {
        final r = (d.abs() / w).clamp(0.0, 1.0);
        dx = d;
        sc = 1.0 - r * 0.09;
        op = 1.0 - r * 0.7;
        blur = 0.0; // tab đang kéo chỉ translate + fade — không blur (rẻ)
      } else if (i == neighbor) {
        final r = (d.abs() / w).clamp(0.0, 1.0);
        final dir = d < 0 ? 1.0 : -1.0;
        dx = dir * w + d;
        sc = 0.90 + 0.10 * r;
        op = r;
        blur = (1.0 - r) * 1.2; // chặn sigma tối đa — blur full-screen đắt
      } else {
        return _offstage(i, child);
      }
    } else {
      final p = _motion;
      if (isFrom && !isTo) {
        dx = -32.0 * p;
        sc = 1.0 - 0.03 * p;
        op = 1.0;
        blur = 0.0;
      } else if (isTo && !isFrom) {
        dx = 72.0 * (1.0 - p);
        sc = 0.90 + 0.10 * p;
        op = p;
        blur = (1.0 - p) *
            1.5; // giảm từ 7σ — blur full-screen mỗi frame là nguồn lag
      } else if (!isFrom && !isTo) {
        return _offstage(i, child);
      }
    }

    return Positioned.fill(
      child: RepaintBoundary(
        child: IgnorePointer(
          ignoring: !(i == current),
          child: TickerMode(
            enabled: i == current || (i == _from),
            child: Opacity(
              opacity: op.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.scale(
                  scale: sc,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: blur,
                      sigmaY: blur,
                    ),
                    child: RepaintBoundary(child: child),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _offstage(int i, Widget child) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: IgnorePointer(
          ignoring: true,
          child: TickerMode(
            enabled: i == _from,
            child: Opacity(
              opacity: 0.0,
              child: Transform.translate(
                offset: Offset.zero,
                child: Transform.scale(
                  scale: 1.0,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: 0,
                      sigmaY: 0,
                    ),
                    child: RepaintBoundary(child: child),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom navigation với "beautiful indicator" bezier
  // ---------------------------------------------------------------------------

  Widget _buildNav(BuildContext context, bool reduced) {
    return AnimatedBuilder(
      animation: Listenable.merge([_tabCtrl, _settleCtrl]),
      builder: (context, _) {
        final dragging = _dragging;
        final from = dragging ? widget.index : _from;
        final to = dragging
            ? (widget.index + (_dragOffset < 0 ? 1 : -1))
                .clamp(0, widget.items.length - 1)
            : widget.index;
        final p = dragging
            ? ((_dragOffset.abs() / (_width > 0 ? _width : 1.0)) * 1.15)
                .clamp(0.0, 1.0)
            : _tabAnim.value;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            border: Border(
              top: BorderSide(color: AppColors.border, width: 2),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final slot = w / widget.items.length;
                  return CustomPaint(
                    size: Size(w, 64),
                    painter: _BezierNavIndicatorPainter(
                      from: from,
                      to: to,
                      t: reduced ? 1.0 : p,
                      settle: reduced ? 1.0 : _settleAnim.value,
                      slotWidth: slot,
                      barHeight: 64,
                    ),
                    child: Row(
                      children: List.generate(widget.items.length, (i) {
                        final active = i == widget.index;
                        final item = widget.items[i];
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              if (i != widget.index) widget.onChanged(i);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: _NavTabContent(
                              active: active,
                              item: item,
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Nội dung icon + nhãn của từng tab: icon có spring bounce khi kích hoạt
/// và phản hồi nhấn (squash khi finger-down, bật lên khi thả).
class _NavTabContent extends StatefulWidget {
  final bool active;
  final NavItem item;

  const _NavTabContent({required this.active, required this.item});

  @override
  State<_NavTabContent> createState() => _NavTabContentState();
}

class _NavTabContentState extends State<_NavTabContent> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final item = widget.item;
    final reduced =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Listener(
      // Dùng Listener (pointer events) thay vì GestureDetector để KHÔNG
      // cạnh tranh gesture arena với GestureDetector cha (nơi xử lý onTap).
      // GestureDetector với onTapDown sẽ "ăn" tap của cha → nav chết.
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
                end: active
                    ? 1.22
                    : (_pressed && !reduced ? 0.82 : 1.0)),
            duration: Duration(milliseconds: active || !reduced ? 300 : 90),
            curve: active ? Curves.easeOutBack : Curves.easeOut,
            builder: (context, scale, child) {
              return Transform.translate(
                offset: Offset(0, active ? -1.5 : 0),
                child: Transform.scale(scale: scale, child: child),
              );
            },
            child: Icon(
              active ? item.activeIcon : item.icon,
              size: 24,
              color: active ? AppColors.green : AppColors.textMuted,
              shadows: active
                  ? [
                      Shadow(
                        color: AppColors.green.withValues(alpha: 0.45),
                        blurRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : const [],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? AppColors.green : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vẽ "quả chạy" indicator di chuyển giữa tâm tab `from` → `to` theo đường
/// bezier bậc 2 vồng lên, đồng bộ với transition của nội dung tab.
class _BezierNavIndicatorPainter extends CustomPainter {
  final int from;
  final int to;
  final double t;
  final double settle;
  final double slotWidth;
  final double barHeight;

  const _BezierNavIndicatorPainter({
    required this.from,
    required this.to,
    required this.t,
    required this.settle,
    required this.slotWidth,
    required this.barHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final A = Offset(from * slotWidth + slotWidth / 2, 52.0);
    final B = Offset(to * slotWidth + slotWidth / 2, 52.0);

    if (t >= 1.0 || from == to) {
      _drawOrb(canvas, B);
      return;
    }

    // Điểm điều khiển nâng lên giữa để tạo vồng bezier
    final C = Offset((A.dx + B.dx) / 2, math.min(A.dy, B.dy) - 26.0);
    final pos = _bezier(A, C, B, t);

    // Vệt hướng dẫn mờ dọc theo bezier
    final guide = Paint()
      ..shader = ui.Gradient.linear(
        A,
        B,
        [
          AppColors.green.withValues(alpha: 0.0),
          AppColors.green.withValues(alpha: 0.18),
        ],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..moveTo(A.dx, A.dy)
      ..quadraticBezierTo(C.dx, C.dy, B.dx, B.dy);
    canvas.drawPath(path, guide);

    _drawOrb(canvas, pos);
  }

  Offset _bezier(Offset a, Offset c, Offset b, double t) {
    final u = 1.0 - t;
    return Offset(
      u * u * a.dx + 2 * u * t * c.dx + t * t * b.dx,
      u * u * a.dy + 2 * u * t * c.dy + t * t * b.dy,
    );
  }

  void _drawOrb(Canvas canvas, Offset center) {
    // Pop khi đáp xuống: phóng to rồi thu về (dùng chung controller settle).
    final pop = math.sin(settle * math.pi);
    final s = 1.0 + 0.32 * pop;

    final orbHeight = 6.0 * s;
    final orbWidth = 34.0 * s;
    final core = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: orbWidth,
        height: orbHeight,
      ),
      Radius.circular(3 * s),
    );
    // Hào quang sprite 2 vòng tròn (thay MaskFilter.blur — rẻ hơn).
    final glow = Paint()
      ..color = AppColors.greenLight.withValues(alpha: 0.22 + 0.4 * pop);
    canvas.drawCircle(center, (orbWidth / 2) + 5, glow);
    canvas.drawCircle(center, (orbWidth / 2) + 1.5, glow);
    // Lõi pill dốc màu
    final orb = Paint()
      ..shader = ui.Gradient.linear(
        center.translate(0, -orbHeight / 2),
        center.translate(0, orbHeight / 2),
        [AppColors.greenLight, AppColors.green],
      );
    canvas.drawRRect(core, orb);
  }

  @override
  bool shouldRepaint(covariant _BezierNavIndicatorPainter oldDelegate) =>
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.t != t ||
      oldDelegate.settle != settle ||
      oldDelegate.slotWidth != slotWidth;
}
