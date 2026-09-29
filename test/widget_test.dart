import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edupulse/core/utils/storage_service.dart';
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

    // Mở tab Tôi qua shortcut Ctrl+3.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Cỡ chữ'), findsOneWidget);

    // Chọn L — fontScale tăng ngay.
    AppearanceService.setFontScaleByKey('large');
    await tester.pump();
    expect(AppearanceService.fontScale.value, greaterThan(1.0));
    expect(AppearanceService.fontScaleKey, 'large');
    expect(StorageService.getString('appearance_font_scale'), 'large');

    // Ctrl+2 sang AI vẫn hoạt động với font lớn (không overflow).
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('AI Coach'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Reset về vừa.
    AppearanceService.setFontScaleByKey('normal');
    expect(AppearanceService.fontScale.value, 1.0);
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
