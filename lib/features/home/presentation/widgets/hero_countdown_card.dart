import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_date.dart';
import '../../../exams/domain/models/exam_model.dart';

class HeroCountdownCard extends StatefulWidget {
  final ExamModel? primaryExam;
  final VoidCallback onTap;
  final Duration remaining;
  final ValueListenable<Duration>? remainingListenable;

  const HeroCountdownCard({
    super.key,
    required this.primaryExam,
    required this.onTap,
    this.remaining = Duration.zero,
    this.remainingListenable,
  });

  @override
  State<HeroCountdownCard> createState() => _HeroCountdownCardState();
}

class _HeroCountdownCardState extends State<HeroCountdownCard> {
  @override
  Widget build(BuildContext context) {
    final primaryExam = widget.primaryExam;
    final phase = primaryExam?.examPhase ?? ExamPhase.normal;
    final urgencyColor = primaryExam != null
        ? _urgencyColor(primaryExam.daysLeft)
        : AppColors.textMuted;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: phase == ExamPhase.examDay ? AppColors.orange : AppColors.border,
            width: phase == ExamPhase.examDay ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hàng trên: emoji + tên kỳ thi + chip urgency/phase.
            Row(
              children: [
                Text(
                  primaryExam?.emoji ?? '🎯',
                  style: const TextStyle(fontSize: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    primaryExam?.name ?? 'Chưa chọn kỳ thi mục tiêu',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (primaryExam != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: urgencyColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: urgencyColor, width: 1.2),
                    ),
                    child: Text(
                      phase == ExamPhase.examDay
                          ? '📍 Ngày thi'
                          : primaryExam.urgencyLabel,
                      style: TextStyle(
                        color: urgencyColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (phase == ExamPhase.examDay) ...[
              // Ngày thi: giờ thi rõ ràng, không cần đếm từng giây.
              Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      color: AppColors.orange, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Giờ thi: ${AppDate.formatDateTime(primaryExam!.dateTime)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ] else
              _buildTimerRow(),
            if (primaryExam != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      color: AppColors.textMuted, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    AppDate.formatDateTime(primaryExam.dateTime),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (phase == ExamPhase.revision) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.orangeLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    primaryExam.daysLeft <= 1
                        ? 'Ngày mai là ngày thi. Bạn đã sẵn sàng chưa?'
                        : 'Chế độ ôn tập: ưu tiên ôn trọng tâm, giảm nhiệm vụ không cần thiết.',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.orangeDark),
                  ),
                ),
              ],
              if (primaryExam.targetScore != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.blueLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    primaryExam.currentScore == null
                        ? 'Mục tiêu: ${primaryExam.targetScore!.toStringAsFixed(1)} điểm'
                        : 'Điểm hiện tại ${primaryExam.currentScore!.toStringAsFixed(1)} → mục tiêu ${primaryExam.targetScore!.toStringAsFixed(1)}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blueDark),
                  ),
                ),
              ],
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Chạm để chọn kỳ thi →',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerRow() {
    if (widget.remainingListenable != null) {
      return ValueListenableBuilder<Duration>(
        valueListenable: widget.remainingListenable!,
        builder: (context, rem, _) => _renderTiles(rem),
      );
    }
    return _renderTiles(widget.remaining);
  }

  Widget _renderTiles(Duration rem) {
    final days = rem.inDays;
    final hours = rem.inHours % 24;
    final minutes = rem.inMinutes % 60;
    final seconds = rem.inSeconds % 60;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildTimerTile(days.toString(), 'ngày'),
        _buildTimerTile(hours.toString().padLeft(2, '0'), 'giờ'),
        _buildTimerTile(minutes.toString().padLeft(2, '0'), 'phút'),
        _buildTimerTile(seconds.toString().padLeft(2, '0'), 'giây'),
      ],
    );
  }

  /// Ô thời gian kiểu Duolingo: nền xám nhạt, số lớn, chữ nhỏ bên dưới.
  Widget _buildTimerTile(String value, String label) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.cardLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Color _urgencyColor(int days) {
    if (days < 30) return AppColors.red;
    if (days < 90) return AppColors.orange;
    return AppColors.primary;
  }
}
