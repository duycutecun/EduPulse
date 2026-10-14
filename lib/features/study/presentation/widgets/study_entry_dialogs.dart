import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Hộp thoại "Ghi điểm thi thử" của màn Tập trung.
///
/// Tách khỏi `study_screen.dart` để phần nhập liệu không lẫn vào state của màn.
/// Gọi [onAdd] với dữ liệu đã hợp lệ; màn cha lo việc lưu trữ.
void showAddScoreDialog(
  BuildContext context, {
  required void Function(
          String subject, double score, String? note, String topic)
      onAdd,
}) {
  final subjectCtrl = TextEditingController();
  final scoreCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final topicCtrl = TextEditingController();
  final subjects = [
    '📐 Toán',
    '📖 Văn',
    '🇬🇧 Anh',
    '⚡ Lý',
    '🧪 Hóa',
    '🧬 Sinh'
  ];

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border, width: 2),
      ),
      title: const Text('Ghi điểm thi thử',
          style: TextStyle(fontWeight: FontWeight.w800)),
      content: StatefulBuilder(
        builder: (ctx, setDialogState) {
          String subject =
              subjectCtrl.text.isEmpty ? '📐 Toán' : subjectCtrl.text;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: subjects.map((sub) {
                  final sel = subject == sub;
                  return GestureDetector(
                    onTap: () => setDialogState(() {
                      subjectCtrl.text = sub;
                      subject = sub;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : AppColors.bgPage,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel ? AppColors.primary : AppColors.border,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        sub,
                        style: TextStyle(
                          fontSize: 12,
                          color: sel ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: subjectCtrl,
                  decoration:
                      const InputDecoration(hintText: 'Hoặc nhập môn khác')),
              const SizedBox(height: 8),
              TextField(
                  controller: scoreCtrl,
                  decoration:
                      const InputDecoration(hintText: 'Điểm (0–10, VD: 7.5)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 8),
              TextField(
                  controller: topicCtrl,
                  decoration: const InputDecoration(
                      hintText: 'Chủ đề/dạng bài (tùy chọn, VD: Hàm số)')),
              const SizedBox(height: 8),
              TextField(
                  controller: noteCtrl,
                  decoration:
                      const InputDecoration(hintText: 'Ghi chú (tùy chọn)')),
            ],
          );
        },
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: TextStyle(color: AppColors.textMuted))),
        TextButton(
          onPressed: () {
            final score =
                double.tryParse(scoreCtrl.text.trim().replaceAll(',', '.'));
            final subject = subjectCtrl.text.trim();
            if (subject.isNotEmpty &&
                score != null &&
                score >= 0 &&
                score <= 10) {
              onAdd(
                  subject,
                  score,
                  noteCtrl.text.isEmpty ? null : noteCtrl.text.trim(),
                  topicCtrl.text);
            } else if (score == null || score < 0 || score > 10) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Vui lòng nhập điểm từ 0 đến 10'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }
            Navigator.pop(ctx);
          },
          child: const Text('Lưu',
              style: TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
}

/// Hộp thoại "Ghi nhật ký học" của màn Tập trung.
void showAddLogDialog(
  BuildContext context, {
  required void Function(String subject, double hours, String? note) onAdd,
}) {
  final subjectCtrl = TextEditingController();
  final hoursCtrl = TextEditingController(text: '1.0');
  final noteCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border, width: 2),
      ),
      title: const Text('Ghi nhật ký học',
          style: TextStyle(fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: subjectCtrl,
              decoration: const InputDecoration(hintText: 'Môn học'),
              autofocus: true),
          const SizedBox(height: 8),
          TextField(
              controller: hoursCtrl,
              decoration: const InputDecoration(hintText: 'Số giờ'),
              keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          TextField(
              controller: noteCtrl,
              decoration:
                  const InputDecoration(hintText: 'Ghi chú (tùy chọn)')),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: TextStyle(color: AppColors.textMuted))),
        TextButton(
          onPressed: () {
            if (subjectCtrl.text.isNotEmpty) {
              onAdd(
                  subjectCtrl.text.trim(),
                  double.tryParse(hoursCtrl.text) ?? 1.0,
                  noteCtrl.text.isEmpty ? null : noteCtrl.text);
            }
            Navigator.pop(ctx);
          },
          child: const Text('Lưu',
              style: TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
}
