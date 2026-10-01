import 'package:flutter/material.dart';

import '../../../../core/ai/ai_daily_briefing.dart';
import '../../../../core/ai/readiness_score.dart';
import '../../../../core/constants/app_colors.dart';

/// Card chỉ số sẵn sàng thi + bản tin AI hằng ngày hiển thị trên Home.
///
/// Cập nhật qua [AiDailyBriefing.revision] — khi bản tin mới sinh xong
/// (background), card tự render lại mà không cần điều hướng ra vào.
class AiReadinessCard extends StatefulWidget {
  const AiReadinessCard({super.key});

  @override
  State<AiReadinessCard> createState() => _AiReadinessCardState();
}

class _AiReadinessCardState extends State<AiReadinessCard> {
  DailyBriefing? _briefing;
  ReadinessResult? _readiness;

  @override
  void initState() {
    super.initState();
    _readiness = ReadinessScore.compute();
    AiDailyBriefing.load().then((b) {
      if (!mounted) return;
      setState(() => _briefing = b);
    });
    AiDailyBriefing.revision.addListener(_onRevision);
  }

  @override
  void dispose() {
    AiDailyBriefing.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() {
    if (!mounted) return;
    AiDailyBriefing.load().then((b) {
      if (!mounted) return;
      setState(() {
        _briefing = b;
        _readiness = ReadinessScore.compute();
      });
    });
  }

  void _openDetail() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final r = ReadinessScore.compute();
        if (r == null) {
          return const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Chưa đủ dữ liệu tính chỉ số — hãy thêm kỳ thi mục tiêu và nhập ít nhất 1 điểm thi thử.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          );
        }
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.92,
            builder: (ctx, scrollCtrl) => ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text('Chỉ số sẵn sàng thi',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                      'Hình chiếu của hành vi học tập thật lên khả năng đạt mục tiêu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                ),
                const SizedBox(height: 18),
                // Vòng điểm tổng
                Center(
                  child: SizedBox(
                    width: 132,
                    height: 132,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 132,
                          height: 132,
                          child: CircularProgressIndicator(
                            value: r.score / 100,
                            strokeWidth: 10,
                            backgroundColor: AppColors.progressBg,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                r.score >= 60 ? AppColors.primary : AppColors.orange),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${r.score}',
                                style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary)),
                            Text(r.band,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Thành phần
                ...r.factors.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(f.label,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary)),
                              ),
                              Text('${(f.value * 100).round()}%',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: f.value >= 0.6
                                          ? AppColors.primary
                                          : AppColors.orange)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: f.value,
                              minHeight: 6,
                              backgroundColor: AppColors.progressBg,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  f.value >= 0.6
                                      ? AppColors.primary
                                      : AppColors.orange),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(f.detail,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textMuted)),
                        ],
                      ),
                    )),
                if (r.levers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('🚀 3 đòn bẩy tăng điểm nhanh nhất',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  ...r.levers.map((l) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.rocket_launch_rounded,
                                size: 16, color: AppColors.purple),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(l,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.45,
                                      color: AppColors.textPrimary)),
                            ),
                          ],
                        ),
                      )),
                ],
                if (r.warnings.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('⚠️ Cảnh báo',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  ...r.warnings.map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 16, color: AppColors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(w,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.45,
                                      color: AppColors.textPrimary)),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _readiness;
    final b = _briefing;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Hàng chỉ số ---
          InkWell(
            onTap: _openDetail,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 52,
                        height: 52,
                        // value 1 khi chưa đủ dữ liệu: vòng đầy, tĩnh —
                        // tránh spinner indeterminate chạy vô hạn (gây
                        // treo pumpAndSettle trong test).
                        child: CircularProgressIndicator(
                          value: r == null ? 1 : r.score / 100,
                          strokeWidth: 5,
                          backgroundColor: AppColors.progressBg,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              r == null || r.score >= 60
                                  ? AppColors.primary
                                  : AppColors.orange),
                        ),
                      ),
                      Text(r == null ? '?' : '${r.score}',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r == null
                            ? 'Sẵn sàng thi: chưa đủ dữ liệu'
                            : 'Sẵn sàng thi: ${r.score}/100 · ${r.band}',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r == null
                            ? 'Thêm kỳ thi + nhập 1 điểm thi thử để AI đo.'
                            : (r.levers.isNotEmpty ? r.levers.first : ''),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted),
              ],
            ),
          ),
          // --- Bản tin AI ---
          if (b != null && !b.isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.blueSoft.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wb_sunny_rounded,
                          size: 14, color: AppColors.blue),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'BẢN TIN AI HÔM NAY'
                          '${b.source == 'ai' ? '' : ' (offline)'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColors.blue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(b.greeting,
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  if (b.focus.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...b.focus.take(3).map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ', style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.blue)),
                              Expanded(
                                child: Text(
                                    item.detail == null
                                        ? item.title
                                        : '${item.title} (${item.detail})',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.4,
                                        color: AppColors.textPrimary)),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
