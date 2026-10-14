import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/feedback/beta_feedback.dart';
import '../../../../core/share/share_service.dart';

/// Mở bottom-sheet "Gửi phản hồi beta" (đặc tả mục 10 — kênh feedback trong app).
Future<void> showBetaFeedbackSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const BetaFeedbackSheet(),
  );
}

/// Form phản hồi ngắn: chọn nhóm, gõ nội dung, liên hệ tùy chọn.
///
/// Lưu **cục bộ** và cho người dùng chủ động sao chép/chia sẻ — không tự gửi
/// đi đâu, phù hợp nguyên tắc quyền riêng tư của app.
class BetaFeedbackSheet extends StatefulWidget {
  const BetaFeedbackSheet({super.key});

  @override
  State<BetaFeedbackSheet> createState() => _BetaFeedbackSheetState();
}

class _BetaFeedbackSheetState extends State<BetaFeedbackSheet> {
  final _messageController = TextEditingController();
  final _contactController = TextEditingController();
  BetaFeedbackCategory _category = BetaFeedbackCategory.bug;
  bool _submitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy nhập nội dung phản hồi trước khi gửi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    BetaFeedbackService.instance.submit(
      _category,
      message,
      contact: _contactController.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã lưu phản hồi. Cảm ơn bạn đã giúp EduPulse tốt hơn!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareAll() async {
    final text = BetaFeedbackService.instance.exportText();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có phản hồi nào để chia sẻ.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await ShareService.shareText(text, subject: 'Phản hồi EduPulse');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gửi phản hồi beta',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Phản hồi được lưu trên máy bạn. Bạn có thể chia sẻ cho nhóm phát triển khi cần.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BetaFeedbackCategory.values.map((c) {
                final selected = c == _category;
                return ChoiceChip(
                  label: Text(c.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = c),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Điều bạn muốn góp ý',
                hintText:
                    'Ví dụ: nút bắt đầu phiên học bị che khi bàn phím mở…',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contactController,
              decoration: const InputDecoration(
                labelText: 'Liên hệ (tùy chọn)',
                hintText: 'Email hoặc cách liên lạc nếu muốn được phản hồi',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _shareAll,
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Chia sẻ phản hồi'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: const Text('Gửi'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
