import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/ai/ai_copilot_service.dart';
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

  /// Thử lại câu hỏi bị lỗi (đặc tả 12 / AI-30).
  final VoidCallback? onRetry;

  /// Bỏ lỗi và quay về tự học — lỗi AI không bao giờ chặn người học.
  final VoidCallback? onContinueSelfStudy;

  const ChatBubble({
    super.key,
    required this.msg,
    this.onRegenerate,
    this.onRetry,
    this.onContinueSelfStudy,
  });

  @override
  Widget build(BuildContext context) {
    if (msg.isError) {
      return Align(
        alignment: Alignment.centerLeft,
        child: GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shadows: const [],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 18, color: AppColors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      msg.text,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              if (onRetry != null || onContinueSelfStudy != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (onRetry != null)
                      TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Thử lại',
                            style: TextStyle(fontSize: 12.5)),
                      ),
                    if (onContinueSelfStudy != null)
                      TextButton.icon(
                        onPressed: onContinueSelfStudy,
                        icon: const Icon(Icons.school_outlined, size: 16),
                        label: const Text('Tiếp tục tự học',
                            style: TextStyle(fontSize: 12.5)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

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
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
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
                    cacheWidth:
                        (MediaQuery.sizeOf(context).width * 1.5).round(),
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
                  cacheWidth: (MediaQuery.sizeOf(context).width * 1.5).round(),
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
                  Clipboard.setData(ClipboardData(text: msg.sourceUrl!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Đã sao chép đường dẫn nguồn')),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            // Chat biết HÀNH ĐỘNG: ưu tiên actions có cấu trúc AI chèn
            // (đúng chủ đề, đúng số phút...); chỉ fallback suy đoán keyword
            // khi AI không chèn khối ACTIONS và lời trả lời đủ dài.
            if (!isUser && msg.actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              _AiActionRow(actions: msg.actions),
            ] else if (!isUser && msg.text.trim().length > 30) ...[
              const SizedBox(height: 10),
              _MessageActionChips(text: msg.text),
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
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
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

/// Hàng nút hành động có cấu trúc do AI đề xuất (chat biết HÀNH ĐỘNG).
/// Khác [_MessageActionChips] (suy đoán từ keyword) — các nút này là hành
/// động AI chủ động chèn với chủ đề/thời lượng chính xác theo ngữ cảnh.
class _AiActionRow extends StatelessWidget {
  final List<dynamic> actions;

  const _AiActionRow({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final action in actions)
          InkWell(
            onTap: () => AiCopilotService.executeAction(context, action),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                    (action.color ?? AppColors.primary).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (action.color ?? AppColors.primary)
                      .withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(action.icon,
                      size: 13, color: action.color ?? AppColors.primary),
                  const SizedBox(width: 5),
                  Text(
                    action.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: action.color ?? AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Thanh các nút hành động 1-chạm giúp biến lời khuyên của AI thành hành động thật trong app
class _MessageActionChips extends StatelessWidget {
  final String text;

  const _MessageActionChips({required this.text});

  String _inferSubject(String t) {
    final lower = t.toLowerCase();
    if (lower.contains('toán') ||
        lower.contains('hàm số') ||
        lower.contains('tích phân') ||
        lower.contains('đạo hàm')) {
      return 'Toán';
    }
    if (lower.contains('hóa') ||
        lower.contains('este') ||
        lower.contains('ancol') ||
        lower.contains('nguyên tố')) {
      return 'Hóa học';
    }
    if (lower.contains('vật lý') ||
        lower.contains('lý') ||
        lower.contains('dao động') ||
        lower.contains('con lắc') ||
        lower.contains('điện xoay chiều')) {
      return 'Vật lý';
    }
    if (lower.contains('tiếng anh') ||
        lower.contains('english') ||
        lower.contains('ngữ pháp') ||
        lower.contains('từ vựng')) {
      return 'Tiếng Anh';
    }
    if (lower.contains('sinh học') ||
        lower.contains('sinh') ||
        lower.contains('di truyền') ||
        lower.contains('adn')) {
      return 'Sinh học';
    }
    if (lower.contains('ngữ văn') ||
        lower.contains('văn') ||
        lower.contains('nghị luận')) {
      return 'Ngữ văn';
    }
    if (lower.contains('lịch sử') || lower.contains('sử')) {
      return 'Lịch sử';
    }
    if (lower.contains('địa lý') || lower.contains('địa')) {
      return 'Địa lý';
    }
    return 'Toán';
  }

  String _extractTaskTitle(String t) {
    final lines = t
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();
    if (lines.isNotEmpty) {
      var candidate = lines.first;
      candidate = candidate.replaceAll(RegExp(r'^[-*•\d.)]+\s*'), '').trim();
      if (candidate.length > 50) {
        candidate = '${candidate.substring(0, 48)}...';
      }
      if (candidate.length > 6) return candidate;
    }
    return 'Luyện bài tập từ lời khuyên AI';
  }

  @override
  Widget build(BuildContext context) {
    final subject = _inferSubject(text);
    final taskTitle = _extractTaskTitle(text);

    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
            width: 0.8,
          ),
        ),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          // 1. Thêm vào nhiệm vụ
          _chip(
            context,
            icon: Icons.add_task_rounded,
            label: '+ Nhiệm vụ',
            color: AppColors.blue,
            action: AiCopilotAction(
              type: AiActionType.addTask,
              label: '+ Nhiệm vụ',
              icon: Icons.add_task_rounded,
              payload: {
                'title': taskTitle,
                'subject': subject,
                'minutes': 30,
                'priority': 'medium',
              },
            ),
          ),

          // 2. Bắt đầu Focus
          _chip(
            context,
            icon: Icons.play_arrow_rounded,
            label: 'Focus $subject',
            color: AppColors.primary,
            action: AiCopilotAction(
              type: AiActionType.startFocus,
              label: 'Focus $subject',
              icon: Icons.play_arrow_rounded,
              payload: {
                'subject': subject,
                'minutes': 25,
              },
            ),
          ),

          // 3. Lưu vào Ghi chú
          _chip(
            context,
            icon: Icons.sticky_note_2_rounded,
            label: 'Lưu Ghi chú',
            color: AppColors.purple,
            action: AiCopilotAction(
              type: AiActionType.saveNote,
              label: 'Lưu Ghi chú',
              icon: Icons.sticky_note_2_rounded,
              payload: {
                'title': taskTitle,
                'body': text,
                'subject': subject,
              },
            ),
          ),

          // 4. Test trắc nghiệm 5 câu
          _chip(
            context,
            icon: Icons.quiz_rounded,
            label: 'Test 5 câu',
            color: AppColors.orange,
            action: AiCopilotAction(
              type: AiActionType.takeQuiz,
              label: 'Test 5 câu',
              icon: Icons.quiz_rounded,
              payload: {
                'subject': subject,
                'topic': taskTitle,
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required AiCopilotAction action,
  }) {
    return InkWell(
      onTap: () => AiCopilotService.executeAction(context, action),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
