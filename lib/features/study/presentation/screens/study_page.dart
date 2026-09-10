import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import 'study_screen.dart';

/// Full-screen page "Tập trung" — bọc [StudyScreen] trong Scaffold có nút back.
/// Tách khỏi bottom nav (tinh gọn 3 tab) nhưng giữ nguyên Pomodoro, nhật ký,
/// biểu đồ và điểm thi thử.
class StudyPage extends StatelessWidget {
  final VoidCallback? onStreakChanged;

  const StudyPage({super.key, this.onStreakChanged});

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
      body: StudyScreen(onStreakChanged: onStreakChanged),
    );
  }
}
