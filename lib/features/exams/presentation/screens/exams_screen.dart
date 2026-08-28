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
  final Function(ExamModel) onUpdateExam;
  final Function(String) onDeleteExam;

  const ExamsScreen({
    super.key,
    required this.exams,
    required this.primaryExamId,
    required this.onSetPrimary,
    required this.onAddExam,
    required this.onUpdateExam,
    required this.onDeleteExam,
  });

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  final _uuid = const Uuid();
  int _selectedFilter = 0;

  static const _availableEmojis = [
    '📚', '📝', '🎓', '🏆', '🎯', '📊', '🧮', '🔬',
    '🧪', '📐', '📏', '✏️', '🖊️', '📖', '🎒', '🏫',
    '⭐', '🔥', '💪', '🧠', '👨‍🎓', '👩‍🎓', '🥇', '🎖️',
  ];

  @override
  Widget build(BuildContext context) {
    final myExams = widget.exams;
    final available = PresetExams.all
        .where((p) => !myExams.any((e) => e.id == p.id))
        .toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Chọn kỳ thi để ghim lên đồng hồ đếm ngược',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showAddCustomDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: AppColors.greenDark, blurRadius: 0, offset: Offset(0, 3)),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('Thêm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Row(
              children: [
                _filterTab(0, 'Đã chọn (${myExams.length})'),
                _filterTab(1, 'Sắp thi'),
                _filterTab(2, 'Thư viện (${available.length})'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_selectedFilter == 0 || _selectedFilter == 1) ...[
            if (myExams.isNotEmpty)
              ...myExams
                  .where((e) => _selectedFilter == 0 ? true : e.daysLeft < 90)
                  .map((e) => _buildExamCard(e))
            else
              _buildEmptyState('Chưa có kỳ thi nào', 'Hãy chọn từ thư viện hoặc tạo mới!'),
          ] else ...[
            if (available.isNotEmpty)
              ...available.map((e) => _buildPresetCard(e))
            else
              _buildEmptyState('Đã thêm tất cả', 'Bạn đã thêm hết kỳ thi có sẵn!'),
          ],
        ],
      ),
    );
  }

  Widget _filterTab(int index, String label) {
    final active = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.green : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? Colors.white : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExamCard(ExamModel exam) {
    final isPrimary = exam.id == widget.primaryExamId;
    final days = exam.daysLeft;
    final urgencyColor = days < 30 ? AppColors.red : days < 90 ? AppColors.orange : AppColors.green;

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
          color: AppColors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.red, size: 22),
      ),
      child: GestureDetector(
        onTap: () => widget.onSetPrimary(exam),
        onLongPress: () => _showEditDialog(exam),
        child: GlassCard(
          padding: const EdgeInsets.all(18),
          borderColor: isPrimary ? AppColors.green : AppColors.border,
          borderWidth: isPrimary ? 3 : 2,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(exam.emoji, style: const TextStyle(fontSize: 24))),
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
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                        ),
                        if (isPrimary)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ĐANG CHỌN',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(exam.dateTime),
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: urgencyColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            exam.isPast ? 'Đã qua' : 'Còn $days ngày',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
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

  Widget _buildPresetCard(ExamModel exam) {
    return GestureDetector(
      onTap: () => widget.onAddExam(exam),
      child: GlassCard(
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(exam.dateTime),
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: AppColors.greenDark, blurRadius: 0, offset: Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Text('🎯', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  void _showAddCustomDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));
    String selectedEmoji = '📝';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border, width: 2),
          ),
          title: const Text('Thêm kỳ thi mới', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _showEmojiPicker(ctx, (emoji) {
                    setDialogState(() => selectedEmoji = emoji);
                  }),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.3), width: 2),
                    ),
                    child: Center(child: Text(selectedEmoji, style: const TextStyle(fontSize: 32))),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Nhấn để chọn biểu tượng', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(hintText: 'Tên kỳ thi (VD: Thi thử Toán)'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(hintText: 'Mục tiêu / Ghi chú'),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(primary: AppColors.green),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.green),
                        const SizedBox(width: 10),
                        Text(
                          'Ngày thi: ${_formatDate(selectedDate)}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const Spacer(),
                        Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Hủy', style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  widget.onAddExam(ExamModel(
                    id: _uuid.v4(),
                    name: nameCtrl.text.trim(),
                    dateTime: selectedDate,
                    type: ExamType.custom,
                    description: descCtrl.text.isEmpty ? null : descCtrl.text,
                    emoji: selectedEmoji,
                  ));
                }
                Navigator.pop(ctx);
              },
              child: const Text('Thêm', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(ExamModel exam) {
    final nameCtrl = TextEditingController(text: exam.name);
    final descCtrl = TextEditingController(text: exam.description ?? '');
    DateTime selectedDate = exam.dateTime;
    String selectedEmoji = exam.emoji;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border, width: 2),
          ),
          title: const Text('Chỉnh sửa kỳ thi', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _showEmojiPicker(ctx, (emoji) {
                    setDialogState(() => selectedEmoji = emoji);
                  }),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.3), width: 2),
                    ),
                    child: Center(child: Text(selectedEmoji, style: const TextStyle(fontSize: 32))),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Nhấn để thay đổi biểu tượng', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(hintText: 'Tên kỳ thi'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(hintText: 'Mục tiêu / Ghi chú'),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(primary: AppColors.green),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.green),
                        const SizedBox(width: 10),
                        Text(
                          'Ngày thi: ${_formatDate(selectedDate)}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const Spacer(),
                        Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Hủy', style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  widget.onUpdateExam(ExamModel(
                    id: exam.id,
                    name: nameCtrl.text.trim(),
                    dateTime: selectedDate,
                    type: exam.type,
                    description: descCtrl.text.isEmpty ? null : descCtrl.text,
                    emoji: selectedEmoji,
                  ));
                }
                Navigator.pop(ctx);
              },
              child: const Text('Lưu', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker(BuildContext context, Function(String) onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Text('Chọn biểu tượng', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            SizedBox(
              height: 200,
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _availableEmojis.length,
                itemBuilder: (ctx, i) {
                  return GestureDetector(
                    onTap: () {
                      onSelected(_availableEmojis[i]);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgPage,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: Center(
                        child: Text(_availableEmojis[i], style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(String name) async {
    bool result = false;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border, width: 2),
        ),
        title: const Text('Xóa kỳ thi?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Xóa "$name" khỏi danh sách theo dõi?'),
        actions: [
          TextButton(
            onPressed: () { result = false; Navigator.pop(ctx); },
            child: Text('Hủy', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () { result = true; Navigator.pop(ctx); },
            child: const Text('Xóa', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    return result;
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}
