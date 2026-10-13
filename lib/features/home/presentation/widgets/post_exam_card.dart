import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/ai/ai_refresh_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../exams/domain/models/exam_model.dart';
import '../../../study/domain/models/study_models.dart';

/// Thẻ hiện ra ở Home khi một kỳ thi đã qua ngày — [reachedTarget] quyết định
/// giọng điệu (chúc mừng / động viên / chờ kết quả). Tách khỏi HomeScreen để
/// phần trình bày không lẫn vào luồng chọn thẻ của màn.
class PostExamCard extends StatelessWidget {
  const PostExamCard({
    super.key,
    required this.exam,
    required this.reachedTarget,
    required this.onOpenExam,
    required this.onScoreSaved,
  });

  final ExamModel exam;
  final bool? reachedTarget; // null = chưa đủ dữ liệu kết luận
  final VoidCallback onOpenExam;
  final VoidCallback onScoreSaved;

  Future<void> _quickScoreEntry(BuildContext context) async {
    final controller = TextEditingController(
      text: exam.currentScore?.toStringAsFixed(1) ?? '',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nhập điểm của bạn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              exam.targetScore != null
                  ? 'Mục tiêu của bạn: ${exam.targetScore!.toStringAsFixed(1)} điểm'
                  : 'Chưa có mục tiêu điểm — nhập để lưu lịch sử.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: 'VD: 8.5',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              final parsed =
                  double.tryParse(controller.text.trim().replaceAll(',', '.'));
              if (parsed == null || parsed < 0 || parsed > 10) return;
              Navigator.pop(dialogContext, parsed);
            },
            child: const Text('Lưu điểm'),
          ),
        ],
      ),
    );
    if (value == null) return;

    // Cập nhật điểm hiện tại của kỳ thi (lưu lịch sử, mục 40).
    final updated = exam.copyWithCurrent(value);
    StorageService.setExamJson(updated.id, updated.toJsonString());

    // Ghi thêm MockScore để biểu đồ điểm có dữ liệu (mục 41).
    final score = MockScore(
      id: const Uuid().v4(),
      date: DateTime.now(),
      subject: updated.name,
      score: value,
      note: 'Điểm ${updated.name}',
    );
    StorageService.setMockScoreJson(score.id, score.toJsonString());
    final ids = StorageService.getMockScoreIds()..add(score.id);
    StorageService.setMockScoreIds(ids);

    // Chu trình AI: điểm mới thay đổi readiness → bản tin/gợi ý tính lại.
    AiRefreshService.notifyDataChanged();

    onScoreSaved();
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = reachedTarget != null;
    final title = reachedTarget == true
        ? 'Chúc mừng bạn đã hoàn thành ${exam.name}! 🎉'
        : reachedTarget == false
            ? '${exam.name} đã kết thúc. Cố gắng của bạn đều đáng giá.'
            : '${exam.name} đã kết thúc — đang chờ kết quả';

    final subtitle = reachedTarget == true
        ? 'Bạn đã đạt mục tiêu điểm. Muốn xem lại phân tích quá trình học không?'
        : reachedTarget == false
            ? 'Xem phân tích khoảng cách điểm để điều chỉnh kế hoạch tiếp theo nhé.'
            : 'Khi có điểm, cập nhật ở tab Mục tiêu để EduPulse phân tích giúp bạn.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
                fontSize: 12.5, color: AppColors.textSecondary, height: 1.35),
          ),
          if (hasResult) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: reachedTarget == true
                    ? AppColors.greenSoft
                    : AppColors.blueLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Điểm hiện tại ${exam.currentScore!.toStringAsFixed(1)} • Mục tiêu ${exam.targetScore!.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: reachedTarget == true
                      ? AppColors.primaryDark
                      : AppColors.blueDark,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Nhập điểm nhanh — luôn hiện khi chưa đủ target + current.
          if (!hasResult)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton.icon(
                onPressed: () => _quickScoreEntry(context),
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Đã có điểm? Nhập ngay'),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpenExam,
                  child: const Text('Xem kỳ thi'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Kỳ thi mới sẽ được tạo ở tab Mục tiêu → thêm kỳ thi.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text('Tạo mục tiêu mới'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
