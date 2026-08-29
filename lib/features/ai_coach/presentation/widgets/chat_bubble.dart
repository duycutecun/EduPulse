import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/animated_pulse.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../study/domain/models/study_models.dart';
import 'latex_widget.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage msg;

  const ChatBubble({super.key, required this.msg});

  @override
  Widget build(BuildContext context) {
    if (msg.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shadows: const [],
          child: const TypingDotsIndicator(),
        ),
      );
    }

    final isUser = msg.isUser;
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
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
              BoxShadow(color: AppColors.greenDark, blurRadius: 0, offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (msg.imageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(msg.imageBytes!, fit: BoxFit.cover, height: 150),
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
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
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
                child: Image.memory(msg.imageBytes!, fit: BoxFit.cover, height: 150),
              ),
              if (msg.text.isNotEmpty) const SizedBox(height: 8),
            ],
            if (msg.text.isNotEmpty)
              RichText(
                text: _buildRichText(msg.text, isUser: false),
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
        final plainText = text.substring(lastEnd, match.start).replaceAll('**', '');
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
