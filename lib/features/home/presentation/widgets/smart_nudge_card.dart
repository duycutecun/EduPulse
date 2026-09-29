import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../exams/domain/models/exam_model.dart';
import '../../../study/domain/models/study_models.dart';

/// Mẹo học hàng ngày — dòng chữ gọn trong card phẳng, không icon tròn to màu.
class SmartNudgeCard extends StatelessWidget {
  const SmartNudgeCard({
    super.key,
    required this.tasks,
    this.primaryExam,
    this.onAskAi,
  });

  final List<TodayTask> tasks;
  final ExamModel? primaryExam;
  final VoidCallback? onAskAi;

  @override
  Widget build(BuildContext context) {
    final recommendation = _recommendation();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.yellow, AppColors.orange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.yellow, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.yellow.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 16, color: AppColors.purple),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gợi ý cho bạn',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  recommendation.text,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                if (recommendation.evidence != null) ...[
                  const SizedBox(height: 4),
                  Text(recommendation.evidence!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
                if (onAskAi != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onAskAi,
                    child: const Text('Hỏi AI Coach',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.purple)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  _Recommendation _recommendation() {
    final overdue = tasks.where((task) =>
        !task.isDone &&
        task.deadline != null &&
        DateUtils.dateOnly(task.deadline!).isBefore(DateUtils.dateOnly(DateTime.now()))).length;
    final skipped = tasks.where((task) => task.status == 'skipped').length;
    final incomplete = tasks.where((task) => !task.isDone && task.status != 'skipped').length;

    if (overdue > 0) {
      return _Recommendation(
        'Bạn có $overdue nhiệm vụ quá hạn. Hãy chọn một việc nhỏ nhất để bắt đầu lại.',
        'Dựa trên deadline đã lưu.',
      );
    }
    if (skipped >= 2) {
      return _Recommendation(
        'Một số nhiệm vụ đã bị bỏ qua. Có thể nên chia nhỏ hoặc dời lịch thay vì dồn lại.',
        'Dựa trên $skipped nhiệm vụ đã bỏ qua.',
      );
    }
    if (primaryExam != null && primaryExam!.daysLeft < 30 && incomplete == 0) {
      return _Recommendation(
        'Kỳ thi đang gần. Hãy tạo một nhiệm vụ ôn tập ngắn cho hôm nay.',
        'Còn ${primaryExam!.daysLeft} ngày đến ${primaryExam!.name}.',
      );
    }
    if (incomplete >= 5) {
      return _Recommendation(
        'Danh sách hôm nay khá dài. Hãy ưu tiên một nhiệm vụ quan trọng và bắt đầu Focus.',
        'Dựa trên $incomplete nhiệm vụ chưa hoàn thành.',
      );
    }
    return const _Recommendation(
      'Một phiên Focus 25 phút là đủ để tạo đà. Bạn không cần hoàn hảo để bắt đầu.',
      null,
    );
  }
}

class _Recommendation {
  const _Recommendation(this.text, this.evidence);
  final String text;
  final String? evidence;
}
