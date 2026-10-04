import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/core/constants/app_colors.dart';
import 'package:edupulse/app/main_shell.dart';
import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:edupulse/features/study/domain/study_analytics.dart';
import 'package:edupulse/shared/widgets/note_markdown.dart';
import 'package:edupulse/core/notifications/adaptive_policy.dart';
import 'package:edupulse/features/study/domain/learning_profile.dart';
import 'package:edupulse/core/utils/data_transfer.dart';
import 'package:edupulse/core/theme/appearance_service.dart';
import 'package:edupulse/features/study/domain/quick_add_parser.dart';
import 'package:edupulse/features/study/domain/score_analysis.dart';
import 'package:edupulse/features/study/domain/optimize_week.dart';
import 'package:edupulse/features/study/domain/app_leaving.dart';
import 'package:edupulse/features/home/presentation/widgets/today_mission_card.dart';
import 'package:edupulse/features/ai_coach/presentation/screens/ai_coach_screen.dart';
import 'package:edupulse/core/ai/ai_feedback.dart';
import 'package:edupulse/features/ai_coach/presentation/widgets/chat_bubble.dart';
import 'package:edupulse/shared/widgets/app_bottom_sheet.dart';
import 'package:edupulse/features/search/presentation/screens/search_screen.dart';
import 'package:edupulse/features/study/presentation/widgets/score_chart_widget.dart';
import 'package:edupulse/core/sync/sync_state.dart';
import 'package:edupulse/core/migration/data_migration.dart';
import 'package:edupulse/shared/widgets/sync_status_bar.dart';
import 'package:edupulse/app/desktop_sidebar.dart';
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

  testWidgets('Điều hướng 4 tab (Hôm nay, Tiến độ, AI, Tôi)',
      (WidgetTester tester) async {
    // Viewport mobile logic 390x844 — không đụng desktop breakpoint 1024.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MainShellScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    // 1. Tab Hôm nay — active mặc định
    expect(find.text('Chào Sĩ tử 2k9 👋'), findsOneWidget);
    expect(find.text('Nhiệm vụ hôm nay'), findsOneWidget);

    // 2. Tab Tiến độ (Tổng quan tiến độ tuần + theo môn)
    await tester.tap(find.text('Tiến độ').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tiến độ học tập'), findsOneWidget);

    // 3. Tab AI Copilot
    await tester.tap(find.text('AI').last);
    await tester.pump(const Duration(milliseconds: 300));

    // 4. Tab Tôi (Account)
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
    await tester.tap(find.text('Tập trung').first);
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
    tester.view.physicalSize = const Size(390, 844);
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

  testWidgets('Onboarding wizard: tên → kỳ thi → quỹ thời gian → seed task',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const OnboardingScreen(),
        routes: {
          '/main': (context) => const MainShellScreen(),
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // Bước 1: nhập tên → Tiếp tục.
    await tester.enterText(find.byType(TextField), 'Minh');
    await tester.pump(); // rebuild để nút Tiếp tục được bật
    await tester.tap(find.text('Tiếp tục'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Kỳ thi mục tiêu của bạn là gì?'), findsOneWidget);

    // Bước 2: chọn preset THPTQG → card cấu hình xuất hiện → Tiếp tục.
    await tester.tap(find.text('Tốt nghiệp THPT'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Ngày thi:'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pump(const Duration(milliseconds: 400));

    // Bước 3: giữ mặc định 2 giờ → Xem lộ trình đề xuất.
    await tester.tap(find.text('Xem lộ trình đề xuất'));
    // AI retry nhiều model — pump đủ thời gian giả để request lỗi xong.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 20));

    // Bước 4: AI (môi trường test không gọi được mạng) sẽ lỗi → fallback.
    expect(
      find.textContaining('Chưa tạo được lộ trình AI'),
      findsWidgets,
    );
    await tester.tap(find.text('Bắt đầu với nhiệm vụ mẫu'));
    // Push replacement + transition: pump đủ lâu để vào thẳng MainShell.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Đã vào app chính với kỳ thi chính + task seed.
    expect(find.text('Chào Minh 👋'), findsOneWidget);
    expect(StorageService.isOnboardingDone(), isTrue);
    expect(StorageService.getUserName(), 'Minh');
    expect(StorageService.getPrimaryExamId(), 'thptqg');
    expect(StorageService.getTodayTaskIds(), isNotEmpty);
  });

  group('Study Analytics (đặc tả mục 12)', () {
    StudySession session({
      required DateTime at,
      int minutes = 30,
      int? focus,
      int? effectiveness,
      int? understanding,
    }) {
      return StudySession(
        id: 's-${at.millisecondsSinceEpoch}',
        completedAt: at,
        subject: '📐 Toán',
        plannedMinutes: minutes,
        actualMinutes: minutes,
        focus: focus,
        effectiveness: effectiveness,
        understanding: understanding,
      );
    }

    final now = DateTime(2026, 9, 30, 10); // thứ Tư.

    test('So sánh tuần: hơn 18% như ví dụ đặc tả', () {
      final sessions = [
        // Tuần trước: 100 phút (2 phiên).
        session(at: now.subtract(const Duration(days: 9)), minutes: 50),
        session(at: now.subtract(const Duration(days: 8)), minutes: 50),
        // Tuần này: 118 phút.
        session(at: now.subtract(const Duration(days: 1)), minutes: 59),
        session(at: now.subtract(const Duration(days: 2)), minutes: 59),
      ];
      final result = compareWeeks(sessions, now);
      expect(result.thisWeekMinutes, 118);
      expect(result.lastWeekMinutes, 100);
      expect(result.percentDelta, 18);
      expect(result.message, 'Tuần này bạn học nhiều hơn 18%.');
    });

    test('So sánh tuần: tuần trước trống → không phần trăm, thông điệp khích lệ', () {
      final result = compareWeeks([
        session(at: now, minutes: 30),
      ], now);
      expect(result.percentDelta, isNull);
      expect(result.message, contains('bắt đầu'));
    });

    test('Efficiency: không đủ 3 phản hồi → null (không đoán)', () {
      final result = efficiency([
        session(at: now, focus: 5, effectiveness: 5),
        session(at: now, focus: 4, effectiveness: 4),
      ], now);
      expect(result, isNull);
    });

    test('Efficiency: composite theo trọng số và delta so với tuần trước', () {
      final result = efficiency([
        // Tuần này: 3 phiên focus 5, eff 5, hiểu 4.
        session(at: now, focus: 5, effectiveness: 5, understanding: 4),
        session(at: now, focus: 5, effectiveness: 5, understanding: 4),
        session(at: now, focus: 5, effectiveness: 5, understanding: 4),
        // Tuần trước: 3 phiên focus 3, eff 3, hiểu 3.
        session(at: now.subtract(const Duration(days: 7)), focus: 3, effectiveness: 3, understanding: 3),
        session(at: now.subtract(const Duration(days: 7)), focus: 3, effectiveness: 3, understanding: 3),
        session(at: now.subtract(const Duration(days: 7)), focus: 3, effectiveness: 3, understanding: 3),
      ], now);
      expect(result, isNotNull);
      // (5*0.4 + 5*0.35 + 4*0.25) / 5 = 0.95 → 95.
      expect(result!.score, 95);
      expect(result.deltaVsLastWeek, 35); // tuần trước: (3*0.4+3*0.35+3*0.25)/5 = 0.6 → 60.
      expect(result.sampleCount, 3);
    });

    test('Focus pattern: phiên dài focus thấp hơn → gợi ý rút ngắn', () {
      final tip = focusPatternTip([
        // 3 phiên 60 phút focus thấp.
        session(at: now, minutes: 60, focus: 2),
        session(at: now, minutes: 60, focus: 2),
        session(at: now, minutes: 60, focus: 3),
        // 3 phiên 25 phút focus cao.
        session(at: now, minutes: 25, focus: 5),
        session(at: now, minutes: 25, focus: 5),
        session(at: now, minutes: 25, focus: 4),
      ]);
      expect(tip, isNotNull);
      expect(tip, contains('phiên dài'));
    });

    test('Focus pattern: chưa đủ mẫu → null', () {
      expect(
        focusPatternTip([session(at: now, minutes: 60, focus: 2)]),
        isNull,
      );
    });

    test('Best study time: tối tập trung tốt hơn hẳn → gợi ý', () {
      final tip = bestStudyTime([
        // Sáng: 3 phiên focus 3 (avg 3.0).
        session(at: DateTime(2026, 9, 30, 8), focus: 3),
        session(at: DateTime(2026, 9, 30, 9), focus: 3),
        session(at: DateTime(2026, 9, 30, 10), focus: 3),
        // Tối: 3 phiên focus 4.5→5 (avg 5.0).
        session(at: DateTime(2026, 9, 30, 19), focus: 5),
        session(at: DateTime(2026, 9, 30, 20), focus: 5),
        session(at: DateTime(2026, 9, 30, 21), focus: 5),
      ]);
      expect(tip, isNotNull);
      expect(tip, contains('tối'));
    });

    test('Best study time: chênh lệch nhỏ → không kết luận', () {
      final tip = bestStudyTime([
        session(at: DateTime(2026, 9, 30, 8), focus: 4),
        session(at: DateTime(2026, 9, 30, 9), focus: 4),
        session(at: DateTime(2026, 9, 30, 10), focus: 4),
        session(at: DateTime(2026, 9, 30, 19), focus: 4),
        session(at: DateTime(2026, 9, 30, 20), focus: 4),
        session(at: DateTime(2026, 9, 30, 21), focus: 4),
      ]);
      expect(tip, isNull);
    });
  });

  testWidgets('NoteMarkdown render heading, list, checklist, code và đậm',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NoteMarkdown(
              body: '# Ôn tập\n## Lý thuyết\nĐạo hàm là **quan trọng** và *hay ra đề*.\n- Chuỗi: [f(g(x))]' 
                  '\n1. Lấy đạo hàm\n2. Thay số\n- [x] Học thuộc công thức\n- [ ] Làm bài tập\n> Ghi nhớ: quy tắc chuỗi'
                  '\n```\nf(x) = x^2\n```\nCông thức: \$x^2 + 1\$\n---',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Ôn tập'), findsOneWidget);
    expect(find.text('Lý thuyết'), findsOneWidget);
    expect(find.text('Lấy đạo hàm'), findsOneWidget);
    expect(find.text('Thay số'), findsOneWidget);
    // Checklist hiển thị cả done lẫn chưa done.
    expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsOneWidget);
    // Khối code giữ nguyên nội dung.
    expect(find.textContaining('f(x) = x^2'), findsOneWidget);
    // Đường kẻ ngang.
    expect(find.byType(Divider), findsOneWidget);
    // Inline đậm/nghiêng: text đầy đủ nằm trong một Text.rich — kiểm tra
    // qua plain text.
    expect(
      find.byWidgetPredicate((w) =>
          w is RichText &&
          (w.text as TextSpan).toPlainText().contains('quan trọng')),
      findsOneWidget,
    );
    // LaTeX inline được render thành widget Math (flutter_math_fork),
    // không phải text thô còn dấu $.
    expect(
      find.byWidgetPredicate((w) => w.runtimeType.toString().contains('Math')),
      findsWidgets,
    );
    expect(find.textContaining(r'$x^2 + 1$'), findsNothing);
  });

  group('Adaptive notifications (đặc tả mục 16)', () {
    test('Bỏ qua nhắc nhiều ngày → tần suất thưa dần, không bỏ hẳn', () {
      final now = DateTime(2026, 9, 30, 10);

      // Mở app hôm qua → nhắc mỗi ngày.
      StorageService.setString(
          'notif_last_open',
          DateTime(now.year, now.month, now.day - 1)
              .toIso8601String()
              .substring(0, 10));
      expect(AdaptivePolicy.reminderIntervalDays(now), 1);

      // Bỏ qua 3 ngày → mỗi 2 ngày.
      StorageService.setString(
          'notif_last_open',
          DateTime(now.year, now.month, now.day - 4)
              .toIso8601String()
              .substring(0, 10));
      expect(AdaptivePolicy.reminderIntervalDays(now), 2);

      // Bỏ qua 6 ngày → mỗi 3 ngày.
      StorageService.setString(
          'notif_last_open',
          DateTime(now.year, now.month, now.day - 7)
              .toIso8601String()
              .substring(0, 10));
      expect(AdaptivePolicy.reminderIntervalDays(now), 3);

      // Bỏ qua 10 ngày → mỗi tuần (không biến mất).
      StorageService.setString(
          'notif_last_open',
          DateTime(now.year, now.month, now.day - 11)
              .toIso8601String()
              .substring(0, 10));
      expect(AdaptivePolicy.reminderIntervalDays(now), 7);
    });

    test('Trong Focus chặn notification thường, urgent vẫn được qua', () {
      StorageService.setBool('notif_in_focus', true);
      expect(AdaptivePolicy.shouldNotifyNow(isUrgent: false), isFalse);
      expect(AdaptivePolicy.shouldNotifyNow(isUrgent: true), isTrue);
      StorageService.setBool('notif_in_focus', false);
      expect(AdaptivePolicy.shouldNotifyNow(isUrgent: false), isTrue);
    });

    test('Digest: đúng tóm tắt task còn lại, phút focus và đếm ngược thi', () {
      final now = DateTime(2026, 9, 30, 20);
      final digest = AdaptivePolicy.buildDigest(
        tasks: [
          TodayTask(id: 't1', title: 'Giải đề Toán', subject: '📐 Toán'),
          TodayTask(
              id: 't2', title: 'Học từ vựng', subject: '🇬🇧 Anh', isDone: true),
          TodayTask(
              id: 't3', title: 'Đã bỏ qua', subject: '📖 Văn', status: 'skipped'),
          TodayTask(
              id: 't4',
              title: 'Ngày mai mới làm',
              subject: '⚡ Lý',
              scheduledAt: DateTime(2026, 10, 1)),
        ],
        sessions: [
          StudySession(
            id: 's1',
            completedAt: now,
            subject: '📐 Toán',
            plannedMinutes: 25,
            actualMinutes: 25,
          ),
        ],
        primaryExam: ExamModel(
          id: 'e1',
          name: 'THPT QG',
          dateTime: now.add(const Duration(days: 42)),
        ),
        now: now,
      );

      expect(digest.title, 'Tóm tắt hôm nay — còn 1 nhiệm vụ');
      expect(digest.body, contains('Focus 25 phút'));
      expect(digest.body, contains('Giải đề Toán'));
      expect(digest.body, isNot(contains('Học từ vựng'))); // đã done
      expect(digest.body, isNot(contains('Đã bỏ qua'))); // skipped
      expect(digest.body, isNot(contains('Ngày mai mới làm'))); // scheduled khác ngày
      expect(digest.body, contains('THPT QG còn 42 ngày'));
    });

    test('Digest khi hoàn thành hết: chúc mừng thay vì ép học thêm', () {
      final digest = AdaptivePolicy.buildDigest(
        tasks: [TodayTask(id: 't1', title: 'X', subject: '📐 Toán', isDone: true)],
        sessions: const [],
        primaryExam: null,
        now: DateTime(2026, 9, 30, 20),
      );
      expect(digest.title, contains('xong hết'));
    });
  });

  group('Learning Profile (đặc tả mục 17, 37)', () {
    StudySession sess({
      required DateTime at,
      int minutes = 25,
      int? focus,
      int? difficulty,
    }) {
      return StudySession(
        id: 'lp-${at.millisecondsSinceEpoch}-$focus-$difficulty',
        completedAt: at,
        subject: '📐 Toán',
        plannedMinutes: minutes,
        actualMinutes: minutes,
        focus: focus,
        difficulty: difficulty,
      );
    }

    test('Chưa đủ dữ liệu → hồ sơ rỗng, không đoán', () {
      final traits = buildLearningProfile(
        sessions: [sess(at: DateTime(2026, 9, 30, 20), focus: 5)],
        tasks: const [],
        overrides: const {},
      );
      expect(traits, isEmpty);
    });

    test('Best study time: tối vượt trội → suy luận Medium confidence', () {
      final traits = buildLearningProfile(
        sessions: [
          // Sáng: 3 phiên focus 3.
          sess(at: DateTime(2026, 9, 30, 8), focus: 3),
          sess(at: DateTime(2026, 9, 30, 9), focus: 3),
          sess(at: DateTime(2026, 9, 30, 10), focus: 3),
          // Tối: 3 phiên focus 5.
          sess(at: DateTime(2026, 9, 30, 19), focus: 5),
          sess(at: DateTime(2026, 9, 30, 20), focus: 5),
          sess(at: DateTime(2026, 9, 30, 21), focus: 5),
        ],
        tasks: const [],
        overrides: const {},
      );
      final time = traits.firstWhere((t) => t.label == 'Thời gian học hiệu quả');
      expect(time.value, 'Tối (17h–23h)');
      expect(time.confidence, Confidence.medium);
      expect(time.isUserOverride, isFalse);
    });

    test('User override luôn thắng suy luận và đánh dấu "Bạn tự chỉnh"', () {
      final traits = buildLearningProfile(
        sessions: [
          sess(at: DateTime(2026, 9, 30, 19), focus: 5),
          sess(at: DateTime(2026, 9, 30, 20), focus: 5),
          sess(at: DateTime(2026, 9, 30, 21), focus: 5),
        ],
        tasks: const [],
        overrides: const {'best_time': 'Sáng (5h–11h)'},
      );
      final time = traits.firstWhere((t) => t.label == 'Thời gian học hiệu quả');
      expect(time.value, 'Sáng (5h–11h)');
      expect(time.isUserOverride, isTrue);
    });

    test('Session length: mode bội 15 vượt trội mới kết luận', () {
      // 5 phiên 25 phút → bucket 15 (1 phiên) và 3 phiên... tính lại:
      // 25 phút → bucket 15; cần rõ ràng.
      final sessions = List.generate(5, (i) => sess(at: DateTime(2026, 9, 30, 19 + i)));
      final traits = buildLearningProfile(
        sessions: sessions,
        tasks: const [],
        overrides: const {},
      );
      // Tất cả 25 phút → bucket 15 duy nhất, không cần so sánh.
      final length = traits.firstWhere((t) => t.label == 'Độ dài phiên phù hợp');
      expect(length.value, '15 phút');
    });

    test('Môn bị bỏ qua nhiều hơn hoàn thành → hypothesis Low confidence', () {
      final tasks = [
        TodayTask(id: 'a', title: 'Toán 1', subject: '📐 Toán', status: 'skipped'),
        TodayTask(id: 'b', title: 'Toán 2', subject: '📐 Toán', status: 'skipped'),
        TodayTask(id: 'c', title: 'Toán 3', subject: '📐 Toán', isDone: true),
      ];
      final traits = buildLearningProfile(
        sessions: const [],
        tasks: tasks,
        overrides: const {},
      );
      final avoided = traits.firstWhere(
          (t) => t.label == 'Môn có vẻ đang bị trì hoãn');
      expect(avoided.value, '📐 Toán');
      expect(avoided.confidence, Confidence.low);
      expect(avoided.evidence, contains('Có thể'));
    });
  });

  group('Data export/import (đặc tả mục 19)', () {
    test('Export JSON chứa đủ toàn bộ dữ liệu', () {
      final task = TodayTask(
          id: 'exp-t1', title: 'Giải đề', subject: '📐 Toán');
      StorageService.setTodayTaskJson(task.id, task.toJsonString());
      StorageService.setTodayTaskIds(['exp-t1']);

      final data = jsonDecode(DataTransfer.exportJson());
      expect(data['app'], 'EduPulse');
      expect((data['tasks'] as List).length, 1);
    });

    test('Import roundtrip: thêm bản ghi mới, bỏ qua trùng, giữ data cũ', () {
      final task = TodayTask(
          id: 'rt-t1', title: 'Task gốc', subject: '📐 Toán');
      StorageService.setTodayTaskJson(task.id, task.toJsonString());
      StorageService.setTodayTaskIds(['rt-t1']);

      final importTask =
          TodayTask(id: 'rt-t2', title: 'Task nhập', subject: '🇬🇧 Anh');
      final payload = jsonEncode({
        'app': 'EduPulse',
        'schema': 1,
        'tasks': [task.toJsonString(), importTask.toJsonString()],
      });

      final result = DataTransfer.importJson(payload);
      expect(result.error, isEmpty);
      expect(result.imported, 1); // rt-t2 mới
      expect(result.skipped, 1); // rt-t1 trùng
      expect(StorageService.getTodayTaskIds(), containsAll(['rt-t1', 'rt-t2']));
    });

    test('Import JSON hỏng / sai app → lỗi rõ ràng, không crash', () {
      // Seed 1 task để xác nhận dữ liệu cũ không bị ảnh hưởng.
      final task = TodayTask(id: 'safe-t1', title: 'An toàn', subject: '📐 Toán');
      StorageService.setTodayTaskJson(task.id, task.toJsonString());
      StorageService.setTodayTaskIds(['safe-t1']);

      expect(DataTransfer.importJson('không phải json').error, isNotEmpty);
      expect(
        DataTransfer.importJson('{"app":"Khác","tasks":[]}').error,
        isNotEmpty,
      );
      // Dữ liệu cũ vẫn nguyên vẹn.
      expect(StorageService.getTodayTaskIds(), contains('safe-t1'));
    });

    test('CSV nhật ký có header và dòng dữ liệu; Markdown ghi chú gộp đủ', () {
      final log = StudyLog(
        id: 'csv-1',
        date: DateTime(2026, 9, 30),
        subject: '📐 Toán',
        hours: 1.5,
      );
      StorageService.setStudyLogJson(log.id, log.toJsonString());
      StorageService.setStudyLogIds(['csv-1']);

      final csv = DataTransfer.exportStudyLogCsv();
      expect(csv.startsWith('date,subject,hours,note'), isTrue);
      expect(csv, contains('2026-09-30,📐 Toán,1.50'));

      final note = StudyNote(
        id: 'md-1',
        title: 'Công thức đạo hàm',
        body: 'Quy tắc chuỗi.',
        createdAt: DateTime(2026, 9, 30),
        updatedAt: DateTime(2026, 9, 30),
      );
      StorageService.setStudyNoteJson(note.id, note.toJsonString());
      StorageService.setStudyNoteIds(['md-1']);

      final md = DataTransfer.exportNotesMarkdown();
      expect(md, contains('## Công thức đạo hàm'));
      expect(md, contains('Quy tắc chuỗi.'));
    });

    test('Xóa dữ liệu học: task/note/session/exam/log về 0, cài đặt giữ', () {
      StorageService.setTodayTaskIds(['del-t1']);
      StorageService.setStudyNoteIds(['del-n1']);
      StorageService.setString('user_name', 'Minh');
      StorageService.setBool('reminder_enabled', true);

      DataTransfer.deleteAllStudyData();

      expect(StorageService.getTodayTaskIds(), isEmpty);
      expect(StorageService.getStudyNoteIds(), isEmpty);
      // Cài đặt và profile không bị xóa.
      expect(StorageService.getUserName(), 'Minh');
      expect(StorageService.getBool('reminder_enabled'), true);
    });
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

  testWidgets('Desktop 1440x900: sidebar hiển thị, collapse còn icon + tooltip',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MainShellScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // Sidebar expanded: có tiêu đề app + nhãn mục điều hướng.
    expect(find.text('EduPulse'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    // Không còn bottom nav của mobile (không tìm thấy icon person nhiều hơn 1).

    // Collapse sidebar.
    await tester.tap(find.byTooltip('Thu gọn thanh điều hướng'));
    await tester.pump(const Duration(milliseconds: 400));

    // Expanded title biến mất; tooltip vẫn dẫn tới nhãn mục ẩn.
    expect(find.text('EduPulse'), findsNothing);
    expect(find.byTooltip('Calendar'), findsOneWidget);
    expect(find.byTooltip('Notes'), findsOneWidget);

    // Mở rộng lại.
    await tester.tap(find.byTooltip('Mở rộng thanh điều hướng'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('EduPulse'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Score analysis (đặc tả mục 41)', () {
    MockScore ms(int day, double score, [String subject = 'THPT QG']) =>
        MockScore(
          id: 'ms-$day-$score',
          date: DateTime(2026, 9, day),
          subject: subject,
          score: score,
        );

    test('Dưới 2 điểm → không kết luận xu hướng', () {
      expect(analyzeTrend([ms(1, 7)]).trend, isNull);
    });

    test('Điểm giảm ≥3 lần liên tiếp → đề xuất điều chỉnh', () {
      final insight = scoreInsight([
        ms(1, 8),
        ms(5, 7.5),
        ms(10, 7),
        ms(15, 6.5),
      ]);
      expect(insight, contains('giảm 3 lần'));
      expect(insight, contains('giảm khối lượng'));
    });

    test('Điểm tăng → ghi nhận nhịp học phù hợp (không khẳng định nguyên nhân)', () {
      final insight = scoreInsight([
        ms(1, 6.5),
        ms(10, 7.5),
      ]);
      expect(insight, contains('+1.0'));
      expect(insight, contains('Có vẻ'));
    });

    test('Có target → so khoảng cách khi trend flat', () {
      final insight = scoreInsight(
        [ms(1, 7.0), ms(5, 7.0)],
        targetScore: 9.0,
      );
      expect(insight, contains('Còn 2.0 điểm'));
    });

    test('Phân tích theo môn: yếu nhất đứng đầu, cần ≥2 điểm mỗi môn', () {
      final subjects = analyzeBySubject([
        ms(1, 6.0, '📐 Toán'),
        ms(10, 6.5, '📐 Toán'),
        ms(2, 8.0, '🇬🇧 Anh'),
        ms(11, 8.5, '🇬🇧 Anh'),
        ms(3, 7.0, '📖 Văn'), // 1 điểm — bị bỏ qua.
      ]);
      expect(subjects.length, 2);
      expect(subjects.first.subject, '📐 Toán'); // yếu nhất đầu tiên.
      expect(subjects.first.improving, isTrue);
    });
  });

  group('Score chart widget (đặc tả mục 41)', () {
    MockScore ms(int day, double score, [String subject = '📐 Toán']) =>
        MockScore(
          id: 'sc-$day-$score-$subject',
          date: DateTime(2026, 9, day),
          subject: subject,
          score: score,
        );

    Widget host(List<MockScore> scores, {ExamModel? exam}) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScoreChartWidget(scores: scores, primaryExam: exam),
            ),
          ),
        );

    testWidgets('≥2 điểm cùng môn → vẽ chart + insight + so target',
        (WidgetTester tester) async {
      await tester.pumpWidget(host([
        ms(1, 6.5),
        ms(10, 7.5),
      ], exam: ExamModel(
        id: 'exam-1',
        name: 'THPT QG 2027',
        dateTime: DateTime(2027, 6, 26),
        targetScore: 9.0,
      )));
      await tester.pump();

      expect(find.text('Tiến bộ điểm thi thử'), findsOneWidget);
      // Trend up → chip +1.0 và insight "Có vẻ nhịp học hiện tại đang phù hợp".
      expect(find.text('+1.0'), findsOneWidget);
      expect(find.textContaining('Có vẻ nhịp học'), findsOneWidget);
      // Có đường target 9.0 → painter không crash + hiển thị điểm mới nhất.
      expect(find.text('7.5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Đủ 2 môn → so sánh giữa các môn, yếu nhất đầu tiên',
        (WidgetTester tester) async {
      await tester.pumpWidget(host([
        ms(1, 8.0, '🇬🇧 Anh'),
        ms(11, 8.5, '🇬🇧 Anh'),
        ms(2, 6.0),
        ms(10, 6.5),
      ]));
      await tester.pump();

      expect(find.text('So sánh giữa các môn'), findsOneWidget);
      // Môn Toán (TB thấp hơn) đứng trên Anh.
      final toanY = tester.getTopLeft(find.text('📐 Toán')).dy;
      final anhY = tester.getTopLeft(find.text('🇬🇧 Anh')).dy;
      expect(toanY, lessThan(anhY));
    });

    testWidgets('1 điểm duy nhất → card gợi ý thi thử thêm, không vẽ chart',
        (WidgetTester tester) async {
      await tester.pumpWidget(host([ms(1, 7.0)]));
      await tester.pump();

      expect(find.text('Chưa đủ dữ liệu vẽ biểu đồ'), findsOneWidget);
      expect(find.textContaining('thi thử thêm 1 lần nữa'), findsOneWidget);
      expect(find.text('Tiến bộ điểm thi thử'), findsNothing);
    });
  });

  group('Sync states (đặc tả mục 19)', () {
    test('Chuyển trạng thái Syncing → Offline/Error/Synced đúng label', () {
      SyncStateService.markSyncing();
      expect(SyncStateService.state.value.status, SyncStatus.syncing);
      expect(SyncStateService.state.value.label, 'Đang đồng bộ…');

      // Offline: trạng thái an toàn mặc định — thông điệp không gây lo lắng.
      SyncStateService.updateConnectivity(isOnline: false);
      expect(SyncStateService.state.value.status, SyncStatus.offline);

      SyncStateService.markError();
      expect(SyncStateService.state.value.status, SyncStatus.error);
      expect(SyncStateService.state.value.label, contains('thử lại'));

      SyncStateService.markSynced();
      expect(SyncStateService.state.value.status, SyncStatus.synced);
      expect(SyncStateService.state.value.lastSyncedAtMs, isNotNull);
      expect(StorageService.getInt('last_cloud_sync_ms'), isNotNull);
    });

    testWidgets('SyncStatusBar: offline → chip cam nhẹ nhàng, không đỏ cảnh báo',
        (WidgetTester tester) async {
      SyncStateService.updateConnectivity(isOnline: false);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: SyncStatusBar())),
      ));
      await tester.pump();

      expect(find.text('Ngoại tuyến — lưu trên máy'), findsOneWidget);
      // Trạng thái synced mới nhất vẫn giữ để hiển thị khi online lại.

      // Dọn trạng thái chung cho các test khác.
      SyncStateService.updateConnectivity(isOnline: true);
    });

    testWidgets('SyncStatusBar: synced vừa xong → chip xanh + nhãn đúng',
        (WidgetTester tester) async {
      SyncStateService.markSynced();
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: SyncStatusBar())),
      ));
      await tester.pump();

      expect(find.text('Đã đồng bộ vừa xong'), findsOneWidget);
    });
  });

  group('Data migration (đặc tả mục 42)', () {
    test('Schema mới nhất → bỏ qua, idempotent', () {
      StorageService.setInt('data_schema_version', DataMigration.currentSchemaVersion);
      final report = DataMigration.run([
        MigrationStep('noop', () => true),
      ]);
      expect(report.ran, isFalse);
      expect(report.success, isTrue);
    });

    test('Thành công: chạy đủ bước + lưu version mới', () {
      StorageService.setInt('data_schema_version', 0);
      var calls = 0;
      final report = DataMigration.run([
        MigrationStep('step_a', () {
          calls++;
          return true;
        }),
        MigrationStep('step_b', () => true),
      ]);
      expect(report.ran, isTrue);
      expect(report.success, isTrue);
      expect(report.stepsRun, ['step_a', 'step_b']);
      expect(calls, 1);
      expect(DataMigration.storedVersion(), DataMigration.currentSchemaVersion);
    });

    test('Lỗi giữa chừng → rollback snapshot + restore + notify', () {
      StorageService.setInt('data_schema_version', 0);
      StorageService.setString('migration_test_key', 'giữ tôi');
      final report = DataMigration.run([
        MigrationStep('mutate', () {
          // Bước "hỏng" làm hỏng dữ liệu rồi fail.
          StorageService.setString('migration_test_key', 'bị ghi đè');
          return false;
        }),
      ]);
      expect(report.rolledBack, isTrue);
      expect(report.userMessage, contains('an toàn'));
      // Restore đúng giá trị trước migration.
      expect(StorageService.getString('migration_test_key'), 'giữ tôi');
      expect(DataMigration.lastReport?.rolledBack, isTrue);
    });

    test('dedupe_id_lists: dẹp trùng giữ thứ tự', () {
      StorageService.prefs.setStringList('today_task_ids', ['a', 'b', 'a', 'c', 'b']);
      StorageService.setInt('data_schema_version', 0);
      DataMigration.run(DataMigration.defaultSteps());
      expect(StorageService.prefs.getStringList('today_task_ids'), ['a', 'b', 'c']);
    });

    test('normalize_task_json: JSON thống nhất shape, giữ entry hỏng', () {
      final task = TodayTask(
        id: 'mig-1',
        title: 'Học toán',
        subject: '📐 Toán',
      );
      StorageService.setTodayTaskJson('mig-1', task.toJsonString());
      StorageService.setTodayTaskIds(['mig-1', 'mig-broken']);
      StorageService.prefs.setString('task_mig-broken', '{không phải json');
      StorageService.setInt('data_schema_version', 0);

      final report = DataMigration.run(DataMigration.defaultSteps());
      expect(report.success, isTrue);
      // Entry tốt vẫn đọc được; entry hỏng KHÔNG bị xóa (không mất dữ liệu).
      expect(TodayTask.fromJsonString(StorageService.getTodayTaskJson('mig-1')!).title, 'Học toán');
      expect(StorageService.getTodayTaskJson('mig-broken'), '{không phải json');
    });
  });

  group('Sidebar keyboard navigation (mục 21)', () {
    void noop() {}
    final items = [
      const NavItem(Icons.home_outlined, Icons.home_rounded, 'Học'),
      const NavItem(Icons.auto_awesome_outlined, Icons.auto_awesome, 'AI'),
      const NavItem(Icons.person_outline, Icons.person_rounded, 'Tôi'),
    ];

    Widget host() => MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                DesktopSidebar(
                  index: 0,
                  items: items,
                  onChanged: (_) {},
                  secondaryItems: [
                    DesktopNavAction(
                        icon: Icons.calendar_month_rounded,
                        label: 'Lịch',
                        onOpen: noop),
                  ],
                  collapsed: false,
                  onToggleCollapse: noop,
                  userName: 'Sĩ tử',
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        );

    testWidgets('Arrow Down/Up di chuyển focus giữa các mục nav có wrap',
        (WidgetTester tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      // Focus mục đầu (Học) — node index 0 trong danh sách nav của state.
      final state = tester.state<DesktopSidebarState>(find.byType(DesktopSidebar));
      state.navFocusNodes.first.requestFocus();
      await tester.pump();

      // Arrow Down → mục 'AI'.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(state.navFocusNodes[1]));

      // Arrow Up → quay lại 'Học'; Up lần nữa → wrap về mục cuối (Lịch).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(state.navFocusNodes[0]));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(state.navFocusNodes.last));
    });

    testWidgets('Enter kích hoạt mục đang focus → đổi tab',
        (WidgetTester tester) async {
      var changed = -1;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              DesktopSidebar(
                index: 0,
                items: items,
                onChanged: (i) => changed = i,
                secondaryItems: const [],
                collapsed: false,
                onToggleCollapse: noop,
                userName: 'Sĩ tử',
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ));
      await tester.pump();

      final state = tester.state<DesktopSidebarState>(find.byType(DesktopSidebar));
      state.navFocusNodes[1].requestFocus(); // mục 'AI'.
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(changed, 1);
    });
  });

  group('Optimize Week (đặc tả mục 13)', () {
    TodayTask task(
      String id, {
      int minutes = 45,
      String priority = 'medium',
      DateTime? deadline,
    }) =>
        TodayTask(
          id: id,
          title: 'Nhiệm vụ $id',
          subject: '📐 Toán',
          priority: priority,
          estimateMinutes: minutes,
          deadline: deadline,
        );

    StudySession session(
      int hour,
      int rating, [
      DateTime? at,
    ]) =>
        StudySession(
          id: 's-$hour-$rating',
          completedAt: at ?? DateTime(2026, 9, 20, hour),
          subject: '📐 Toán',
          plannedMinutes: 45,
          actualMinutes: 45,
          effectiveness: rating,
        );

    test('Không có task chưa xếp lịch → rỗng (không bịa đề xuất)', () {
      expect(proposeWeekPlan([], now: DateTime(2026, 9, 30)), isEmpty);
    });

    test('Deadline gần xếp trước; không bao giờ xếp vào đúng ngày deadline', () {
      final now = DateTime(2026, 9, 30, 10);
      final proposals = proposeWeekPlan([
        task('far', deadline: DateTime(2026, 10, 20)),
        task('near', deadline: DateTime(2026, 10, 2)),
      ], now: now);

      expect(proposals.first.task.id, 'near');
      // Xếp sớm nhất có thể — hôm nay còn trống → 30/9.
      expect(proposals.first.proposedStart.day, 30);
      expect(proposals.first.reason, contains('deadline'));

      // Hôm nay đầy (120') → chuyển sang 1/10, tuyệt đối không 2/10
      // (margin an toàn: dừng trước deadline ≥ 1 ngày).
      final full = proposeWeekPlan([
        task('filler', minutes: 120, deadline: DateTime(2026, 10, 1)),
        task('near', deadline: DateTime(2026, 10, 2)),
      ], now: now);
      final near = full.firstWhere((p) => p.task.id == 'near');
      expect(near.proposedStart.day, 1);
    });

    test('Có signal phiên học tốt buổi sáng → xếp 8h + lý do ghi nguồn', () {
      final now = DateTime(2026, 9, 30, 10);
      final proposals = proposeWeekPlan(
        [task('a')],
        sessions: [session(8, 5), session(9, 4), session(20, 2)],
        now: now,
      );
      expect(proposals.single.proposedStart.hour, 8);
      expect(proposals.single.reason, contains('bạn học tốt buổi sáng'));
    });

    test('Chưa đủ dữ liệu phiên → giờ mặc định 19h và lý do ghi rõ "mặc định"', () {
      final proposals = proposeWeekPlan(
        [task('a')],
        sessions: [session(8, 5)], // 1 phiên — không đủ kết luận.
        now: DateTime(2026, 9, 30, 10),
      );
      expect(proposals.single.proposedStart.hour, 19);
      expect(proposals.single.reason, contains('mặc định'));
    });

    test('Quỹ 120 phút/ngày → task tràn chuyển sang ngày hôm sau', () {
      final now = DateTime(2026, 9, 30, 10);
      final proposals = proposeWeekPlan([
        task('big1', minutes: 90),
        task('big2', minutes: 90),
      ], now: now);

      expect(proposals[0].proposedStart.day, 30); // hôm nay.
      expect(proposals[1].proposedStart.day, 1); // tràn → ngày mai.
    });

    test('Priority high đứng trước khi deadline bằng nhau', () {
      final now = DateTime(2026, 9, 30, 10);
      final proposals = proposeWeekPlan([
        task('low', priority: 'low', deadline: DateTime(2026, 10, 5)),
        task('high', priority: 'high', deadline: DateTime(2026, 10, 5)),
      ], now: now);
      expect(proposals.first.task.id, 'high');
      expect(proposals.first.reason, contains('ưu tiên cao'));
    });
  });

  group('Empty states (đặc tả mục 33)', () {
    void noop() {}
    void noopTask(TodayTask _) {}

    TodayTask emptyTask() => TodayTask(id: 'x', title: 'x');

    testWidgets('Empty Task: copy đúng spec + 2 actions tạo kế hoạch/gợi ý',
        (WidgetTester tester) async {
      var addTapped = false;
      var sampleTapped = false;
      var planTapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TodayMissionCard(
              tasks: const [],
              onAddTask: () => addTapped = true,
              onToggle: noopTask,
              onDelete: noopTask,
              onSkip: noopTask,
              onReschedule: noopTask,
              onAddSample: () => sampleTapped = true,
              onOpenAiPlan: () => planTapped = true,
            ),
          ),
        ),
      ));
      await tester.pump();

      // Copy đúng đặc tả UX mục 11 "No tasks".
      expect(find.text('Hôm nay chưa có nhiệm vụ.'), findsOneWidget);
      expect(find.text('Tạo kế hoạch để biết mình nên học gì.'),
          findsOneWidget);
      expect(find.text('+ Thêm nhiệm vụ'), findsOneWidget);
      expect(find.text('AI lập kế hoạch'), findsOneWidget);
      expect(find.text('Gợi ý sẵn từ kỳ thi mục tiêu'), findsOneWidget);

      await tester.tap(find.text('+ Thêm nhiệm vụ'));
      expect(addTapped, isTrue);
      await tester.tap(find.text('AI lập kế hoạch'));
      expect(planTapped, isTrue);
      await tester.tap(find.text('Gợi ý sẵn từ kỳ thi mục tiêu'));
      expect(sampleTapped, isTrue);
    });

    testWidgets('Có nhiệm vụ → không hiện empty state',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TodayMissionCard(
              tasks: [emptyTask()],
              onAddTask: noop,
              onToggle: noopTask,
              onDelete: noopTask,
              onSkip: noopTask,
              onReschedule: noopTask,
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('Hôm nay chưa có kế hoạch.'), findsNothing);
    });

    testWidgets('Semantics: hàng task đọc được trạng thái + hành động (mục 21)',
        (WidgetTester tester) async {
      final t = TodayTask(id: 'a11y', title: 'Hàm số', subject: '📐 Toán');
      var toggled = false;
      var detailOpened = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TodayMissionCard(
              tasks: [t],
              onAddTask: noop,
              onToggle: (_) => toggled = true,
              onDelete: noopTask,
              onSkip: noopTask,
              onReschedule: noopTask,
              onOpenDetail: (_) => detailOpened = true,
            ),
          ),
        ),
      ));
      await tester.pump();

      // Screen-reader đọc được nhãn mô tả trạng thái + hành động. Nhãn mới tách
      // rõ "chạm để mở chi tiết" (hàng) và "đánh dấu hoàn thành" (nút tròn), vì
      // bản v1 gộp chung khiến người dùng không biết chạm đâu để đánh dấu.
      // Nhãn hàng bị framework gộp thêm text con nên so khớp bằng RegExp.
      final rowLabel = RegExp(
          r'^Nhiệm vụ Hàm số, môn Toán, chưa hoàn thành\. Chạm để mở chi tiết\.');
      expect(find.bySemanticsLabel(rowLabel), findsOneWidget);
      expect(
        find.bySemanticsLabel('Đánh dấu hoàn thành'),
        findsOneWidget,
        reason: 'nút tròn phải tự mô tả hành động của nó',
      );

      // Tap qua semantics trên hàng mở chi tiết.
      final row = tester.getRect(find.bySemanticsLabel(rowLabel));
      await tester.tapAt(row.center);
      await tester.pump();
      expect(detailOpened, isTrue);

      // Tap nút tròn vẫn đánh dấu hoàn thành.
      final check = tester.getRect(find.bySemanticsLabel('Đánh dấu hoàn thành'));
      await tester.tapAt(check.center);
      await tester.pump();
      expect(toggled, isTrue);
    });

    testWidgets('Task đã hoàn thành: nhãn semantics đổi trạng thái',
        (WidgetTester tester) async {
      final t = TodayTask(
        id: 'a11y-done',
        title: 'Hàm số',
        subject: '📐 Toán',
        isDone: true,
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TodayMissionCard(
              tasks: [t],
              onAddTask: noop,
              onToggle: noopTask,
              onDelete: noopTask,
              onSkip: noopTask,
              onReschedule: noopTask,
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(
        find.bySemanticsLabel(RegExp(
            r'^Nhiệm vụ Hàm số, môn Toán, đã hoàn thành\. Chạm để đánh dấu hoàn thành\.')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Bỏ đánh dấu hoàn thành'), findsOneWidget);
    });

    testWidgets('Empty AI: gợi ý prompt ĐỘNG chạm để điền vào ô nhập',
        (WidgetTester tester) async {
      // G2-C: chip gợi ý không còn là chuỗi tĩnh mà dựng từ dữ liệu thật —
      // nên test phải gieo dữ liệu thật rồi khẳng định đúng nội dung suy ra.
      // Chat history trống → màn AI ở trạng thái intro (mục 33 — Empty AI).
      StorageService.setString('ai_chat_history_v1', '');
      StorageService.setPrimaryExamId('e-dyn');
      StorageService.setExamJson(
        'e-dyn',
        ExamModel(id: 'e-dyn', name: 'Kỳ thi Đại học', dateTime: DateTime.now().add(const Duration(days: 30))).toJsonString(),
      );

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AiCoachScreen()),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Gợi ý hiển thị dạng chip, lấy đúng TÊN kỳ thi đang lưu.
      const prompt = 'Lập kế hoạch ôn thi Kỳ thi Đại học';
      expect(find.text(prompt), findsOneWidget);

      // Luôn có chip dự phòng kể cả khi chưa có kỳ thi / nhiệm vụ nào.
      expect(find.text('Kiểm tra lần này sai ở đâu?'), findsOneWidget);

      // Chạm chip → prompt được điền vào ô nhập, KHÔNG tự gửi (mục 10.4).
      await tester.tap(find.text(prompt));
      await tester.pump();
      expect(find.widgetWithText(TextField, prompt), findsOneWidget);

      StorageService.removeString('primary_exam_id');
    });
  });

  group('AI feedback (đặc tả mục 10.10)', () {
    test('Store: lưu/đọc/ghi đè theo message, downvote filter đúng', () {
      AiFeedbackStore.put(AiFeedback(
        messageId: 'm1',
        kind: 'up',
        createdAt: DateTime(2026, 9, 30),
      ));
      AiFeedbackStore.put(AiFeedback(
        messageId: 'm2',
        kind: 'down',
        reason: 'sai_kien_thuc',
        createdAt: DateTime(2026, 9, 30),
      ));
      expect(AiFeedbackStore.get('m1')?.kind, 'up');
      expect(AiFeedbackStore.get('m2')?.reason, 'sai_kien_thuc');

      // Ghi đè: đổi m1 từ 👍 sang 👎.
      AiFeedbackStore.put(AiFeedback(
        messageId: 'm1',
        kind: 'down',
        reason: 'qua_dai',
        createdAt: DateTime(2026, 9, 30),
      ));
      expect(AiFeedbackStore.get('m1')?.kind, 'down');
      expect(AiFeedbackStore.allDownvotes().length, 2);
    });

    test('Danh sách lý do 👎 khớp đặc tả mục 10.10', () {
      final values = kAiFeedbackReasons.map((r) => r.$1).toSet();
      expect(values, containsAll([
        'sai_kien_thuc',
        'khong_hieu_cau_hoi',
        'giai_thich_kho_hieu',
        'nguon_khong_dang_tin',
        'qua_dai',
        'qua_ngan',
        'khac',
      ]));
    });

    testWidgets('ChatBubble AI: bấm 👍 lưu feedback, icon đổi màu',
        (WidgetTester tester) async {
      final msg = ChatMessage(
        id: 'fb-1',
        text: 'Đạo hàm của x² là 2x.',
        isUser: false,
        timestamp: DateTime(2026, 9, 30),
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: [ChatBubble(msg: msg)]),
        ),
      ));
      await tester.pump();

      expect(AiFeedbackStore.get('fb-1'), isNull);
      await tester.tap(find.byIcon(Icons.thumb_up_outlined));
      await tester.pump();

      expect(AiFeedbackStore.get('fb-1')?.kind, 'up');
      // Đã vote → nút chuyển thành bản filled và disable.
      expect(find.byIcon(Icons.thumb_up_outlined), findsNothing);
      expect(find.byIcon(Icons.thumb_up), findsOneWidget);
    });
  });

  group('Reschedule check (mục 13 — Warning + AI alternative)', () {
    test('Ngày mới trước deadline → không warning', () {
      final t = TodayTask(
        id: 'r1',
        title: 'Ôn Hàm số',
        subject: '📐 Toán',
        deadline: DateTime(2026, 10, 10),
      );
      final check = checkReschedule(
        t,
        DateTime(2026, 10, 5),
        now: DateTime(2026, 9, 30, 10),
      );
      expect(check.exceedsDeadline, isFalse);
      expect(check.alternative, isNull);
    });

    test('Không có deadline → không bao giờ warning', () {
      final t = TodayTask(id: 'r2', title: 'Đọc thêm', subject: '📖 Văn');
      final check = checkReschedule(
        t,
        DateTime(2026, 11, 1),
        now: DateTime(2026, 9, 30, 10),
      );
      expect(check.exceedsDeadline, isFalse);
    });

    test('Vượt deadline → warning + AI đề xuất ngày trước deadline', () {
      final t = TodayTask(
        id: 'r3',
        title: 'Luyện đề',
        subject: '📐 Toán',
        deadline: DateTime(2026, 10, 2),
      );
      final check = checkReschedule(
        t,
        DateTime(2026, 10, 5), // trễ hơn deadline 2/10.
        now: DateTime(2026, 9, 30, 10),
      );
      expect(check.exceedsDeadline, isTrue);
      expect(check.alternative, isNotNull);
      // Đề xuất phải trước deadline.
      expect(
        check.alternative!.proposedStart.isBefore(DateTime(2026, 10, 2)),
        isTrue,
      );
    });
  });

  group('Bottom sheet chuẩn (mục 30)', () {
    testWidgets('Có drag handle + contextual height',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showAppBottomSheet(
                  context: context,
                  builder: (_) => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Nội dung sheet'),
                  ),
                ),
                child: const Text('Mở sheet'),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('Mở sheet'));
      await tester.pumpAndSettle();

      // Nội dung + drag handle (Container 44x5) đều có mặt.
      expect(find.text('Nội dung sheet'), findsOneWidget);
      final handles = find.byWidgetPredicate((w) =>
          w is Container &&
          w.constraints == const BoxConstraints.tightFor(
              width: 44, height: 5));
      expect(handles, findsOneWidget);
    });
  });

  group('Notes links + draft (mục 14/35)', () {
    test('StudyNote parse ngược tương thích: note cũ không field mới vẫn đọc được', () {
      final oldJson = '{"id":"n1","title":"Cũ","body":"nội dung",'
          '"createdAt":"2026-09-01T10:00:00.000","updatedAt":"2026-09-01T10:00:00.000","tags":["toan"]}';
      final note = StudyNote.fromJsonString(oldJson);
      expect(note.title, 'Cũ');
      expect(note.taskId, isNull);
      expect(note.subject, isNull);
      expect(note.imageBase64, isNull);

      // Note mới có đủ field → round-trip giữ nguyên.
      final full = StudyNote(
        id: 'n2',
        title: 'Lỗi sai hàm số',
        body: 'Nhớ công thức **đạo hàm**',
        createdAt: DateTime(2026, 9, 30),
        updatedAt: DateTime(2026, 9, 30),
        tags: const ['toan'],
        taskId: 'task-9',
        subject: '📐 Toán',
        sessionId: 'sess-1',
        imageBase64: 'aGk=',
      );
      final back = StudyNote.fromJsonString(full.toJsonString());
      expect(back.taskId, 'task-9');
      expect(back.subject, '📐 Toán');
      expect(back.sessionId, 'sess-1');
      expect(back.imageBase64, 'aGk=');
    });

    test('Autosave draft: lưu + khôi phục + xóa sau khi save', () async {
      // Mô phỏng draft đã lưu từ phiên trước.
      final draft = StudyNote(
        id: 'draft',
        title: 'Nháp',
        body: 'bản nháp chưa kịp lưu',
        createdAt: DateTime(2026, 9, 29),
        updatedAt: DateTime(2026, 9, 29),
        subject: '📖 Văn',
      );
      StorageService.setString('note_draft_v1', draft.toJsonString());

      final restored = StudyNote.fromJsonString(
          StorageService.getString('note_draft_v1')!);
      expect(restored.body, 'bản nháp chưa kịp lưu');
      expect(restored.subject, '📖 Văn');

      // Khi user bấm Lưu → draft bị xóa (không đè lần sau).
      StorageService.prefs.remove('note_draft_v1');
      expect(StorageService.getString('note_draft_v1'), isNull);
    });
  });

  group('Global search (mục 15)', () {
    testWidgets('Tìm thấy task + note; không có kết quả → gợi ý query khác',
        (WidgetTester tester) async {
      // Seed dữ liệu local.
      final task = TodayTask(
        id: 's-task',
        title: 'Ôn đạo hàm hợp',
        subject: '📐 Toán',
      );
      StorageService.setTodayTaskJson(task.id, task.toJsonString());
      StorageService.setTodayTaskIds([task.id]);

      final note = StudyNote(
        id: 's-note',
        title: 'Công thức/logarithm',
        body: 'log cơ số đổi cơ số',
        createdAt: DateTime(2026, 9, 30),
        updatedAt: DateTime(2026, 9, 30),
      );
      StorageService.setStudyNoteJson(note.id, note.toJsonString());
      StorageService.setStudyNoteIds([note.id]);

      await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
      await tester.pump();

      // Tìm trúng task.
      await tester.enterText(find.byType(TextField), 'đạo hàm');
      await tester.pump();
      expect(find.text('Ôn đạo hàm hợp'), findsOneWidget);
      expect(find.text('Nhiệm vụ'), findsOneWidget);

      // Tìm trúng note.
      await tester.enterText(find.byType(TextField), 'logarithm');
      await tester.pump();
      expect(find.text('Công thức/logarithm'), findsOneWidget);
      expect(find.text('Ghi chú'), findsOneWidget);

      // Không có kết quả → gợi ý thử từ khóa khác (mục 15).
      await tester.enterText(find.byType(TextField), 'zzz không có');
      await tester.pump();
      expect(find.textContaining('Không tìm thấy'), findsOneWidget);
      expect(find.textContaining('Thử chỉ tìm'), findsOneWidget);
    });
  });

  group('Reschedule quá nhiều lần (mục 7.10)', () {
    TodayTask rsTask(int count, [int minutes = 90]) => TodayTask(
          id: 'rs-$count',
          title: 'Luyện đề',
          subject: '📐 Toán',
          estimateMinutes: minutes,
          rescheduleCount: count,
        );

    test('Dưới ngưỡng 3 lần → không quấy rầy', () {
      expect(rescheduleSplitSuggestion(rsTask(0)), isNull);
      expect(rescheduleSplitSuggestion(rsTask(2)), isNull);
    });

    test('Từ lần thứ 3 → cảnh báo + gợi ý chia nhỏ đúng dữ liệu', () {
      final tip = rescheduleSplitSuggestion(rsTask(3));
      expect(tip, isNotNull);
      expect(tip, contains('3 lần'));
      expect(tip, contains('90 phút'));
      expect(tip, contains('~45 phút'));
      expect(tip, contains('Có vẻ')); // hypothesis tone, mục 36.
    });
  });

  group('App-leaving pattern (mục 11.5)', () {
    AppLeavingEvent ev(int planned, int studied) =>
        AppLeavingEvent(plannedMinutes: planned, studiedMinutes: studied);

    test('Dưới 3 sự kiện → không kết luận', () {
      expect(analyzeAppLeaving([ev(25, 5)]).message, isNull);
      expect(analyzeAppLeaving([ev(25, 5), ev(25, 10)]).message, isNull);
    });

    test('3 sự kiện nhưng chỉ 1 bỏ dở → không gợi ý', () {
      final insight = analyzeAppLeaving([
        ev(25, 5), // bỏ dở.
        ev(25, 20),
        ev(25, 25),
      ]);
      expect(insight.abandonedCount, 1);
      expect(insight.message, isNull);
    });

    test('Phiên 50p+ hay bỏ dở → gợi ý phiên ngắn hơn, đúng giọng "có vẻ"', () {
      final insight = analyzeAppLeaving([
        ev(50, 15),
        ev(50, 18),
        ev(25, 22),
      ]);
      expect(insight.kind, 'shorter');
      expect(insight.suggestedMinutes, inInclusiveRange(15, 25));
      expect(insight.message, contains('Có vẻ'));
      expect(insight.message, contains('phút'));
    });

    test('Bỏ dở ≥3 nhưng phiên ngắn → break suggestion, không ép học', () {
      final insight = analyzeAppLeaving([
        ev(25, 5),
        ev(25, 8),
        ev(25, 10),
      ]);
      expect(insight.kind, 'break');
      expect(insight.message, contains('nghỉ'));
    });
  });

  group('High contrast (mục 21)', () {
    testWidgets('Bật → theme đổi viền đậm hơn, lưu cài đặt',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightWithContrast(true),
        home: Scaffold(
          body: Card(
            child: const SizedBox(height: 50, width: 50),
          ),
        ),
      ));
      await tester.pump();

      // Theme high contrast: divider đậm hơn (so sánh với theme thường).
      final normalDivider = AppTheme.lightWithContrast(false).dividerTheme.color;
      final hcDivider = AppTheme.lightWithContrast(true).dividerTheme.color;
      expect(hcDivider, AppColors.borderStrong);
      expect(hcDivider, isNot(normalDivider));
      expect(AppTheme.lightWithContrast(true).dividerTheme.thickness, 1.5);

      // Service lưu + khôi phục.
      AppearanceService.setHighContrast(true);
      expect(StorageService.getBool('appearance_high_contrast'), isTrue);
      expect(AppearanceService.highContrast.value, isTrue);
      AppearanceService.setHighContrast(false); // dọn cho test khác.
    });
  });

  group('AI citations (mục 10.9)', () {
    testWidgets('Bubble AI có nguồn → hiện source card',
        (WidgetTester tester) async {
      final msg = ChatMessage(
        id: 'cite-1',
        text: 'Định lý Pytago: a² + b² = c².',
        isUser: false,
        timestamp: DateTime(2026, 9, 30),
        sourceTitle: 'Định lý Pytago — Wikipedia',
        sourceUrl: 'https://vi.wikipedia.org/wiki/Định_lý_Pytago',
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: [ChatBubble(msg: msg)]),
        ),
      ));
      await tester.pump();

      expect(find.text('Nguồn tham khảo'), findsOneWidget);
      expect(find.text('Định lý Pytago — Wikipedia'), findsOneWidget);

      // Bấm source card → copy URL (chưa có url_launcher).
      await tester.tap(find.text('Định lý Pytago — Wikipedia'));
      await tester.pump();
      expect(find.textContaining('sao chép'), findsOneWidget);
    });

    testWidgets('Bubble không nguồn → không hiện card',
        (WidgetTester tester) async {
      final msg = ChatMessage(
        id: 'cite-2',
        text: 'Câu trả lời không dùng web.',
        isUser: false,
        timestamp: DateTime(2026, 9, 30),
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: [ChatBubble(msg: msg)]),
        ),
      ));
      await tester.pump();
      expect(find.text('Nguồn tham khảo'), findsNothing);
    });
  });

  group('Quick Add parser (đặc tả mục 25)', () {
    final now = DateTime(2026, 9, 30, 10); // thứ Tư.

    test('Ví dụ đặc tả: "Mai 19h học toán hàm số 45 phút"', () {
      final r = parseQuickAdd('Mai 19h học toán hàm số 45 phút', now)!;
      expect(r.scheduledAt, DateTime(2026, 10, 1, 19));
      expect(r.subject, '📐 Toán');
      expect(r.minutes, 45);
      expect(r.title, contains('hàm số'));
    });

    test('"Chủ nhật 8h tối ôn văn 1 giờ" → buổi tối +12h, 60 phút', () {
      final r = parseQuickAdd('Chủ nhật 8h tối ôn văn 1 giờ', now)!;
      // Chủ nhật kế tiếp từ thứ Tư 30/09 = 04/10.
      expect(r.scheduledAt.day, 4);
      expect(r.scheduledAt.hour, 20);
      expect(r.subject, '📖 Văn');
      expect(r.minutes, 60);
    });

    test('Mặc định: không nói thời lượng → 45 phút, giờ → 19h', () {
      final r = parseQuickAdd('Mai luyện anh văn', now)!;
      expect(r.minutes, 45);
      expect(r.scheduledAt.hour, 19);
      expect(r.subject, '🇬🇧 Anh');
    });

    test('Priority: "quan trọng" → high, "nhẹ" → low', () {
      expect(
          parseQuickAdd('Mai 7h làm toán 30 phút quan trọng', now)!.priority,
          'high');
      expect(parseQuickAdd('Mai đọc thêm sử 15p nhẹ', now)!.priority, 'low');
    });

    test('Text vô nghĩa → null (không tạo task rác)', () {
      expect(parseQuickAdd('   ', now), isNull);
      expect(parseQuickAdd('blah blah', now), isNull);
    });
  });

  testWidgets('Appearance: đổi cỡ chữ S/M/L áp dụng tức thì; Ctrl+2 đổi tab AI',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900); // desktop để test shortcut
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MainShellScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // Mở tab Tôi qua shortcut Ctrl+4.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Cỡ chữ'), findsOneWidget);

    // Chọn L — fontScale tăng ngay.
    AppearanceService.setFontScaleByKey('large');
    await tester.pump();
    expect(AppearanceService.fontScale.value, greaterThan(1.0));
    expect(AppearanceService.fontScaleKey, 'large');
    expect(StorageService.getString('appearance_font_scale'), 'large');

    // Ctrl+3 sang tab Tiến độ vẫn hoạt động với font lớn (không overflow).
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tiến độ học tập'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Reset về vừa.
    AppearanceService.setFontScaleByKey('normal');
    expect(AppearanceService.fontScale.value, 1.0);
  });

  testWidgets('iPhone 390x844: 4 tab + trang Mục tiêu/Tập trung không tràn layout',
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
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);

    // Home render gọn trong màn hẹp.
    expect(find.text('Chào Sĩ tử 2k9 👋'), findsOneWidget);
    expect(find.text('Nhiệm vụ hôm nay'), findsOneWidget);

    // Tab Tiến độ.
    await tester.tap(find.text('Tiến độ').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tiến độ học tập'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Tab Tôi.
    await tester.tap(find.text('Tôi'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sĩ tử 2k9'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Về Home, mở trang Mục tiêu qua thẻ đếm ngược.
    await tester.tap(find.text('Hôm nay'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Chưa chọn kỳ thi mục tiêu'));
    await tester.pumpAndSettle();
    expect(find.text('Kỳ Thi Của Tôi'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Route fullscreenDialog dùng nút Close (X) thay vì BackButton.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // Mở trang Tập trung qua quick action.
    await tester.ensureVisible(find.text('Tập trung').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tập trung').first);
    await tester.pumpAndSettle();
    expect(find.text('Pomodoro'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
