import 'package:flutter/material.dart';
import '../../../../core/utils/feedback_service.dart';
import 'package:uuid/uuid.dart';

import '../../features/ai_coach/domain/quiz_models.dart';
import '../../features/ai_coach/presentation/screens/quiz_play_screen.dart';
import '../../features/exams/domain/models/exam_model.dart';
import '../../features/exams/domain/exam_repository.dart';
import '../../features/exams/presentation/screens/exams_page.dart';
import '../../features/notes/presentation/screens/notes_screen.dart';
import '../../features/study/domain/models/study_models.dart';
import '../../features/study/presentation/screens/study_page.dart';
import '../../features/tasks/presentation/widgets/delete_task_dialog.dart';
import '../../features/tasks/presentation/widgets/task_edit_sheet.dart';
import '../../features/tasks/domain/repositories/task_repository.dart';
import '../constants/app_colors.dart';
import 'ai_action.dart';
import 'ai_consent.dart';
import 'ai_sprint4_planner.dart';
import '../constants/subject_catalog.dart';
import '../analytics/product_analytics.dart';
import '../analytics/product_events.dart';
import '../pwa/pwa_service.dart';
import '../utils/storage_service.dart';
import 'ai_models.dart';
import 'ai_router.dart';

export 'ai_action.dart';

/// Báo cáo tình huống học tập thực tế của học sinh (đọc trực tiếp từ local DB)
class AiSituationReport {
  final String greeting;
  final String statusTitle;
  final String headline;
  final String details;
  final String badgeText;
  final Color badgeColor;
  final IconData badgeIcon;
  final List<AiCopilotAction> actions;
  final List<String> promptSuggestions;
  final String? weakSubject;
  final double? weakSubjectScore;
  final int daysUntilExam;
  final String? examName;

  const AiSituationReport({
    required this.greeting,
    required this.statusTitle,
    required this.headline,
    required this.details,
    required this.badgeText,
    required this.badgeColor,
    required this.badgeIcon,
    required this.actions,
    required this.promptSuggestions,
    this.weakSubject,
    this.weakSubjectScore,
    required this.daysUntilExam,
    this.examName,
  });
}

/// Dịch vụ Trợ lý Học tập AI (EduPulse AI Copilot)
///
/// Chuyển đổi AI từ một khung chat rời rạc thành một Trợ lý thực thụ:
/// - Đọc dữ liệu thật: kỳ thi, số ngày còn lại, điểm thi thử từng môn, nhiệm vụ chưa làm, chuỗi học.
/// - Nhận diện tình huống thực tế theo thời gian thực (real-time context).
/// - Liên kết trực tiếp vào các phần khác của app: 1-click thêm task, bắt đầu Focus, lưu ghi chú, sinh quiz trắc nghiệm.
class AiCopilotService {
  AiCopilotService._();

  static const _uuid = Uuid();

  /// Môn yếu nhất theo điểm thi thử đã lưu (trung bình từng môn, chọn môn
  /// thấp nhất). Dùng làm trung gian để mọi phần của app (Exams, Home, AI
  /// Coach) tư vấn cùng một "môn ưu tiên" thay vì hardcode môn Toán.
  /// Trả về null khi chưa có dữ liệu điểm.
  static (String, double)? weakestSubject() {
    final mockIds = StorageService.getMockScoreIds();
    final scoreBySubject = <String, List<double>>{};
    for (final id in mockIds) {
      final raw = StorageService.getMockScoreJson(id);
      if (raw == null) continue;
      try {
        final s = MockScore.fromJsonString(raw);
        final sub = s.subject.trim().isEmpty ? 'Khác' : s.subject.trim();
        scoreBySubject.putIfAbsent(sub, () => <double>[]).add(s.score);
      } catch (_) {
        continue;
      }
    }
    if (scoreBySubject.isEmpty) return null;
    final averages = scoreBySubject.entries
        .map((e) =>
            MapEntry(e.key, e.value.reduce((a, b) => a + b) / e.value.length))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return (averages.first.key, averages.first.value);
  }

  /// Môn ưu tiên cho gợi ý: môn yếu nhất nếu có dữ liệu, ngược lại môn của
  /// nhiệm vụ ưu tiên cao còn lại, cuối cùng fallback 'Toán'.
  static String preferredSubject() {
    final weak = weakestSubject();
    if (weak != null) return weak.$1;
    final taskIds = StorageService.getTodayTaskIds();
    for (final id in taskIds) {
      final raw = StorageService.getTodayTaskJson(id);
      if (raw == null) continue;
      try {
        final t = TodayTask.fromJsonString(raw);
        if (!t.isDone && t.status != 'skipped' && t.priority == 'high') {
          return t.subject;
        }
      } catch (_) {
        continue;
      }
    }
    return 'Toán';
  }

  /// Phân tích dữ liệu thực tế để tạo báo cáo tình huống tức thì
  static AiSituationReport buildSituationReport() {
    final now = DateTime.now();
    final name = StorageService.getUserName().trim();
    final studentName =
        (name.isEmpty || name == 'Sĩ tử EduPulse') ? 'bạn' : name;

    // 1. Chào hỏi theo thời gian
    final hour = now.hour;
    final String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = 'Chào buổi sáng, $studentName!';
    } else if (hour >= 12 && hour < 18) {
      greeting = 'Chào buổi chiều, $studentName!';
    } else {
      greeting = 'Chào buổi tối, $studentName!';
    }

    // 2. Dữ liệu kỳ thi
    final examIds = StorageService.getExamIds();
    final exams = examIds
        .map((id) {
          final raw = StorageService.getExamJson(id);
          if (raw == null) return null;
          return ExamModel.fromJsonString(raw);
        })
        .whereType<ExamModel>()
        .toList();

    ExamModel? primaryExam;
    final primaryId = StorageService.getPrimaryExamId();
    if (primaryId != null) {
      for (final e in exams) {
        if (e.id == primaryId) {
          primaryExam = e;
          break;
        }
      }
    }
    primaryExam ??= exams.isNotEmpty ? exams.first : null;
    final daysLeft = primaryExam?.daysLeft ?? 90;
    final examName = primaryExam?.name ?? 'Kỳ thi mục tiêu';

    // 3. Dữ liệu điểm thi thử (tìm môn yếu nhất)
    final mockIds = StorageService.getMockScoreIds();
    final scores = mockIds
        .map((id) {
          final raw = StorageService.getMockScoreJson(id);
          if (raw == null) return null;
          return MockScore.fromJsonString(raw);
        })
        .whereType<MockScore>()
        .toList();

    final scoreBySubject = <String, List<double>>{};
    for (final s in scores) {
      final sub = s.subject.trim().isEmpty ? 'Khác' : s.subject.trim();
      scoreBySubject.putIfAbsent(sub, () => <double>[]).add(s.score);
    }

    String? weakestSub;
    double? weakestScore;
    if (scoreBySubject.isNotEmpty) {
      final averages = scoreBySubject.entries
          .map((e) =>
              MapEntry(e.key, e.value.reduce((a, b) => a + b) / e.value.length))
          .toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      weakestSub = averages.first.key;
      weakestScore = averages.first.value;
    }

    // 4. Dữ liệu nhiệm vụ hôm nay
    final taskIds = StorageService.getTodayTaskIds();
    final tasks = taskIds
        .map((id) {
          final raw = StorageService.getTodayTaskJson(id);
          if (raw == null) return null;
          return TodayTask.fromJsonString(raw);
        })
        .whereType<TodayTask>()
        .toList();

    final todayTasks = tasks.where((t) {
      final scheduled = t.scheduledAt;
      return scheduled == null ||
          (scheduled.year == now.year &&
              scheduled.month == now.month &&
              scheduled.day == now.day);
    }).toList();

    final todoTasks =
        todayTasks.where((t) => !t.isDone && t.status != 'skipped').toList();
    final highPriorityTodo =
        todoTasks.where((t) => t.priority == 'high').toList();

    // 5. Chuỗi học tập
    final streak = StorageService.getStreak();
    final todayDayKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final hasStudiedToday =
        StorageService.getString('last_study_date') == todayDayKey;

    // --- XÁC ĐỊNH TÌNH HUỐNG THỰC TẾ ---

    // Tình huống 1: Giai đoạn nước rút (≤ 7 ngày trước ngày thi)
    if (daysLeft >= 0 && daysLeft <= 7) {
      return AiSituationReport(
        greeting: greeting,
        statusTitle: 'BÁO ĐỘNG NƯỚC RÚT',
        headline: 'Chỉ còn $daysLeft ngày đến $examName!',
        details:
            'Giai đoạn vàng: Tuyệt đối không nhồi nhét lý thuyết mới. Tập trung rà soát sơ đồ công thức & luyện phản xạ đề ngắn.',
        badgeText: 'Nước rút ≤$daysLeft ngày',
        badgeColor: AppColors.iosError,
        badgeIcon: Icons.alarm_rounded,
        weakSubject: weakestSub,
        weakSubjectScore: weakestScore,
        daysUntilExam: daysLeft,
        examName: examName,
        actions: [
          AiCopilotAction(
            type: AiActionType.startFocus,
            label: '▶ 25p Rà soát công thức',
            icon: Icons.timer_rounded,
            color: AppColors.iosPrimary,
            payload: {'subject': weakestSub ?? 'Tổng hợp', 'minutes': 25},
          ),
          AiCopilotAction(
            type: AiActionType.takeQuiz,
            label: '⚡ 5 câu phản xạ đề thi',
            icon: Icons.quiz_rounded,
            color: AppColors.iosSecondary,
            payload: {
              'subject': weakestSub ?? 'Toán',
              'topic': 'Trắc nghiệm tổng hợp trọng tâm',
            },
          ),
          AiCopilotAction(
            type: AiActionType.addTask,
            label: '+ Nhiệm vụ: Rà soát đề cương cuối',
            icon: Icons.add_task_rounded,
            color: AppColors.iosInfo,
            payload: {
              'title': 'Rà soát toàn bộ đề cương trọng tâm $examName',
              'subject': weakestSub ?? 'Tổng hợp',
              'minutes': 30,
              'priority': 'high',
            },
          ),
        ],
        promptSuggestions: [
          'Chiến lược làm bài thi trắc nghiệm để không bị mất điểm oan',
          'Tóm tắt công thức trọng tâm hay thi nhất môn ${weakestSub ?? "Toán"}',
          'Cách giữ bình tĩnh và phân bổ thời gian trong phòng thi',
        ],
      );
    }

    // Tình huống 2: Điểm thi thử có môn yếu báo động (điểm trung bình < 7.0)
    if (weakestSub != null && (weakestScore ?? 10) < 7.0) {
      final scoreStr = weakestScore!.toStringAsFixed(1);
      return AiSituationReport(
        greeting: greeting,
        statusTitle: 'CẢNH BÁO MÔN YẾU',
        headline: 'Môn $weakestSub đang là mắt xích yếu nhất (TB $scoreStr/10)',
        details:
            'Kỳ thi $examName còn $daysLeft ngày. Đừng bỏ mặc lỗ hổng kiến thức này — hãy dành 25p hôm nay để bù đắp.',
        badgeText: 'Môn yếu: $weakestSub ($scoreStrđ)',
        badgeColor: AppColors.iosWarning,
        badgeIcon: Icons.warning_amber_rounded,
        weakSubject: weakestSub,
        weakSubjectScore: weakestScore,
        daysUntilExam: daysLeft,
        examName: examName,
        actions: [
          AiCopilotAction(
            type: AiActionType.startFocus,
            label: '▶ Bắt đầu 25p Focus $weakestSub',
            icon: Icons.play_arrow_rounded,
            color: AppColors.iosPrimary,
            payload: {'subject': weakestSub, 'minutes': 25},
          ),
          AiCopilotAction(
            type: AiActionType.takeQuiz,
            label: '⚡ Test nhanh 5 câu $weakestSub',
            icon: Icons.quiz_rounded,
            color: AppColors.iosSecondary,
            payload: {
              'subject': weakestSub,
              'topic': 'Dạng bài cơ bản đến nâng cao môn $weakestSub',
            },
          ),
          AiCopilotAction(
            type: AiActionType.addTask,
            label: '+ Thêm task: Ôn 10 câu $weakestSub',
            icon: Icons.add_task_rounded,
            color: AppColors.iosInfo,
            payload: {
              'title': 'Luyện 10 câu bài tập chuyên đề $weakestSub',
              'subject': weakestSub,
              'minutes': 30,
              'priority': 'high',
            },
          ),
        ],
        promptSuggestions: [
          'Chỉ ra 3 lỗi sai/bẫy trắc nghiệm hay gặp nhất môn $weakestSub',
          'Lộ trình 7 ngày nâng điểm $weakestSub từ $scoreStr lên 8.0',
          'Giải thích phương pháp giải nhanh bài tập $weakestSub',
        ],
      );
    }

    // Tình huống 3: Chuỗi học tập có nguy cơ đứt (đã chiều/tối mà chưa ghi nhận học hôm nay)
    if (streak >= 1 && !hasStudiedToday && hour >= 16) {
      return AiSituationReport(
        greeting: greeting,
        statusTitle: 'BẢO VỆ CHUỖI HỌC',
        headline: 'Chuỗi học $streak ngày đang chờ bạn hoàn thành hôm nay!',
        details:
            'Chỉ cần 1 phiên Focus 15–20 phút để giữ vững chuỗi và tiếp tục đà tiến bộ.',
        badgeText: 'Giữ chuỗi $streak ngày',
        badgeColor: AppColors.iosWarningDark,
        badgeIcon: Icons.local_fire_department_rounded,
        weakSubject: weakestSub,
        weakSubjectScore: weakestScore,
        daysUntilExam: daysLeft,
        examName: examName,
        actions: [
          AiCopilotAction(
            type: AiActionType.startFocus,
            label: '▶ Focus 20p giữ chuỗi ngay',
            icon: Icons.local_fire_department_rounded,
            color: AppColors.iosWarning,
            payload: {'subject': weakestSub ?? 'Toán', 'minutes': 20},
          ),
          if (todoTasks.isNotEmpty)
            AiCopilotAction(
              type: AiActionType.startFocus,
              label: '▶ Xử lý: ${todoTasks.first.title}',
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.iosPrimary,
              payload: {
                'subject': todoTasks.first.subject,
                'minutes': todoTasks.first.estimateMinutes,
                'task': todoTasks.first,
              },
            )
          else
            AiCopilotAction(
              type: AiActionType.addTask,
              label: '+ Nhiệm vụ ôn tập nhanh 15p',
              icon: Icons.add_task_rounded,
              color: AppColors.iosInfo,
              payload: {
                'title': 'Đọc lại ghi chú và giải 5 câu bài tập',
                'subject': weakestSub ?? 'Toán',
                'minutes': 15,
                'priority': 'medium',
              },
            ),
        ],
        promptSuggestions: [
          'Cho tôi động lực và 3 việc nhẹ nhàng nên làm tối nay',
          'Mẹo duy trì thói quen học tập đều đặn khi mệt mỏi',
        ],
      );
    }

    // Tình huống 4: Có nhiệm vụ ưu tiên cao đang chờ giải quyết
    if (highPriorityTodo.isNotEmpty) {
      final topTask = highPriorityTodo.first;
      return AiSituationReport(
        greeting: greeting,
        statusTitle: 'NHIỆM VỤ THEN CHỐT',
        headline: 'Hôm nay có nhiệm vụ ưu tiên: "${topTask.title}"',
        details:
            'Dự kiến ${topTask.estimateMinutes} phút môn ${topTask.subject}. Hoàn thành sớm để giải tỏa áp lực.',
        badgeText: 'Ưu tiên cao',
        badgeColor: AppColors.iosPrimary,
        badgeIcon: Icons.flag_rounded,
        weakSubject: weakestSub,
        weakSubjectScore: weakestScore,
        daysUntilExam: daysLeft,
        examName: examName,
        actions: [
          AiCopilotAction(
            type: AiActionType.startFocus,
            label: '▶ Focus ngay: ${topTask.title}',
            icon: Icons.play_arrow_rounded,
            color: AppColors.iosPrimary,
            payload: {
              'subject': topTask.subject,
              'minutes': topTask.estimateMinutes,
              'task': topTask,
            },
          ),
          AiCopilotAction(
            type: AiActionType.takeQuiz,
            label: '⚡ Làm test môn ${topTask.subject}',
            icon: Icons.quiz_rounded,
            color: AppColors.iosSecondary,
            payload: {
              'subject': topTask.subject,
              'topic': topTask.title,
            },
          ),
        ],
        promptSuggestions: [
          'Gợi ý cách tiếp cận nhanh và hiệu quả cho nhiệm vụ "${topTask.title}"',
          'Tóm tắt các điểm quan trọng của bài học "${topTask.title}"',
        ],
      );
    }

    // Tình huống 5: Trạng thái bình thường / Định hướng chung
    return AiSituationReport(
      greeting: greeting,
      statusTitle: 'LỘ TRÌNH HÔM NAY',
      headline: 'Kỳ thi $examName còn $daysLeft ngày!',
      details: todoTasks.isEmpty
          ? 'Bạn chưa có nhiệm vụ nào cho hôm nay. Hãy lên kế hoạch 2–3 việc để giữ vững nhịp độ.'
          : 'Bạn đang có ${todoTasks.length} nhiệm vụ cần giải quyết hôm nay. Bắt đầu với một phiên tập trung nhẹ nhàng nhé!',
      badgeText: 'Còn $daysLeft ngày',
      badgeColor: AppColors.iosSecondary,
      badgeIcon: Icons.auto_awesome_rounded,
      weakSubject: weakestSub,
      weakSubjectScore: weakestScore,
      daysUntilExam: daysLeft,
      examName: examName,
      actions: [
        AiCopilotAction(
          type: AiActionType.startFocus,
          label: '▶ Bắt đầu 25p Pomodoro',
          icon: Icons.timer_rounded,
          color: AppColors.iosPrimary,
          payload: {'subject': weakestSub ?? 'Toán', 'minutes': 25},
        ),
        AiCopilotAction(
          type: AiActionType.addTask,
          label: '+ Thêm nhiệm vụ trọng tâm',
          icon: Icons.add_task_rounded,
          color: AppColors.iosInfo,
          payload: {
            'title': 'Luyện đề và củng cố kiến thức $examName',
            'subject': weakestSub ?? 'Toán',
            'minutes': 45,
            'priority': 'medium',
          },
        ),
        if (weakestSub != null)
          AiCopilotAction(
            type: AiActionType.takeQuiz,
            label: '⚡ Luyện 5 câu $weakestSub',
            icon: Icons.quiz_rounded,
            color: AppColors.iosSecondary,
            payload: {
              'subject': weakestSub,
              'topic': 'Trọng tâm môn $weakestSub',
            },
          ),
      ],
      promptSuggestions: [
        'Lập thời gian biểu tối ưu cho ngày hôm nay',
        'Cách phân bổ thời gian ôn thi khi còn $daysLeft ngày',
        'Gợi ý phương pháp Pomodoro phù hợp với người hay mất tập trung',
      ],
    );
  }

  /// Thực thi hành động AI trực tiếp vào các phần khác của ứng dụng.
  ///
  /// Callbacks [onTasksChanged] / [onStreakChanged] được truyền xuyên suốt
  /// qua quiz (payload 'onTasksChanged' / 'onStreakChanged') để khi quiz ghi
  /// kết quả ngược vào dữ liệu, Home và streak cũng cập nhật theo — đây là
  /// mảnh ghép khép vòng lặp AI → làm bài → dữ liệu cập nhật → AI tư vấn lại.
  static Future<void> executeAction(
    BuildContext context,
    AiCopilotAction action, {
    VoidCallback? onTasksChanged,
    VoidCallback? onStreakChanged,
  }) async {
    action.payload['onTasksChanged'] = onTasksChanged;
    action.payload['onStreakChanged'] = onStreakChanged;
    // Người dùng vừa chủ động yêu cầu AI làm gì đó — đo ý định, không log nội
    // dung hội thoại hay dữ liệu học tập (chỉ loại hành động).
    ProductAnalytics.instance.track(ProductEvents.aiActionRequested,
        props: {'kind': action.type.name});
    // Xoá callback khi rời khỏi context để không giữ reference rác.
    // (payload là map thường nên gán callback an toàn, được đọc lại phía sau.)
    FeedbackService.medium();

    switch (action.type) {
      case AiActionType.addTask:
        // Giữ messenger từ đầu case: sau các `await` sẽ không còn dùng
        // BuildContext nữa.
        final messenger = ScaffoldMessenger.of(context);
        final title = (action.payload['title'] ?? 'Nhiệm vụ mới').toString();
        // AI-2.1: chuẩn hoá môn trước khi ghi, nếu không AI gõ "Toán" sẽ tạo ra
        // môn khác với '📐 Toán' đang lưu ⇒ thống kê theo môn vỡ tan.
        final subject = AppSubjects.normalize(
            (action.payload['subject'] ?? 'Toán').toString());
        final minutes = (action.payload['minutes'] as num?)?.toInt() ?? 30;
        final priority = (action.payload['priority'] ?? 'medium').toString();

        final task = TodayTask(
          id: _uuid.v4(),
          title: title,
          subject: subject,
          priority: priority,
          estimateMinutes: minutes,
          scheduledAt: DateTime.now(),
        );

        // Mọi ghi của AI đi qua TaskRepository — và bị chặn nếu trùng.
        final result = await TaskRepository.instance.createTaskIfMissing(task);
        if (result.isDuplicate) {
          if (context.mounted) {
            _showAiSnackBar(
              messenger,
              message: result.error ?? 'Nhiệm vụ này đã có trong kế hoạch',
              icon: Icons.info_outline_rounded,
              color: AppColors.iosTextMuted,
            );
          }
          break;
        }
        if (result.failed) {
          if (context.mounted) {
            _showAiSnackBar(
              messenger,
              message: result.error ?? 'Không thêm được nhiệm vụ',
              icon: Icons.error_outline_rounded,
              color: AppColors.iosError,
            );
          }
          break;
        }

        onTasksChanged?.call();

        if (context.mounted) {
          // Undo đi đúng đường của người dùng: xoá rồi khôi phục lại y hệt.
          final ref = await TaskRepository.instance.deleteTask(task.id);
          _showAiSnackBar(
            messenger,
            message: 'Đã thêm: "$title"',
            icon: Icons.check_circle_rounded,
            color: AppColors.iosPrimary,
            onUndo: () async {
              await TaskRepository.instance.restoreTask(ref);
              onTasksChanged?.call();
            },
          );
        }
        break;

      case AiActionType.editTask:
      case AiActionType.rescheduleTask:
      case AiActionType.deleteTask:
        await _executeTaskMutationAction(
          context,
          action,
          onTasksChanged: onTasksChanged,
        );
        break;

      case AiActionType.startFocus:
        final subject = (action.payload['subject'] ?? 'Toán').toString();
        final minutes = (action.payload['minutes'] as num?)?.toInt() ?? 25;
        final task = action.payload['task'] as TodayTask?;

        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => StudyPage(
                onStreakChanged: onStreakChanged,
                initialSubject: subject,
                initialMinutes: minutes,
                initialTask: task,
                autoStart: true,
              ),
            ),
          );
        }
        break;

      case AiActionType.saveNote:
        final title = (action.payload['title'] ?? 'Ghi chú từ AI').toString();
        final body = (action.payload['body'] ?? '').toString();
        final subject = (action.payload['subject'] ?? 'Tổng hợp').toString();

        final note = StudyNote(
          id: _uuid.v4(),
          title: title,
          body: body,
          subject: subject,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: ['AI Coach', subject],
        );

        StorageService.setStudyNoteJson(note.id, note.toJsonString());
        final noteIds = StorageService.getStudyNoteIds();
        if (!noteIds.contains(note.id)) {
          noteIds.add(note.id);
          StorageService.setStudyNoteIds(noteIds);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.sticky_note_2_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Đã lưu vào Ghi chú: "$title"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              backgroundColor: AppColors.iosSecondary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Mở xem',
                textColor: Colors.white,
                onPressed: () {
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => const NotesScreen(),
                      ),
                    );
                  }
                },
              ),
            ),
          );
        }
        break;

      case AiActionType.takeQuiz:
        final subject = (action.payload['subject'] ?? 'Toán').toString();
        final topic =
            (action.payload['topic'] ?? 'Trắc nghiệm tổng hợp').toString();
        final quizOnTasks = action.payload['onTasksChanged'] as VoidCallback?;
        final quizOnStreak = action.payload['onStreakChanged'] as VoidCallback?;

        // Quyền riêng tư (§8): chủ đề quiz thường do AI suy ra từ dữ liệu học
        // tập — không gửi lại lên AI khi người dùng đã tắt quyền phân tích.
        if (!AiConsent.ensure(context)) return;

        if (!PwaService.isOnline) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Cần kết nối mạng để AI soạn câu hỏi trắc nghiệm!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        // Hiện modal loading
        if (!context.mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  const CircularProgressIndicator(
                      color: AppColors.iosSecondary),
                  const SizedBox(height: 18),
                  Text('AI đang soạn 5 câu hỏi môn $subject...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text('Chủ đề: "$topic"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.iosTextMuted)),
                ],
              ),
            ),
          ),
        );

        try {
          final prompt = buildTopicQuizPrompt(subject, topic);
          final raw = await AiRouter.chat(
            model: AIModel.defaultModel,
            history: const [],
            userMessage: prompt,
            searchWeb: false,
          );

          final questions = parseQuiz(raw);

          // Đóng dialog loading
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }

          if (questions.isEmpty) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('AI chưa tạo được câu hỏi. Thử lại nhé!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return;
          }

          if (context.mounted) {
            Navigator.of(context)
                .push(MaterialPageRoute(
              builder: (_) => QuizPlayScreen(
                questions: questions,
                subject: subject,
                topic: topic,
                onTasksChanged: quizOnTasks,
                onStreakChanged: quizOnStreak,
              ),
            ))
                .then((_) {
              // Vừa quay lại từ quiz: dữ liệu điểm/streak đã đổi — báo UI
              // liên quan (Home) đọc lại để AI lần sau tư vấn theo kết quả
              // mới nhất, khép vòng lặp học tập.
              quizOnTasks?.call();
            });
          }
        } catch (e) {
          ProductAnalytics.instance.track(ProductEvents.aiActionFailed,
              props: {'kind': action.type.name, 'reason': 'exception'});
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Lỗi: $e'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
        break;

      case AiActionType.openExams:
        // Mở màn hình kỳ thi
        break;

      case AiActionType.openNotes:
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const NotesScreen(),
            ),
          );
        }
        break;

      case AiActionType.plan:
        // Kế hoạch nhiều ngày KHÔNG BAO GIỜ tự áp dụng (một lệnh = 10–30
        // task): màn chat luôn xử lý bằng AiPlanPreviewSheet. Nút thủ công
        // nếu vẫn gặp type này thì không làm gì cả — an toàn tuyệt đối.
        break;
    }
    // Dọn callback ra khỏi payload sau khi chạy xong để payload trở lại
    // trạng thái thuần dữ liệu (không giữ reference UI).
    action.payload.remove('onTasksChanged');
    action.payload.remove('onStreakChanged');
    // Đi hết switch nghĩa là hành động đã được thực thi (hoặc đã mở màn hình
    // tương ứng) — ghi nhận "đã áp dụng" kèm loại hành động.
    ProductAnalytics.instance.track(ProductEvents.aiActionApplied,
        props: {'kind': action.type.name, 'result': 'ok'});
  }

  // ─── AI-2.1: các hành động sửa / dời lịch / xoá nhiệm vụ ────────────────

  /// Thực thi hành động AI lên một nhiệm vụ **đang có sẵn**.
  ///
  /// Ba nguyên tắc không được lỏng:
  /// 1. Không đoán bừa — không tìm thấy task khớp tên thì báo, không tạo mới.
  /// 2. **Xoá luôn phải xác nhận** (AI-2.1), dùng đúng hộp thoại của FE-2.5.
  /// 3. Mọi ghi đi qua `TaskRepository` — AI và người dùng dùng chung một đường.
  static Future<void> _executeTaskMutationAction(
    BuildContext context,
    AiCopilotAction action, {
    VoidCallback? onTasksChanged,
  }) async {
    final title = (action.payload['title'] ?? action.label).toString();
    final subjectRaw = action.payload['subject']?.toString();
    final messenger = ScaffoldMessenger.of(context);

    final match = _findTaskByTitle(title, subjectRaw);
    if (match == null) {
      _showAiSnackBar(
        messenger,
        message: 'Không tìm thấy nhiệm vụ "$title" trong kế hoạch',
        icon: Icons.search_off_rounded,
        color: AppColors.iosTextMuted,
      );
      return;
    }

    final repo = TaskRepository.instance;

    switch (action.type) {
      case AiActionType.editTask:
        if (!context.mounted) return;
        // Ảnh chụp trước khi sửa để luôn có đường Hoàn tác (đặc tả 5.5):
        // hành động AI không được phép là ngõ cụt nếu người dùng đổi ý.
        final beforeEdit = TodayTask.fromJsonString(match.toJsonString());
        final edited = await TaskEditSheet.show(context, initialTask: match);
        if (edited == null || !context.mounted) return;
        // Bỏ qua nếu người dùng đóng form mà không sửa gì.
        final dirty = edited.task.title != match.title ||
            edited.task.estimateMinutes != match.estimateMinutes ||
            edited.task.subject != match.subject ||
            edited.task.deadline != match.deadline ||
            edited.task.scheduledAt != match.scheduledAt ||
            edited.task.priority != match.priority ||
            edited.task.note != match.note;
        if (!dirty) return;
        final result = await repo.updateTask(edited.task);
        onTasksChanged?.call();
        _showAiSnackBar(
          messenger,
          message: result.failed
              ? (result.error ?? 'Không lưu được thay đổi')
              : 'Đã cập nhật "${match.title}"',
          icon: result.failed
              ? Icons.error_outline_rounded
              : Icons.check_circle_rounded,
          color: result.failed ? AppColors.iosError : AppColors.iosPrimary,
          onUndo: result.failed
              ? null
              : () async {
                  await repo.updateTask(beforeEdit);
                  onTasksChanged?.call();
                },
        );

      case AiActionType.rescheduleTask:
        final days = (action.payload['days'] as num?)?.toInt() ?? 1;
        final when = (action.payload['date']?.toString()) != null
            ? DateTime.tryParse(action.payload['date'].toString())
            : DateTime.now().add(Duration(days: days));
        if (when == null || !context.mounted) return;
        if (match.isDone) {
          _showAiSnackBar(
            messenger,
            message: '"${match.title}" đã hoàn thành nên không dời lịch được',
            icon: Icons.info_outline_rounded,
            color: AppColors.iosTextMuted,
          );
          return;
        }
        // Chụp lịch cũ để dời có thể hoàn tác (đặc tả 5.5).
        final beforeMove = TodayTask.fromJsonString(match.toJsonString());
        final result = await repo.rescheduleTask(match.id, when);
        onTasksChanged?.call();
        _showAiSnackBar(
          messenger,
          message: result.failed
              ? (result.error ?? 'Không dời lịch được')
              : 'Đã dời "${match.title}" sang ${when.day}/${when.month}',
          icon: result.failed
              ? Icons.error_outline_rounded
              : Icons.event_available_rounded,
          color: result.failed ? AppColors.iosError : AppColors.iosPrimary,
          onUndo: result.failed
              ? null
              : () async {
                  await repo.updateTask(beforeMove);
                  onTasksChanged?.call();
                },
        );

      case AiActionType.deleteTask:
        if (!context.mounted) return;
        // Bắt buộc xác nhận — dùng chung hộp thoại của người dùng (FE-2.5).
        final confirmed = await showConfirmDelete(context, match);
        if (confirmed != true || !context.mounted) return;
        try {
          final ref = await repo.deleteTask(match.id);
          onTasksChanged?.call();
          _showAiSnackBar(
            messenger,
            message: 'Đã xoá "${match.title}"',
            icon: Icons.delete_outline_rounded,
            color: AppColors.iosError,
            onUndo: () async {
              await repo.restoreTask(ref);
              onTasksChanged?.call();
            },
          );
        } catch (_) {
          _showAiSnackBar(
            messenger,
            message: 'Không xoá được nhiệm vụ',
            icon: Icons.error_outline_rounded,
            color: AppColors.iosError,
          );
        }

      default:
        break;
    }
  }

  // ─── AI-2.2: executor TỰ THỰC THI (agentic) ─────────────────────────────

  /// Thực thi **ngay lập tức** một hành động AI và trả về kết quả dạng chip.
  ///
  /// Khác [executeAction] (đường bấm thủ công, kết quả hiện bằng SnackBar),
  /// hàm này phục vụ luồng AI tự làm việc ngay khi vừa trả lời:
  /// - trả [AiActionResult] để màn chat hiển thị chip ✅/⚠️/❌ kèm nút Hoàn tác;
  /// - các thao tác ghi **không cần context** được tách thành hàm `perform*`
  ///   để test unit chạy không cần dựng widget;
  /// - `deleteTask` luôn đi qua hộp thoại xác nhận của người dùng (FE-2.5);
  /// - `plan` không bao giờ tự áp dụng — màn chat sẽ mở `AiPlanPreviewSheet`.
  ///
  /// [context] chỉ bắt buộc với loại hành động cần điều hướng (focus, mở màn)
  /// hoặc dialog xác nhận; bằng `null` thì các loại đó trả kết quả `failed`.
  static Future<AiActionResult> executeAuto(
    BuildContext? context,
    AiCopilotAction action, {
    int actionIndex = 0,
    VoidCallback? onTasksChanged,
    VoidCallback? onStreakChanged,
  }) async {
    ProductAnalytics.instance.track(ProductEvents.aiActionRequested,
        props: {'kind': action.type.name});

    late final AiActionResult res;
    switch (action.type) {
      case AiActionType.addTask:
      case AiActionType.saveNote:
      case AiActionType.editTask:
      case AiActionType.rescheduleTask:
        res = await _dataMutationResult(context, action, actionIndex,
            onTasksChanged: onTasksChanged);
        break;
      case AiActionType.deleteTask:
        res = await _deleteWithConfirm(context, action, actionIndex);
        break;
      case AiActionType.startFocus:
        res = await _openFocus(context, action, actionIndex, onStreakChanged);
        break;
      case AiActionType.openNotes:
        res = await _openNotes(context, actionIndex);
        break;
      case AiActionType.openExams:
        res = await _openExams(context, actionIndex);
        break;
      case AiActionType.takeQuiz:
        // Quiz cần soạn câu hỏi và loading dialog — giữ đường bấm thủ công,
        // không tự bấm giùm người học.
        res = AiActionResult(
          actionIndex: actionIndex,
          kind: AiActionResultKind.failed,
          message: 'Quiz cần bạn bấm nút để bắt đầu',
        );
        break;
      case AiActionType.plan:
        res = AiActionResult(
          actionIndex: actionIndex,
          kind: AiActionResultKind.failed,
          message: 'Kế hoạch cần xem trước rồi mới áp dụng',
        );
        break;
    }
    action.clearUiCallbacks();
    ProductAnalytics.instance.track(ProductEvents.aiActionApplied,
        props: {'kind': action.type.name, 'result': 'ok'});
    return res;
  }

  /// Đường thực thi cho các hành động **ghi dữ liệu không cần màn hình**:
  /// add/edit/reschedule task và ghi chú. Mỗi loại tự chặn trùng, tự chụp
  /// snapshot trước khi sửa (đặc tả 5.5) và tự đóng gói closure hoàn tác.
  static Future<AiActionResult> _dataMutationResult(
    BuildContext? context,
    AiCopilotAction action,
    int actionIndex, {
    VoidCallback? onTasksChanged,
  }) async {
    final AiMutationOutcome outcome;
    switch (action.type) {
      case AiActionType.addTask:
        outcome = await performAddTask(action.payload);
        break;
      case AiActionType.saveNote:
        outcome = await performSaveNote(action.payload);
        break;
      case AiActionType.editTask:
        // AI chỉ đọc tên task mà không đưa giá trị mới → mở form sửa (luồng
        // cũ) cho người dùng tự điền; tự sửa hộ là mất quyền của người dùng.
        if (!hasEditFields(action.payload)) {
          return _editViaSheet(context, action, actionIndex);
        }
        outcome = await performEditTask(action.payload);
        break;
      case AiActionType.rescheduleTask:
        outcome = await performRescheduleTask(action.payload);
        break;
      default:
        outcome = const AiMutationOutcome(
          AiActionResultKind.failed,
          'Hành động không hợp lệ',
        );
    }
    // Task đổi → báo UI (Home, kế hoạch hôm nay) đọc lại.
    if (action.type != AiActionType.saveNote) {
      onTasksChanged?.call();
    }
    return AiActionResult(
      actionIndex: actionIndex,
      kind: outcome.kind,
      message: outcome.message,
      undo: outcome.undo,
    );
  }

  /// **addTask** tự động: tạo qua `TaskRepository.createTaskIfMissing` —
  /// trùng là bị chặn, AI không bao giờ được tự tay ghi storage.
  static Future<AiMutationOutcome> performAddTask(
      Map<String, dynamic> payload) async {
    final title = (payload['title'] ?? 'Nhiệm vụ mới').toString().trim();
    final subject =
        AppSubjects.normalize((payload['subject'] ?? 'Toán').toString());
    final minutes = (payload['minutes'] as num?)?.toInt() ?? 25;
    final priority = (payload['priority'] ?? 'medium').toString();
    final when = parseAiWhen(payload['scheduledAt'] ?? payload['when']);

    final task = TodayTask(
      id: _uuid.v4(),
      title: title.isEmpty ? 'Nhiệm vụ mới' : title,
      subject: subject,
      priority: priority,
      estimateMinutes: minutes.clamp(5, 180).toInt(),
      scheduledAt: when ?? DateTime.now(),
    );

    final result = await TaskRepository.instance.createTaskIfMissing(task);
    if (result.isDuplicate) {
      return AiMutationOutcome(
        AiActionResultKind.duplicate,
        result.error ?? 'Nhiệm vụ này đã có trong kế hoạch rồi',
      );
    }
    if (result.failed || result.task == null) {
      return AiMutationOutcome(
        AiActionResultKind.failed,
        result.error ?? 'Không thêm được nhiệm vụ',
      );
    }
    final created = result.task ?? task;
    return AiMutationOutcome(
      AiActionResultKind.done,
      'Đã tạo nhiệm vụ: "${created.title}" '
      '(${created.subject}, ${created.estimateMinutes} phút)',
      undo: () async {
        try {
          // Hoàn tác "thêm" là xoá đúng nhiệm vụ AI vừa tạo.
          await TaskRepository.instance.deleteTask(created.id);
        } catch (_) {
          // Hoàn tác là nỗ lực tốt nhất — không chọc lỗi lên chip nữa.
        }
      },
    );
  }

  /// **saveNote** tự động: ghi StudyNote qua `StorageService`; hoàn tác là
  /// xoá đúng ghi chú AI vừa tạo (chỉ đụng id AI tự đặt, không xoá nhầm của
  /// người dùng).
  static Future<AiMutationOutcome> performSaveNote(
      Map<String, dynamic> payload) async {
    final title = (payload['title'] ?? 'Ghi chú từ AI').toString().trim();
    final body = (payload['body'] ?? '').toString();
    final subject = (payload['subject'] ?? 'Tổng hợp').toString();

    final note = StudyNote(
      id: _uuid.v4(),
      title: title.isEmpty ? 'Ghi chú từ AI' : title,
      body: body,
      subject: subject,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tags: ['AI Coach', subject],
    );

    StorageService.setStudyNoteJson(note.id, note.toJsonString());
    final noteIds = StorageService.getStudyNoteIds();
    if (!noteIds.contains(note.id)) {
      noteIds.add(note.id);
      StorageService.setStudyNoteIds(noteIds);
    }

    return AiMutationOutcome(
      AiActionResultKind.done,
      'Đã lưu ghi chú: "${note.title}"',
      undo: () async {
        try {
          StorageService.removeStudyNote(note.id);
        } catch (_) {}
      },
    );
  }

  /// **editTask** tự động: chỉ áp dụng khi AI đưa ít nhất một giá trị mới.
  static Future<AiMutationOutcome> performEditTask(
      Map<String, dynamic> payload) async {
    final title = (payload['title'] ?? payload['task'] ?? '').toString().trim();
    if (title.isEmpty) {
      return const AiMutationOutcome(
        AiActionResultKind.failed,
        'AI chưa nói rõ nhiệm vụ cần sửa',
      );
    }
    final match = _findTaskByTitle(title, payload['subject']?.toString());
    if (match == null) {
      return AiMutationOutcome(
        AiActionResultKind.failed,
        'Không tìm thấy nhiệm vụ "$title" trong kế hoạch',
      );
    }

    final newTitle = (payload['newTitle'] ?? '').toString().trim();
    final minutes = (payload['minutes'] as num?)?.toInt();
    final priority = (payload['priority'] ?? '').toString().trim();
    final when = parseAiWhen(
        payload['scheduledAt'] ?? payload['newDate'] ?? payload['date']);
    final deadline = parseAiWhen(payload['deadline']);

    if (newTitle.isEmpty &&
        minutes == null &&
        priority.isEmpty &&
        when == null &&
        deadline == null) {
      return const AiMutationOutcome(
        AiActionResultKind.rejected,
        'AI chưa đưa giá trị thay đổi — cần bạn điền bằng form',
      );
    }

    // Chụp trạng thái cũ trước khi sửa để luôn có đường hoàn tác (đặc tả 5.5).
    final before = TodayTask.fromJsonString(match.toJsonString());
    final updated = TodayTask.fromJsonString(match.toJsonString());
    if (newTitle.isNotEmpty) updated.title = newTitle;
    if (minutes != null) {
      updated.estimateMinutes = minutes.clamp(5, 180).toInt();
    }
    if (priority.isNotEmpty) updated.priority = priority;
    if (when != null) updated.scheduledAt = when;
    if (deadline != null) updated.deadline = deadline;

    final result = await TaskRepository.instance.updateTask(updated);
    if (result.failed) {
      return AiMutationOutcome(
        AiActionResultKind.failed,
        result.error ?? 'Không lưu được thay đổi',
      );
    }
    return AiMutationOutcome(
      AiActionResultKind.done,
      'Đã cập nhật "${match.title}"',
      undo: () async {
        try {
          await TaskRepository.instance.updateTask(before);
        } catch (_) {}
      },
    );
  }

  /// **rescheduleTask** tự động: thiếu ngày → dời +1 ngày như hành vi cũ.
  static Future<AiMutationOutcome> performRescheduleTask(
      Map<String, dynamic> payload) async {
    final title = (payload['title'] ?? '').toString().trim();
    if (title.isEmpty) {
      return const AiMutationOutcome(
        AiActionResultKind.failed,
        'AI chưa nói rõ nhiệm vụ cần dời',
      );
    }
    final match = _findTaskByTitle(title, payload['subject']?.toString());
    if (match == null) {
      return AiMutationOutcome(
        AiActionResultKind.failed,
        'Không tìm thấy nhiệm vụ "$title" trong kế hoạch',
      );
    }
    if (match.isDone) {
      return AiMutationOutcome(
        AiActionResultKind.failed,
        '"${match.title}" đã hoàn thành nên không dời lịch được',
      );
    }

    final parsed = parseAiWhen(payload['date'] ?? payload['newDate']);
    final extraDays = (payload['days'] as num?)?.toInt() ?? 1;
    final newDate = parsed ??
        DateTime.now().add(Duration(days: extraDays < 0 ? 1 : extraDays));

    final before = TodayTask.fromJsonString(match.toJsonString());
    final result =
        await TaskRepository.instance.rescheduleTask(match.id, newDate);
    if (result.failed) {
      return AiMutationOutcome(
        AiActionResultKind.failed,
        result.error ?? 'Không dời lịch được',
      );
    }
    return AiMutationOutcome(
      AiActionResultKind.done,
      'Đã dời "${match.title}" sang ${newDate.day}/${newDate.month}',
      undo: () async {
        try {
          await TaskRepository.instance.updateTask(before);
        } catch (_) {}
      },
    );
  }

  /// **deleteTask**: AI chỉ được *đề nghị*; thật sự xoá phải đi qua hộp thoại
  /// của người dùng (FE-2.5). Chốt "Xóa" mới ghi dữ liệu và vẫn luôn có đường
  /// hoàn tác (`restoreTask`).
  static Future<AiActionResult> _deleteWithConfirm(
    BuildContext? context,
    AiCopilotAction action,
    int actionIndex,
  ) async {
    final title = (action.payload['title'] ?? '').toString().trim();
    if (context == null || !context.mounted) {
      return AiActionResult(
        actionIndex: actionIndex,
        kind: AiActionResultKind.failed,
        message: 'Không thể hiện hộp thoại xác nhận ngay bây giờ',
      );
    }
    if (title.isEmpty) {
      return AiActionResult(
        actionIndex: actionIndex,
        kind: AiActionResultKind.failed,
        message: 'AI chưa nói rõ nhiệm vụ cần xoá',
      );
    }
    final match =
        _findTaskByTitle(title, action.payload['subject']?.toString());
    if (match == null) {
      return AiActionResult(
        actionIndex: actionIndex,
        kind: AiActionResultKind.failed,
        message: 'Không tìm thấy nhiệm vụ "$title" trong kế hoạch',
      );
    }

    final confirmed = await showConfirmDelete(context, match);
    if (confirmed != true || !context.mounted) {
      return AiActionResult(
        actionIndex: actionIndex,
        kind: AiActionResultKind.rejected,
        message: 'Đã giữ lại "${match.title}"',
      );
    }
    final ref = await TaskRepository.instance.deleteTask(match.id);
    return AiActionResult(
      actionIndex: actionIndex,
      kind: AiActionResultKind.done,
      message: 'Đã xoá "${match.title}"',
      undo: () async {
        try {
          await TaskRepository.instance.restoreTask(ref);
        } catch (_) {}
      },
    );
  }

  /// editTask mà AI **không** đưa giá trị mới → mở form sửa (như luồng cũ)
  /// và đóng gói kết quả thành chip hoàn tác được.
  static Future<AiActionResult> _editViaSheet(
    BuildContext? context,
    AiCopilotAction action,
    int actionIndex,
  ) async {
    if (context == null || !context.mounted) {
      return AiActionResult(
        actionIndex: actionIndex,
        kind: AiActionResultKind.failed,
        message: 'Không tìm thấy nhiệm vụ để sửa',
      );
    }
    final match = _findTaskByTitle(
      (action.payload['title'] ?? '').toString(),
      action.payload['subject']?.toString(),
    );
    if (match == null) {
      return AiActionResult(
        actionIndex: actionIndex,
        kind: AiActionResultKind.failed,
        message:
            'Không tìm thấy nhiệm vụ "${action.payload['title'] ?? ''}" trong kế hoạch',
      );
    }

    // Chụp trước khi sửa để hoàn tác đúng đặc tả 5.5.
    final beforeEdit = TodayTask.fromJsonString(match.toJsonString());
    final edited = await TaskEditSheet.show(context, initialTask: match);
    if (edited == null || !context.mounted) {
      return AiActionResult(
        actionIndex: actionIndex,
        kind: AiActionResultKind.rejected,
        message: 'Bạn đã đóng form sửa không đổi gì',
      );
    }
    final dirty = edited.task.title != match.title ||
        edited.task.estimateMinutes != match.estimateMinutes ||
        edited.task.subject != match.subject ||
        edited.task.deadline != match.deadline ||
        edited.task.scheduledAt != match.scheduledAt ||
        edited.task.priority != match.priority ||
        edited.task.note != match.note;
    if (!dirty) {
      return AiActionResult(
        actionIndex: actionIndex,
        kind: AiActionResultKind.rejected,
        message: 'Bạn đã đóng form sửa không đổi gì',
      );
    }
    final result = await TaskRepository.instance.updateTask(edited.task);
    return AiActionResult(
      actionIndex: actionIndex,
      kind: result.failed ? AiActionResultKind.failed : AiActionResultKind.done,
      message: result.failed
          ? (result.error ?? 'Không lưu được thay đổi')
          : 'Đã cập nhật "${match.title}"',
      undo: result.failed
          ? null
          : () async {
              try {
                await TaskRepository.instance.updateTask(beforeEdit);
              } catch (_) {}
            },
    );
  }

  /// Mở phiên tập trung ngay (StudyPage `autoStart`) — đúng đường của nút ▶ cũ.
  static Future<AiActionResult> _openFocus(
    BuildContext? context,
    AiCopilotAction action,
    int actionIndex,
    VoidCallback? onStreakChanged,
  ) async {
    final subject = (action.payload['subject'] ?? 'Toán').toString();
    final minutes = (action.payload['minutes'] as num?)?.toInt() ?? 25;
    final task = action.payload['task'] as TodayTask?;
    if (context == null || !context.mounted) {
      return AiActionResult(
        actionIndex: actionIndex,
        kind: AiActionResultKind.failed,
        message: 'Không mở được phiên tập trung ngay bây giờ',
      );
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StudyPage(
          onStreakChanged: onStreakChanged,
          initialSubject: subject,
          initialMinutes: minutes,
          initialTask: task,
          autoStart: true,
        ),
      ),
    );
    return AiActionResult(
      actionIndex: actionIndex,
      kind: AiActionResultKind.done,
      message: 'Đã mở phiên tập trung $minutes phút môn $subject',
    );
  }

  /// Mở màn Ghi chú.
  static Future<AiActionResult> _openNotes(
    BuildContext? context,
    int actionIndex,
  ) async {
    if (context == null || !context.mounted) {
      return AiActionResult(
        actionIndex: actionIndex,
        kind: AiActionResultKind.failed,
        message: 'Không mở được Ghi chú ngay bây giờ',
      );
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const NotesScreen(),
      ),
    );
    return AiActionResult(
      actionIndex: actionIndex,
      kind: AiActionResultKind.done,
      message: 'Đã mở màn Ghi chú',
    );
  }

  /// Mở màn Mục tiêu (kỳ thi). Callback gắn thẳng vào [ExamRepository] —
  /// repository tự bắn revision nên mọi phần của app vẽ lại theo dữ liệu mới.
  static Future<AiActionResult> _openExams(
    BuildContext? context,
    int actionIndex,
  ) async {
    if (context == null || !context.mounted) {
      return AiActionResult(
        actionIndex: actionIndex,
        kind: AiActionResultKind.failed,
        message: 'Không mở được Mục tiêu ngay bây giờ',
      );
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ExamsPage(
          onSetPrimary: (exam) => ExamRepository.instance.setPrimary(exam.id),
          onAddExam: (exam) => ExamRepository.instance.save(exam),
          onUpdateExam: (exam) => ExamRepository.instance.save(exam),
          onDeleteExam: (id) => ExamRepository.instance.delete(id),
        ),
      ),
    );
    return AiActionResult(
      actionIndex: actionIndex,
      kind: AiActionResultKind.done,
      message: 'Đã mở màn Mục tiêu (kỳ thi)',
    );
  }

  /// Ngày/giờ AI gửi về dạng ISO hoặc chuỗi tự do — đọc dịu dàng: chuỗi rỗng
  /// hay parse hỏng trả `null` thay vì nhảy vào 1/1/1970.
  static DateTime? parseAiWhen(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  /// editTask có thực sự mang giá trị mới? Chỉ có tên task là không đủ để tự
  /// áp dụng — cần ít nhất tên mới / số phút / độ ưu tiên / ngày học /
  /// deadline.
  static bool hasEditFields(Map<String, dynamic> payload) =>
      (payload['newTitle'] ?? '').toString().trim().isNotEmpty ||
      payload['minutes'] != null ||
      (payload['priority'] ?? '').toString().trim().isNotEmpty ||
      parseAiWhen(payload['scheduledAt'] ??
              payload['newDate'] ??
              payload['date']) !=
          null ||
      parseAiWhen(payload['deadline']) != null;

  /// Chuyển payload hành động `plan` (JSON từ AI) thành [AiStudyPlan] cho
  /// `AiPlanPreviewSheet`. Không áp dụng gì — chờ người dùng bấm "Áp dụng".
  static AiStudyPlan planFromAction(
    AiCopilotAction action, {
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final base = DateTime(ref.year, ref.month, ref.day);
    final raw = action.payload['tasks'];
    final tasks = <AiPlannedTask>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final title = (m['title'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        final dayOffset =
            ((m['dayOffset'] ?? m['day'] ?? 0) as num).toInt().clamp(0, 30);
        tasks.add(AiPlannedTask(
          id: _uuid.v4(),
          title: title,
          subject:
              AppSubjects.normalize((m['subject'] ?? 'Tổng hợp').toString()),
          estimateMinutes: ((m['minutes'] ?? m['estimateMinutes'] ?? 25) as num)
              .toInt()
              .clamp(10, 120)
              .toInt(),
          priority: (m['priority'] ?? 'medium').toString(),
          scheduledAt: base.add(Duration(days: dayOffset)),
          day: dayOffset + 1,
          reason: m['reason']?.toString(),
        ));
      }
    }
    final summary = (action.payload['summary'] ?? action.payload['title'] ?? '')
        .toString()
        .trim();
    return AiStudyPlan(
      tasks: tasks,
      summary: summary.isEmpty
          ? 'Kế hoạch AI đề xuất (${tasks.length} nhiệm vụ)'
          : summary,
    );
  }

  /// Tìm task theo tên mà AI đưa ra — so khớp "chứa" sau khi bỏ dấu/emoji.
  /// Trả `null` nếu không chắc chắn, để AI không sửa nhầm task.
  static TodayTask? _findTaskByTitle(String title, String? subject) {
    final needle = _foldText(title);
    if (needle.isEmpty) return null;

    final subjectKey =
        subject == null ? null : AppSubjects.normalize(subject).toLowerCase();

    TodayTask? fallback;
    for (final task in TaskRepository.instance.getTasksForDay()) {
      final name = _foldText(task.title);
      if (!name.contains(needle) && !needle.contains(name)) continue;
      if (subjectKey != null &&
          AppSubjects.normalize(task.subject).toLowerCase() != subjectKey) {
        continue;
      }
      // Ưu tiên task chưa xong và khớp chính xác.
      if (name == needle && !task.isDone) return task;
      if (!task.isDone) fallback ??= task;
      fallback ??= task;
    }
    return fallback;
  }

  static String _foldText(String value) => AppSubjects.foldDiacritics(value)
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// SnackBar thống nhất cho hành động AI (có tuỳ chọn Hoàn tác).
  ///
  /// Nhận `ScaffoldMessengerState` thay vì `BuildContext` vì hành động luôn có
  /// `await` ở giữa — giữ context sống dai là mời lỗi "dùng context sau khi
  /// widget đã bị huỷ".
  static void _showAiSnackBar(
    ScaffoldMessengerState messenger, {
    required String message,
    required IconData icon,
    required Color color,
    VoidCallback? onUndo,
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: onUndo == null ? 4 : 5),
          action: onUndo == null
              ? null
              : SnackBarAction(
                  label: 'Hoàn tác',
                  textColor: Colors.white,
                  onPressed: onUndo,
                ),
        ),
      );
  }
}
