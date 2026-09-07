import 'package:flutter/material.dart';

/// Số đếm lên/xuống mượt khi [value] thay đổi.
///
/// - Lần mount đầu: đếm từ 0 → [value] (hiệu ứng "fill-up" điểm/kết quả).
/// - Mỗi lần [value] đổi: đếm tiếp từ giá trị đang hiển thị → giá trị mới,
///   không nhảy cóc.
/// - Điều khiển bằng [AnimationController] một lần duy nhất, luôn giải phóng
///   trong dispose nên không bao giờ "leak" ticker.
class AnimatedCountUp extends StatefulWidget {
  const AnimatedCountUp({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
    this.decimals = 0,
    this.format,
  });

  /// Giá trị đích cần hiển thị.
  final double value;

  /// Style của con số.
  final TextStyle? style;

  /// Thời lượng chạy từ giá trị hiện tại → giá trị mới.
  final Duration duration;

  /// Đường cong easing (mặc định ease-out cho cảm giác "tăng tốc rồi hạ cánh").
  final Curve curve;

  /// Số chữ số thập phân. `0` → hiển thị số nguyên.
  final int decimals;

  /// Tuỳ chọn định dạng riêng (ví dụ thêm 0 ở đầu, kW, %...).
  final String Function(double value)? format;

  @override
  State<AnimatedCountUp> createState() => _AnimatedCountUpState();
}

class _AnimatedCountUpState extends State<AnimatedCountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late double _from;
  late double _display;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addListener(_onTick);
    _from = 0.0;
    _display = 0.0;
    if (widget.value != 0.0) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedCountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _from = _display;
      _controller.duration = widget.duration;
      _controller.forward(from: 0.0);
    }
  }

  void _onTick() {
    final t = widget.curve.transform(_controller.value);
    setState(() {
      _display = _from + (widget.value - _from) * t;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _format(double v) {
    if (widget.format != null) return widget.format!(v);
    if (widget.decimals <= 0) return v.round().toString();
    return v.toStringAsFixed(widget.decimals);
  }

  @override
  Widget build(BuildContext context) {
    return Text(_format(_display), style: widget.style);
  }
}
