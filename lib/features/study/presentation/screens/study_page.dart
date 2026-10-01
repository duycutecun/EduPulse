import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/study_models.dart';
import 'study_screen.dart';

/// Full-screen page "Tập trung" — bọc [StudyScreen] trong Scaffold có nút back.
/// Tách khỏi bottom nav (tinh gọn 3 tab) nhưng giữ nguyên Pomodoro, nhật ký,
/// biểu đồ và điểm thi thử.
class StudyPage extends StatelessWidget {
  final VoidCallback? onStreakChanged;
  final String? initialSubject;
  final int? initialMinutes;
  final TodayTask? initialTask;
  final bool autoStart;

  const StudyPage({
    super.key,
    this.onStreakChanged,
    this.initialSubject,
    this.initialMinutes,
    this.initialTask,
    this.autoStart = false,
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
      ),
      body: StudyScreen(
        onStreakChanged: onStreakChanged,
        initialSubject: initialSubject,
        initialMinutes: initialMinutes,
        initialTask: initialTask,
        autoStart: autoStart,
      ),
    );
  }
}
