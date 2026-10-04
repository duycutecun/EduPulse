import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/subject_catalog.dart';

/// Ô nhập điểm mục tiêu theo môn cho một kỳ thi — đặc tả 5.13:
///
/// ```text
/// Mục tiêu
/// Toán     9.0
/// Lý       9.0
/// Hóa      9.0
/// ```
///
/// Ô trống nghĩa là môn đó chưa đặt mục tiêu — không ghi vào dữ liệu, để những
/// môn chưa học không tạo ra mục tiêu giả.
class SubjectTargetsEditor extends StatefulWidget {
  final Map<String, double> initial;
  final ValueChanged<Map<String, double>> onChanged;

  const SubjectTargetsEditor({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<SubjectTargetsEditor> createState() => _SubjectTargetsEditorState();
}

class _SubjectTargetsEditorState extends State<SubjectTargetsEditor> {
  late final Map<String, TextEditingController> _controllers = {
    for (final s in AppSubjects.all)
      s.plainName: TextEditingController(
        text: widget.initial[s.name]?.toString() ?? '',
      ),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit(String plainName) {
    final result = <String, double>{};
    for (final entry in _controllers.entries) {
      final value =
          double.tryParse(entry.value.text.trim().replaceAll(',', '.'));
      if (value == null) continue;
      final subject = AppSubjects.all.firstWhere(
        (s) => s.plainName == entry.key,
        orElse: () => AppSubjects.all.first,
      );
      result[subject.name] = value;
    }
    widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mục tiêu điểm theo môn',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in AppSubjects.all)
              SizedBox(
                width: 104,
                child: TextField(
                  key: ValueKey('subject-target-${s.plainName}'),
                  controller: _controllers[s.plainName],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _emit(s.plainName),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: s.plainName,
                    labelStyle: const TextStyle(fontSize: 11),
                    prefixIcon: Icon(s.icon, size: 15, color: s.color),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 30, minHeight: 30),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Hiển thị read-only điểm mục tiêu theo môn (Toán 9.0 · Lý 9.0).
class SubjectTargetsChips extends StatelessWidget {
  final Map<String, double> targets;

  const SubjectTargetsChips({super.key, required this.targets});

  @override
  Widget build(BuildContext context) {
    if (targets.isEmpty) return const SizedBox.shrink();
    final entries = targets.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in entries)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.blueSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${AppSubjects.displayName(e.key)} ${e.value.toStringAsFixed(1)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.blueDark,
              ),
            ),
          ),
      ],
    );
  }
}
