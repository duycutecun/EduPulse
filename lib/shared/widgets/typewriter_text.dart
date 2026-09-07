import 'package:flutter/material.dart';

/// Hiệu ứng AI đang "gõ" — text hiện dần như máy đánh chữ (streaming).
///
/// - Reveal theo từ (word boundary) và KHÔNG bao giờ cắt giữa khối LaTeX
///   `$...$`/`$$...$$`: mỗi khối LaTeX là một "atom" hiện nguyên vẹn.
/// - Chỉ stream **một lần** cho mỗi [id] trong cùng tiến trình app
///   (dùng set tĩnh để tránh re-stream khi ListView recycle / vào lại màn hình).
/// - Khi đang stream hiển thị con trỏ `▍` cuối câu.
/// - Được điều khiển bằng một [AnimationController] hữu hạn → an toàn test.
class TypewriterText extends StatefulWidget {
  const TypewriterText({
    super.key,
    required this.id,
    required this.text,
    required this.builder,
  });

  /// Id của tin nhắn — dùng để "chỉ stream đúng một lần".
  final String id;

  /// Nội dung đầy đủ cần reveal.
  final String text;

  /// Nhận phần text đã reveal (luôn dừng ở ranh giới từ / khối LaTeX)
  /// và trả về widget hiển thị (thường là RichText/Text).
  final Widget Function(String partial) builder;

  /// Những id đã stream xong trong phiên làm việc.
  static final Set<String> _played = <String>{};

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  List<int> _endpoints = const [];
  bool _streaming = false;

  @override
  void initState() {
    super.initState();
    _endpoints = _buildEndpoints(widget.text);
    if (TypewriterText._played.contains(widget.id) || widget.text.isEmpty) {
      _streaming = false;
      _ctrl = AnimationController(
        vsync: this,
        duration: Duration.zero,
      );
    } else {
      TypewriterText._played.add(widget.id);
      final ms = 1100 +
          (widget.text.length > 60
              ? (widget.text.length - 60).clamp(0, 800)
              : 0);
      _ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: ms),
      )..forward();
      _streaming = true;
      _ctrl.addListener(_onTick);
      _ctrl.addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() => _streaming = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTick() {
    setState(() {});
  }

  static List<int> _buildEndpoints(String text) {
    if (text.isEmpty) return const [0];
    final endpoints = <int>{0, text.length};
    final latex =
        RegExp(r'(?<!\$)\$\$(.*?)\$\$|(?<!\$)\$(?!\$)(.*?)(?<!\$)\$(?!\$)');
    for (final m in latex.allMatches(text)) {
      if (m.start > 0 && text[m.start - 1] == ' ') endpoints.add(m.start - 1);
      endpoints.add(m.end);
    }
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == ' ' || ch == '\n') endpoints.add(i + 1);
    }
    final list = endpoints.toList()..sort();
    return list;
  }

  int _revealedCount(double t) {
    final requested = (widget.text.length * t).round();
    var chosen = _endpoints.first;
    for (final e in _endpoints) {
      if (e <= requested) {
        chosen = e;
      } else {
        break;
      }
    }
    return chosen;
  }

  @override
  Widget build(BuildContext context) {
    if (!_streaming) {
      return widget.builder(widget.text);
    }
    final partial = widget.text.substring(0, _revealedCount(_ctrl.value));
    return widget.builder('$partial▍');
  }
}