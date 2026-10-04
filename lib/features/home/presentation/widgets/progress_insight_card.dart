import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../progress/domain/progress_engine.dart';
import '../../../progress/domain/progress_insights.dart';
import '../../../study/domain/repositories/study_session_repository.dart';
import '../../../tasks/domain/repositories/task_repository.dart';

/// "Nhận định tuần" trên Home.
///
/// Nối [ProgressEngine] + [ProgressInsights] vào màn Hôm nay: mỗi lần có nhiệm
/// vụ hoặc phiên học mới, thẻ đọc lại số liệu tuần và hiển thị nhận định
/// **cục bộ** ([ProgressInsights.localInsight]) — đồng bộ, không mạng, nên Home
/// không bao giờ phải chờ AI. Tuần chưa có dữ liệu thì thẻ tự ẩn, không bịa
/// câu động viên.
class ProgressInsightCard extends StatefulWidget {
  /// Chuyển sang tab Tiến độ để xem chi tiết biểu đồ/phiên.
  final VoidCallback? onOpenProgress;

  /// Gửi nhận định + số liệu cho AI Coach phân tích sâu hơn.
  final ValueChanged<String>? onAskAi;

  /// Nguồn thời gian, cho phép test cố định "now".
  final DateTime Function() clock;

  const ProgressInsightCard({
    super.key,
    this.onOpenProgress,
    this.onAskAi,
    this.clock = DateTime.now,
  });

  @override
  State<ProgressInsightCard> createState() => _ProgressInsightCardState();
}

class _ProgressInsightCardState extends State<ProgressInsightCard> {
  ProgressSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    // Task/phiên đổi ở bất kỳ màn nào cũng phát tín hiệu qua repository —
    // không cần Home phải là màn đang mở mới cập nhật.
    TaskRepository.instance.revision.addListener(_reload);
    StudySessionRepository.instance.revision.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    TaskRepository.instance.revision.removeListener(_reload);
    StudySessionRepository.instance.revision.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _snapshot = ProgressEngine.snapshot(
        StudySessionRepository.instance.getAll(),
        TaskRepository.instance.getAllTasks(),
        widget.clock(),
      );
    });
  }

  void _askAi(ProgressSnapshot snapshot) {
    widget.onAskAi?.call(ProgressInsights.buildPrompt(snapshot));
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    if (snapshot == null) return const SizedBox.shrink();

    final insight = ProgressInsights.localInsight(snapshot);
    // Chưa có gì để nói (tuần trắng) → không chiếm chỗ trên Home.
    if (insight == null) return const SizedBox.shrink();

    final delta = snapshot.weekDeltaPercent;
    final weekHours = snapshot.week.totalHours;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.purpleSoft.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 18, color: AppColors.purple),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Nhận định tuần',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              if (widget.onOpenProgress != null)
                GestureDetector(
                  onTap: widget.onOpenProgress,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.purple,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insights_rounded,
                            size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Xem tuần',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            insight,
            style: const TextStyle(fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metric('${weekHours.toStringAsFixed(1)}h', 'Tuần này'),
              const SizedBox(width: 8),
              _metric(
                delta == null ? '—' : '${delta > 0 ? '+' : ''}$delta%',
                'So tuần trước',
              ),
              const SizedBox(width: 8),
              _metric(
                '${snapshot.week.tasksCompleted}/${snapshot.week.tasksTotal}',
                'Nhiệm vụ',
              ),
            ],
          ),
          if (widget.onAskAi != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _askAi(snapshot),
              behavior: HitTestBehavior.opaque,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.psychology_outlined,
                      size: 15, color: AppColors.purple),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Hỏi AI phân tích tuần',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.purple),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.bgPageSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
