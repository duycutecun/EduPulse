import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../domain/models/exam_model.dart';
import '../../data/preset_exams.dart';

class ExamsScreen extends StatefulWidget {
  final List<ExamModel> exams;
  final String? primaryExamId;
  final Function(ExamModel) onSetPrimary;
  final Function(ExamModel) onAddExam;
  final Function(String) onDeleteExam;

  const ExamsScreen({
    super.key,
    required this.exams,
    required this.primaryExamId,
    required this.onSetPrimary,
    required this.onAddExam,
    required this.onDeleteExam,
  });

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  final _uuid = const Uuid();
  int _selectedFilter = 0; // 0: Tất cả, 1: Sắp thi, 2: Có sẵn

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myExams = widget.exams;
    final available = PresetExams.all
        .where((p) => !myExams.any((e) => e.id == p.id))
        .toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with Add button
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kỳ Thi Của Tôi',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chọn kỳ thi để ghim lên đồng hồ đếm ngược',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showAddCustomDialog(isDark),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.iosIndigo, AppColors.iosBlue],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.iosIndigo.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.plus, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Thêm',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Segmented Filter
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E28).withValues(alpha: 0.7)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                _filterTab(0, '🎯 Đã chọn (${myExams.length})', isDark),
                _filterTab(1, '🔥 Sắp thi', isDark),
                _filterTab(2, '📚 Thư viện (${available.length})', isDark),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Filter Content
          if (_selectedFilter == 0 || _selectedFilter == 1) ...[
            if (myExams.isNotEmpty) ...[
              ...myExams
                  .where((e) => _selectedFilter == 0 ? true : e.daysLeft < 90)
                  .map((e) => _buildLiquidExamCard(e, isDark)),
            ] else ...[
              _buildEmptyState('Chưa có kỳ thi nào', 'Hãy chọn kỳ thi có sẵn từ thư viện hoặc tự tạo mới!', isDark),
            ],
          ] else ...[
            if (available.isNotEmpty) ...[
              ...available.map((e) => _buildPresetCard(e, isDark)),
            ] else ...[
              _buildEmptyState('Đã thêm tất cả kỳ thi', 'Bạn đã thêm tất cả kỳ thi có sẵn vào danh sách!', isDark),
            ],
          ],
        ],
      ),
    );
  }

  Widget _filterTab(int index, String label, bool isDark) {
    final active = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? (isDark ? const Color(0xFF33314B) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              color: active
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiquidExamCard(ExamModel exam, bool isDark) {
    final isPrimary = exam.id == widget.primaryExamId;
    final days = exam.daysLeft;
    final urgencyColor = days < 30
        ? AppColors.iosRed
        : days < 90
            ? AppColors.iosOrange
            : AppColors.iosGreen;

    return Dismissible(
      key: Key(exam.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async => await _confirmDelete(exam.name),
      onDismissed: (_) => widget.onDeleteExam(exam.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.iosRed.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(CupertinoIcons.trash, color: AppColors.iosRed, size: 22),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: GlassCard(
          onTap: () => widget.onSetPrimary(exam),
          padding: const EdgeInsets.all(18),
          customColor: isPrimary
              ? AppColors.iosIndigo.withValues(alpha: isDark ? 0.22 : 0.12)
              : null,
          borderColor: isPrimary
              ? AppColors.iosIndigo.withValues(alpha: 0.6)
              : null,
          borderWidth: isPrimary ? 1.5 : 0.8,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (isPrimary ? AppColors.iosIndigo : AppColors.iosBlue).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(exam.emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            exam.name,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (isPrimary)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.iosIndigo, AppColors.iosBlue],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ĐANG CHỌN',
                              style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(CupertinoIcons.calendar, size: 13,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(exam.dateTime),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: urgencyColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            exam.isPast ? 'Đã qua' : 'Còn $days ngày',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: urgencyColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetCard(ExamModel exam, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: () => widget.onAddExam(exam),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Text(exam.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exam.name,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(exam.dateTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.iosBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(CupertinoIcons.plus, color: AppColors.iosBlue, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Text('🎯', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCustomDialog(bool isDark) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Thêm Kỳ Thi Mới'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              CupertinoTextField(
                controller: nameCtrl,
                placeholder: 'Tên kỳ thi (VD: Thi thử Toán)',
                autofocus: true,
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: descCtrl,
                placeholder: 'Mục tiêu / Ghi chú',
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                widget.onAddExam(ExamModel(
                  id: _uuid.v4(),
                  name: nameCtrl.text.trim(),
                  dateTime: selectedDate,
                  type: ExamType.custom,
                  description: descCtrl.text.isEmpty ? null : descCtrl.text,
                  emoji: '📝',
                ));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(String name) async {
    bool result = false;
    await showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Xóa kỳ thi?'),
        content: Text('Bạn có chắc muốn xóa "$name" khỏi danh sách theo dõi?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              result = false;
              Navigator.pop(ctx);
            },
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              result = true;
              Navigator.pop(ctx);
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    return result;
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}
