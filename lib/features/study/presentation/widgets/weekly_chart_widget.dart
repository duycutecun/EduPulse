import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../domain/models/study_models.dart';

class WeeklyChartWidget extends StatelessWidget {
  final List<StudyLog> logs;

  const WeeklyChartWidget({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final dailyHours = List<double>.filled(7, 0.0);

    for (final log in logs) {
      final diff = now.difference(log.date).inDays;
      if (diff >= 0 && diff < 7) {
        final weekdayIndex = (log.date.weekday - 1) % 7;
        dailyHours[weekdayIndex] += log.hours;
      }
    }

    if (logs.isEmpty) {
      dailyHours[0] = 3.5; dailyHours[1] = 4.0; dailyHours[2] = 2.5;
      dailyHours[3] = 5.0; dailyHours[4] = 4.5; dailyHours[5] = 6.0; dailyHours[6] = 3.0;
    }

    final maxHours = dailyHours.reduce((curr, next) => curr > next ? curr : next);
    final safeMax = maxHours > 0 ? maxHours : 8.0;
    final totalWeeklyHours = dailyHours.fold(0.0, (sum, val) => sum + val);
    final avgDaily = totalWeeklyHours / 7;

    final subjectMap = <String, double>{};
    for (final log in logs) {
      subjectMap[log.subject] = (subjectMap[log.subject] ?? 0) + log.hours;
    }
    if (subjectMap.isEmpty) {
      subjectMap['Toán học'] = 8.5;
      subjectMap['Vật lý'] = 6.0;
      subjectMap['Hóa học'] = 5.0;
      subjectMap['Tiếng Anh'] = 4.5;
      subjectMap['Ngữ văn'] = 4.5;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.access_time, size: 16, color: AppColors.blue),
                      SizedBox(width: 6),
                      Text('Tuần này', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ]),
                    const SizedBox(height: 6),
                    Text('${totalWeeklyHours.toStringAsFixed(1)}h', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.trending_up, size: 16, color: AppColors.green),
                      SizedBox(width: 6),
                      Text('Trung bình', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ]),
                    const SizedBox(height: 6),
                    Text('${avgDaily.toStringAsFixed(1)}h/ngày', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.green)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Giờ học trong tuần', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: const Text('Phong độ cao!', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 140,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    final h = dailyHours[index];
                    final barHeightFactor = (h / safeMax).clamp(0.08, 1.0);
                    final isToday = (now.weekday - 1) % 7 == index;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          h > 0 ? '${h.toStringAsFixed(1)}h' : '-',
                          style: TextStyle(fontSize: 10, fontWeight: isToday ? FontWeight.bold : FontWeight.w500, color: isToday ? AppColors.green : AppColors.textMuted),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 22,
                          height: 90 * barHeightFactor,
                          decoration: BoxDecoration(
                            color: isToday ? AppColors.green : AppColors.blue.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dayNames[index],
                          style: TextStyle(fontSize: 12, fontWeight: isToday ? FontWeight.bold : FontWeight.normal, color: isToday ? AppColors.textPrimary : AppColors.textMuted),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phân bổ theo môn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              ...subjectMap.entries.map((entry) {
                final percent = (entry.value / (totalWeeklyHours > 0 ? totalWeeklyHours : 28.5)).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          Text('${entry.value.toStringAsFixed(1)}h (${(percent * 100).toInt()}%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 8,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
