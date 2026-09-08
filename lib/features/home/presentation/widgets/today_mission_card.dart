import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/animated_count_up.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/heartbeat_combo.dart';
import '../../../../shared/widgets/progress_ring.dart';
import '../../../../shared/widgets/spring_press.dart';
import '../../../study/domain/models/study_models.dart';

class TodayMissionCard extends StatelessWidget {
  final List<TodayTask> tasks;
  final VoidCallback onAddTask;
  final ValueChanged<TodayTask> onToggle;
  final ValueChanged<TodayTask> onDelete;

  const TodayMissionCard({
    super.key,
    required this.tasks,
    required this.onAddTask,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.isDone).length;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('📋', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'Nhiệm vụ hôm nay',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                  ),
                ],
              ),
              Row(
                children: [
                  HeartbeatCombo(
                    value: done.toDouble(),
                    peakScale: 0.05,
                    glowColor: progress >= 1.0 && tasks.isNotEmpty
                        ? AppColors.green
                        : null,
                    child: ProgressRing(
                      size: 56,
                      strokeWidth: 6.5,
                      progress: progress,
                      color: AppColors.green,
                      gradientColors: tasks.isNotEmpty && done == tasks.length
                          ? const [AppColors.green, AppColors.blue]
                          : const [AppColors.green, AppColors.greenDark],
                      glowColor: AppColors.greenLight,
                      duration: const Duration(milliseconds: 800),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedCountUp(
                            value: done.toDouble(),
                            duration: const Duration(milliseconds: 800),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '/${tasks.length}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SpringPress(
                    onTap: onAddTask,
                    pressScale: 0.88,
                    pressTranslate: 2.5,
                    shadowColor: AppColors.greenDark,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          const Icon(Icons.add, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (context, pVal, _) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: pVal,
                  minHeight: 8,
                  backgroundColor: AppColors.border,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.green),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...tasks.map((task) => _buildTaskItem(task)),
          ] else ...[
            const SizedBox(height: 14),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Chưa có nhiệm vụ. Nhấn nút + để thêm!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskItem(TodayTask task) {
    Color priorityColor = AppColors.green;
    String priorityText = 'Thường';
    if (task.priority == 'high') {
      priorityColor = AppColors.red;
      priorityText = 'Quan trọng';
    } else if (task.priority == 'medium') {
      priorityColor = AppColors.orange;
      priorityText = 'Vừa';
    }

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(task),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.red, size: 20),
      ),
      child: SpringPress(
        pressScale: 0.97,
        pressTranslate: 1.5,
        onTap: () {
          HapticFeedback.selectionClick();
          onToggle(task);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: task.isDone
                ? AppColors.greenLight.withValues(alpha: 0.45)
                : AppColors.cardWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: task.isDone ? AppColors.green : AppColors.border,
              width: 2,
            ),
            boxShadow: task.isDone
                ? null
                : [
                    BoxShadow(
                      color: AppColors.borderDark,
                      blurRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _CheckBurstRing(isDone: task.isDone, color: AppColors.green),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                          begin: 0.0, end: task.isDone ? 1.0 : 0.0),
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutBack,
                      builder: (context, anim, _) {
                        return Transform.scale(
                          scale: 0.85 + (anim * 0.15),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: task.isDone
                                  ? AppColors.green
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: task.isDone
                                    ? AppColors.green
                                    : AppColors.textMuted,
                                width: 2,
                              ),
                              boxShadow: task.isDone
                                  ? [
                                      BoxShadow(
                                        color: AppColors.green
                                            .withValues(alpha: 0.3 * anim),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: task.isDone
                                ? Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 16 * anim.clamp(0.0, 1.0),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Nunito',
                        color: task.isDone
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        decoration: task.isDone
                            ? TextDecoration.lineThrough
                            : null,
                        fontWeight: FontWeight.w700,
                      ),
                      child: Text('${task.subject} ${task.title}'),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '⏱ ${task.estimateMinutes} phút',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          priorityText,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: priorityColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vòng sóng lan (burst ring) phát ra khi tick hoàn thành nhiệm vụ —
/// signature "check-pop" kiểu Duolingo. Vẽ CustomPaint rẻ, không blur.
class _CheckBurstRing extends StatelessWidget {
  final bool isDone;
  final Color color;

  const _CheckBurstRing({required this.isDone, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Key đổi theo trạng thái → mỗi lần tick lại chạy từ đầu.
      key: ValueKey(isDone),
      tween: Tween<double>(begin: 0.0, end: isDone ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        if (!isDone || t >= 0.999) return const SizedBox.shrink();
        return IgnorePointer(
          child: CustomPaint(
            size: const Size(36, 36),
            painter: _BurstRingPainter(t: t, color: color),
          ),
        );
      },
    );
  }
}

class _BurstRingPainter extends CustomPainter {
  final double t;
  final Color color;

  const _BurstRingPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Bánhxe sóng lan: bán kính tăng dần, alpha fade out.
    final radius = 12.0 + t * 10.0;
    final alpha = (1.0 - t) * 0.5;
    if (alpha <= 0.01) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * (1.0 - t * 0.6)
      ..color = color.withValues(alpha: alpha);

    canvas.drawCircle(center, radius, paint);

    // 6 tia nhỏ bắn ra ngoài (kiểu sparkles).
    if (t < 0.55) {
      final sparkT = t / 0.55;
      final sparkAlpha = (1.0 - sparkT) * 0.65;
      final sparkPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: sparkAlpha);

      for (int i = 0; i < 6; i++) {
        final angle = i * math.pi / 3 + 0.26; // lệch nhẹ cho tự nhiên
        final r1 = 14.0 + sparkT * 4.0;
        final r2 = r1 + 3.5 * (1.0 - sparkT * 0.5);
        canvas.drawLine(
          center + Offset(math.cos(angle) * r1, math.sin(angle) * r1),
          center + Offset(math.cos(angle) * r2, math.sin(angle) * r2),
          sparkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BurstRingPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}
