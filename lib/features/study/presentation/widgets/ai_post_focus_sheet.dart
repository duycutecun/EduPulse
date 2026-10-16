import 'dart:async';

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

  /// Đặc tả 5.3 — "đã hoàn thành mục tiêu chưa?". Mặc định đã xong.
  final bool goalMet;

  /// Đặc tả 5.3 — "cần ôn lại / có trở ngại gì không?". Nhãn ngắn hoặc rỗng.
  final String blocker;

  const SessionFeedback({
    required this.mood,
    required this.focus,
    required this.difficulty,
    required this.understanding,
    required this.effectiveness,
    required this.note,
    this.goalMet = true,
    this.blocker = '',
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

  /// Mức hiểu kiến thức suy ra từ emoji: 0 = chưa hiểu, 1 = tạm ổn,
  /// 2 = tự tin. Quyết định có gợi ý "Ôn lại ngày mai" hay không (đặc tả 5.3).
  final int understandingLevel;

  const _QuickRating({
    required this.emoji,
    required this.label,
    required this.value,
    required this.mood,
    required this.focus,
    required this.difficulty,
    required this.understanding,
    required this.effectiveness,
    required this.understandingLevel,
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
    understandingLevel: 0,
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
    understandingLevel: 1,
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
    understandingLevel: 2,
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
    understandingLevel: 2,
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
    understandingLevel: 2,
  ),
];

/// Thang đánh giá chi tiết 1–5 dùng trong chế độ "Thêm đánh giá chi tiết".
Widget _reflectionScale(String label, int value, ValueChanged<int> onChanged) {
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
                    color: selected
                        ? AppColors.iosPrimary
                        : AppColors.iosSeparator,
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

/// Một lựa chọn "mức hiểu" trong 3 mức (đặc tả 5.3: chưa hiểu / tạm ổn / tự tin).
///
/// Tách thành hàm dùng chung để ba lựa chọn luôn cùng kích thước, cùng kiểu
/// viền/chữ — tránh ba khối code gần giống nhau dễ lệch nhau khi sửa.
Widget _understandingOption({
  required String emoji,
  required String label,
  required bool selected,
  required Color accent,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.15) : AppColors.iosFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? accent : AppColors.iosSeparator,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? accent : AppColors.iosTextPrimary,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Chip một lựa chọn (đã chọn = tô đậm) cho câu hỏi "cần ôn lại / trở ngại".
Widget _selectableChip({
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) {
  return ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    selectedColor: AppColors.iosPrimary.withValues(alpha: 0.15),
    side: BorderSide(
      color: selected ? AppColors.iosPrimary : AppColors.iosSeparator,
      width: 1.5,
    ),
    labelStyle: TextStyle(
      fontSize: 11.5,
      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      color: selected ? AppColors.iosPrimaryDark : AppColors.iosTextPrimary,
    ),
  );
}

/// Đếm 4 giây im lặng rồi báo về [onSilence] (V2 mục C.3).
///
/// Tách thành widget riêng chỉ để có `dispose`: `Timer` tạo trong thân sheet
/// vẫn treo khi sheet bị đóng bằng đường khác, và một timer treo trong test là
/// lỗi thật (Flutter báo "Pending timers" và đỏ cả test khác).
class _SilenceWatcher extends StatefulWidget {
  final VoidCallback onSilence;
  final Widget child;

  const _SilenceWatcher({required this.onSilence, required this.child});

  @override
  State<_SilenceWatcher> createState() => _SilenceWatcherState();
}

class _SilenceWatcherState extends State<_SilenceWatcher> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 4), widget.onSilence);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
  required Future<void> Function(BuildContext sheetContext,
          StudySession session, SessionFeedback feedback)
      onSave,
  required Future<void> Function(BuildContext sheetContext,
          StudySession session, SessionFeedback feedback)
      onCompleteAndGo,
  required Future<void> Function(String subject) onScheduleReview,
  required void Function(String subject, {String? sessionId}) onQuickNote,
  required VoidCallback onTasksChanged,
  VoidCallback? onSplitTask,
}) async {
  // Đánh giá 1 chạm (FE-3.3): 5 emoji → 5 mức. Chạm một lần là đủ để lưu,
  // không bắt người dùng chờ điền thang chi tiết 5 dòng.
  // Mức hiểu mặc định "tự tin" (2) khớp với understanding mặc định 4.
  var quickRating = 0;
  var understandingLevel = 2; // 0 chưa hiểu · 1 tạm ổn · 2 tự tin (đặc tả 5.3)
  bool showDetailed = false;
  var mood = 4;
  var focus = 4;
  var difficulty = 3;
  var understanding = 4;
  var effectiveness = 4;
  // Đặc tả 5.3: hai câu hỏi bắt buộc ngoài mức hiểu — mục tiêu đã xong chưa và
  // có trở ngại gì không. Mặc định "đã xong / không trở ngại" để học sinh bận
  // vẫn lưu được trong 1 chạm.
  var goalMet = true;
  var blocker = '';
  final noteController = TextEditingController();

  // V2 (mục C.3): "không bấm 4 giây → ghi 'chưa rõ' rồi biến". Đây là chống
  // phiền, không phải chống thất lạc dữ liệu: phiên học đã được ghi trước khi
  // sheet mở, còn phản hồi cảm nhận thì im lặng nghĩa là "chưa rõ".
  var silenceBroken = false;
  BuildContext? sheetCtx;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.iosCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      sheetCtx = sheetContext;
      void saveSilence() {
        final ctx = sheetCtx;
        if (silenceBroken || ctx == null || !ctx.mounted) return;
        onSave(
          ctx,
          session,
          SessionFeedback(
            mood: mood,
            focus: focus,
            difficulty: difficulty,
            understanding: understanding,
            effectiveness: effectiveness,
            note: 'chưa rõ',
            goalMet: goalMet,
            blocker: blocker,
          ),
        );
      }

      return StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          // Đồng hồ im lặng nằm trong một widget có `dispose` riêng: hẹn giờ bằng
          // biến cục bộ sẽ để lại timer treo khi sheet bị đóng vì lý do khác
          // (người dùng vuốt xuống, màn bị thay) — và timer treo là lỗi test thật,
          // không phải chuyện hình thức.
          child: _SilenceWatcher(
            onSilence: saveSilence,
            child: Listener(
              // Bất kỳ cú chạm nào trong sheet cũng đã phá im lặng: người học đang
              // trả lời, không được tự lưu thay họ.
              onPointerDown: (_) => silenceBroken = true,
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
                              color: AppColors.iosSuccessSoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.auto_awesome_rounded,
                                color: AppColors.iosPrimary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Xuất sắc! Xong phiên ${session.actualMinutes}p',
                                  style: const TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  'Môn ${session.subject} • +25 EXP Mascot',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.iosTextSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: AppColors.iosTextMuted, size: 20),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text('Phiên học thế nào? Chạm 1 emoji là xong',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.iosTextPrimary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final option in _quickRatings)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                    right:
                                        option == _quickRatings.last ? 0 : 6),
                                child: GestureDetector(
                                  key: ValueKey('quick-rating-${option.value}'),
                                  onTap: () => setSheetState(() {
                                    quickRating = option.value;
                                    mood = option.mood;
                                    focus = option.focus;
                                    difficulty = option.difficulty;
                                    understanding = option.understanding;
                                    effectiveness = option.effectiveness;
                                    understandingLevel =
                                        option.understandingLevel;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: quickRating == option.value
                                          ? AppColors.iosPrimary
                                              .withValues(alpha: 0.15)
                                          : AppColors.iosFill,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: quickRating == option.value
                                            ? AppColors.iosPrimary
                                            : AppColors.iosSeparator,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(option.emoji,
                                            style:
                                                const TextStyle(fontSize: 22)),
                                        const SizedBox(height: 2),
                                        Text(option.label,
                                            style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight:
                                                    quickRating == option.value
                                                        ? FontWeight.w800
                                                        : FontWeight.w600,
                                                color: quickRating ==
                                                        option.value
                                                    ? AppColors.iosPrimary
                                                    : AppColors.iosTextMuted)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // V2 mục C.3: **một câu, hai nút to** — "Hiểu chưa?" — thay cho
                      // ba bậc chưa hiểu / tạm ổn / tự tin. Sau một phiên 10 phút,
                      // người học trả lời được câu này; ba bậc là dữ liệu khai chi
                      // tiết hơn thứ họ muốn bấm, và người ta bỏ qua cả ba.
                      const Text('Hiểu chưa?',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.iosTextPrimary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: KeyedSubtree(
                              key: const ValueKey('understanding-no'),
                              child: _understandingOption(
                                emoji: '😕',
                                label: 'Chưa hiểu',
                                selected: understandingLevel == 0,
                                accent: AppColors.iosError,
                                onTap: () => setSheetState(() {
                                  understandingLevel = 0;
                                  understanding = 1;
                                  effectiveness = 2;
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: KeyedSubtree(
                              key: const ValueKey('understanding-yes'),
                              child: _understandingOption(
                                emoji: '🤩',
                                label: 'Hiểu rồi',
                                selected: understandingLevel == 2,
                                accent: AppColors.iosPrimary,
                                onTap: () => setSheetState(() {
                                  understandingLevel = 2;
                                  understanding = 4;
                                  effectiveness = 4;
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Ba chip **chỉ** hiện khi "Chưa hiểu" (V2): lý do ngắn để app
                      // biết nên đề xuất chia nhỏ hay đổi lịch, thay vì hỏi một câu
                      // mở mà người học phải gõ.
                      if (understandingLevel == 0) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _selectableChip(
                              label: 'Quá khó',
                              selected: blocker == 'Quá khó',
                              onTap: () => setSheetState(() {
                                blocker = 'Quá khó';
                                goalMet = false;
                              }),
                            ),
                            _selectableChip(
                              label: 'Hết giờ',
                              selected: blocker == 'Hết giờ',
                              onTap: () => setSheetState(() {
                                blocker = 'Hết giờ';
                                goalMet = false;
                              }),
                            ),
                            _selectableChip(
                              label: 'Làm việc khác',
                              selected: blocker == 'Làm việc khác',
                              onTap: () => setSheetState(() {
                                blocker = 'Làm việc khác';
                                goalMet = false;
                              }),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              AppColors.iosSecondarySoft.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.iosSecondary
                                  .withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.bolt_rounded,
                                    color: AppColors.iosSecondary, size: 16),
                                SizedBox(width: 6),
                                Text('Liên kết AI thông minh:',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.iosSecondary)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ActionChip(
                                  avatar: const Icon(Icons.quiz_rounded,
                                      size: 15, color: AppColors.iosSecondary),
                                  label: const Text('🧠 Test nhanh 1 câu AI'),
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                      color: AppColors.iosSecondary
                                          .withValues(alpha: 0.4)),
                                  labelStyle: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.iosSecondary),
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
                                  avatar: const Icon(
                                      Icons.sticky_note_2_rounded,
                                      size: 15,
                                      color: AppColors.iosInfo),
                                  label: const Text('📝 Ghi chú nhanh'),
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                      color: AppColors.iosInfo
                                          .withValues(alpha: 0.4)),
                                  labelStyle: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.iosInfo),
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    onQuickNote(session.subject,
                                        sessionId: session.id);
                                  },
                                ),
                                // Đặc tả 5.3: phản hồi "cần ôn lại" (dù hiểu bài) cũng
                                // phải dẫn tới đề xuất ôn lại — không chỉ khi "chưa
                                // hiểu". Nhờ vậy mục đích của câu hỏi trở ngại được
                                // dùng thật, không chỉ lưu trữ.
                                if (understandingLevel == 0 ||
                                    blocker == 'Cần ôn lại')
                                  ActionChip(
                                    avatar: const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 15,
                                        color: AppColors.iosWarning),
                                    label: const Text('📅 Ôn lại ngày mai'),
                                    backgroundColor: Colors.white,
                                    side: BorderSide(
                                        color: AppColors.iosWarning
                                            .withValues(alpha: 0.4)),
                                    labelStyle: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.iosWarning),
                                    onPressed: () {
                                      Navigator.pop(sheetContext);
                                      onScheduleReview(session.subject);
                                    },
                                  ),
                                // Đặc tả 5.3: phản hồi "chưa xong mục tiêu" phải dẫn tới
                                // đề xuất chia nhỏ nhiệm vụ cho lần sau — dùng lại câu
                                // trả lời mục tiêu thay vì chỉ lưu trữ.
                                if (!goalMet && onSplitTask != null)
                                  ActionChip(
                                    avatar: const Icon(Icons.call_split_rounded,
                                        size: 15, color: AppColors.iosPrimary),
                                    label:
                                        const Text('✂️ Chia nhỏ cho lần sau'),
                                    backgroundColor: Colors.white,
                                    side: BorderSide(
                                        color: AppColors.iosPrimary
                                            .withValues(alpha: 0.4)),
                                    labelStyle: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.iosPrimary),
                                    onPressed: () {
                                      Navigator.pop(sheetContext);
                                      onSplitTask();
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
                            onPressed: () => setSheetState(
                                () => showDetailed = !showDetailed),
                            child: Text(
                              showDetailed
                                  ? 'Thu gọn đánh giá'
                                  : 'Thêm đánh giá chi tiết ▾',
                              style: const TextStyle(fontSize: 12),
                            ),
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
                        _reflectionScale(
                            'Mức độ hiểu',
                            understanding,
                            (value) =>
                                setSheetState(() => understanding = value)),
                        _reflectionScale(
                            'Hiệu quả',
                            effectiveness,
                            (value) =>
                                setSheetState(() => effectiveness = value)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: noteController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              hintText: 'Ghi chú thêm (không bắt buộc)'),
                        ),
                        const SizedBox(height: 14),
                        // Đặc tả 5.3: hai câu hỏi phản tư sâu — để trong mục "chi
                        // tiết" nhằm giữ đường lưu 1 chạm (FE-3.3) luôn nằm trong
                        // tầm mắt, không phải cuộn xuống.
                        const Text('Đã hoàn thành mục tiêu phiên này chưa?',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.iosTextPrimary)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _understandingOption(
                                emoji: '✅',
                                label: 'Đã xong',
                                selected: goalMet,
                                accent: AppColors.iosPrimary,
                                onTap: () =>
                                    setSheetState(() => goalMet = true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _understandingOption(
                                emoji: '🟡',
                                label: 'Chưa xong',
                                selected: !goalMet,
                                accent: AppColors.iosWarning,
                                onTap: () =>
                                    setSheetState(() => goalMet = false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text('Cần ôn lại hoặc có trở ngại nào không?',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.iosTextPrimary)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _selectableChip(
                              label: 'Không',
                              selected: blocker.isEmpty,
                              onTap: () => setSheetState(() => blocker = ''),
                            ),
                            _selectableChip(
                              label: '🔁 Cần ôn lại',
                              selected: blocker == 'Cần ôn lại',
                              onTap: () =>
                                  setSheetState(() => blocker = 'Cần ôn lại'),
                            ),
                            _selectableChip(
                              label: '🚧 Có trở ngại',
                              selected: blocker == 'Có trở ngại',
                              onTap: () =>
                                  setSheetState(() => blocker = 'Có trở ngại'),
                            ),
                          ],
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
                              goalMet: goalMet,
                              blocker: blocker,
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
                      // V2 mục C.3: "không muốn nói gì" phải to **bằng** nút lưu —
                      // một liên kết chữ nhỏ là cách đẩy người học vào việc trả lời
                      // họ đã nói rõ là không muốn.
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          key: const ValueKey('skip-session-feedback'),
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Không muốn nói gì',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.iosTextMuted)),
                        ),
                      ),
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
                                goalMet: goalMet,
                                blocker: blocker,
                              ),
                            ),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text(
                              'Xong việc này — về Hôm nay',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.iosPrimary,
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
        ),
      );
    },
  ).whenComplete(noteController.dispose);
}
