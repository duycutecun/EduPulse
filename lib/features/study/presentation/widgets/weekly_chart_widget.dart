import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../domain/models/study_models.dart';

class WeeklyChartWidget extends StatelessWidget {
  final List<StudyLog> logs;

  const WeeklyChartWidget({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate daily hours for past 7 days
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

    // Default mock distribution if logs are empty to showcase rich UI
    if (logs.isEmpty) {
      dailyHours[0] = 3.5;
      dailyHours[1] = 4.0;
      dailyHours[2] = 2.5;
      dailyHours[3] = 5.0;
      dailyHours[4] = 4.5;
      dailyHours[5] = 6.0;
      dailyHours[6] = 3.0;
    }

    final maxHours = dailyHours.reduce((curr, next) => curr > next ? curr : next);
    final safeMax = maxHours > 0 ? maxHours : 8.0;
    final totalWeeklyHours = dailyHours.fold(0.0, (sum, val) => sum + val);
    final avgDaily = totalWeeklyHours / 7;

    // Subject breakdown
    final subjectMap = <String, double>{};
    for (final log in logs) {
      subjectMap[log.subject] = (subjectMap[log.subject] ?? 0) + log.hours;
    }
    if (subjectMap.isEmpty) {
      subjectMap['Toán học 📐'] = 8.5;
      subjectMap['Vật lý ⚡'] = 6.0;
      subjectMap['Hóa học 🧪'] = 5.0;
      subjectMap['Tiếng Anh 🇬🇧'] = 4.5;
      subjectMap['Ngữ văn 📖'] = 4.5;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary cards row
        Row(
          children: [
            Expanded(
              child: GlassCard(
                borderRadius: 18,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(CupertinoIcons.clock_fill,
                            size: 16, color: AppColors.neonCyan),
                        const SizedBox(width: 6),
                        Text(
                          'Tổng tuần này',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${totalWeeklyHours.toStringAsFixed(1)}h',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassCard(
                borderRadius: 18,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(CupertinoIcons.chart_bar_alt_fill,
                            size: 16, color: AppColors.appleGreen),
                        const SizedBox(width: 6),
                        Text(
                          'Trung bình/ngày',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${avgDaily.toStringAsFixed(1)}h/ngày',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.appleGreen,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Weekly Bar Chart Glass Card
        GlassCard(
          borderRadius: 22,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Biểu đồ giờ học trong tuần',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.appleIndigo.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Phong độ cao 🔥',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.appleIndigo,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Bars
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
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                            color: isToday
                                ? AppColors.neonCyan
                                : (isDark ? Colors.white54 : Colors.black45),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 22,
                          height: 90 * barHeightFactor,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: isToday
                                ? const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      AppColors.neonCyan,
                                      AppColors.neonPurple,
                                    ],
                                  )
                                : LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      AppColors.appleIndigo.withValues(alpha: 0.5),
                                      AppColors.appleIndigo,
                                    ],
                                  ),
                            boxShadow: isToday
                                ? [
                                    BoxShadow(
                                      color: AppColors.neonCyan.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dayNames[index],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday
                                ? (isDark ? Colors.white : Colors.black)
                                : (isDark ? Colors.white38 : Colors.black38),
                          ),
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

        // Subject Breakdown Card
        GlassCard(
          borderRadius: 22,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Phân bổ thời gian theo môn',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
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
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${entry.value.toStringAsFixed(1)}h (${(percent * 100).toInt()}%)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 6,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.neonCyan,
                          ),
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
