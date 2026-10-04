import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../exams/domain/models/exam_model.dart';
import '../../domain/services/today_service.dart';

/// Widget tổng kết trong ngày (FE-1.4) kèm ngữ cảnh kỳ thi súc tích (FE-1.2).
class DailySummaryCard extends StatelessWidget {
  final DailySummary summary;
  final ExamModel? primaryExam;
  final VoidCallback onExamTap;

  const DailySummaryCard({
    super.key,
    required this.summary,
    required this.primaryExam,
    required this.onExamTap,
  });

  @override
  Widget build(BuildContext context) {
    final daysLeft = primaryExam?.daysLeft;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: AppTokens.brXl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppTokens.shadowSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Ngữ cảnh kỳ thi súc tích
              Flexible(
                child: InkWell(
                  onTap: onExamTap,
                  borderRadius: AppTokens.brFull,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.space12,
                      vertical: AppTokens.space4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.blueSoft,
                      borderRadius: AppTokens.brFull,
                      border: Border.all(
                          color: AppColors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flag_rounded,
                            size: 14, color: AppColors.blueDark),
                        const SizedBox(width: AppTokens.space4),
                        Flexible(
                          child: Text(
                            primaryExam == null
                                ? 'Chưa chọn kỳ thi mục tiêu'
                                : 'Còn $daysLeft ngày · ${primaryExam!.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTokens.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.blueDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTokens.space2),
                        const Icon(Icons.chevron_right_rounded,
                            size: 14, color: AppColors.blueDark),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space8),
              // Thời gian học thực tế
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space8,
                  vertical: AppTokens.space4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: AppTokens.brSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 14, color: AppColors.primaryDark),
                    const SizedBox(width: AppTokens.space4),
                    Text(
                      summary.studyDurationFormatted,
                      style: AppTokens.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Tiến độ hôm nay',
                  style: AppTokens.heading3,
                ),
              ),
              Text(
                '${summary.completedTasks}/${summary.totalTasks} nhiệm vụ',
                style: AppTokens.bodySubtle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: summary.completedTasks == summary.totalTasks &&
                          summary.totalTasks > 0
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space8),
          ClipRRect(
            borderRadius: AppTokens.brFull,
            child: LinearProgressIndicator(
              value: summary.completionRate,
              minHeight: 8,
              backgroundColor: AppColors.progressBg,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
