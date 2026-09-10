import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/exam_model.dart';
import 'exams_screen.dart';

/// Full-screen page "Mục tiêu" — bọc [ExamsScreen] trong Scaffold có nút back.
/// Tách khỏi bottom nav (tinh gòn 3 tab) nhưng giữ nguyên toàn bộ tính năng.
class ExamsPage extends StatelessWidget {
  final List<ExamModel> exams;
  final String? primaryExamId;
  final ValueChanged<ExamModel> onSetPrimary;
  final ValueChanged<ExamModel> onAddExam;
  final ValueChanged<ExamModel> onUpdateExam;
  final ValueChanged<String> onDeleteExam;

  const ExamsPage({
    super.key,
    required this.exams,
    required this.primaryExamId,
    required this.onSetPrimary,
    required this.onAddExam,
    required this.onUpdateExam,
    required this.onDeleteExam,
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
          'Mục tiêu',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: ExamsScreen(
        exams: exams,
        primaryExamId: primaryExamId,
        onSetPrimary: onSetPrimary,
        onAddExam: onAddExam,
        onUpdateExam: onUpdateExam,
        onDeleteExam: onDeleteExam,
      ),
    );
  }
}
