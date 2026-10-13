import 'package:flutter/material.dart';

import '../../../../core/ai/ai_copilot_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/study_models.dart';

/// Phản hồi gom lại từ các điều khiển trong sheet, để hàm lưu không phải giữ
/// tham chiếu tới `StatefulBuilder`.
class SessionFeedback {
  final int mood;
  final int focus;
  final int difficulty;
  final int understanding;
  final int effectiveness;
  final String note;

  const SessionFeedback({
    required this.mood,
    required this.focus,
    required this.difficulty,
    required this.understanding,
    required this.effectiveness,
    required this.note,
  });
}

/// Năm mức đánh giá phiên học, chọn bằng 1 chạm (FE-3.3).
class _QuickRating {
  final String emoji;
  final String label;
  final int value;
  final int mood;
  final int focus;
  final int difficulty;
  final int understanding;
  final int effectiveness;

  /// Đã nắm được kiến thức hay còn cần củng cố — quyết định có gợi ý "Ôn lại
  /// ngày mai" hay không.
  final bool understood;

  const _QuickRating({
    required this.emoji,
    required this.label,
    required this.value,
    required this.mood,
    required this.focus,
    required this.difficulty,
    required this.understanding,
    required this.effectiveness,
    required this.understood,
  });
}

/// Một mức đánh giá 1 chạm (FE-3.3).
///
/// Emoji là thứ người dùng thật sự bấm; các thang đánh giá chi tiết suy ra từ
/// đó theo một quy tắc cố định thay vì để người dùng điền 5 dòng — nếu
/// không có quy tắc, số phản hồi sẽ là dữ liệu bịa.
const List<_QuickRating> _quickRatings = [
  _QuickRating(
    emoji: '😫',
    label: 'Khó',
    value: 1,
    mood: 1,
    focus: 2,
    difficulty: 5,
    understanding: 1,
    effectiveness: 2,
    understood: false,
  ),
  _QuickRating(
    emoji: '😐',
    label: 'Tạm',
    value: 2,
    mood: 2,
    focus: 3,
    difficulty: 4,
    understanding: 2,
    effectiveness: 2,
    understood: false,
  ),
  _QuickRating(
    emoji: '🙂',
    label: 'Ổn',
    value: 3,
    mood: 3,
    focus: 3,
    difficulty: 3,
    understanding: 3,
    effectiveness: 3,
    understood: true,
  ),
  _QuickRating(
    emoji: '😄',
    label: 'Tốt',
    value: 4,
    mood: 4,
    focus: 4,
    difficulty: 3,
    understanding: 4,
    effectiveness: 4,
    understood: true,
  ),
  _QuickRating(
    emoji: '🔥',
    label: 'Chất',
    value: 5,
    mood: 5,
    focus: 5,
    difficulty: 2,
    understanding: 5,
    effectiveness: 5,
    understood: true,
  ),
];

/// Thang đánh giá chi tiết 1–5 dùng trong chế độ "Thêm đánh giá chi tiết".
Widget _reflectionScale(
    String label, int value, ValueChanged<int> onChanged) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(
            width: 112,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w700))),
        ...List.generate(
          5,
          (index) {
            final score = index + 1;
            final selected = score <= value;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(score),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    selected ? Icons.circle_rounded : Icons.circle_outlined,
                    color:
                        selected ? AppColors.primary : AppColors.borderStrong,
                    size: 22,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

/// Sheet "Phiên học thế nào?" hiển thị sau khi kết thúc một phiên focus.
///
/// Toàn bộ giao diện + đánh giá 1 chạm nằm ở đây; màn Tập trung chỉ truyền
/// vào các callback hành động ([onSave], [onCompleteAndGo], [onScheduleReview],
/// [onQuickNote]) và cờ [hasSelectedTask] để quyết định lối tắt "xong việc này".
Future<void> showAiPostFocusSheet({
  required BuildContext context,
  required StudySession session,
  required bool hasSelectedTask,
  required Future<void> Function(
          BuildContext sheetContext, StudySession session, SessionFeedback feedback)
      onSave,
  required Future<void> Function(
          BuildContext sheetContext, StudySession session, SessionFeedback feedback)
      onCompleteAndGo,
  required Future<void> Function(String subject) onScheduleReview,
  required void Function(String subject, {String? sessionId}) onQuickNote,
  required VoidCallback onTasksChanged,
}) async {
  var understandingLevel = 1; // 1: Hiểu tốt, 0: Cần củng cố
  bool showDetailed = false;
  // Đánh giá 1 chạm (FE-3.3): 5 emoji → 5 mức. Chạm một lần là đủ để lưu,
  // không bắt người dùng chờ điền thang chi tiết 5 dòng.
  var quickRating = 0;
  var mood = 4;
  var focus = 4;
  var difficulty = 3;
  var understanding = 4;
  var effectiveness = 4;
  final noteController = TextEditingController();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cardWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 18, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.greenSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xuất sắc! Xong phiên ${session.actualMinutes}p',
                            style: const TextStyle(
                                fontSize: 16.5, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Môn ${session.subject} • +25 EXP Mascot',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textMuted, size: 20),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Phiên học thế nào? Chạm 1 emoji là xong',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final option in _quickRatings)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: option == _quickRatings.last ? 0 : 6),
                          child: GestureDetector(
                            key: ValueKey('quick-rating-${option.value}'),
                            onTap: () => setSheetState(() {
                              quickRating = option.value;
                              mood = option.mood;
                              focus = option.focus;
                              difficulty = option.difficulty;
                              understanding = option.understanding;
                              effectiveness = option.effectiveness;
                              understandingLevel = option.understood ? 1 : 0;
                            }),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: quickRating == option.value
                                    ? AppColors.primary
                                        .withValues(alpha: 0.15)
                                    : AppColors.cardLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: quickRating == option.value
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(option.emoji,
                                      style: const TextStyle(fontSize: 22)),
                                  const SizedBox(height: 2),
                                  Text(option.label,
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight:
                                              quickRating == option.value
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                          color: quickRating == option.value
                                              ? AppColors.primary
                                              : AppColors.textMuted)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Bạn nắm kiến thức phiên này thế nào?',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSheetState(() {
                          understandingLevel = 1;
                          understanding = 4;
                          effectiveness = 4;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: understandingLevel == 1
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : AppColors.cardLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: understandingLevel == 1
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('👍',
                                  style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Hiểu tốt',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: understandingLevel == 1
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: understandingLevel == 1
                                          ? AppColors.primary
                                          : AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSheetState(() {
                          understandingLevel = 0;
                          understanding = 2;
                          effectiveness = 3;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: understandingLevel == 0
                                ? AppColors.orange.withValues(alpha: 0.15)
                                : AppColors.cardLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: understandingLevel == 0
                                  ? AppColors.orange
                                  : AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🤔',
                                  style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Cần củng cố',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: understandingLevel == 0
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: understandingLevel == 0
                                          ? AppColors.orange
                                          : AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.purpleSoft.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.purple.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.bolt_rounded,
                              color: AppColors.purple, size: 16),
                          SizedBox(width: 6),
                          Text('Liên kết AI thông minh:',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.purple)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.quiz_rounded,
                                size: 15, color: AppColors.purple),
                            label: const Text('🧠 Test nhanh 1 câu AI'),
                            backgroundColor: Colors.white,
                            side: BorderSide(
                                color:
                                    AppColors.purple.withValues(alpha: 0.4)),
                            labelStyle: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.purple),
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              final sub = session.subject.isEmpty ||
                                      session.subject == 'Pomodoro'
                                  ? 'Toán'
                                  : session.subject;
                              AiCopilotService.executeAction(
                                context,
                                AiCopilotAction(
                                  type: AiActionType.takeQuiz,
                                  label: 'Kiểm tra nhanh',
                                  icon: Icons.quiz_rounded,
                                  payload: {
                                    'subject': sub,
                                    'topic': 'Củng cố kiến thức môn $sub',
                                    'onTasksChanged': onTasksChanged,
                                  },
                                ),
                              );
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.sticky_note_2_rounded,
                                size: 15, color: AppColors.blue),
                            label: const Text('📝 Ghi chú nhanh'),
                            backgroundColor: Colors.white,
                            side: BorderSide(
                                color: AppColors.blue.withValues(alpha: 0.4)),
                            labelStyle: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.blue),
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              onQuickNote(session.subject,
                                  sessionId: session.id);
                            },
                          ),
                          if (understandingLevel == 0)
                            ActionChip(
                              avatar: const Icon(Icons.calendar_today_rounded,
                                  size: 15, color: AppColors.orange),
                              label: const Text('📅 Ôn lại ngày mai'),
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                  color:
                                      AppColors.orange.withValues(alpha: 0.4)),
                              labelStyle: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.orange),
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                onScheduleReview(session.subject);
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      onPressed: () =>
                          setSheetState(() => showDetailed = !showDetailed),
                      child: Text(
                        showDetailed
                            ? 'Thu gọn đánh giá'
                            : 'Thêm đánh giá chi tiết ▾',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Bỏ qua',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                    ),
                  ],
                ),
                if (showDetailed) ...[
                  _reflectionScale('Tâm trạng', mood,
                      (value) => setSheetState(() => mood = value)),
                  _reflectionScale('Tập trung', focus,
                      (value) => setSheetState(() => focus = value)),
                  _reflectionScale('Độ khó', difficulty,
                      (value) => setSheetState(() => difficulty = value)),
                  _reflectionScale('Mức độ hiểu', understanding,
                      (value) => setSheetState(() => understanding = value)),
                  _reflectionScale('Hiệu quả', effectiveness,
                      (value) => setSheetState(() => effectiveness = value)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        hintText: 'Ghi chú thêm (không bắt buộc)'),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const ValueKey('save-session-feedback'),
                    onPressed: () => onSave(
                      sheetContext,
                      session,
                      SessionFeedback(
                        mood: mood,
                        focus: focus,
                        difficulty: difficulty,
                        understanding: understanding,
                        effectiveness: effectiveness,
                        note: noteController.text,
                      ),
                    ),
                    child: Text(quickRating > 0
                        ? 'Lưu đánh giá & Hoàn tất'
                        : 'Lưu phản hồi & Hoàn tất'),
                  ),
                ),
                // Đường 1 chạm: xong việc thì đánh dấu nhiệm vụ hoàn thành
                // và về thẳng màn Hôm nay — đúng tinh thần "xong việc này,
                // sang việc tiếp theo" (FE-3.3).
                if (hasSelectedTask) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const ValueKey('complete-task-and-go-today'),
                      onPressed: () => onCompleteAndGo(
                        sheetContext,
                        session,
                        SessionFeedback(
                          mood: mood,
                          focus: focus,
                          difficulty: difficulty,
                          understanding: understanding,
                          effectiveness: effectiveness,
                          note: noteController.text,
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text(
                        'Xong việc này — về Hôm nay',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  ).whenComplete(noteController.dispose);
}
