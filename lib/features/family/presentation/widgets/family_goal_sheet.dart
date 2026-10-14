import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/family/family_models.dart';
import '../../../../core/family/family_service.dart';

/// Đặt/bỏ mục tiêu ba mẹ giao cho một con.
///
/// Server là nguồn quyết định (kiểm tra liên kết, giới hạn giá trị); sheet này
/// chỉ soạn payload rồi báo kết quả qua callback. Kết quả gọi lại [onSaved]
/// để màn ba mẹ kéo lại danh sách + mục tiêu mới.
class FamilyGoalSheet {
  FamilyGoalSheet._();

  static Future<void> open(
    BuildContext context, {
    required String studentUserId,
    required String childName,
    required List<FamilyGoal> current,
    VoidCallback? onSaved,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
        ),
        child: _GoalEditor(
          studentUserId: studentUserId,
          childName: childName,
          current: current,
          onSaved: onSaved,
        ),
      ),
    );
  }
}

class _GoalEditor extends StatefulWidget {
  const _GoalEditor({
    required this.studentUserId,
    required this.childName,
    required this.current,
    this.onSaved,
  });

  final String studentUserId;
  final String childName;
  final List<FamilyGoal> current;
  final VoidCallback? onSaved;

  @override
  State<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<_GoalEditor> {
  String _metric = FamilyGoal.metricsOrder.first;
  final TextEditingController _targetCtrl = TextEditingController();
  bool _saving = false;

  FamilyGoal? get _existing {
    for (final g in widget.current) {
      if (g.metric == _metric) return g;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final existing = _existing;
    if (existing != null) {
      _targetCtrl.text = _prefill(existing);
    }
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }

  /// Giá trị khởi đầu trong ô nhập, theo từng loại mục tiêu.
  String _prefill(FamilyGoal g) {
    final t = g.target;
    if (t == t.roundToDouble()) return '${t.toInt()}';
    return '$t';
  }

  double? _parse() {
    final text = _targetCtrl.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  String? _validate(double target) {
    switch (_metric) {
      case 'streak':
        if (target < 1 || target > 365) return 'Chuỗi ngày từ 1 đến 365.';
      case 'mock_avg':
        if (target < 0 || target > 10) return 'Điểm từ 0 đến 10.';
      case 'readiness':
        if (target < 0 || target > 100) return 'Chỉ số từ 0 đến 100.';
      default:
        if (target < 1 || target > 100000)
          return 'Số phút trong khoảng hợp lệ.';
    }
    return null;
  }

  Future<void> _save() async {
    final value = _parse();
    if (value == null) {
      _snack('Nhập con số mục tiêu.', error: true);
      return;
    }
    final invalid = _validate(value);
    if (invalid != null) {
      _snack(invalid, error: true);
      return;
    }
    setState(() => _saving = true);
    final result =
        await FamilyService.setGoal(widget.studentUserId, _metric, value);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!result.ok) {
      _snack(result.message, error: true);
      return;
    }
    widget.onSaved?.call();
    Navigator.pop(context);
  }

  Future<void> _removeCurrent() async {
    final goal = _existing;
    if (goal == null) return;
    setState(() => _saving = true);
    final result =
        await FamilyService.removeGoal(widget.studentUserId, goal.metric);
    if (!mounted) return;
    if (!result.ok) {
      setState(() => _saving = false);
      _snack(result.message, error: true);
      return;
    }
    widget.onSaved?.call();
    Navigator.pop(context);
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.red : AppColors.primary,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final existing = _existing;
    final unit = switch (_metric) {
      'weekly_minutes' => 'phút/tuần',
      'streak' => 'ngày',
      'mock_avg' => 'điểm (0–10)',
      'readiness' => 'chỉ số (0–100)',
      _ => '',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mục tiêu cho con',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    'Đặt mục tiêu cùng ${widget.childName} — khi con chưa đạt, '
                    'bạn được nhắc để động viên thay vì quở.',
                    style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Đóng',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final metric in FamilyGoal.metricsOrder)
              ChoiceChip(
                key: Key('goal-metric-$metric'),
                label: Text(FamilyGoal.labelOf(metric),
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _metric == metric
                            ? Colors.white
                            : AppColors.textPrimary)),
                selected: _metric == metric,
                selectedColor: AppColors.primary,
                showCheckmark: false,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                        color: _metric == metric
                            ? AppColors.primary
                            : AppColors.border)),
                onSelected: (_) {
                  setState(() {
                    _metric = metric;
                    final g = _existing;
                    _targetCtrl.text = g == null ? '' : _prefill(g);
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          existing == null
              ? 'Chọn loại rồi nhập con số: $unit'
              : 'Đang đặt: ${FamilyGoal.labelOf(existing.metric)} '
                  '${existing.displayTarget} — nhập giá trị mới để đổi.',
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('goal-target-input'),
          controller: _targetCtrl,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: InputDecoration(
            labelText: 'Mục tiêu ($unit)',
            filled: true,
            fillColor: AppColors.bgPageSoft,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (existing != null) ...[
              TextButton(
                key: Key('goal-remove-${existing.metric}'),
                onPressed: _saving ? null : _removeCurrent,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.red,
                ),
                child: const Text('Bỏ mục tiêu này',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
            ],
            SizedBox(
              height: 46,
              child: ElevatedButton(
                key: const Key('goal-save-button'),
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Lưu mục tiêu',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13.5)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
