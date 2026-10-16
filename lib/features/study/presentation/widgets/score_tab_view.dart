import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/models/study_models.dart';
import '../../domain/score_recovery_plan.dart';
import '../../domain/score_summary.dart';
import '../../domain/topic_breakdown.dart';

/// Lát cắt "Điểm thi" của màn Học tập (kế hoạch §6.2).
///
/// Widget chỉ *trình bày*: nhận danh sách điểm và các callback từ màn cha,
/// không tự đọc/ghi storage hay gọi mạng. Nhờ vậy phần thống kê, kế hoạch bù
/// điểm, chủ đề yếu và danh sách điểm có thể test riêng mà không cần dựng cả
/// `StudyScreen`.
class ScoreTabView extends StatelessWidget {
  const ScoreTabView({
    super.key,
    required this.scores,
    required this.daysLeft,
    required this.onAddScore,
    required this.onAnalyze,
    required this.onAddRecoveryTask,
    required this.onScheduleTopicReview,
    required this.onDeleteScore,
  });

  final List<MockScore> scores;

  /// Số ngày còn lại tới kỳ thi chính (dùng để tính nhịp bù điểm).
  final int daysLeft;

  final VoidCallback onAddScore;
  final VoidCallback onAnalyze;
  final ValueChanged<ScoreRecoveryPlan> onAddRecoveryTask;
  final void Function(String subject, String topic) onScheduleTopicReview;
  final ValueChanged<MockScore> onDeleteScore;

  @override
  Widget build(BuildContext context) {
    final summaries = summarizeMockScores(scores);
    final avg = overallAverage(scores);
    final recovery = buildScoreRecoveryPlan(scores, daysLeft: daysLeft);
    // Chỉ nhắc chủ đề thực sự yếu (dưới ngưỡng) — tránh làm nhiễu khi mọi
    // chủ đề đều ổn.
    final weakTopics = analyzeTopicWeakness(scores)
        .where((t) => t.average < kWeakTopicThreshold)
        .take(3)
        .toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          // Thống kê.
          Row(
            children: [
              Expanded(
                child: StatCard(
                  value: '${scores.length}',
                  label: 'Lần thi thử',
                  color: AppColors.iosInfo,
                  icon: Icons.assignment_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  value: avg > 0 ? avg.toStringAsFixed(1) : '—',
                  label: 'Điểm TB',
                  color: AppColors.iosPrimary,
                  icon: Icons.stars_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Hai nút action.
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onAddScore,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.iosPrimary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color:
                                AppColors.iosPrimaryDark.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('GHI ĐIỂM THI THỬ',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: scores.isEmpty ? null : onAnalyze,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: scores.isEmpty
                          ? AppColors.iosFill
                          : AppColors.iosSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scores.isEmpty
                            ? AppColors.iosSeparator
                            : AppColors.iosSecondary,
                        width: 1.5,
                      ),
                      boxShadow: scores.isEmpty
                          ? null
                          : [
                              BoxShadow(
                                  color: AppColors.iosSecondary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4)),
                            ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.psychology_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text('AI PHÂN TÍCH',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (scores.isEmpty)
            const EmptyStatePanel(
              icon: Icons.assignment_outlined,
              title: 'Chưa có điểm thi thử.',
              description: 'Ghi lại điểm mỗi lần thi thử để theo dõi tiến bộ '
                  'và biết môn nào cần ôn trước.',
            )
          else ...[
            if (recovery != null) ...[
              _buildRecoveryPlanCard(recovery),
              const SizedBox(height: 14),
            ],
            if (weakTopics.isNotEmpty) ...[
              _buildWeakTopicsCard(weakTopics),
              const SizedBox(height: 14),
            ],
            if (summaries.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.iosCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.iosSeparator, width: 1),
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
                    const Text('Tổng hợp theo môn',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.iosTextPrimary)),
                    const SizedBox(height: 12),
                    ...summaries.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(s.subject,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.iosTextPrimary)),
                                  Text(
                                    '${s.average.toStringAsFixed(1)} • ${s.rating}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: s.average >= 8
                                          ? AppColors.iosPrimary
                                          : (s.average >= 6.5
                                              ? AppColors.iosWarning
                                              : AppColors.iosError),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: (s.average / 10).clamp(0.0, 1.0),
                                  minHeight: 8,
                                  backgroundColor: AppColors.iosFill,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    s.average >= 8
                                        ? AppColors.iosSuccess
                                        : (s.average >= 6.5
                                            ? AppColors.iosWarning
                                            : AppColors.iosError),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            ...scores.map((s) => _buildScoreItem(s)),
          ],
        ],
      ),
    );
  }

  Widget _buildRecoveryPlanCard(ScoreRecoveryPlan plan) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.iosSecondarySoft.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppColors.iosSecondary.withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.auto_graph_rounded,
                size: 17, color: AppColors.iosSecondary),
            SizedBox(width: 7),
            Text('Kế hoạch bù điểm',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.iosSecondary)),
          ]),
          const SizedBox(height: 7),
          Text(
              '${plan.reason} Gợi ý ${plan.sessionsPerWeek} phiên/tuần, ${plan.minutesPerSession} phút/phiên.',
              style: const TextStyle(fontSize: 12.5, height: 1.35)),
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => onAddRecoveryTask(plan),
              icon: const Icon(Icons.add_task_rounded, size: 16),
              label: const Text('Thêm phiên đầu tiên'),
            ),
          ),
        ]),
      );

  /// Thẻ chủ đề yếu: tổng hợp theo (môn, chủ đề) và cho một chạm đặt nhiệm vụ
  /// ôn lại. Chỉ xuất hiện khi có chủ đề dưới ngưỡng (xem `build`).
  Widget _buildWeakTopicsCard(List<WeakTopic> topics) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.iosWarning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppColors.iosWarning.withValues(alpha: 0.35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.trending_down_rounded,
                size: 17, color: AppColors.iosWarning),
            SizedBox(width: 7),
            Text('Chủ đề cần ôn lại',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.iosWarning)),
          ]),
          const SizedBox(height: 4),
          const Text('Dưới 6.5 điểm — ôn sớm để bù kịp trước kỳ thi.',
              style: TextStyle(fontSize: 12, color: AppColors.iosTextMuted)),
          const SizedBox(height: 8),
          for (final t in topics)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${t.topic} · ${t.subject}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(
                          'TB ${t.average.toStringAsFixed(1)} • ${t.attempts} lần thi',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.iosTextMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => onScheduleTopicReview(t.subject, t.topic),
                    icon: const Icon(Icons.add_task_rounded, size: 16),
                    label: const Text('Ôn chủ đề này',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
        ]),
      );

  Widget _buildScoreItem(MockScore s) {
    final color = s.score >= 8
        ? AppColors.iosPrimary
        : (s.score >= 6.5 ? AppColors.iosWarning : AppColors.iosError);
    return Dismissible(
      key: Key(s.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDeleteScore(s),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.iosError.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_rounded,
            color: AppColors.iosError, size: 18),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.iosCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.iosSeparator, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Score circle — nền xanh lá/cam/red tùy điểm.
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  s.score.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      s.topic != null && s.topic!.isNotEmpty
                          ? '${s.subject} · ${s.topic}'
                          : s.subject,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.iosTextPrimary)),
                  if (s.note != null && s.note!.isNotEmpty)
                    Text(s.note!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.iosTextMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text('${s.date.day}/${s.date.month}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.iosTextMuted)),
          ],
        ),
      ),
    );
  }
}
