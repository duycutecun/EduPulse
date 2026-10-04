import 'package:edupulse/core/ai/ai_context.dart';
import 'package:edupulse/core/ai/ai_sprint4_planner.dart';
import 'package:edupulse/core/ai/ai_weakness_analyzer.dart';
import 'package:edupulse/core/constants/subject_catalog.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// QA-4.1 — Bộ kiểm thử Trợ lý AI (Sprint 4).
///
/// Bao phủ: Context Engine đa cấp độ (AI-4.1), Weakness Analyzer (AI-4.5) và
/// AI Study Planner — parse + idempotency (AI-4.4 / AI-4.6).
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  void seedTask(
    String id,
    String title,
    String subject, {
    String priority = 'medium',
    int minutes = 30,
    DateTime? scheduledAt,
    DateTime? deadline,
    int reschedule = 0,
    String status = 'todo',
  }) {
    final t = TodayTask(
      id: id,
      title: title,
      subject: subject,
      priority: priority,
      estimateMinutes: minutes,
      scheduledAt: scheduledAt,
      deadline: deadline,
      rescheduleCount: reschedule,
      status: status,
    );
    StorageService.setTodayTaskJson(id, t.toJsonString());
    StorageService.setTodayTaskIds([...StorageService.getTodayTaskIds(), id]);
  }

  void seedSession(
    String id,
    String subject,
    int minutes,
    DateTime at, {
    int? understanding,
    int? mood,
  }) {
    final s = StudySession(
      id: id,
      subject: subject,
      plannedMinutes: minutes,
      actualMinutes: minutes,
      completedAt: at,
      startedAt: at.subtract(Duration(minutes: minutes)),
      endedAt: at,
      status: StudySession.statusCompleted,
      understanding: understanding,
      mood: mood,
    );
    StorageService.setStudySessionJson(id, s.toJsonString());
    StorageService.setStudySessionIds(
        [...StorageService.getStudySessionIds(), id]);
  }

  group('AI-4.1 — AiStudyContext theo cấp độ', () {
    test('Level 0 (none) không gửi gì', () {
      seedTask('t1', 'Ôn hàm số', 'Toán');
      expect(AiStudyContext.buildFor(AiContextLevel.none), '');
    });

    test('Level 1 (task) chỉ mô tả bài hiện tại', () {
      final now = DateTime(2026, 10, 3, 10);
      final task = TodayTask(
        id: 't1',
        title: 'Ôn hàm số',
        subject: 'Toán',
        topic: 'Hàm số bậc hai',
        note: 'Chú ý điều kiện xác định',
        priority: 'high',
        estimateMinutes: 45,
      );
      final ctx = AiStudyContext.buildFor(
        AiContextLevel.task,
        now: now,
        task: task,
      );
      expect(ctx, contains('BÀI HỌC HIỆN TẠI: Ôn hàm số'));
      expect(ctx, contains('Hàm số bậc hai'));
      expect(ctx, contains('Chú ý điều kiện xác định'));
      // Không kéo theo dữ liệu không liên quan.
      expect(ctx, isNot(contains('ĐIỂM THI THỬ')));
    });

    test('Level 1 thiếu bài học → chuỗi rỗng, không đoán bừa', () {
      expect(AiStudyContext.buildFor(AiContextLevel.task), '');
    });

    test('Level 2 (today) có giờ hiện tại + nhiệm vụ hôm nay', () {
      final now = DateTime(2026, 10, 3, 9, 30);
      seedTask('t1', 'Ôn hàm số', 'Toán', minutes: 45);
      seedTask('t2', 'Luyện đề Lý', 'Lý',
          priority: 'high',
          minutes: 60,
          scheduledAt: now.subtract(const Duration(days: 1)));
      seedTask('t3', 'Đã xong', 'Hóa', status: 'completed');

      final ctx = AiStudyContext.buildFor(
        AiContextLevel.today,
        now: now,
        availableMinutes: 120,
      );
      expect(ctx, contains('THỜI ĐIỂM HIỆN TẠI'));
      expect(ctx, contains('09:30'));
      expect(ctx, contains('THỜI GIAN RẢNH HÔM NAY: khoảng 120 phút'));
      expect(ctx, contains('NHIỆM VỤ HÔM NAY'));
      expect(ctx, contains('Ôn hàm số'));
      expect(ctx, contains('QUÁ HẠN'));
    });

    test('Level 3 (learningProfile) có hiệu quả theo môn', () {
      final now = DateTime(2026, 10, 3, 10);
      seedSession('s1', 'Toán', 90, now.subtract(const Duration(days: 1)),
          understanding: 4);
      seedSession('s2', 'Hóa', 45, now.subtract(const Duration(days: 2)),
          understanding: 2);
      final ctx = AiStudyContext.buildFor(
        AiContextLevel.learningProfile,
        now: now,
      );
      expect(ctx, contains('PHIÊN FOCUS'));
      expect(ctx, contains('Toán'));
    });

    test('quyền riêng tư tắt → mọi cấp độ trả rỗng', () {
      seedTask('t1', 'Ôn hàm số', 'Toán');
      StorageService.setBool('ai_permission_read', false);
      expect(
        AiStudyContext.buildFor(
          AiContextLevel.today,
          task: TodayTask(id: 't1', title: 'x', subject: 'Toán'),
        ),
        '',
      );
    });

    test('Level 1 bị giới hạn ký tự', () {
      final task = TodayTask(
        id: 't1',
        title: 'Bài rất dài ${'x' * 2000}',
        subject: 'Toán',
        note: 'y' * 2000,
      );
      final ctx = AiStudyContext.buildFor(AiContextLevel.task, task: task);
      expect(ctx.length, lessThan(1400));
    });
  });

  group('AI-4.5 — WeaknessAnalyzer', () {
    test('thiếu dữ liệu → nói thật, không phán đoán', () {
      final report = WeaknessAnalyzer.analyze();
      expect(report.hasEnoughData, isFalse);
      expect(report.summary, contains('Chưa đủ dữ liệu'));
      expect(report.suggestions, isEmpty);
    });

    test('đủ ≥3 phiên → phân tích được', () {
      final now = DateTime.now();
      seedSession('s1', 'Toán', 60, now.subtract(const Duration(days: 1)));
      seedSession('s2', 'Toán', 60, now.subtract(const Duration(days: 2)));
      seedSession('s3', 'Hóa', 60, now.subtract(const Duration(days: 3)));
      final report = WeaknessAnalyzer.analyze();
      expect(report.hasEnoughData, isTrue);
      expect(report.summary, isNotEmpty);
    });
  });

  group('AI-4.4/4.6 — AiStudyPlannerService.parsePlan', () {
    test('bóc JSON, chuẩn hoá môn, kẹp thời lượng', () {
      final now = DateTime(2026, 10, 3, 9);
      const raw = '''
```json
{"summary":"Kế hoạch tuần","tasks":[
  {"title":"Ôn hàm số","subject":"toán","estimateMinutes":5,"priority":"high","date":"2027-01-01"},
  {"title":"Luyện đề","subject":"Lý","estimateMinutes":999}
]}
```''';
      final plan = AiStudyPlannerService.parsePlan(raw, now);
      expect(plan.summary, 'Kế hoạch tuần');
      expect(plan.tasks.length, 2);
      expect(plan.tasks.first.title, 'Ôn hàm số');
      expect(plan.tasks.first.subject, AppSubjects.normalize('toán'));
      // 5 phút bị kẹp lên tối thiểu 10.
      expect(plan.tasks.first.estimateMinutes, 10);
      // 999 phút bị kẹp xuống tối đa 120.
      expect(plan.tasks[1].estimateMinutes, 120);
    });

    test('bỏ qua phần tử thiếu title và không vỡ khi JSON lỗi', () {
      final now = DateTime(2026, 10, 3, 9);
      const raw =
          '{"summary":"x","tasks":[{"subject":"Toán"},{"title":"Hợp lệ"}]}';
      final plan = AiStudyPlannerService.parsePlan(raw, now);
      expect(plan.tasks.length, 1);
      expect(plan.tasks.first.title, 'Hợp lệ');

      final broken = AiStudyPlannerService.parsePlan('không phải json', now);
      expect(broken.isEmpty, isTrue);
      expect(broken.summary, isNotEmpty);
    });
  });

  group('AI-4.4/4.6 — applyPlan idempotent', () {
    test('áp dụng lần đầu tạo task, lần hai bỏ qua hết', () async {
      final now = DateTime(2026, 10, 3, 9);
      final tasks = <AiPlannedTask>[
        AiPlannedTask(
          id: 'a1',
          title: 'Ôn hàm số',
          subject: 'Toán',
          estimateMinutes: 30,
          priority: 'high',
          scheduledAt: now,
        ),
        AiPlannedTask(
          id: 'a2',
          title: 'Luyện đề Lý',
          subject: 'Lý',
          estimateMinutes: 45,
          priority: 'medium',
          scheduledAt: now,
        ),
      ];

      final first = await AiStudyPlannerService.applyPlan(tasks);
      expect(first.created, 2);
      expect(first.skipped, 0);

      // Áp dụng lại đúng kế hoạch → không nhân bản nhiệm vụ.
      final second = await AiStudyPlannerService.applyPlan(tasks);
      expect(second.created, 0);
      expect(second.skipped, 2);
    });
  });
}
