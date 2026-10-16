import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/models/study_models.dart';
import '../../domain/study_analytics.dart';
import '../../domain/study_timeline.dart';
import '../../../exams/domain/models/exam_model.dart';
import '../widgets/score_chart_widget.dart';
import '../widgets/weekly_chart_widget.dart';

/// Tab "Biểu đồ" của màn Học — tách khỏi `study_screen.dart` (mục 6.2) để
/// phần phân tích chỉ là hàm thuần trên dữ liệu đầu vào, không truy cập
/// storage/network. Mọi dữ liệu được truyền từ ngoài vào.
class StudyAnalyticsView extends StatelessWidget {
  const StudyAnalyticsView({
    super.key,
    required this.sessions,
    required this.timeline,
    required this.scores,
    required this.primaryExam,
    required this.onStartStudy,
  });

  final List<StudySession> sessions;
  final List<StudyTimelineEntry> timeline;
  final List<MockScore> scores;
  final ExamModel? primaryExam;
  final VoidCallback onStartStudy;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          _buildFocusAnalytics(),
          const SizedBox(height: 16),
          _buildAdvancedAnalytics(),
          const SizedBox(height: 16),
          ScoreChartWidget(scores: scores, primaryExam: primaryExam),
          const SizedBox(height: 16),
          WeeklyChartWidget(entries: timeline, onStartStudy: onStartStudy),
        ],
      ),
    );
  }

  /// Analytics nâng cao (đặc tả mục 12.2–12.5): so sánh tuần, efficiency
  /// composite, focus pattern và khung giờ học tốt. Mỗi mục chỉ hiện khi
  /// đủ dữ liệu — không kết luận khi thiếu mẫu.
  Widget _buildAdvancedAnalytics() {
    final now = DateTime.now();
    final comparison = compareWeeks(sessions, now);
    final efficiencyReport = efficiency(sessions, now);
    final focusTip = focusPatternTip(sessions);
    final timeTip = bestStudyTime(sessions);

    final hasAnything = comparison.thisWeekMinutes > 0 ||
        comparison.lastWeekMinutes > 0 ||
        efficiencyReport != null ||
        focusTip != null ||
        timeTip != null;
    if (!hasAnything) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.iosCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.iosSeparator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Phân tích nâng cao',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (comparison.message != null)
            _analyticsRow(
              icon: Icons.compare_arrows_rounded,
              color: AppColors.iosInfo,
              text: comparison.message!,
            ),
          if (efficiencyReport != null) ...[
            _analyticsRow(
              icon: Icons.speed_rounded,
              color: AppColors.iosPrimary,
              text:
                  'Efficiency ${efficiencyReport.score}%${efficiencyReport.deltaVsLastWeek == null ? '' : ' (${efficiencyReport.deltaVsLastWeek! >= 0 ? '+' : ''}${efficiencyReport.deltaVsLastWeek}% vs tuần trước)'} — dựa trên ${efficiencyReport.sampleCount} phiên có phản hồi.',
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 30),
              child: Text(efficiencyReport.description,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.iosTextSecondary)),
            ),
          ],
          if (focusTip != null)
            _analyticsRow(
              icon: Icons.timer_outlined,
              color: AppColors.iosWarning,
              text: focusTip,
            ),
          if (timeTip != null)
            _analyticsRow(
              icon: Icons.schedule_rounded,
              color: AppColors.iosSecondary,
              text: timeTip,
            ),
        ],
      ),
    );
  }

  Widget _analyticsRow({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.iosTextPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusAnalytics() {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final thisWeek = sessions
        .where((session) => !session.completedAt.isBefore(startOfWeek))
        .toList();
    final totalMinutes =
        thisWeek.fold<int>(0, (sum, session) => sum + session.actualMinutes);
    final ratedFocus =
        thisWeek.where((session) => session.focus != null).toList();
    final ratedEffectiveness =
        thisWeek.where((session) => session.effectiveness != null).toList();
    final avgFocus = ratedFocus.isEmpty
        ? null
        : ratedFocus.fold<int>(0, (sum, session) => sum + session.focus!) /
            ratedFocus.length;
    final avgEffectiveness = ratedEffectiveness.isEmpty
        ? null
        : ratedEffectiveness.fold<int>(
                0, (sum, session) => sum + session.effectiveness!) /
            ratedEffectiveness.length;

    String? insight;
    if (ratedFocus.length >= 3) {
      if (avgFocus! < 3) {
        insight = 'Các phiên gần đây có vẻ tập trung chưa cao — thử rút ngắn '
            'phiên hoặc nghỉ giữa hiệp sớm hơn một chút.';
      } else if (ratedEffectiveness.length >= 3 && avgEffectiveness! >= 4) {
        insight = 'Bạn đang giữ nhịp tốt: tập trung cao và hiệu quả ổn định.';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.iosCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.iosSeparator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Focus tuần',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              _analyticsMetric('$totalMinutes phút', 'Thời gian focus'),
              const SizedBox(width: 8),
              _analyticsMetric('${thisWeek.length}', 'Phiên hoàn thành'),
              const SizedBox(width: 8),
              _analyticsMetric(
                  avgFocus == null ? '—' : '${avgFocus.toStringAsFixed(1)}/5',
                  'Focus TB'),
            ],
          ),
          if (insight != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.iosSecondarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 18, color: AppColors.iosSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(insight,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.iosTextPrimary)),
                  ),
                ],
              ),
            ),
          ] else if (sessions.isEmpty) ...[
            const SizedBox(height: 12),
            // UX mục 11 "No study history": đủ 3 câu trả lời —
            // thiếu gì / vì sao quan trọng / làm gì tiếp theo.
            EmptyStatePanel(
              icon: Icons.timer_outlined,
              title: 'Chưa có phiên học nào.',
              description: 'Bắt đầu phiên đầu tiên hôm nay — sau đó bạn sẽ '
                  'thấy giờ focus, số phiên và xu hướng tiến bộ của mình.',
              actionLabel: 'Bắt đầu học',
              actionKey: const ValueKey('start-first-session'),
              actionIcon: Icons.play_arrow_rounded,
              onAction: onStartStudy,
            ),
          ],
        ],
      ),
    );
  }

  Widget _analyticsMetric(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.iosFill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.iosTextMuted)),
          ],
        ),
      ),
    );
  }
}
