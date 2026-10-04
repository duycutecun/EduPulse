import 'package:flutter/material.dart';
import '../../../../core/utils/feedback_service.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/ai/ai_copilot_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_date.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/models/exam_model.dart';
import '../../domain/exam_repository.dart';
import '../../../../core/constants/subject_catalog.dart';
import '../widgets/subject_targets_editor.dart';

class ExamsScreen extends StatefulWidget {
  final Function(ExamModel) onSetPrimary;
  final Function(ExamModel) onAddExam;
  final Function(ExamModel) onUpdateExam;
  final Function(String) onDeleteExam;

  const ExamsScreen({
    super.key,
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

  /// Xoá kỳ thi nhưng **luôn có lối quay lại** (đối xứng với Task).
  ///
  /// Kỳ thi là dữ liệu lớn hơn một nhiệm vụ: xoá nó làm các nhiệm vụ đã gắn
  /// `examId` mất ngữ cảnh. Người học bấm nhầm là chuyện thường, nên không
  /// được để họ phải tự nhận lỗi rồi gõ tay tạo lại từ đầu.
  Future<void> _deleteWithUndo(ExamModel exam) async {
    widget.onDeleteExam(exam.id);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('Đã xoá "${exam.name}"'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.red,
      action: SnackBarAction(
        label: 'Hoàn tác',
        textColor: Colors.white,
        onPressed: () {
          // Khôi phục đúng bản ghi đã xoá — không dựng lại từ cây.
          widget.onUpdateExam(exam);
          FeedbackService.medium();
        },
      ),
    ));
  }

  @override
  void initState() {
    super.initState();
    // Màn này từng nhận `exams` là một ảnh chụp danh sách lúc mở. Hệ quả:
    // lưu xong một kỳ thi, repository đã có dữ liệu mới nhưng màn vẫn hiện
    // danh sách cũ — người dùng phải đóng app mở lại mới thấy. Nay đọc SỐNG
    // từ repository và tự vẽ lại mỗi khi `revision` tăng.
    ExamRepository.instance.revision.addListener(_onExamsChanged);
  }

  @override
  void dispose() {
    ExamRepository.instance.revision.removeListener(_onExamsChanged);
    super.dispose();
  }

  void _onExamsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  static const _availableEmojis = [
    '📚',
    '📝',
    '🎓',
    '🏆',
    '🎯',
    '📊',
    '🧮',
    '🔬',
    '🧪',
    '📐',
    '📏',
    '✏️',
    '🖊️',
    '📖',
    '🎒',
    '🏫',
    '⭐',
    '🔥',
    '💪',
    '🧠',
    '👨‍🎓',
    '👩‍🎓',
    '🥇',
    '🎖️',
  ];

  @override
  Widget build(BuildContext context) {
    final myExams = ExamRepository.instance.getAll();
    final filteredExams = _selectedFilter == 0
        ? myExams
        : myExams.where((e) => e.daysLeft < 90).toList();

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
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Chọn kỳ thi để ghim lên đồng hồ đếm ngược',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showAddCustomDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                            color: AppColors.primaryDark,
                            blurRadius: 0,
                            offset: Offset(0, 3)),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('Thêm',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (myExams.isNotEmpty) ...[
            const SizedBox(height: 14),
            Builder(builder: (context) {
              final primary = myExams.firstWhere(
                (e) => e.id == ExamRepository.instance.primaryExamId,
                orElse: () => myExams.first,
              );
              final target = primary.targetScore ?? 8.0;
              final current = primary.currentScore ?? 6.0;
              final diff = (target - current).clamp(0.0, 10.0);
              // Tư vấn theo dữ liệu thật (môn yếu nhất từ điểm thi thử) thay
              // vì hardcode 'Toán' — mọi phần của app cùng nói một thứ ngữ.
              final weak = AiCopilotService.weakestSubject();
              final weakSubject = weak?.$1 ?? 'Tổng hợp';
              final weakScore = weak?.$2;

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.purpleSoft.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.purple.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            size: 16, color: AppColors.purple),
                        const SizedBox(width: 8),
                        // Tên kỳ thi có thể rất dài → phần này phải co được.
                        Expanded(
                          child: Text(
                            'AI Chiến lược: ${primary.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.purple,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Còn ${primary.daysLeft} ngày',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hiện tại: ${current.toStringAsFixed(1)}đ ➔ Mục tiêu: ${target.toStringAsFixed(1)}đ (${diff > 0 ? "+${diff.toStringAsFixed(1)}đ" : "Đạt mục tiêu"}). '
                      'Còn ${primary.daysLeft} ngày — ưu tiên ${weakScore != null ? 'môn $weakSubject (TB ${weakScore.toStringAsFixed(1)}đ, đang thấp nhất)' : 'duy trì nhịp 3 phiên Focus/tuần'} và làm bài thi thử định kỳ.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Hai nút hành động: trên màn hẹp phải xuống hàng thay vì
                    // tràn ngang. `Wrap` tự xuống hàng, không cần tính trước độ
                    // rộng — an toàn cả khi cỡ chữ hệ thống tăng.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        InkWell(
                          onTap: () {
                            AiCopilotService.executeAction(
                              context,
                              AiCopilotAction(
                                type: AiActionType.startFocus,
                                label: 'Focus cho ${primary.name}',
                                icon: Icons.play_arrow_rounded,
                                payload: {
                                  'subject': weakSubject,
                                  'minutes': 25,
                                },
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.purple,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_arrow_rounded,
                                    size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Bắt đầu Focus',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            AiCopilotService.executeAction(
                              context,
                              AiCopilotAction(
                                type: AiActionType.takeQuiz,
                                label: 'Luyện 5 câu test',
                                icon: Icons.quiz_rounded,
                                payload: {
                                  'subject': weakSubject,
                                  'topic': 'Trọng tâm ${primary.name}',
                                },
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.cardWhite,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color:
                                      AppColors.purple.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.quiz_rounded,
                                    size: 14, color: AppColors.purple),
                                SizedBox(width: 4),
                                Text(
                                  'Luyện 5 câu test',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.purple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
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
                _filterTab(1,
                    'Sắp thi (${myExams.where((e) => e.daysLeft < 90).length})'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (myExams.isNotEmpty)
            Column(
              children: [
                for (final exam in filteredExams) _buildExamCard(exam),
              ],
            )
          else
            EmptyStateView(
              icon: Icons.flag_outlined,
              title: 'Chưa có kỳ thi nào',
              description:
                  'Tạo kỳ thi mục tiêu để EduPulse xếp kế hoạch ôn cho bạn.',
              actionLabel: 'Thêm kỳ thi',
              onAction: _showAddCustomDialog,
            ),
        ],
      ),
    );
  }

  Widget _filterTab(int index, String label) {
    final active = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
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
    final isPrimary = exam.id == ExamRepository.instance.primaryExamId;
    final days = exam.daysLeft;
    final urgencyColor = days < 30
        ? AppColors.red
        : days < 90
            ? AppColors.orange
            : AppColors.primary;

    return Dismissible(
      key: Key(exam.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async => await _confirmDelete(exam.name),
      onDismissed: (_) => _deleteWithUndo(exam),
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
        onTap: () {
          FeedbackService.selection();
          widget.onSetPrimary(exam);
        },
        onLongPress: () => _showEditDialog(exam),
        child: GlassCard(
          padding: const EdgeInsets.all(18),
          borderColor: isPrimary ? AppColors.primary : AppColors.border,
          borderWidth: isPrimary ? 3 : 2,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                    child:
                        Text(exam.emoji, style: const TextStyle(fontSize: 24))),
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
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary),
                          ),
                        ),
                        if (isPrimary)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ĐANG CHỌN',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        // Ngày là phần co được: tên kỳ thi và chip “Còn N ngày”
                        // phải giữ nguyên độ dài. Không bọc Flexible ở đây thì một
                        // ngày dài (hoặc cỡ chữ lớn) làm cả hàng tràn ra ngoài thẻ.
                        Flexible(
                          child: Text(
                            AppDate.formatDate(exam.dateTime),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: urgencyColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            exam.isPast ? 'Đã qua' : 'Còn $days ngày',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    if (exam.targetScore != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        exam.currentScore == null
                            ? 'Mục tiêu: ${exam.targetScore!.toStringAsFixed(1)} điểm'
                            : '${exam.currentScore!.toStringAsFixed(1)} → ${exam.targetScore!.toStringAsFixed(1)} điểm',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blueDark),
                      ),
                    ],
                    if (exam.subjectTargets.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      SubjectTargetsChips(targets: exam.subjectTargets),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCustomDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final currentScoreCtrl = TextEditingController();
    final targetScoreCtrl = TextEditingController();
    var subjectTargets = <String, double>{};
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
          title: const Text('Thêm kỳ thi mới',
              style: TextStyle(fontWeight: FontWeight.w800)),
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
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 2),
                    ),
                    child: Center(
                        child: Text(selectedEmoji,
                            style: const TextStyle(fontSize: 32))),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Nhấn để chọn biểu tượng',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      hintText: 'Tên kỳ thi (VD: Thi thử Toán)'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration:
                      const InputDecoration(hintText: 'Mục tiêu / Ghi chú'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: currentScoreCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(hintText: 'Điểm hiện tại'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: targetScoreCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(hintText: 'Điểm mục tiêu'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SubjectTargetsEditor(
                  initial: subjectTargets,
                  onChanged: (map) => subjectTargets = map,
                ),
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
                            colorScheme: Theme.of(context)
                                .colorScheme
                                .copyWith(primary: AppColors.primary),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        // Expanded thay cho Spacer: chữ ngày co lại được khi
                        // hẹp/cỡ chữ lớn, còn icon lịch luôn giữ sát mép phải.
                        Expanded(
                          child: Text(
                            'Ngày thi: ${AppDate.formatDate(selectedDate)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.edit_calendar_rounded,
                            size: 18, color: AppColors.textMuted),
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
                    currentScore: double.tryParse(
                        currentScoreCtrl.text.trim().replaceAll(',', '.')),
                    targetScore: double.tryParse(
                        targetScoreCtrl.text.trim().replaceAll(',', '.')),
                    subjectTargets: subjectTargets,
                    subjects: subjectTargets.keys
                        .map(AppSubjects.displayName)
                        .toList(),
                  ));
                }
                Navigator.pop(ctx);
              },
              child: const Text('Thêm',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(ExamModel exam) {
    final nameCtrl = TextEditingController(text: exam.name);
    final descCtrl = TextEditingController(text: exam.description ?? '');
    final currentScoreCtrl =
        TextEditingController(text: exam.currentScore?.toString() ?? '');
    final targetScoreCtrl =
        TextEditingController(text: exam.targetScore?.toString() ?? '');
    var subjectTargets = Map<String, double>.from(exam.subjectTargets);
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
          title: const Text('Chỉnh sửa kỳ thi',
              style: TextStyle(fontWeight: FontWeight.w800)),
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
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 2),
                    ),
                    child: Center(
                        child: Text(selectedEmoji,
                            style: const TextStyle(fontSize: 32))),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Nhấn để thay đổi biểu tượng',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(hintText: 'Tên kỳ thi'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration:
                      const InputDecoration(hintText: 'Mục tiêu / Ghi chú'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: currentScoreCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(hintText: 'Điểm hiện tại'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: targetScoreCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(hintText: 'Điểm mục tiêu'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SubjectTargetsEditor(
                  initial: subjectTargets,
                  onChanged: (map) => subjectTargets = map,
                ),
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
                            colorScheme: Theme.of(context)
                                .colorScheme
                                .copyWith(primary: AppColors.primary),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        // Expanded thay cho Spacer: chữ ngày co lại được khi
                        // hẹp/cỡ chữ lớn, còn icon lịch luôn giữ sát mép phải.
                        Expanded(
                          child: Text(
                            'Ngày thi: ${AppDate.formatDate(selectedDate)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.edit_calendar_rounded,
                            size: 18, color: AppColors.textMuted),
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
                    currentScore: double.tryParse(
                        currentScoreCtrl.text.trim().replaceAll(',', '.')),
                    targetScore: double.tryParse(
                        targetScoreCtrl.text.trim().replaceAll(',', '.')),
                    subjectTargets: subjectTargets,
                    subjects: subjectTargets.keys
                        .map(AppSubjects.displayName)
                        .toList(),
                  ));
                }
                Navigator.pop(ctx);
              },
              child: const Text('Lưu',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w800)),
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
              child: Text('Chọn biểu tượng',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
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
                        child: Text(_availableEmojis[i],
                            style: const TextStyle(fontSize: 28)),
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
        title: const Text('Xóa kỳ thi?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Xóa "$name" khỏi danh sách theo dõi?'),
        actions: [
          TextButton(
            onPressed: () {
              result = false;
              Navigator.pop(ctx);
            },
            child: Text('Hủy', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              result = true;
              Navigator.pop(ctx);
            },
            child: const Text('Xóa',
                style: TextStyle(
                    color: AppColors.red, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    return result;
  }
}
