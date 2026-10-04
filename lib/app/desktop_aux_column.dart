import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/subject_catalog.dart';
import '../features/exams/domain/models/exam_model.dart';
import '../features/home/domain/services/today_service.dart';
import '../features/progress/domain/progress_engine.dart';
import '../features/study/domain/repositories/study_session_repository.dart';
import '../features/tasks/domain/repositories/task_repository.dart';
import '../shared/widgets/glass_card.dart';
import '../shared/widgets/sync_status_bar.dart';

/// Bề rộng cột phụ và ngưỡng bật — cột phụ chỉ xuất hiện khi màn hình đủ rộng.
///
/// Ở 1024–1400px, nội dung chính đã vừa đẹp; thêm cột phụ 300px khiến cột
/// chính co lại còn ~490px và phá bố cục một cột. Vì vậy ngưỡng đặt cao hơn
/// hẳn ngưỡng desktop và nằm ngoài vùng bố cục "đọc dài".
const double kAuxColumnWidth = 300;

/// Ngưỡng bật cột phụ (px chiều rộng cửa sổ).
const double kAuxColumnBreakpoint = 1440;

bool hasAuxColumn(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kAuxColumnBreakpoint;

/// Cột phụ trên desktop: thông tin bổ sung theo ngữ cảnh tab đang mở.
///
/// Ở desktop có nhiều chỗ trống ngang, nhưng thông tin quan trọng (đếm ngược
/// kỳ thi, tổng kết tuần, trạng thái đồng bộ) lại nằm sâu trong nội dung
/// chính và phải cuộn mới thấy. Cột phụ đưa chúng ra mép màn hình — tức là
/// "luôn nhìn thấy" mà không nhân bản nội dung hay phá tinh thần tinh gọn.
class DesktopAuxColumn extends StatelessWidget {
  /// 0 = Hôm nay, 1 = AI, 2 = Tiến độ, 3 = Tôi.
  final int tabIndex;

  /// Kỳ thi chính đang ghim (đếm ngược).
  final ExamModel? primaryExam;

  /// Tên người dùng + chuỗi ngày học liên tục (tab Tôi).
  final String userName;
  final int streak;

  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenNotes;
  final VoidCallback? onOpenExams;
  final VoidCallback? onOpenProgress;

  const DesktopAuxColumn({
    super.key,
    required this.tabIndex,
    this.primaryExam,
    this.userName = '',
    this.streak = 0,
    this.onOpenCalendar,
    this.onOpenNotes,
    this.onOpenExams,
    this.onOpenProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kAuxColumnWidth,
      decoration: const BoxDecoration(
        color: AppColors.bgPage,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          ..._cardsForTab(),
          const SizedBox(height: 12),
          _Card(
            title: 'Lối tắt',
            children: [
              _ActionTile(
                icon: Icons.calendar_month_outlined,
                label: 'Lịch học',
                onTap: onOpenCalendar,
              ),
              _ActionTile(
                icon: Icons.sticky_note_2_outlined,
                label: 'Ghi chú',
                onTap: onOpenNotes,
              ),
              _ActionTile(
                icon: Icons.flag_outlined,
                label: 'Kỳ thi mục tiêu',
                onTap: onOpenExams,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _cardsForTab() {
    switch (tabIndex) {
      case 0:
        return [if (primaryExam != null) _examCard(), _todayCard()];
      case 1:
        return [const _AiCard()];
      case 2:
        return [const _WeekCard()];
      case 3:
        return [
          _ProfileCard(userName: userName, streak: streak),
          const _SyncCard(),
        ];
      default:
        return const [];
    }
  }

  Widget _examCard() {
    final exam = primaryExam!;
    final days = exam.daysLeftAt(DateTime.now());
    return _Card(
      title: 'Kỳ thi chính',
      children: [
        Text(
          exam.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          days > 0
              ? 'Còn $days ngày nữa'
              : (days == 0 ? 'Thi hôm nay' : 'Đã qua ${-days} ngày'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: days > 0 ? AppColors.primary : AppColors.orangeDark,
          ),
        ),
      ],
    );
  }

  Widget _todayCard() {
    final summary = TodayService.getDailySummary();
    return _Card(
      title: 'Hôm nay',
      children: [
        _Stat(
          label: 'Nhiệm vụ',
          value: '${summary.completedTasks}/${summary.totalTasks}',
          hint: '${summary.remainingTasks} việc còn lại',
        ),
        const SizedBox(height: 10),
        _Stat(
          label: 'Đã học',
          value: summary.studyDurationFormatted,
          hint: 'hôm nay',
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Card({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;

  const _Stat({required this.label, required this.value, this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        // `FittedBox` giữ số liệu không bao giờ làm vỡ cột hẹp.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (hint != null)
          Text(
            hint!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionTile({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab AI: nhắc người dùng AI có thể làm gì và tôn trọng trạng thái mạng —
/// thay vì để họ tự mở màn mới rồi mới biết.
class _AiCard extends StatelessWidget {
  const _AiCard();

  @override
  Widget build(BuildContext context) {
    const capabilities = [
      (Icons.auto_awesome_outlined, 'Giải thích bài đang học'),
      (Icons.calendar_month_outlined, 'Lập kế hoạch ôn tập'),
      (Icons.insights_outlined, 'Phân tích điểm yếu'),
    ];
    return _Card(
      title: 'Trợ lý AI',
      children: [
        for (final c in capabilities)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(c.$1, size: 16, color: AppColors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    c.$2,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        const SyncStatusBar(),
      ],
    );
  }
}

/// Tab Tiến độ: số liệu tuần ở dạng chữ, không cần vẽ biểu đồ.
class _WeekCard extends StatelessWidget {
  const _WeekCard();

  @override
  Widget build(BuildContext context) {
    final snapshot = ProgressEngine.snapshot(
      StudySessionRepository.instance.getAll(),
      TaskRepository.instance.getAllTasks(),
      DateTime.now(),
    );
    final week = snapshot.week;
    final neglected = snapshot.neglectedSubjects.take(2).toList();
    return _Card(
      title: 'Tuần này',
      children: [
        _Stat(
          label: 'Giờ học',
          value: '${week.totalHours.toStringAsFixed(1)}h',
          hint: 'TB ${week.avgDailyMinutes.round()} phút/ngày',
        ),
        const SizedBox(height: 10),
        _Stat(
          label: 'Nhiệm vụ',
          value: '${week.tasksCompleted}/${week.tasksTotal}',
          hint: 'trong tuần',
        ),
        if (neglected.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Môn đang bị bỏ qua',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.orangeDark,
            ),
          ),
          const SizedBox(height: 6),
          for (final s in neglected)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(AppSubjects.iconOf(s.subject),
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      AppSubjects.displayName(s.subject),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textPrimary),
                    ),
                  ),
                  Text(
                    s.lastStudied == null
                        ? 'chưa học'
                        : '${DateTime.now().difference(s.lastStudied!).inDays} ngày trước',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String userName;
  final int streak;

  const _ProfileCard({required this.userName, required this.streak});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Tài khoản',
      children: [
        Text(
          userName.isEmpty ? 'Chưa đặt tên' : userName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          streak > 0
              ? '🔥 Chuỗi học: $streak ngày'
              : 'Học 1 phiên hôm nay để khởi động chuỗi',
          style:
              const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      title: 'Đồng bộ',
      children: [SyncStatusBar()],
    );
  }
}
