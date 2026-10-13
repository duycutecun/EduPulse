import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../study/domain/models/study_models.dart';
import '../../../study/domain/repositories/study_session_repository.dart';
import '../../../study/domain/score_analysis.dart';
import '../../../study/domain/study_analytics.dart';
import '../../../study/domain/topic_breakdown.dart';
import '../../domain/deep_report.dart';

/// P2 — Báo cáo học tập chuyên sâu, chạy hoàn toàn offline (không gọi AI).
///
/// Trả lời các câu "mình đang đi lên hay xuống, thời gian học dồn vào đâu,
/// chủ đề nào thực sự yếu" bằng một màn ráp các domain đã có
/// ([DeepReport]) thay vì bắt học sinh tự ghép từ nhiều tab.
class DeepReportScreen extends StatefulWidget {
  /// Nguồn thời gian, cho phép test cố định "now".
  final DateTime Function() clock;

  /// Lối ra cho empty state toàn màn (G4-B).
  final VoidCallback? onStartStudy;

  const DeepReportScreen({
    super.key,
    this.clock = DateTime.now,
    this.onStartStudy,
  });

  @override
  State<DeepReportScreen> createState() => _DeepReportScreenState();
}

class _DeepReportScreenState extends State<DeepReportScreen> {
  DeepReport? _report;
  int _scoreCount = 0;

  @override
  void initState() {
    super.initState();
    StudySessionRepository.instance.revision.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    StudySessionRepository.instance.revision.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      final scores = _loadScores();
      _scoreCount = scores.length;
      _report = DeepReport.build(
        scores,
        StudySessionRepository.instance.getAll(),
        now: widget.clock(),
      );
    });
  }

  List<MockScore> _loadScores() {
    final scores = StorageService.getMockScoreIds()
        .map(StorageService.getMockScoreJson)
        .whereType<String>()
        .map((v) {
          try {
            return MockScore.fromJsonString(v);
          } catch (_) {
            return null;
          }
        })
        .whereType<MockScore>()
        .toList();
    scores.sort((a, b) => b.date.compareTo(a.date));
    return scores;
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    if (report == null) {
      return Scaffold(
        backgroundColor: AppColors.bgPage,
        appBar: AppBar(title: const Text('Báo cáo học tập')),
        body: const LoadingStateView(message: 'Đang tổng hợp số liệu…'),
      );
    }

    if (!report.hasScores && !report.hasSessions) {
      return Scaffold(
        backgroundColor: AppColors.bgPage,
        appBar: AppBar(title: const Text('Báo cáo học tập')),
        body: EmptyStateView(
          icon: Icons.insights_outlined,
          title: 'Chưa có dữ liệu để phân tích',
          description:
              'Thêm vài điểm thi thử và học một vài phiên để báo cáo bắt đầu có ý nghĩa.',
          actionLabel: widget.onStartStudy != null ? 'Bắt đầu học' : null,
          onAction: widget.onStartStudy,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(title: const Text('Báo cáo học tập')),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(report),
              const SizedBox(height: 14),
              _statCard(report),
              const SizedBox(height: 14),
              if (report.hasScores) ...[
                _trendCard(report),
                const SizedBox(height: 14),
                _subjectCard(report),
                const SizedBox(height: 14),
                _topicCard(report),
                const SizedBox(height: 14),
              ] else
                _emptyBanner(),
              if (report.hasSessions) ...[
                _hoursCard(report),
                const SizedBox(height: 14),
              ],
              _privacyNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(DeepReport report) {
    final hours = report.hoursComparison.thisWeekMinutes;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nhìn lại dài hạn',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                report.hasScores && report.hasSessions
                    ? 'Xu hướng điểm, năng lực chủ đề và thời gian học'
                    : report.hasScores
                        ? 'Xu hướng điểm và năng lực theo chủ đề'
                        : 'Thời gian học và hiệu quả phiên',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        _hoursBadge(hours),
      ],
    );
  }

  /// "12 phút tuần này" — mốc tham chiếu nhanh bên cạnh tiêu đề.
  Widget _hoursBadge(int minutes) {
    final text = minutes >= 60
        ? '${(minutes / 60).toStringAsFixed(1)} giờ'
        : '$minutes phút';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('Tuần này',
              style: TextStyle(
                  fontSize: 9.5, color: AppColors.textSecondary)),
          Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.greenDark)),
        ],
      ),
    );
  }

  Widget _statCard(DeepReport report) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          _statCell(
            value: report.hasScores
                ? report.overallAverage.toStringAsFixed(1)
                : '—',
            label: 'Điểm TB các môn',
            color: report.hasScores ? AppColors.primary : AppColors.textMuted,
          ),
          _statDivider(),
          _statCell(
            value: '$_scoreCount',
            label: 'Lần thi thử',
            color: AppColors.textPrimary,
          ),
          _statDivider(),
          _statCell(
            value: _weekDelta(report),
            label: 'So tuần trước',
            color: _deltaColor(report.hoursComparison.percentDelta),
          ),
        ],
      ),
    );
  }

  Widget _statCell({
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(
        width: 1,
        height: 28,
        color: AppColors.divider,
      );

  /// "+45%" / "−12%" / "0%" — `null` khi tuần trước chưa có giờ (không mốc).
  String _weekDelta(DeepReport report) {
    final pct = report.hoursComparison.percentDelta;
    if (pct == null) return '—';
    return pct > 0 ? '+$pct%' : '$pct%';
  }

  Color _deltaColor(int? percent) {
    if (percent == null || percent == 0) return AppColors.textPrimary;
    return percent > 0 ? AppColors.greenDark : AppColors.orangeDark;
  }

  // ------------------------------------------------------------------
  // Điểm
  // ------------------------------------------------------------------

  Widget _trendCard(DeepReport report) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.stacked_line_chart_rounded,
            title: 'Xu hướng điểm theo tuần',
            color: AppColors.purple,
          ),
          const SizedBox(height: 12),
          _trendChart(report),
          const SizedBox(height: 12),
          _trendMessage(report),
        ],
      ),
    );
  }

  /// Biểu đồ cột tối giản vẽ bằng Container — không kéo thư viện chart nào
  /// vào chỉ cho một màn ít dùng (nhất quán với các biểu đồ tay khác).
  Widget _trendChart(DeepReport report) {
    final buckets = report.weeklyBuckets;
    const chartHeight = 84.0;
    final maxValue = buckets
        .map((b) => b.average)
        .fold(3.0, (m, v) => v > m ? v : m);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final bucket in buckets)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(bucket.average.toStringAsFixed(1),
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: _scoreColor(bucket.average))),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: (bucket.average / maxValue.clamp(3, 10)) * chartHeight,
                  decoration: BoxDecoration(
                    color: _scoreColor(bucket.average),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
                const SizedBox(height: 3),
                Text(bucket.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 8.5, color: AppColors.textMuted)),
              ],
            ),
          ),
      ],
    );
  }

  Color _scoreColor(double value) {
    if (value >= 8) return AppColors.greenDark;
    if (value >= 6.5) return AppColors.orangeDark;
    return AppColors.red;
  }

  Widget _trendMessage(DeepReport report) {
    final trend = report.scoreTrend;
    final String text;
    final Color color;
    if (trend.trend == 'up') {
      text = 'Điểm đang tăng +${trend.delta!.toStringAsFixed(1)} so với lần trước.';
      color = AppColors.greenDark;
    } else if (trend.trend == 'down') {
      text = 'Điểm đang giảm nhẹ. Xem phần chủ đề yếu bên dưới để ưu tiên ôn lại.';
      color = AppColors.orangeDark;
    } else if (trend.trend == 'flat') {
      text = 'Điểm đang ổn định. Giữ nhịp thi thử định kỳ nhé!';
      color = AppColors.textSecondary;
    } else {
      text = report.weeklyBuckets.length >= 2
          ? 'Cần nhiều điểm hơn để nhận định xu hướng.'
          : 'Thi thử 1 lần nữa để thấy rõ xu hướng.';
      color = AppColors.textMuted;
    }
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _subjectCard(DeepReport report) {
    final subjects = report.subjects;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.rule_rounded,
            title: 'Điểm theo môn',
            color: AppColors.blue,
          ),
          const SizedBox(height: 4),
          const Text('Trung bình từng môn + chiều hướng thay đổi',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          const SizedBox(height: 12),
          if (subjects.isEmpty)
            const Text('Cần đủ 2 điểm một môn để so sánh xu hướng.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted))
          else
            for (final subject in subjects) ...[
              _subjectRow(subject),
              const Divider(height: 14),
            ],
        ],
      ),
    );
  }

  Widget _subjectRow(SubjectScore subject) {
    return Row(
      children: [
        Expanded(
          child: Text(subject.subject,
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 8),
        Text('TB ${subject.avg.toStringAsFixed(1)}',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _scoreColor(subject.avg))),
        const SizedBox(width: 6),
        Icon(
          subject.improving
              ? Icons.trending_up_rounded
              : subject.declining
                  ? Icons.trending_down_rounded
                  : Icons.trending_flat_rounded,
          size: 16,
          color: subject.improving
              ? AppColors.greenDark
              : subject.declining
                  ? AppColors.orangeDark
                  : AppColors.textMuted,
        ),
        const SizedBox(width: 6),
        Text('×${subject.count}',
            style:
                const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }

  Widget _topicCard(DeepReport report) {
    final topics = report.weakTopics;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.priority_high_rounded,
            title: 'Chủ đề cần ưu tiên ôn',
            color: AppColors.orange,
          ),
          const SizedBox(height: 4),
          const Text('Chủ đề trung bình dưới 6.5 điểm',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          const SizedBox(height: 12),
          if (topics.isEmpty)
            const Text(
                'Chưa có chủ đề nào dưới ngưỡng 6.5 — giữ nhịp ôn tập nhé! Nếu chưa từng ghi chủ đề khi nhập điểm, hãy ghi để báo cáo chi tiết hơn.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted))
          else
            for (final topic in topics) ...[
              _topicRow(topic),
              const Divider(height: 14),
            ],
        ],
      ),
    );
  }

  Widget _topicRow(WeakTopic topic) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(topic.topic,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800)),
              Text(topic.subject,
                  style: const TextStyle(
                      fontSize: 10.5, color: AppColors.textMuted)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(topic.average.toStringAsFixed(1),
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _scoreColor(topic.average))),
        const SizedBox(width: 6),
        Text('×${topic.attempts}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }

  Widget _emptyBanner() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.stacked_line_chart_rounded,
              size: 20, color: AppColors.orangeDark),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
                'Chưa có điểm thi thử — thêm điểm ở màn Điểm thi để báo cáo có thêm phần xu hướng và năng lực chủ đề.',
                style:
                    TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Thời gian học
  // ------------------------------------------------------------------

  Widget _hoursCard(DeepReport report) {
    final comparison = report.hoursComparison.message;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.schedule_rounded,
            title: 'Thời gian học tuần này',
            color: AppColors.greenDark,
          ),
          const SizedBox(height: 12),
          if (comparison != null)
            Text(comparison,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textSecondary)),
          if (report.efficiencyReport != null) ...[
            const SizedBox(height: 10),
            _efficiencyRow(report.efficiencyReport!),
          ],
          if (report.bestTimeTip != null) ...[
            const SizedBox(height: 10),
            _tipRow(Icons.wb_twilight_rounded, report.bestTimeTip!),
          ],
          if (report.focusPatternTipValue != null) ...[
            const SizedBox(height: 10),
            _tipRow(Icons.av_timer_rounded, report.focusPatternTipValue!),
          ],
        ],
      ),
    );
  }

  Widget _efficiencyRow(EfficiencyReport efficiency) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.greenSoft,
          ),
          child: Center(
            child: Text('${efficiency.score}',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.greenDark)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hiệu quả phiên học',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              Text(efficiency.description,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tipRow(IconData icon, String tip) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.blueDark),
        const SizedBox(width: 10),
        Expanded(
          child: Text(tip,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _privacyNote() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.offline_pin_rounded, size: 14, color: AppColors.textMuted),
          SizedBox(width: 6),
          Expanded(
            child: Text(
                'Báo cáo này chạy hoàn toàn trên thiết bị — không gửi dữ liệu lên mạng.',
                style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
      ],
    );
  }
}