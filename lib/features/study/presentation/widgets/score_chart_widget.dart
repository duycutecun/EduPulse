import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../exams/domain/models/exam_model.dart';
import '../../domain/models/study_models.dart';
import '../../domain/score_analysis.dart';

/// Biểu đồ tiến bộ điểm thi thử theo thời gian (đặc tả mục 41).
///
/// Nguyên tắc áp dụng:
/// - Chart chỉ hiện khi có **≥ 2 điểm cùng môn** — 1 điểm chưa đủ vẽ
///   xu hướng, thay vào đó hiện card gợi ý thi thử thêm (mục 10.8).
/// - Đường mục tiêu (target) chỉ vẽ khi kỳ thi chính có `targetScore`.
/// - Insight dùng `scoreInsight` — câu "có vẻ/thử", không phán xét khi
///   điểm giảm (mục 36, 40).
class ScoreChartWidget extends StatelessWidget {
  /// Điểm đã sort mới → cũ (như `_scores` trong StudyScreen).
  final List<MockScore> scores;

  /// Kỳ thi chính (nếu có) — dùng để vẽ đường target.
  final ExamModel? primaryExam;

  const ScoreChartWidget({
    super.key,
    required this.scores,
    this.primaryExam,
  });

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) return _buildEmpty();

    // Nhóm theo môn: mỗi môn một chuỗi điểm sort cũ → mới.
    final bySubject = <String, List<MockScore>>{};
    for (final s in scores) {
      (bySubject[s.subject] ??= []).add(s);
    }

    // Môn có nhiều điểm nhất làm chuỗi chính.
    String? mainSubject;
    var mainCount = 0;
    bySubject.forEach((subject, list) {
      if (list.length > mainCount) {
        mainSubject = subject;
        mainCount = list.length;
      }
    });

    final mainScores =
        (mainSubject == null ? null : bySubject[mainSubject])
                ?.toList() ??
            <MockScore>[]
      ..sort((a, b) => a.date.compareTo(b.date));

    if (mainScores.length < 2) {
      return _buildNeedMoreScores(mainSubject);
    }

    final trend = analyzeTrend(mainScores);
    final insight =
        scoreInsight(mainScores, targetScore: primaryExam?.targetScore);
    final subjects = analyzeBySubject(scores);

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Tiến bộ điểm thi thử',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ),
              _trendChip(trend),
            ],
          ),
          const SizedBox(height: 4),
          Text('Môn $mainSubject • ${mainScores.length} lần thi',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          _buildLineChart(mainScores),
          if (insight != null) ...[
            const SizedBox(height: 14),
            _insightRow(insight),
          ],
          if (subjects.length >= 2) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Text('So sánh giữa các môn',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            ...subjects.take(4).map(_buildSubjectRow),
          ],
        ],
      ),
    );
  }

  Widget _trendChip(ScoreTrend trend) {
    final isUp = trend.trend == 'up';
    final isDown = trend.trend == 'down';
    final color = isUp ? AppColors.green : (isDown ? AppColors.orange : AppColors.blue);
    final icon = isUp
        ? Icons.trending_up_rounded
        : (isDown ? Icons.trending_down_rounded : Icons.trending_flat_rounded);
    final label = trend.trend == null
        ? '—'
        : isUp
            ? '+${trend.delta!.toStringAsFixed(1)}'
            : isDown
                ? trend.delta!.toStringAsFixed(1)
                : 'Ổn định';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  /// Biểu đồ đường vẽ bằng CustomPainter — điểm 0..10, trục y từ
  /// [floor, ceiling] vừa khít dữ liệu, kèm đường target (nếu có).
  Widget _buildLineChart(List<MockScore> mainScores) {
    final target = primaryExam?.targetScore;
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: CustomPaint(
        painter: _ScoreLinePainter(
          scores: mainScores,
          targetScore: target,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nhãn min/max trên cùng — painter vẽ dưới nền.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('10',
                    style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                Text(mainScores.last.score.toStringAsFixed(1),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmtDate(mainScores.first.date),
                    style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                Text(_fmtDate(mainScores.last.date),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _insightRow(String insight) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.insights_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(insight,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectRow(SubjectScore s) {
    final color = s.declining ? AppColors.orange : AppColors.primary;
    final deltaLabel = s.delta >= 0
        ? '+${s.delta.toStringAsFixed(1)}'
        : s.delta.toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(s.subject,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ),
          Text('TB ${s.avg.toStringAsFixed(1)}',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(deltaLabel,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildNeedMoreScores(String? subject) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.show_chart_rounded,
                size: 20, color: AppColors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chưa đủ dữ liệu vẽ biểu đồ',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  subject == null
                      ? 'Ghi 2 điểm thi thử cùng môn để EduPulse vẽ tiến bộ của bạn.'
                      : 'Môn "$subject" mới có 1 điểm — thi thử thêm 1 lần nữa để thấy xu hướng.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.show_chart_rounded,
                size: 20, color: AppColors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chưa có điểm thi thử',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  'Ghi điểm sau mỗi lần thi thử để EduPulse theo dõi tiến bộ và đề xuất điều chỉnh.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtDate(DateTime d) => '${d.day}/${d.month}';

class _ScoreLinePainter extends CustomPainter {
  final List<MockScore> scores; // sort cũ → mới
  final double? targetScore;

  _ScoreLinePainter({required this.scores, this.targetScore});

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.length < 2) return;

    // Trục y: floor/ceil vừa khít dữ liệu (cách nhau ≥ 1.5 điểm), max 10.
    var minS = scores.map((s) => s.score).reduce((a, b) => a < b ? a : b);
    var maxS = scores.map((s) => s.score).reduce((a, b) => a > b ? a : b);
    if (targetScore != null) {
      minS = minS < targetScore! ? minS : targetScore!;
      maxS = maxS > targetScore! ? maxS : targetScore!;
    }
    var lo = (minS - 0.8).clamp(0.0, 10.0);
    var hi = (maxS + 0.8).clamp(0.0, 10.0);
    if (hi - lo < 1.5) {
      final mid = (hi + lo) / 2;
      lo = (mid - 0.75).clamp(0.0, 10.0);
      hi = (mid + 0.75).clamp(0.0, 10.0);
    }

    // Khoảng đệm cho nhãn ngày (trên/dưới) và phải.
    const padTop = 14.0;
    const padBottom = 16.0;
    const padRight = 10.0;
    final chartW = size.width - padRight;
    final chartH = size.height - padTop - padBottom;

    Offset pointAt(int i, double score) {
      final x = scores.length == 1
          ? chartW / 2
          : i * chartW / (scores.length - 1);
      final y = padTop + chartH * (1 - (score - lo) / (hi - lo));
      return Offset(x, y);
    }

    // Lưới ngang mờ.
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var g = 0; g <= 3; g++) {
      final y = padTop + chartH * g / 3;
      canvas.drawLine(Offset(0, y), Offset(chartW, y), gridPaint);
    }

    // Đường target (nét đứt, màu cam nhạt).
    if (targetScore != null && targetScore! >= lo && targetScore! <= hi) {
      final y = pointAt(0, targetScore!).dy;
      final dashPaint = Paint()
        ..color = AppColors.orange.withValues(alpha: 0.7)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      const dashLen = 6.0;
      const gapLen = 5.0;
      var x = 0.0;
      while (x < chartW) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x + dashLen > chartW ? chartW : x + dashLen, y),
          dashPaint,
        );
        x += dashLen + gapLen;
      }
    }

    // Đường điểm — gradient dọc từ primary sang blue.
    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: 0.18),
          AppColors.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, padTop, chartW, chartH));

    final path = Path();
    for (var i = 0; i < scores.length; i++) {
      final p = pointAt(i, scores[i].score);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    // Nền gradient dưới đường.
    final fillPath = Path.from(path)
      ..lineTo(chartW, padTop + chartH)
      ..lineTo(0, padTop + chartH)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Điểm tròn + nhãn giá trị.
    for (var i = 0; i < scores.length; i++) {
      final p = pointAt(i, scores[i].score);
      canvas.drawCircle(
        p,
        i == scores.length - 1 ? 4.5 : 3.5,
        Paint()..color = AppColors.primary,
      );
      canvas.drawCircle(
        p,
        i == scores.length - 1 ? 2 : 1.5,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreLinePainter old) =>
      old.scores.length != scores.length ||
      old.targetScore != targetScore ||
      old.scores.last.score != scores.last.score;
}
