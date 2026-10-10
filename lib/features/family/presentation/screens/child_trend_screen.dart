import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/family/family_models.dart';

/// Xu hướng học tập của con theo thời gian — vẽ từ chính các báo cáo con đã
/// gửi (không suy diễn thêm dữ liệu nào).
///
/// Ba biểu đồ đơn giản: thời gian tập trung, chỉ số sẵn sàng thi, và điểm thi
/// thử. Mỗi điểm là một lần con gửi báo cáo, nối lại thành đường xu hướng.
class ChildTrendScreen extends StatelessWidget {
  const ChildTrendScreen({
    super.key,
    required this.child,
    required this.reports,
  });

  final FamilyMember child;

  /// Báo cáo con đã gửi (mới nhất đứng đầu, đúng như [ChildReportScreen] giữ).
  final List<SharedReport> reports;

  @override
  Widget build(BuildContext context) {
    // Mới nhất đứng đầu → đảo lại thành cũ → mới để vẽ từ trái sang phải.
    final ordered = reports.reversed.toList();

    final focus = _series(ordered, 'study_time', _parseMinutes);
    final readiness = _series(ordered, 'readiness', _parseNumber);
    final mock = _series(ordered, 'mock_score', _parseNumber);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Xu hướng & cột mốc',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('Tiến độ của ${child.name}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          if (ordered.isEmpty)
            _emptyCard()
          else ...[
            _chartCard(
              title: 'Thời gian tập trung',
              unit: 'phút',
              color: AppColors.primary,
              points: focus,
              emptyHint: 'Chưa có dữ liệu thời gian tập trung trong các báo cáo.',
            ),
            const SizedBox(height: 14),
            _chartCard(
              title: 'Chỉ số sẵn sàng thi',
              unit: '/100',
              color: AppColors.purple,
              points: readiness,
              emptyHint: 'Chưa có dữ liệu chỉ số sẵn sàng.',
            ),
            const SizedBox(height: 14),
            _chartCard(
              title: 'Điểm thi thử',
              unit: '/10',
              color: AppColors.orange,
              points: mock,
              emptyHint: 'Chưa có điểm thi thử trong các báo cáo.',
            ),
            const SizedBox(height: 18),
            _milestones(ordered),
          ],
        ],
      ),
    );
  }

  Widget _chartCard({
    required String title,
    required String unit,
    required Color color,
    required List<_Point> points,
    required String emptyHint,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          if (points.length < 2)
            Text(emptyHint,
                style: const TextStyle(
                    fontSize: 12.5, height: 1.4, color: AppColors.textMuted))
          else ...[
            SizedBox(
              height: 140,
              child: CustomPaint(
                size: Size.infinite,
                painter: _LineChartPainter(points: points, color: color),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${points.first.value.toStringAsFixed(1)}$unit',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
                Text('${points.last.value.toStringAsFixed(1)}$unit',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _milestones(List<SharedReport> ordered) {
    final rows = <Widget>[];
    for (final r in ordered.reversed) {
      final report = r.report;
      if (report == null) continue;
      final headline = report.headline.trim();
      if (headline.isEmpty) continue;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 5),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_dateLabel(r.createdAt),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(headline,
                      style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cột mốc',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Text('📈', style: TextStyle(fontSize: 34)),
          SizedBox(height: 8),
          Text('Chưa có báo cáo để vẽ xu hướng',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text(
            'Khi con gửi báo cáo tuần vài lần, biểu đồ và cột mốc sẽ hiện ở đây.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12.5, height: 1.45, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Lấy chuỗi điểm theo thứ tự thời gian cho một mục trong báo cáo.
  static List<_Point> _series(
    List<SharedReport> ordered,
    String key,
    double? Function(String raw) parse,
  ) {
    final points = <_Point>[];
    for (final r in ordered) {
      final report = r.report;
      if (report == null) continue;
      for (final item in report.items) {
        if (item.key != key) continue;
        final value = parse(item.value);
        if (value == null) break;
        points.add(_Point(at: r.createdAt, value: value));
        break;
      }
    }
    return points;
  }

  /// "120 phút" → 120.0; "8.5/10" → 8.5; "72/100" → 72.0.
  static double? _parseNumber(String raw) {
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(raw);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  static double? _parseMinutes(String raw) => _parseNumber(raw);

  static String _dateLabel(DateTime at) =>
      '${at.day}/${at.month}/${at.year}';
}

class _Point {
  const _Point({required this.at, required this.value});

  final DateTime at;
  final double value;
}

/// Vẽ đường xu hướng đơn giản: trục tung theo giá trị, trục hoành theo thời
/// gian. Không phụ thuộc thư viện ngoài.
class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.points, required this.color});

  final List<_Point> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    double minV = points.first.value;
    double maxV = points.first.value;
    for (final p in points) {
      minV = p.value < minV ? p.value : minV;
      maxV = p.value > maxV ? p.value : maxV;
    }
    // Mở rộng biên để đường không dính sát mép; nếu phẳng thì tạo khoảng nhỏ.
    if ((maxV - minV).abs() < 0.001) {
      maxV += 1;
      minV -= 1;
    }
    final padding = (maxV - minV) * 0.15;
    minV -= padding;
    maxV += padding;

    final dx = size.width / (points.length - 1);
    double yFor(double v) =>
        size.height - ((v - minV) / (maxV - minV)) * size.height;

    // Lưới ngang mờ.
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    final fill = Path();
    for (var i = 0; i < points.length; i++) {
      final x = dx * i;
      final y = yFor(points[i].value);
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fill, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = color;
    for (var i = 0; i < points.length; i++) {
      final x = dx * i;
      final y = yFor(points[i].value);
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.points != points || old.color != color;
}
