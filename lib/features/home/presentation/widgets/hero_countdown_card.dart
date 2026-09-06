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
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final primaryExam = widget.primaryExam;
    final urgencyColor = primaryExam != null
        ? _urgencyColor(primaryExam.daysLeft)
        : AppColors.textMuted;
    final progress = primaryExam != null
        ? (1.0 - (primaryExam.daysLeft / 365.0)).clamp(0.05, 0.98)
        : 0.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
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
                            ? '📅 ${AppDate.formatDateTime(primaryExam.dateTime)}'
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
                      primaryExam.urgencyLabel,
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
            _buildTimerRow(),
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
        _buildTimerTile(days.toString().padLeft(3, '0'), 'ngày'),
        _timerColon(),
        _buildTimerTile(hours.toString().padLeft(2, '0'), 'giờ'),
        _timerColon(),
        _buildTimerTile(minutes.toString().padLeft(2, '0'), 'phút'),
        _timerColon(),
        _buildTimerTile(seconds.toString().padLeft(2, '0'), 'giây', isAccent: true),
      ],
    );
  }

  Widget _buildTimerTile(String value, String label, {bool isAccent = false}) {
    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAccent ? AppColors.green.withValues(alpha: 0.6) : AppColors.border,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(color: AppColors.borderDark, blurRadius: 0, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.25),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Text(
              value,
              key: ValueKey<String>(value),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isAccent ? AppColors.greenDark : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: isAccent ? AppColors.green : AppColors.textMuted,
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
