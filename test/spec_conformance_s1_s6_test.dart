import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/constants/subject_catalog.dart';
import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/exams/domain/models/exam_model.dart';
import 'package:edupulse/features/exams/presentation/widgets/subject_targets_editor.dart';
import 'package:edupulse/features/home/presentation/screens/home_screen.dart';
import 'package:edupulse/features/progress/domain/progress_engine.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';
import 'package:edupulse/features/study/presentation/screens/study_screen.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';

class _FakeClock {
  DateTime _now;
  _FakeClock(this._now);
  DateTime now() => _now;
  void advance(Duration d) => _now = _now.add(d);
}

/// Màn Hôm nay với đủ callback bắt buộc — các callback không dùng trong test
/// này nên để trống.
Widget homeHarness() => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: HomeScreen(
          primaryExam: null,
          exams: const [],
          onExamTap: () {},
          onOpenStudy: () {},
          onOpenAiCoach: () {},
          onOpenCalendar: () {},
          streak: 0,
        ),
      ),
    );

/// Đi đúng đường người học: menu thẻ nhiệm vụ → Đổi lịch → Ngày mai →
/// Xác nhận. Gọi xong là lịch đã được ghi qua repository thật.
Future<void> rescheduleViaUi(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Tùy chọn nhiệm vụ').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Dời lịch'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ngày mai'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Xác nhận dời'));
  await tester.pumpAndSettle();
}

/// Đợt đối chiếu thứ hai với 3 file đặc tả — các điểm trước đây lệch:
///
/// - UX 5.6: xong việc thì kết thúc phiên được, không phải ngồi đợi đồng hồ.
/// - UX 5.5 / FE-2.4: từ lần dời thứ 3 phải **đề nghị** thu nhỏ bài, không
///   tự ý sửa kế hoạch của người học.
/// - UX 5.13 / BE-5.2: mục tiêu điểm phải đặt được **theo từng môn**.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('UX 5.6 — kết thúc phiên sớm', () {
    testWidgets('Nút "Hoàn thành" hiện ở vòng focus, không hiện khi nghỉ',
        (tester) async {
      final clock = _FakeClock(DateTime(2026, 5, 1, 8));
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StudyScreen(clock: clock.now)),
      ));
      await tester.pump();

      expect(find.byKey(const ValueKey('finish-session-early')),
          findsOneWidget);
      expect(find.text('Hoàn thành'), findsOneWidget);
    });

    testWidgets('Học ≥1 phút rồi bấm Hoàn thành → ghi phiên thật',
        (tester) async {
      final repo = StudySessionRepository.instance;
      final clock = _FakeClock(DateTime(2026, 5, 1, 8));
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StudyScreen(clock: clock.now)),
      ));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('pom-toggle')));
      for (var i = 0; i < 90; i++) {
        clock.advance(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      expect(repo.getAll(), isEmpty, reason: 'chưa kết thúc thì chưa ghi phiên');

      await tester.tap(find.byKey(const ValueKey('finish-session-early')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(repo.getAll(), hasLength(1),
          reason: 'xong việc thì phiên phải được ghi, không mất thời gian đã học');
      // Bước đánh giá 1 chạm mở ra — không bắt điền thang chi tiết.
      expect(find.byKey(const ValueKey('save-session-feedback')),
          findsOneWidget);
    });

    testWidgets('Bấm khi chưa học gì → nhắc, không ghi phiên rác',
        (tester) async {
      final repo = StudySessionRepository.instance;
      final clock = _FakeClock(DateTime(2026, 5, 1, 8));
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StudyScreen(clock: clock.now)),
      ));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('finish-session-early')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.getAll(), isEmpty);
      expect(find.textContaining('Hãy bắt đầu phiên học trước'), findsOneWidget);
    });
  });

  group('UX 5.5 — dời ≥3 lần thì đề nghị thu nhỏ, không tự sửa', () {
    testWidgets('Lần thứ 3 → hộp thoại 3 lựa chọn, không tự giảm thời lượng',
        (tester) async {
      final repo = TaskRepository.instance;
      // Bài đã bị dời 2 lần trước đó → lần ghi tiếp theo là lần thứ 3.
      await repo.createTask(TodayTask(
        id: 'resched-1',
        title: 'Bài lớn',
        estimateMinutes: 60,
        rescheduleCount: 2,
      ));

      tester.view.physicalSize = const Size(1400, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(homeHarness());
      await tester.pump(const Duration(milliseconds: 700));

      await rescheduleViaUi(tester);

      // Hộp thoại mở ra sau khi ghi lần dời thứ 3.
      expect(find.text('Bài này có vẻ hơi lớn'), findsOneWidget);
      expect(find.text('Giảm thời lượng'), findsOneWidget);
      expect(find.text('Chia nhỏ'), findsOneWidget);
      expect(find.text('Giữ nguyên'), findsOneWidget);
      // Chưa bấm gì → thời lượng phải giữ nguyên (AI chỉ đề nghị, không sửa).
      expect(repo.getTaskById('resched-1')!.estimateMinutes, 60);
    });

    testWidgets('Dưới ngưỡng 3 lần → không bị hỏi', (tester) async {
      final repo = TaskRepository.instance;
      await repo.createTask(TodayTask(
        id: 'few-1',
        title: 'Bài bình thường',
        estimateMinutes: 60,
        rescheduleCount: 1,
      ));

      tester.view.physicalSize = const Size(1400, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(homeHarness());
      await tester.pump(const Duration(milliseconds: 700));

      await rescheduleViaUi(tester);

      expect(find.text('Bài này có vẻ hơi lớn'), findsNothing,
          reason: 'chỉ dời 2 lần thì không quấy rầy');
      expect(repo.getTaskById('few-1')!.estimateMinutes, 60);
    });

    testWidgets('Bấm "Giữ nguyên" → thời lượng không đổi', (tester) async {
      final repo = TaskRepository.instance;
      await repo.createTask(TodayTask(
        id: 'keep-1',
        title: 'Bài lớn',
        estimateMinutes: 60,
        rescheduleCount: 2,
      ));

      tester.view.physicalSize = const Size(1400, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(homeHarness());
      await tester.pump(const Duration(milliseconds: 700));

      await rescheduleViaUi(tester);
      await tester.tap(find.text('Giữ nguyên'));
      await tester.pump(const Duration(milliseconds: 700));

      expect(repo.getTaskById('keep-1')!.estimateMinutes, 60);
    });

    testWidgets('Bấm "Giảm thời lượng" → mới thu nhỏ', (tester) async {
      final repo = TaskRepository.instance;
      await repo.createTask(TodayTask(
        id: 'shrink-1',
        title: 'Bài lớn',
        estimateMinutes: 90,
        rescheduleCount: 2,
      ));

      tester.view.physicalSize = const Size(1400, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(homeHarness());
      await tester.pump(const Duration(milliseconds: 700));

      await rescheduleViaUi(tester);
      await tester.tap(find.text('Giảm thời lượng'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(repo.getTaskById('shrink-1')!.estimateMinutes, 45,
          reason: 'giảm còn một nửa');
    });
  });

  group('UX 5.13 / BE-5.2 — mục tiêu điểm theo môn', () {
    test('ExamModel giữ được mục tiêu từng môn qua serialize', () {
      final exam = ExamModel(
        id: 'e1',
        name: 'THPTQG',
        dateTime: DateTime(2026, 6, 1),
        targetScore: 9.0,
        subjectTargets: const {'Toán': 9.5, 'Lý': 8.5},
      );

      final restored = ExamModel.fromJsonString(exam.toJsonString());

      expect(restored.targetScore, 9.0);
      expect(restored.subjectTargets['Toán'], 9.5);
      expect(restored.subjectTargets['Lý'], 8.5);
      expect(restored.subjects, containsAll(<String>['Toán', 'Lý']));
    });

    test('copyWith giữ mục tiêu môn khi chỉ đổi điểm hiện tại', () {
      final exam = ExamModel(
        id: 'e1',
        name: 'THPTQG',
        dateTime: DateTime(2026, 6, 1),
        subjectTargets: const {'Toán': 9.5},
      );

      final updated = exam.copyWithCurrent(7.0);

      expect(updated.currentScore, 7.0);
      expect(updated.subjectTargets['Toán'], 9.5,
          reason: 'điểm hiện tại đổi không được xoá mục tiêu môn');
    });

    testWidgets('Editor nhập điểm môn → phát ra map chuẩn hoá theo tên môn',
        (tester) async {
      Map<String, double>? emitted;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SubjectTargetsEditor(
            initial: const {},
            onChanged: (m) => emitted = m,
          ),
        ),
      ));
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('subject-target-Toán')),
        '9,5',
      );
      await tester.pump();

      expect(emitted, isNotNull);
      expect(emitted!.length, 1, reason: 'môn để trống không sinh mục tiêu');
      expect(emitted!.values.single, 9.5,
          reason: 'dấu phẩy kiểu VN vẫn hiểu');
    });

    testWidgets('Editor giữ mục tiêu cũ khi sửa', (tester) async {
      Map<String, double>? emitted;
      final math = AppSubjects.all.firstWhere((s) => s.plainName == 'Toán');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SubjectTargetsEditor(
            initial: {math.name: 8.0},
            onChanged: (m) => emitted = m,
          ),
        ),
      ));
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('subject-target-Toán')),
        '9',
      );
      await tester.pump();

      expect(emitted![math.name], 9.0);
    });
  });

  group('UX 5.12 — xu hướng môn', () {
    SubjectProgress progress(int minutes, int? previous, int sessions) =>
        SubjectProgress(
          subject: 'Toán',
          minutes: minutes,
          sessionCount: sessions,
          tasksTotal: 0,
          tasksCompleted: 0,
          avgUnderstanding: null,
          lastStudied: null,
          lastPeriodMinutes: previous,
        );

    test('Tăng → up, không đổi → flat, giảm → down', () {
      expect(progress(120, 90, 3).trend, SubjectTrend.up);
      expect(progress(90, 90, 3).trend, SubjectTrend.flat);
      expect(progress(60, 90, 3).trend, SubjectTrend.down);
    });

    test('Không đủ dữ liệu thì KHÔNG đoán — trả null', () {
      expect(progress(120, null, 3).trend, isNull,
          reason: 'chưa có kỳ trước để so sánh');
      expect(progress(0, 90, 0).trend, isNull,
          reason: 'kỳ trước có nhưng kỳ này chưa học — không kết luận');
      expect(progress(120, 0, 3).trend, isNull,
          reason: '0 phút ở kỳ trước là thiếu dữ liệu, không phải "tăng vọt"');
    });

    test('subjectProgress lấy phút kỳ trước từ tuần liền trước', () {
      final now = DateTime(2026, 3, 18, 10);
      final thisWeek = StudySession(
        id: 'a',
        completedAt: now.subtract(const Duration(days: 2)),
        subject: 'Toán',
        plannedMinutes: 30,
        actualMinutes: 30,
        startedAt: now,
        endedAt: now,
        status: StudySession.statusCompleted,
      );
      final lastWeek = StudySession(
        id: 'b',
        completedAt: now.subtract(const Duration(days: 9)),
        subject: 'Toán',
        plannedMinutes: 10,
        actualMinutes: 10,
        startedAt: now,
        endedAt: now,
        status: StudySession.statusCompleted,
      );

      final list = ProgressEngine.subjectProgress(
        [thisWeek, lastWeek],
        const [],
        now,
      );
      // Khoá môn đã chuẩn hoá qua danh mục (có emoji) — so khớp phải đi qua
      // cùng đường chuẩn hoá, không so chuỗi thô.
      final math = list.firstWhere(
          (s) => s.subject == AppSubjects.normalize('Toán'));

      expect(math.minutes, 30);
      expect(math.lastPeriodMinutes, 10);
      expect(math.trend, SubjectTrend.up);
    });
  });

  group('UX 5.3 — tạo nhiệm vụ phải khẳng định đã vào hôm nay', () {
    testWidgets('Sau khi tạo → snackbar xác nhận + lối "Bắt đầu ngay"',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(homeHarness());
      await tester.pump(const Duration(milliseconds: 700));

      await tester.tap(find.text('+ Thêm nhiệm vụ'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.enterText(find.byType(TextField).first, 'Ôn đạo hàm');
      await tester.tap(find.text('30 phút'));
      await tester.pump();
      await tester.tap(find.text('Thêm'));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Đã thêm vào hôm nay'), findsOneWidget,
          reason: 'phải khẳng định rõ đã vào kế hoạch hôm nay');
      expect(find.text('Bắt đầu ngay'), findsOneWidget,
          reason: 'đề nghị hành động tiếp theo, không để người học tự đoán');
      // G3-A: phản hồi mang ngữ nghĩa bằng ICON + màu, không chỉ bằng chữ.
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });
}