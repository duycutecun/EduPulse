import 'package:flutter/material.dart';
import '../../../../core/utils/feedback_service.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/subject_catalog.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../exams/domain/exam_repository.dart';
import '../../../exams/domain/models/exam_model.dart';
import '../../../study/domain/repositories/study_session_repository.dart';
import '../../../tasks/domain/repositories/task_repository.dart';
import '../../domain/progress_engine.dart';
import '../../domain/progress_insights.dart';

/// FE-5.1 + FE-5.2 — Màn hình Tổng quan Tiến độ.
///
/// Trả lời câu hỏi \"tuần này mình tiến bộ hay thụt lùi?\" trong ~5 giây: một
/// thẻ tóm tắt hôm nay, một biểu đồ tuần tối giản, danh sách môn và cảnh báo
/// môn bị bỏ quên. Số liệu lấy từ [ProgressEngine] — không tự cộng tay ở UI.
class ProgressScreen extends StatefulWidget {
  /// Mở màn Quản lý Kỳ thi (FE-5.3) — truyền từ shell để dùng chung điều hướng.
  final VoidCallback? onOpenExams;

  /// G4-B: empty state phải có LỐI RA, không chỉ giải thích. Truyền từ shell
  /// để dùng chung điều hướng với các tab khác.
  final VoidCallback? onStartStudy;

  /// Nguồn thời gian, cho phép test cố định \"now\".
  final DateTime Function() clock;

  const ProgressScreen({
    super.key,
    this.onOpenExams,
    this.onStartStudy,
    this.clock = DateTime.now,
  });

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ProgressSnapshot? _snapshot;
  String? _aiInsight;
  bool _loadingAi = false;

  @override
  void initState() {
    super.initState();
    TaskRepository.instance.revision.addListener(_reload);
    StudySessionRepository.instance.revision.addListener(_reload);
    ExamRepository.instance.revision.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    TaskRepository.instance.revision.removeListener(_reload);
    StudySessionRepository.instance.revision.removeListener(_reload);
    ExamRepository.instance.revision.removeListener(_reload);
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

  Future<void> _askAi() async {
    final snapshot = _snapshot;
    if (snapshot == null || _loadingAi) return;
    setState(() => _loadingAi = true);
    final result = await ProgressInsights.generate(snapshot);
    if (!mounted) return;
    setState(() {
      _loadingAi = false;
      _aiInsight = result;
    });
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'AI cần kết nối mạng — nhận định bên dưới vẫn dựa trên số liệu thật.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    if (snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final exam = ExamRepository.instance.primaryExam;

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 14),
            if (exam != null) ...[
              _examCountdownCard(exam),
              const SizedBox(height: 14),
            ],
            _todayCard(snapshot.today),
            const SizedBox(height: 14),
            _weeklyCard(snapshot),
            const SizedBox(height: 14),
            _subjectSection(snapshot),
            const SizedBox(height: 14),
            _insightCard(snapshot),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Tiến độ học tập',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text('Nhìn nhanh tuần này bạn đang tiến bộ thế nào',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
        if (widget.onOpenExams != null)
          IconButton(
            tooltip: 'Quản lý kỳ thi',
            onPressed: widget.onOpenExams,
            icon: const Icon(Icons.flag_outlined),
          ),
      ],
    );
  }

  /// FE-5.3 — đồng hồ đếm ngược kỳ thi chính, luôn hiện diện làm kim chỉ nam.
  Widget _examCountdownCard(ExamModel exam) {
    final now = widget.clock();
    final days = exam.daysLeftAt(now);
    final isOver = exam.isExamDayOverAt(now);
    final phaseLabel = switch (exam.phaseAt(now)) {
      ExamPhase.revision => 'Giai đoạn nước rút — tập trung ôn trọng tâm',
      ExamPhase.examDay => 'Hôm nay là ngày thi — bình tĩnh và tự tin!',
      ExamPhase.postExam => 'Kỳ thi đã kết thúc — nghỉ ngơi và nhìn lại',
      ExamPhase.normal => 'Còn nhiều thời gian — xây nền vững chắc',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.purpleLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(exam.emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exam.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(phaseLabel,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            children: [
              Text(isOver ? '—' : '$days',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isOver ? AppColors.textMuted : AppColors.purple)),
              Text(isOver ? 'đã thi' : 'ngày',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _todayCard(DayProgress today) {
    final rate = (today.completionRate * 100).round();
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.today_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Hôm nay',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _metric('${today.studyMinutes} phút', 'Thời gian học'),
              const SizedBox(width: 8),
              _metric('${today.tasksCompleted}/${today.tasksTotal}',
                  'Nhiệm vụ xong'),
              const SizedBox(width: 8),
              _metric('$rate%', 'Tỉ lệ hoàn thành'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weeklyCard(ProgressSnapshot snapshot) {
    final week = snapshot.week;
    final rate = (week.completionRate * 100).round();
    final delta = snapshot.weekDeltaPercent;
    final maxMinutes = week.dailyMinutes.isEmpty
        ? 0
        : week.dailyMinutes.reduce((a, b) => a > b ? a : b);
    final safeMax = maxMinutes > 0 ? maxMinutes : 60;
    final now = widget.clock();
    final dayNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    final deltaText = delta == null
        ? null
        : delta > 0
            ? '↑ $delta% so với tuần trước'
            : delta < 0
                ? '↓ ${-delta}% so với tuần trước'
                : 'Duy trì như tuần trước';
    final deltaColor = delta == null || delta == 0
        ? AppColors.textMuted
        : delta > 0
            ? AppColors.primary
            : AppColors.orange;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up_rounded,
                  size: 18, color: AppColors.blue),
              const SizedBox(width: 8),
              const Text('Tuần này',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              if (deltaText != null) ...[
                const SizedBox(width: 8),
                // Expanded + ellipsis: chuỗi delta dài ("↑ 325% so với tuần
                // trước") không được đẩy tràn khi màn hẹp hoặc chữ lớn.
                Expanded(
                  child: Text(deltaText,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: deltaColor)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _metric(
                  '${week.totalHours.toStringAsFixed(1)}h', 'Tổng thời lượng'),
              const SizedBox(width: 8),
              _metric('$rate%', 'Tỉ lệ hoàn thành'),
              const SizedBox(width: 8),
              _metric('${(week.avgDailyMinutes / 60).toStringAsFixed(1)}h',
                  'TB mỗi ngày'),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            // Cao theo cỡ chữ: nhãn ngày + số phút phóng to vẫn không đè lên
            // cột (tránh tràn dọc khi người dùng chọn cỡ chữ lớn).
            height: MediaQuery.textScalerOf(context).scale(120),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final minutes = week.dailyMinutes[index];
                final factor = (minutes / safeMax).clamp(0.06, 1.0);
                final isToday = (now.weekday - 1) % 7 == index;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(minutes > 0 ? '$minutes' : '-',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.w500,
                            color: isToday
                                ? AppColors.primary
                                : AppColors.textMuted)),
                    const SizedBox(height: 6),
                    Container(
                      width: 22,
                      height: 72 * factor,
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppColors.primary
                            : AppColors.blue.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(dayNames[index],
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday
                                ? AppColors.textPrimary
                                : AppColors.textMuted)),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subjectSection(ProgressSnapshot snapshot) {
    final subjects = snapshot.subjects;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.menu_book_rounded, size: 18, color: AppColors.purple),
              SizedBox(width: 8),
              Expanded(
                child: Text('Tiến độ theo môn',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Thời gian, số bài và mức độ hiểu bài trong tuần',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 12),
          if (subjects.isEmpty)
            // UX mục 11 "No progress" + G4-B: không để trống — luôn nói rõ dữ
            // liệu gì sẽ xuất hiện sau khi học, VÀ đưa người dùng tới chỗ tạo
            // ra dữ liệu đó bằng một chạm. Giải thích mà không có nút bấm thì
            // người học vẫn phải tự mò về tab Hôm nay.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chưa có dữ liệu học trong tuần này.',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Sau mỗi phiên Focus, thẻ này sẽ hiện thời gian học, số bài '
                    'và xu hướng ↑/→/↓ của từng môn.',
                    style: TextStyle(
                        fontSize: 12, height: 1.4, color: AppColors.textMuted),
                  ),
                  if (widget.onStartStudy != null) ...[
                    const SizedBox(height: 12),
                    PrimaryButton(
                      key: const Key('progress-start-study'),
                      label: 'Bắt đầu học ngay',
                      icon: Icons.play_arrow_rounded,
                      onPressed: () {
                        FeedbackService.light();
                        widget.onStartStudy!();
                      },
                    ),
                  ],
                ],
              ),
            )
          else
            for (final s in subjects)
              _subjectRow(s, snapshot.week.totalMinutes),
          if (snapshot.neglectedSubjects.isNotEmpty) ...[
            const SizedBox(height: 6),
            _neglectBanner(snapshot.neglectedSubjects),
          ],
        ],
      ),
    );
  }

  Widget _subjectRow(SubjectProgress s, int weekTotal) {
    final percent =
        weekTotal == 0 ? 0.0 : (s.minutes / weekTotal).clamp(0.0, 1.0);
    final understanding = s.avgUnderstanding;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Icon(AppSubjects.iconOf(s.subject),
                  size: 16, color: AppSubjects.colorOf(s.subject)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  // Mũi tên xu hướng (đặc tả 5.12: `Toán ↑`, `Vật lý →`) chỉ
                  // hiện khi có đủ dữ liệu ở cả kỳ này lẫn kỳ trước.
                  '${AppSubjects.displayName(s.subject)}${_trendSuffix(s.trend)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
              Text('${s.hours.toStringAsFixed(1)}h • ${s.sessionCount} phiên',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppSubjects.colorOf(s.subject)),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                s.tasksTotal > 0
                    ? '${s.tasksCompleted}/${s.tasksTotal} bài'
                    : '${s.sessionCount} phiên',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  understanding == null
                      ? 'Chưa có đánh giá hiểu bài'
                      : 'Hiểu bài ${understanding.toStringAsFixed(1)}/5',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// `↑` tăng · `→` đi ngang · `↓` giảm · rỗng khi chưa đủ dữ liệu.
  static String _trendSuffix(SubjectTrend? trend) {
    switch (trend) {
      case SubjectTrend.up:
        return ' ↑';
      case SubjectTrend.flat:
        return ' →';
      case SubjectTrend.down:
        return ' ↓';
      case null:
        return '';
    }
  }

  Widget _neglectBanner(List<SubjectProgress> neglected) {
    final names = neglected
        .take(3)
        .map((s) => AppSubjects.displayName(s.subject))
        .join(', ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications_active_outlined,
              size: 16, color: AppColors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$names đã lâu chưa học lại. Thử xếp một phiên ngắn cho môn này nhé.',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.orangeDark, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightCard(ProgressSnapshot snapshot) {
    final local = ProgressInsights.localInsight(snapshot);
    final text = _aiInsight ?? local;

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
                child: Text('Nhận định tiến độ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text ??
                'Chưa có đủ dữ liệu để nhận định. Hãy học vài phiên rồi quay lại nhé!',
            style: const TextStyle(fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 12),
          // FE-6.4 — một điểm nhấn hành động rõ ràng: CTA chính của màn Tiến
          // độ là nhờ AI phân tích, luôn nổi bật ở cuối thẻ nhận định.
          PrimaryButton(
            label: _aiInsight != null ? 'Phân tích lại' : 'Hỏi AI phân tích',
            icon: Icons.psychology_outlined,
            backgroundColor: AppColors.purple,
            isLoading: _loadingAi,
            onPressed: _loadingAi ? null : _askAi,
            width: double.infinity,
          ),
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
            Text(value,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// Nút mở màn Quản lý Kỳ thi từ nơi khác (dùng cho desktop secondary action).
class ProgressExamButton extends StatelessWidget {
  final VoidCallback onTap;
  const ProgressExamButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        FeedbackService.selection();
        onTap();
      },
      icon: const Icon(Icons.flag_outlined, size: 18),
      label: const Text('Quản lý kỳ thi'),
    );
  }
}
