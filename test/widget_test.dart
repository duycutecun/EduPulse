import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/app/main_shell.dart';
import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/exams/domain/models/exam_model.dart'
    show ExamModel, ExamPhase;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'streak': 15,
      'streak_record': 35,
      'user_name': 'Sĩ tử 2k9',
      'user_target': 'ĐH Bách Khoa Hà Nội > 27đ',
      'study_log_ids': ['log-1'],
      'study_log_log-1': StudyLog(
        id: 'log-1',
        date: DateTime.now(),
        subject: 'Toán',
        hours: 2.0,
      ).toJsonString(),
    });
    await StorageService.init();
  });

  // Lưu ý: KHÔNG dùng pumpAndSettle — HomeScreen chạy Timer.periodic 1s
  // gọi setState mỗi tick nên pumpAndSettle sẽ treo.

  Finder navIcon(IconData icon) => find.byIcon(icon);

  testWidgets('Điều hướng 3 tab (Học, AI, Tôi)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MainShellScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // 1. Home (Học) — active mặc định
    expect(find.text('Chào Sĩ tử 2k9 👋'), findsOneWidget);
    expect(find.text('Nhiệm vụ hôm nay'), findsOneWidget);

    // 2. AI Coach — tap nhãn nav (icon trùng với quick action ở Home)
    await tester.tap(find.text('AI'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('AI Coach'), findsOneWidget);
    expect(navIcon(Icons.photo_camera_rounded), findsOneWidget);

    // 3. Tôi (Account)
    await tester.tap(find.text('Tôi'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sĩ tử 2k9'), findsOneWidget);
  });

  testWidgets('Pomodoro đổi chế độ 50/10 và Biểu đồ tuần có dữ liệu',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MainShellScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Vào trang Tập trung qua nút quick action trên Home
    await tester.tap(find.text('Tập trung'));
    await tester.pumpAndSettle();

    // Đổi chế độ sang 50/10
    await tester.tap(find.text('50/10'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('50:00'), findsOneWidget);

    // Sang tab Biểu đồ — đã seed 1 study log hôm nay
    await tester.tap(find.text('Biểu đồ'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Giờ học trong tuần'), findsOneWidget);
    expect(find.text('Phân bổ theo môn'), findsOneWidget);
  });

  testWidgets('Bảng vàng trong Tài khoản và Storage TodayTask',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MainShellScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Vào Account tab
    await tester.tap(navIcon(Icons.person_outline));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sĩ tử 2k9'), findsOneWidget);

    // Chuyển sang segment Bảng vàng (Supabase chưa cấu hình → empty state)
    await tester.tap(find.text('Bảng vàng'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bảng vàng đang chờ!'), findsOneWidget);

    // Storage round-trip TodayTask
    final task = TodayTask(
      id: 'task-v2',
      title: 'Luyện 50 câu ĐGNL TSA',
      subject: '📐 Toán',
      priority: 'high',
      estimateMinutes: 60,
    );
    StorageService.setTodayTaskJson(task.id, task.toJsonString());
    final loaded = StorageService.getTodayTaskJson('task-v2');
    expect(loaded, isNotNull);
    final parsed = TodayTask.fromJsonString(loaded!);
    expect(parsed.subject, '📐 Toán');
    expect(parsed.priority, 'high');
  });

  test('TodayTask lưu được metadata mở rộng và vẫn đọc dữ liệu cũ', () {
    final deadline = DateTime(2026, 10, 15);
    final task = TodayTask(
      id: 'task-rich',
      title: 'Ôn hàm số',
      subject: '📐 Toán',
      topic: 'Khảo sát hàm số',
      estimateMinutes: 60,
      deadline: deadline,
      note: 'Làm lại các câu sai',
      goalId: 'goal-1',
      subtasks: const ['Lý thuyết', 'Bài tập'],
      recurrence: 'weekly',
      status: 'skipped',
      skipReason: 'Quá khó',
      rescheduleCount: 2,
    );

    final restored = TodayTask.fromJsonString(task.toJsonString());
    expect(restored.topic, 'Khảo sát hàm số');
    expect(restored.deadline, deadline);
    expect(restored.subtasks, ['Lý thuyết', 'Bài tập']);
    expect(restored.recurrence, 'weekly');
    expect(restored.goalId, 'goal-1');
    expect(restored.status, 'skipped');
    expect(restored.skipReason, 'Quá khó');
    expect(restored.rescheduleCount, 2);

    final legacy = TodayTask.fromJsonString(
      '{"id":"old","title":"Nhiệm vụ cũ","subject":"Toán"}',
    );
    expect(legacy.estimateMinutes, 45);
    expect(legacy.deadline, isNull);
    expect(legacy.subtasks, isEmpty);
    expect(legacy.status, 'todo');
  });

  test('TodayTask và StudyNote giữ dữ liệu lịch/ghi chú qua serialize', () {
    final scheduled = DateTime(2026, 10, 16, 19);
    final task = TodayTask(
      id: 'calendar-task',
      title: 'Ôn chuyên đề',
      subject: '📐 Toán',
      scheduledAt: scheduled,
    );
    expect(TodayTask.fromJsonString(task.toJsonString()).scheduledAt, scheduled);

    final note = StudyNote(
      id: 'note-1',
      title: 'Công thức đạo hàm',
      body: 'Ghi nhớ quy tắc chuỗi.',
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 2),
      tags: const ['Toán', 'công thức'],
    );
    StorageService.setStudyNoteJson(note.id, note.toJsonString());
    StorageService.setStudyNoteIds([note.id]);
    final restored = StudyNote.fromJsonString(StorageService.getStudyNoteJson(note.id)!);
    expect(restored.tags, ['Toán', 'công thức']);
    expect(restored.body, 'Ghi nhớ quy tắc chuỗi.');
  });

  test('StudySession lưu liên kết nhiệm vụ và thời lượng focus', () {
    final session = StudySession(
      id: 'session-1',
      completedAt: DateTime(2026, 10, 1, 9, 30),
      taskId: 'task-1',
      subject: '📐 Toán',
      plannedMinutes: 25,
      actualMinutes: 25,
      mood: 4,
      focus: 5,
      difficulty: 3,
      understanding: 4,
      effectiveness: 5,
      reflectionNote: 'Hoàn thành tốt',
    );
    final restored = StudySession.fromJsonString(session.toJsonString());
    expect(restored.taskId, 'task-1');
    expect(restored.plannedMinutes, 25);
    expect(restored.actualMinutes, 25);
    expect(restored.focus, 5);
    expect(restored.reflectionNote, 'Hoàn thành tốt');

    StorageService.setStudySessionJson(session.id, session.toJsonString());
    StorageService.setStudySessionIds([session.id]);
    expect(StorageService.getStudySessionIds(), [session.id]);
    expect(StorageService.getStudySessionJson(session.id), isNotNull);
  });

  test('ExamModel lưu mục tiêu và điểm hiện tại', () {
    final exam = ExamModel(
      id: 'exam-1',
      name: 'Thi thử',
      dateTime: DateTime(2026, 12, 1),
      currentScore: 7.5,
      targetScore: 9.0,
    );
    final restored = ExamModel.fromJsonString(exam.toJsonString());
    expect(restored.currentScore, 7.5);
    expect(restored.targetScore, 9.0);
  });

  test('ExamModel xác định đúng giai đoạn Exam Mode', () {
    final now = DateTime.now();

    // Còn xa (> 7 ngày) → bình thường.
    final far = ExamModel(
      id: 'far',
      name: 'THPT QG',
      dateTime: DateTime(now.year, now.month, now.day + 30, 7, 30),
    );
    expect(far.examPhase, ExamPhase.normal);

    // Mai thi → revision (đặc tả mục 39: 7 ngày trước thi).
    final tomorrow = ExamModel(
      id: 'tomorrow',
      name: 'ĐGNL TSA',
      dateTime: DateTime(now.year, now.month, now.day + 1, 7, 30),
    );
    expect(tomorrow.examPhase, ExamPhase.revision);
    expect(tomorrow.isRevisionPeriod, isTrue);

    // Hôm nay là ngày thi (dù giờ thi đã qua nhưng chưa hết ngày).
    final today = ExamModel(
      id: 'today',
      name: 'HSA',
      dateTime: DateTime(now.year, now.month, now.day, 7, 0),
    );
    expect(today.examPhase, ExamPhase.examDay);

    // Hôm qua đã thi → post-exam.
    final past = ExamModel(
      id: 'past',
      name: 'Thi thử 10',
      dateTime: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1)),
    );
    expect(past.examPhase, ExamPhase.postExam);

    // Kết quả post-exam: chỉ kết luận khi đủ target + current.
    expect(
      past.copyWithCurrent(null).postExamResult,
      isNull,
    );
    expect(
      ExamModel(id: 'p2', name: 'x', dateTime: past.dateTime, currentScore: 9.0, targetScore: 9.0)
          .postExamResult,
      isTrue,
    );
    expect(
      ExamModel(id: 'p3', name: 'x', dateTime: past.dateTime, currentScore: 8.5, targetScore: 9.0)
          .postExamResult,
      isFalse,
    );
  });

  testWidgets('Exam Mode trên Home: ôn tập, ngày thi và sau thi',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime.now();
    var step = 0;
    // Key đổi mỗi lần pump để MainShellScreen đọc lại dữ liệu kỳ thi từ storage
    // (nếu không, State cũ được tái sử dụng và giữ exam cũ).
    Widget shell() => MaterialApp(
          theme: AppTheme.lightTheme,
          home: MainShellScreen(key: ValueKey('exam-mode-step-${step++}')),
        );

    // 1. Còn 3 ngày thi → revision banner trên Home.
    StorageService.setExamJson(
      'exam-mode',
      ExamModel(
        id: 'exam-mode',
        name: 'THPT QG 2026',
        dateTime: DateTime(now.year, now.month, now.day + 3, 7, 30),
      ).toJsonString(),
    );
    StorageService.setExamIds(['exam-mode']);
    StorageService.setPrimaryExamId('exam-mode');
    await tester.pumpWidget(shell());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Chế độ ôn tập đang bật'), findsOneWidget);

    // 2. Hôm nay là ngày thi → exam day card + ẩn danh sách task dài.
    StorageService.setExamJson(
      'exam-mode',
      ExamModel(
        id: 'exam-mode',
        name: 'THPT QG 2026',
        dateTime: DateTime(now.year, now.month, now.day, 7, 30),
      ).toJsonString(),
    );
    await tester.pumpWidget(shell());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hôm nay là ngày thi — làm tốt nhé!'), findsOneWidget);
    expect(find.text('Ôn nhẹ hôm nay (tùy chọn)'), findsNothing);

    // 3. Đã qua thi, chưa nhập điểm → post-exam “đang chờ kết quả”.
    StorageService.setExamJson(
      'exam-mode',
      ExamModel(
        id: 'exam-mode',
        name: 'THPT QG 2026',
        dateTime: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1)),
      ).toJsonString(),
    );
    await tester.pumpWidget(shell());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('THPT QG 2026 đã kết thúc — đang chờ kết quả'),
        findsOneWidget);
  });

  testWidgets('iPhone 390x844: 3 tab + trang Mục tiêu/Tập trung không tràn layout',
      (WidgetTester tester) async {
    // Logical 390x844 = iPhone 14/15 (physical 1170x2532 @3x).
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MainShellScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);

    // Home render gọn trong màn hẹp.
    expect(find.text('Chào Sĩ tử 2k9 👋'), findsOneWidget);
    expect(find.text('Nhiệm vụ hôm nay'), findsOneWidget);

    // Tab AI.
    await tester.tap(find.text('AI'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('AI Coach'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Tab Tôi.
    await tester.tap(find.text('Tôi'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sĩ tử 2k9'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Về Home, mở trang Mục tiêu qua thẻ đếm ngược.
    await tester.tap(find.text('Học'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Chưa chọn kỳ thi mục tiêu'));
    await tester.pumpAndSettle();
    expect(find.text('Kỳ Thi Của Tôi'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Route fullscreenDialog dùng nút Close (X) thay vì BackButton.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // Mở trang Tập trung qua quick action.
    await tester.tap(find.text('Tập trung'));
    await tester.pumpAndSettle();
    expect(find.text('Pomodoro'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
