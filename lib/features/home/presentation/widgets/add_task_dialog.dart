import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/subject_catalog.dart';
import '../../../../core/utils/feedback_service.dart';
import '../../../exams/domain/models/exam_model.dart';

/// Hộp thoại "Thêm nhiệm vụ" của Home. Tách riêng để màn Home chỉ còn việc mở
/// hộp thoại và nhận kết quả qua [onAdd].
class AddTaskDialog extends StatefulWidget {
  const AddTaskDialog({
    super.key,
    required this.onAdd,
    required this.exams,
    this.primaryExamId,
  });

  final void Function(
      String title, String subject, String priority, int minutes,
      {String? topic,
      DateTime? deadline,
      String? note,
      String? goalId,
      List<String> subtasks,
      String? recurrence}) onAdd;
  final List<ExamModel> exams;
  final String? primaryExamId;

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _titleCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _subtasksCtrl = TextEditingController();
  String _subject = AppSubjects.toan.name;
  String _priority = 'medium';
  int _minutes = 45;
  DateTime? _deadline;
  String? _goalId;
  String? _recurrence;
  final _durations = [15, 30, 45, 60, 90];
  final Map<String, String> _priorities = const {
    'high': '🔥 Quan trọng',
    'medium': '⭐ Vừa',
    'low': '🌱 Nhẹ',
  };

  @override
  void initState() {
    super.initState();
    _goalId = widget.primaryExamId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _topicCtrl.dispose();
    _noteCtrl.dispose();
    _subtasksCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      FeedbackService.vibrate();
      return;
    }
    widget.onAdd(
      title,
      _subject,
      _priority,
      _minutes,
      topic: _topicCtrl.text.trim().isEmpty ? null : _topicCtrl.text.trim(),
      deadline: _deadline,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      goalId: _goalId,
      subtasks: _subtasksCtrl.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      recurrence: _recurrence,
    );
    Navigator.pop(context);
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      helpText: 'Chọn hạn hoàn thành',
    );
    if (selected != null && mounted) setState(() => _deadline = selected);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.iosSeparator, width: 2),
      ),
      title: const Text('Thêm nhiệm vụ',
          style: TextStyle(fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                hintText: 'Tên nhiệm vụ (VD: Giải 1 đề Toán)',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _topicCtrl,
              decoration: const InputDecoration(
                hintText: 'Chủ đề (không bắt buộc)',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Chọn môn:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: AppSubjects.all.map((subject) {
                final sel = _subject == subject.name;
                final color = subject.color;
                return GestureDetector(
                  onTap: () => setState(() => _subject = subject.name),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? color : AppColors.iosBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? color : AppColors.iosSeparator,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      subject.plainName,
                      style: TextStyle(
                        fontSize: 12,
                        color: sel ? Colors.white : AppColors.iosTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDeadline,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(_deadline == null
                  ? 'Thêm hạn hoàn thành'
                  : 'Hạn: ${_deadline!.day.toString().padLeft(2, '0')}/${_deadline!.month.toString().padLeft(2, '0')}/${_deadline!.year}'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ghi chú (không bắt buộc)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _subtasksCtrl,
              decoration: const InputDecoration(
                hintText: 'Việc nhỏ (ngăn cách bằng dấu phẩy)',
              ),
            ),
            if (widget.exams.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _goalId,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Kỳ thi / Mục tiêu'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Chưa gắn mục tiêu'),
                  ),
                  ...widget.exams.map(
                    (exam) => DropdownMenuItem<String?>(
                      value: exam.id,
                      child: Text(exam.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _goalId = value),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _recurrence,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Lặp lại'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Không lặp lại')),
                DropdownMenuItem(value: 'daily', child: Text('Mỗi ngày')),
                DropdownMenuItem(value: 'weekly', child: Text('Mỗi tuần')),
              ],
              onChanged: (value) => setState(() => _recurrence = value),
            ),
            const SizedBox(height: 12),
            const Text('Thời gian:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _durations.map((dur) {
                final sel = _minutes == dur;
                return GestureDetector(
                  onTap: () => setState(() => _minutes = dur),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.iosInfo : AppColors.iosBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? AppColors.iosInfo : AppColors.iosSeparator,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '$dur phút',
                      style: TextStyle(
                        fontSize: 12,
                        color: sel ? Colors.white : AppColors.iosTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text('Mức ưu tiên:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _priorities.entries.map((e) {
                final sel = _priority == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _priority = e.key),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color:
                          sel ? AppColors.iosWarning : AppColors.iosBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            sel ? AppColors.iosWarning : AppColors.iosSeparator,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 12,
                        color: sel ? Colors.white : AppColors.iosTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Hủy', style: TextStyle(color: AppColors.iosTextMuted)),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Thêm',
              style: TextStyle(
                  color: AppColors.iosPrimary, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
