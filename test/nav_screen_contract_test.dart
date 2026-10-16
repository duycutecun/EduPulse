import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/home/presentation/screens/home_screen.dart';
import 'package:edupulse/features/home/presentation/widgets/active_session_resume_card.dart';
import 'package:edupulse/features/home/presentation/widgets/ai_actions_row.dart';
import 'package:edupulse/features/home/presentation/widgets/daily_summary_card.dart';
import 'package:edupulse/features/home/presentation/widgets/home_header.dart';
import 'package:edupulse/features/home/presentation/widgets/progress_insight_card.dart';
import 'package:edupulse/features/home/presentation/widgets/start_session_bar.dart';
import 'package:edupulse/features/home/presentation/widgets/today_mission_card.dart';
import 'package:edupulse/features/study/domain/active_study_session.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';
import 'package:edupulse/features/study/presentation/screens/study_screen.dart';
import 'package:edupulse/features/study/presentation/widgets/ai_post_focus_sheet.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';

/// Gate M1' ② — "3 màn × trạng thái, khác 0 là chặn".
///
/// **Vì sao không dùng golden ảnh:** CI chạy `ubuntu-latest`
/// (`.github/workflows/ci.yml`) còn máy dev là Windows; ảnh golden phụ thuộc
/// cách hệ điều hành vẽ chữ nên baseline sinh trên Windows sẽ đỏ trên CI và
/// ngược lại. Một baseline đỏ vì nền tảng sẽ bị tắt hoặc bỏ qua, và lúc đó cổng
/// coi như không có. Bản dưới đây khoá đúng thứ cổng cần bắt — màn nào, khối
/// nào, key nào phải có — theo cách chạy giống nhau ở mọi nền tảng.
///
/// Mỗi khối trong danh sách là một **hợp đồng**: bỏ khối, đổi màn, hoặc để nó
/// biến mất sau một lần refactor điều hướng đều làm test đỏ ngay.
class _FakeClock {
  DateTime _now;
  _FakeClock(this._now);
  DateTime now() => _now;
  void advance(Duration d) => _now = _now.add(d);
}

/// Chữ khớp một phần — dùng cho tiêu đề kèm số phút thay đổi theo phiên.
class _Contains {
  final String text;
  const _Contains(this.text);
}

Future<void> expectLandmarks(
  WidgetTester tester,
  List<Object> landmarks,
) async {
  for (final landmark in landmarks) {
    if (landmark is _Contains) {
      expect(find.textContaining(landmark.text), findsWidgets,
          reason: 'thiếu chữ chứa "${landmark.text}" trên màn/trạng thái này');
    } else if (landmark is Type) {
      expect(find.byType(landmark), findsWidgets,
          reason: 'thiếu khối $landmark trên màn/trạng thái này');
    } else if (landmark is Key) {
      expect(find.byKey(landmark), findsWidgets,
          reason: 'thiếu key $landmark trên màn/trạng thái này');
    } else if (landmark is String) {
      expect(find.text(landmark), findsWidgets,
          reason: 'thiếu chữ "$landmark" trên màn/trạng thái này');
    }
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    StudySessionRepository.instance.clearActive();
  });

  TodayTask task(String id, String title, {int minutes = 30}) => TodayTask(
        id: id,
        title: title,
        subject: 'Toán',
        scheduledAt: DateTime.now(),
        estimateMinutes: minutes,
      );

  // ───────────────────────────────────────────────────────────────────────
  // Màn 1 — Hôm nay
  // ───────────────────────────────────────────────────────────────────────
  group('Hợp đồng màn Hôm nay', () {
    Future<void> pumpHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: HomeScreen(
            clock: DateTime.now,
            primaryExam: null,
            exams: const [],
            onExamTap: () {},
            onOpenStudy: () {},
            onOpenAiCoach: () {},
            onOpenCalendar: () {},
            streak: 0,
          ),
        ),
      ));
      // Khung xương có độ trễ 300ms trước khi đổ dữ liệu thật.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
    }

    testWidgets('trạng thái 1 — hôm nay trống', (tester) async {
      await pumpHome(tester);

      await expectLandmarks(tester, [
        HomeHeader,
        TodayMissionCard,
        DailySummaryCard,
        ProgressInsightCard,
        AiActionsRow,
        StartSessionBar,
        const ValueKey('start-session-bar'),
        'Việc tiếp theo: Focus tự do',
      ]);
      // Không có việc thì không hứa hoãn được việc nào.
      expect(find.byKey(const ValueKey('defer-priority-task')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('trạng thái 2 — có việc ưu tiên', (tester) async {
      await TaskRepository.instance.createTask(task('t1', 'Ôn hàm số'));
      await pumpHome(tester);

      await expectLandmarks(tester, [
        TodayMissionCard,
        StartSessionBar,
        const ValueKey('start-session-bar'),
        const ValueKey('defer-priority-task'),
        'Việc tiếp theo: Ôn hàm số',
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('trạng thái 3 — còn phiên học bỏ dở', (tester) async {
      await TaskRepository.instance.createTask(task('t1', 'Ôn hàm số'));
      final now = DateTime.now();
      StudySessionRepository.instance.saveActive(ActiveStudySession(
        taskId: 't1',
        taskTitle: 'Ôn hàm số',
        subject: 'Toán',
        totalSeconds: 10 * 60,
        remainingAtAnchor: 6 * 60,
        anchorAt: now,
        startedAt: now.subtract(const Duration(minutes: 4)),
      ));
      await pumpHome(tester);

      await expectLandmarks(tester, [
        TodayMissionCard,
        ActiveSessionResumeCard,
        'Bạn có phiên học đang dở',
      ]);
      // Hai CTA cạnh tranh nhau là thứ trạng thái này phải dẹp: có phiên dở thì
      // thanh "Bắt đầu" không được hiện.
      expect(find.byType(StartSessionBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Màn 2 — Phiên học (Tập trung)
  // ───────────────────────────────────────────────────────────────────────
  group('Hợp đồng màn Phiên học', () {
    Future<_FakeClock> pumpStudy(WidgetTester tester,
        {TodayTask? withTask}) async {
      final clock = _FakeClock(DateTime(2026, 5, 1, 8));
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: StudyScreen(clock: clock.now, initialTask: withTask),
        ),
      ));
      await tester.pump();
      return clock;
    }

    testWidgets('trạng thái 1 — sẵn sàng', (tester) async {
      await pumpStudy(tester, withTask: task('t1', 'Ôn hàm số'));

      await expectLandmarks(tester, [
        'Pomodoro',
        'Biểu đồ',
        'Nhật ký',
        'Điểm thi',
        '10:00',
        '10/3',
        '20/5',
        '35/10',
        'Bắt đầu để tính thời gian',
        const ValueKey('clock-current-task'),
        const ValueKey('finish-session-early'),
      ]);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('clock-current-task')))
            .data,
        'Đang làm: Ôn hàm số',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('trạng thái 2 — đang chạy', (tester) async {
      final clock = await pumpStudy(tester);

      await tester.tap(find.byKey(const ValueKey('pom-toggle')));
      await tester.pump();
      for (var i = 0; i < 30; i++) {
        clock.advance(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }

      await expectLandmarks(tester, [
        'Đang trong phiên học!',
        'Phiên 0',
        const ValueKey('clock-current-task'),
      ]);
      expect(find.text('09:30'), findsOneWidget,
          reason: 'đồng hồ phải đếm theo mốc thời gian thật');
      expect(tester.takeException(), isNull);
    });

    testWidgets('trạng thái 3 — đang nghỉ', (tester) async {
      final clock = await pumpStudy(tester);
      await tester.tap(find.byKey(const ValueKey('pom-toggle')));
      await tester.pump();

      // Hết phiên 10 phút → chọn "Nghỉ" để sang vòng nghỉ.
      for (var i = 0; i < 601; i++) {
        clock.advance(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nghỉ'));
      await tester.pumpAndSettle();
      // Sheet đánh giá đang mở; đóng lại để nhìn thấy màn Phiên học bên dưới.
      await tester.tap(find.text('Không muốn nói gì'));
      await tester.pumpAndSettle();

      await expectLandmarks(tester, [
        '☕ Nghỉ giải lao',
        '03:00',
        const ValueKey('clock-current-task'),
      ]);
      expect(tester.takeException(), isNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Màn 3 — Phản tư sau phiên
  // ───────────────────────────────────────────────────────────────────────
  group('Hợp đồng màn Phản tư', () {
    Future<void> openSheet(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAiPostFocusSheet(
                context: context,
                session: StudySession(
                  id: 's1',
                  completedAt: DateTime(2026, 10, 16, 20, 0),
                  subject: 'Toán',
                  plannedMinutes: 10,
                  actualMinutes: 10,
                ),
                hasSelectedTask: true,
                onSave: (ctx, s, fb) async => Navigator.pop(ctx),
                onCompleteAndGo: (ctx, s, fb) async => Navigator.pop(ctx),
                onScheduleReview: (_) async {},
                onQuickNote: (_, {String? sessionId}) {},
                onTasksChanged: () {},
                onSplitTask: () {},
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
    }

    testWidgets('trạng thái 1 — mở ra là đánh giá được ngay', (tester) async {
      await openSheet(tester);

      await expectLandmarks(tester, [
        _Contains('Xong phiên'),
        '😫',
        '😐',
        '🙂',
        '😄',
        '🔥',
        'Thêm đánh giá chi tiết ▾',
        const ValueKey('save-session-feedback'),
        const ValueKey('complete-task-and-go-today'),
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('trạng thái 2 — đã chọn 1 chạm', (tester) async {
      await openSheet(tester);

      await tester.tap(find.text('🔥'));
      await tester.pumpAndSettle();

      await expectLandmarks(tester, [
        '🔥',
        const ValueKey('save-session-feedback'),
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('trạng thái 3 — mở phần đánh giá chi tiết', (tester) async {
      await openSheet(tester);

      await tester.tap(find.text('Thêm đánh giá chi tiết ▾'));
      await tester.pumpAndSettle();

      await expectLandmarks(tester, [
        // V2 mục C.3: một câu, hai nút — rồi 3 chip lý do khi chọn "Chưa hiểu".
        'Hiểu chưa?',
        'Chưa hiểu',
        'Hiểu rồi',
        const ValueKey('understanding-no'),
        const ValueKey('understanding-yes'),
        // Phần chi tiết (đặc tả 5.3) vẫn còn cho ai muốn khai thêm.
        'Chưa xong',
        '🚧 Có trở ngại',
        const ValueKey('save-session-feedback'),
        const ValueKey('skip-session-feedback'),
        'Không muốn nói gì',
      ]);
      expect(tester.takeException(), isNull);
    });
  });
}
