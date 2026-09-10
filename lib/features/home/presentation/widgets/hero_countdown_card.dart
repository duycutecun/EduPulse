import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_date.dart';
import '../../../../shared/widgets/glass_card.dart';
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
    final urgencyColor = primaryExam != null
        ? _urgencyColor(primaryExam.daysLeft)
        : AppColors.textMuted;

    return GestureDetector(
      onTap: widget.onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hàng trên: tên kỳ thi + chip mức độ khẩn cấp.
            Row(
              children: [
                Text(
                  primaryExam?.emoji ?? '🎯',
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    primaryExam?.name ?? 'Chưa chọn kỳ thi mục tiêu',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (primaryExam != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: urgencyColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      primaryExam.urgencyLabel,
                      style: TextStyle(
                        color: urgencyColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _buildTimerRow(),
            if (primaryExam != null) ...[
              const SizedBox(height: 12),
              Text(
                '📅 ${AppDate.formatDateTime(primaryExam.dateTime)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Chạm để chọn kỳ thi →',
                  style: TextStyle(
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

  /// Ô thời gian phẳng: chỉ số lớn + nhãn nhỏ, không khung viền.
  Widget _buildTimerTile(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
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
    return AppColors.green;
  }
}
