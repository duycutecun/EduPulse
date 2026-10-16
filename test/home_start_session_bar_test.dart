import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/home/presentation/screens/home_screen.dart';
import 'package:edupulse/features/study/domain/active_study_session.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';

/// V2 M1' mục 4 + gate ⑤: "mở app → việc ưu tiên ≤2 chạm, <15s tới phiên đầu".
///
/// Test này khoá đúng thứ cổng đó đo: thanh "Bắt đầu · 10 phút" luôn nhìn thấy
/// ở đáy màn Hôm nay (không nằm trong vùng cuộn), một chạm là vào phiên 10 phút
/// gắn đúng việc ưu tiên, và thao tác thứ hai trong tầm tay là "Hoãn".
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    StudySessionRepository.instance.clearActive();
  });

  Widget harness() => MaterialApp(
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
      );

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness());
    // Khung xương Hôm nay có độ trễ 300ms trước khi đổ dữ liệu thật.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  TodayTask todayTask(String id, String title, {int minutes = 45}) => TodayTask(
        id: id,
        title: title,
        subject: 'Toán',
        scheduledAt: DateTime.now(),
        estimateMinutes: minutes,
      );

  testWidgets('chưa có việc nào → vẫn bắt đầu được phiên 10 phút',
      (tester) async {
    await pumpHome(tester);

    expect(find.byKey(const ValueKey('start-session-bar')), findsOneWidget);
    expect(find.text('Bắt đầu · 10 phút'), findsOneWidget);
    expect(find.byKey(const ValueKey('defer-priority-task')), findsNothing,
        reason: 'không có việc thì không có gì để hoãn');
  });

  testWidgets('có việc hôm nay → thanh hiện tên việc ưu tiên và nút Hoãn',
      (tester) async {
    await TaskRepository.instance.createTask(todayTask('t1', 'Ôn hàm số'));
    await pumpHome(tester);

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('start-bar-task'))).data,
      contains('Ôn hàm số'),
    );
    expect(find.byKey(const ValueKey('defer-priority-task')), findsOneWidget);
  });

  testWidgets('một chạm "Bắt đầu" → mở phiên 10 phút gắn đúng việc',
      (tester) async {
    // Việc ước lượng 45 phút vẫn phải vào phiên 10 phút: thanh này là "bắt đầu
    // nhẹ cho khỏi chán", không phải "ngồi hết 45 phút".
    await TaskRepository.instance
        .createTask(todayTask('t1', 'Ôn hàm số', minutes: 45));
    await pumpHome(tester);

    await tester.tap(find.byKey(const ValueKey('start-session-bar')));
    await tester.pumpAndSettle();

    expect(find.text('10:00'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('clock-current-task')))
          .data,
      contains('Ôn hàm số'),
      reason: 'phiên phải gắn đúng việc ưu tiên, không phải focus trơ',
    );
  });

  testWidgets(
      'còn phiên bỏ dở → thanh Bắt đầu ẩn, nhường chỗ thẻ phiên đang dở',
      (tester) async {
    await TaskRepository.instance.createTask(todayTask('t1', 'Ôn hàm số'));
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

    expect(find.byKey(const ValueKey('start-session-bar')), findsNothing);
  });

  testWidgets('nút Hoãn mở đúng hộp dời lịch của việc ưu tiên', (tester) async {
    await TaskRepository.instance.createTask(todayTask('t1', 'Ôn hàm số'));
    await pumpHome(tester);

    await tester.tap(find.byKey(const ValueKey('defer-priority-task')));
    await tester.pumpAndSettle();

    expect(find.text('Dời lịch nhiệm vụ'), findsOneWidget);
    expect(find.text('Xác nhận dời'), findsOneWidget);
  });
}
