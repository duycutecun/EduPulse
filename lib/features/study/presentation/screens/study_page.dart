import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../ai_coach/presentation/screens/ai_coach_screen.dart';
import '../../domain/models/study_models.dart';
import 'study_screen.dart';

/// Full-screen page "Tập trung" — bọc [StudyScreen] trong Scaffold có nút back.
/// Tách khỏi bottom nav (tinh gọn 3 tab) nhưng giữ nguyên Pomodoro, nhật ký,
/// biểu đồ và điểm thi thử.
class StudyPage extends StatelessWidget {
  final VoidCallback? onStreakChanged;

  /// Phiên học vừa kết thúc → màn bên ngoài cập nhật tổng thời gian ngay.
  final VoidCallback? onSessionCompleted;
  final String? initialSubject;
  final int? initialMinutes;
  final TodayTask? initialTask;
  final bool autoStart;

  /// Nguồn thời gian, xem [StudyScreen.clock].
  final DateTime Function() clock;

  const StudyPage({
    super.key,
    this.onStreakChanged,
    this.onSessionCompleted,
    this.initialSubject,
    this.initialMinutes,
    this.initialTask,
    this.autoStart = false,
    this.clock = DateTime.now,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          'Tập trung',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        actions: [
          // AI-4.3 — "Hỏi AI về bài này" ngay trong chế độ học tập trung.
          IconButton(
            tooltip: 'Hỏi AI về bài này',
            icon: const Icon(Icons.psychology_outlined),
            onPressed: () => _openAskAi(context),
          ),
        ],
      ),
      body: StudyScreen(
        onStreakChanged: onStreakChanged,
        onSessionCompleted: onSessionCompleted,
        initialSubject: initialSubject,
        initialMinutes: initialMinutes,
        initialTask: initialTask,
        autoStart: autoStart,
        clock: clock,
      ),
    );
  }

  /// Mở AI Coach kèm câu hỏi bám đúng bài/môn đang học — để học sinh gỡ vướng
  /// ngay trong lúc học thay vì thoát ra ngoài.
  void _openAskAi(BuildContext context) {
    final task = initialTask;
    final subject = initialSubject ?? task?.subject;
    final title = task?.title;

    String? prompt;
    if (title != null && title.isNotEmpty) {
      prompt = 'Giải thích trọng tâm kiến thức của bài "$title"'
          '${subject == null || subject.isEmpty ? '' : ' môn $subject'}. '
          'Nêu ý chính, lỗi thường gặp và 2-3 câu hỏi để tôi tự kiểm tra.';
    } else if (subject != null && subject.isNotEmpty) {
      prompt = 'Hãy giải thích các dạng bài trọng tâm môn $subject '
          'và những lỗi học sinh hay mắc.';
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: AppColors.bgPage,
          appBar: AppBar(
            backgroundColor: AppColors.bgPage,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text(
              'Hỏi AI',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          body: AiCoachScreen(initialPrompt: prompt),
        ),
      ),
    );
  }
}
