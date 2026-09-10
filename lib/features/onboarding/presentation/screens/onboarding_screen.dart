import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/main_shell.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../exams/domain/models/exam_model.dart';
import '../../../exams/domain/preset_exams.dart';
import '../../../study/domain/models/study_models.dart';

/// Màn hình chào mừng lần đầu: chọn kỳ thi mục tiêu → app tự tạo kỳ thi
/// và seed nhiệm vụ mẫu cho ngày hôm nay, rồi vào MainShell.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _uuid = const Uuid();
  bool _busy = false;

  Future<void> _pickPreset(PresetExam preset) async {
    setState(() => _busy = true);

    // Tạo kỳ thi mục tiêu.
    final exam = ExamModel(
      id: preset.id,
      name: preset.name,
      dateTime: preset.defaultDate(),
      type: ExamType.preset,
      description: preset.description,
      emoji: preset.emoji,
    );
    StorageService.setExamJson(exam.id, exam.toJsonString());
    StorageService.setExamIds([exam.id]);
    StorageService.setPrimaryExamId(exam.id);

    // Seed nhiệm vụ mẫu cho hôm nay.
    for (final t in preset.sampleTasks) {
      final task = TodayTask(
        id: _uuid.v4(),
        title: t.title,
        subject: t.subject,
        priority: t.priority,
        estimateMinutes: t.minutes,
      );
      StorageService.setTodayTaskJson(task.id, task.toJsonString());
      final ids = StorageService.getTodayTaskIds()..add(task.id);
      StorageService.setTodayTaskIds(ids);
    }

    // Ghi nhận đã hoàn tất onboarding rồi vào app chính.
    StorageService.setOnboardingDone();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShellScreen()),
    );
  }

  Future<void> _skip() async {
    StorageService.setOnboardingDone();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShellScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: _busy
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mascot + lời chào
                    Center(
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/mascot.png',
                          width: 96,
                          height: 96,
                          fit: BoxFit.contain,
                          cacheWidth: 288,
                          errorBuilder: (_, __, ___) => Container(
                            width: 96,
                            height: 96,
                            decoration: const BoxDecoration(
                              color: AppColors.primarySoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.school_rounded,
                                color: AppColors.primary, size: 48),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        'Chào sĩ tử! 👋',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'EduPulse giúp bạn đếm ngược kỳ thi và giữ vững đà học mỗi ngày.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Kỳ thi mục tiêu của bạn là gì?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'App sẽ tự tạo đồng hồ đếm ngược và gợi ý nhiệm vụ học cho hôm nay. Bạn có thể chỉnh sửa sau.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 14),
                    // Danh sách kỳ thi mẫu
                    for (final preset in PresetExams.all) ...[
                      _buildPresetCard(preset),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 8),
                    // Tự tạo sau
                    Center(
                      child: GestureDetector(
                        onTap: _skip,
                        child: Text(
                          'Để sau — tôi tự tạo kỳ thi',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPresetCard(PresetExam preset) {
    return GestureDetector(
      onTap: () => _pickPreset(preset),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(preset.emoji, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preset.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}