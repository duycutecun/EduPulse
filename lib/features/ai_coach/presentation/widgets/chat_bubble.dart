import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/typewriter_text.dart';
import '../../../../shared/widgets/wave_shimmer.dart';
import '../../../study/domain/models/study_models.dart';
import 'latex_widget.dart';

/// Bubble trượt vào từ phía bên gửi (user từ phải, AI từ trái) với ease-out
/// nhẹ + fade.
///
/// Tối ưu: dùng Set tĩnh lưu id tin nhắn đã animate — khi ListView tái tạo
/// State (cuộn ra khỏi viewport rồi cuộn lại), bubble cũ KHÔNG phát lại
/// animation (không nhấp nháy, không tốn frame khi scroll).
class _BubbleEntrance extends StatefulWidget {
  final String msgId;
  final bool fromRight;
  final Widget child;

  const _BubbleEntrance({
    required this.msgId,
    required this.fromRight,
    required this.child,
  });

  @override
  State<_BubbleEntrance> createState() => _BubbleEntranceState();
}

class _BubbleEntranceState extends State<_BubbleEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  /// Id đã animate trong phiên — tránh phát lại khi ListView tái tạo State.
  static final Set<String> _shown = <String>{};

  @override
  void initState() {
    super.initState();
    final alreadyShown = _shown.contains(widget.msgId);
    final reducedMotion = _isReducedMotion();

    if (alreadyShown || reducedMotion) {
      // Không animate: đứng ngay vị trí cuối, không tốn controller.
      _ctrl = AnimationController(vsync: this, duration: Duration.zero);
      _ctrl.value = 1.0;
    } else {
      _shown.add(widget.msgId);
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 320),
      );
    }

    final slideBegin = widget.fromRight ? const Offset(0.35, 0) : const Offset(-0.35, 0);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: slideBegin, end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static bool _isReducedMotion() {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    return dispatcher.accessibilityFeatures.disableAnimations;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage msg;

  const ChatBubble({super.key, required this.msg});

  @override
  Widget build(BuildContext context) {
    if (msg.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: _BubbleEntrance(
          msgId: msg.id,
          fromRight: false,
          child: GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shadows: const [],
          child: const RepaintBoundary(
            child: WaveShimmer(
              width: 180,
              height: 48,
              blockCount: 2,
              blockHeight: 12,
              blockRadius: 6,
              showParticles: false,
            ),
          ),
        ),
        ),
      );
    }

    final isUser = msg.isUser;
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: _BubbleEntrance(
          msgId: msg.id,
          fromRight: true,
          child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.80),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.green,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: const [
              BoxShadow(
                  color: AppColors.greenDark,
                  blurRadius: 0,
                  offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (msg.imageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(msg.imageBytes!,
                      fit: BoxFit.cover, height: 150),
                ),
                if (msg.text.isNotEmpty) const SizedBox(height: 8),
              ],
              if (msg.text.isNotEmpty)
                RichText(
                  text: _buildRichText(msg.text, isUser: true),
                ),
            ],
          ),
        ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: _BubbleEntrance(
        msgId: msg.id,
        fromRight: false,
        child: GlassCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        borderRadius: 18,
        shadows: const [],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.imageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(msg.imageBytes!,
                    fit: BoxFit.cover, height: 150),
              ),
              if (msg.text.isNotEmpty) const SizedBox(height: 8),
            ],
            if (msg.text.isNotEmpty)
              TypewriterText(
                id: msg.id,
                text: msg.text,
                builder: (partial) => RichText(
                  text: _buildRichText(partial, isUser: false),
                ),
              ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép')),
                );
              },
              child: Icon(Icons.copy, size: 14, color: AppColors.textMuted),
            ),
          ],
        ),
        ),
      ),
    );
  }

  TextSpan _buildRichText(String text, {required bool isUser}) {
    final textColor = isUser ? Colors.white : AppColors.textPrimary;
    final regex = RegExp(r'\$\$(.*?)\$\$|(?<!\$)\$(?!\$)(.*?)(?<!\$)\$(?!\$)');
    final matches = regex.allMatches(text).toList();

    if (matches.isEmpty) {
      return TextSpan(
        text: text.replaceAll('**', ''),
        style: TextStyle(fontSize: 14, color: textColor, height: 1.45),
      );
    }

    final List<InlineSpan> spans = [];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        final plainText =
            text.substring(lastEnd, match.start).replaceAll('**', '');
        if (plainText.isNotEmpty) {
          spans.add(TextSpan(
            text: plainText,
            style: TextStyle(fontSize: 14, color: textColor, height: 1.45),
          ));
        }
      }

      final latex = match.group(1) ?? match.group(2) ?? '';
      if (latex.isNotEmpty) {
        spans.add(WidgetSpan(
          child: LatexWidget(latex: latex, textColor: textColor),
          alignment: PlaceholderAlignment.middle,
        ));
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      final remaining = text.substring(lastEnd).replaceAll('**', '');
      if (remaining.isNotEmpty) {
        spans.add(TextSpan(
          text: remaining,
          style: TextStyle(fontSize: 14, color: textColor, height: 1.45),
        ));
      }
    }

    return TextSpan(children: spans);
  }
}
