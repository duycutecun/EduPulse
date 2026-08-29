import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_date.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../exams/domain/models/exam_model.dart';

class HeroCountdownCard extends StatelessWidget {
  final ExamModel? primaryExam;
  final VoidCallback onTap;
  final Duration remaining;

  const HeroCountdownCard({
    super.key,
    required this.primaryExam,
    required this.onTap,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;
    final urgencyColor = primaryExam != null
        ? _urgencyColor(primaryExam!.daysLeft)
        : AppColors.textMuted;
    final progress = primaryExam != null
        ? (1.0 - (primaryExam!.daysLeft / 365.0)).clamp(0.05, 0.98)
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    primaryExam?.emoji ?? '🎯',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        primaryExam?.name ?? 'Chưa chọn kỳ thi mục tiêu',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        primaryExam != null
                            ? '📅 ${AppDate.formatDateTime(primaryExam!.dateTime)}'
                            : 'Chạm vào đây để chọn kỳ thi →',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (primaryExam != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: urgencyColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      primaryExam!.urgencyLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTimerTile(days.toString().padLeft(3, '0'), 'NGÀY'),
                _timerColon(),
                _buildTimerTile(hours.toString().padLeft(2, '0'), 'GIỜ'),
                _timerColon(),
                _buildTimerTile(minutes.toString().padLeft(2, '0'), 'PHÚT'),
                _timerColon(),
                _buildTimerTile(seconds.toString().padLeft(2, '0'), 'GIÂY'),
              ],
            ),
            if (primaryExam != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chặng đường ôn luyện',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimerTile(String value, String label) {
    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 2),
        boxShadow: [
          BoxShadow(color: AppColors.borderDark, blurRadius: 0, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timerColon() {
    return Text(
      ':',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
      ),
    );
  }

  Color _urgencyColor(int days) {
    if (days < 30) return AppColors.red;
    if (days < 90) return AppColors.orange;
    return AppColors.green;
  }
}
