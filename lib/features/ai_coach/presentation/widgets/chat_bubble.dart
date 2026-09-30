import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/ai/ai_feedback.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../study/domain/models/study_models.dart';
import 'latex_widget.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage msg;

  /// Regenerate câu trả lời này (mục 10.10) — null khi không khả dụng
  /// (vd màn quiz).
  final VoidCallback? onRegenerate;

  const ChatBubble({super.key, required this.msg, this.onRegenerate});

  @override
  Widget build(BuildContext context) {
    if (msg.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shadows: const [],
          child: SizedBox(
            width: 180,
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'AI đang soạn...',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isUser = msg.isUser;
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.80),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: const [
              BoxShadow(
                  color: AppColors.primaryDark,
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
                  child: Image.memory(
                    msg.imageBytes!,
                    fit: BoxFit.cover,
                    height: 150,
                    // Ảnh chụp có thể 12MP — decode theo kích thước hiển thị.
                    cacheWidth: (MediaQuery.sizeOf(context).width * 1.5)
                        .round(),
                  ),
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
                child: Image.memory(
                  msg.imageBytes!,
                  fit: BoxFit.cover,
                  height: 150,
                  cacheWidth: (MediaQuery.sizeOf(context).width * 1.5)
                      .round(),
                ),
              ),
              if (msg.text.isNotEmpty) const SizedBox(height: 8),
            ],
            if (msg.text.isNotEmpty)
              RichText(
                text: _buildRichText(msg.text, isUser: false),
              ),
            // Source card (mục 10.9 — AI citations): hiện nguồn web đã
            // dùng cho câu trả lời này, bấm mở được.
            if (msg.sourceTitle != null && msg.sourceUrl != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  // Chưa có url_launcher trong deps — copy URL để user
                  // dán vào trình duyệt (trung thực hơn là nút hỏng).
                  Clipboard.setData(ClipboardData(text: msg.sourceUrl!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Đã sao chép đường dẫn nguồn')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.blueSoft.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.blue.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.public_rounded,
                        size: 14, color: AppColors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Nguồn tham khảo',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.blue)),
                            Text(msg.sourceTitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                          ]),
                    ),
                    const Icon(Icons.open_in_new_rounded,
                        size: 13, color: AppColors.blue),
                  ]),
                ),
              ),
            ],
            const SizedBox(height: 6),
            _AiFeedbackRow(msg: msg, onRegenerate: onRegenerate),
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

/// Hàng phản hồi câu trả lời AI (đặc tả mục 10.10): 👍 👎 Regenerate
/// Report. Lưu local qua [AiFeedbackStore], không tự gửi đi đâu.
class _AiFeedbackRow extends StatefulWidget {
  final ChatMessage msg;
  final VoidCallback? onRegenerate;

  const _AiFeedbackRow({required this.msg, this.onRegenerate});

  @override
  State<_AiFeedbackRow> createState() => _AiFeedbackRowState();
}

class _AiFeedbackRowState extends State<_AiFeedbackRow> {
  @override
  void initState() {
    super.initState();
    _saved = AiFeedbackStore.get(widget.msg.id);
  }

  AiFeedback? _saved;

  void _save(String kind, {String? reason}) {
    final f = AiFeedback(
      messageId: widget.msg.id,
      kind: kind,
      reason: reason,
      createdAt: DateTime.now(),
    );
    AiFeedbackStore.put(f);
    setState(() => _saved = f);
  }

  Future<void> _report() async {
    final reason = await showModalBottomSheet<(String, String)>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Câu trả lời này có gì chưa ổn?',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            for (final (value, label) in kAiFeedbackReasons)
              ListTile(
                title: Text(label),
                onTap: () => Navigator.pop(sheetContext, (value, label)),
              ),
          ],
        ),
      ),
    );
    if (reason == null) return;
    _save('down', reason: reason.$1);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Cảm ơn bạn — đã ghi nhận "${reason.$2}". '
            'EduPulse sẽ dùng phản hồi này để cải thiện.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final voted = _saved?.kind;
    return Row(
      children: [
        IconButton(
          tooltip: 'Câu trả lời tốt',
          visualDensity: VisualDensity.compact,
          iconSize: 15,
          onPressed: voted == 'up' ? null : () => _save('up'),
          icon: Icon(
            voted == 'up' ? Icons.thumb_up : Icons.thumb_up_outlined,
            color: voted == 'up' ? AppColors.primary : AppColors.textMuted,
          ),
        ),
        IconButton(
          tooltip: 'Câu trả lời chưa tốt',
          visualDensity: VisualDensity.compact,
          iconSize: 15,
          onPressed: voted == 'down'
              ? null
              : () async {
                  // 👎 mở luôn sheet lý do — feedback có lý do mới dùng được
                  // để cải thiện (đặc tả mục 10.10 liệt kê Feedback reason).
                  await _report();
                  // Người dùng đóng sheet mà không chọn lý do → vẫn ghi 👎.
                  if (_saved == null) _save('down');
                },
          icon: Icon(
            voted == 'down' ? Icons.thumb_down : Icons.thumb_down_outlined,
            color: voted == 'down' ? AppColors.red : AppColors.textMuted,
          ),
        ),
        if (widget.onRegenerate != null)
          IconButton(
            tooltip: 'Tạo lại câu trả lời',
            visualDensity: VisualDensity.compact,
            iconSize: 15,
            onPressed: widget.onRegenerate,
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textMuted),
          ),
        IconButton(
          tooltip: 'Báo câu trả lời có vấn đề',
          visualDensity: VisualDensity.compact,
          iconSize: 15,
          onPressed: _report,
          icon: const Icon(Icons.flag_outlined, color: AppColors.textMuted),
        ),
        const Spacer(),
        // Copy giữ nguyên từ bản cũ.
        IconButton(
          tooltip: 'Sao chép câu trả lời',
          visualDensity: VisualDensity.compact,
          iconSize: 15,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: widget.msg.text));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã sao chép')),
            );
          },
          icon: const Icon(Icons.copy, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
