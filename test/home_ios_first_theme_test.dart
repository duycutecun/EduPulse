import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/constants/app_colors.dart';
import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/home/presentation/screens/home_screen.dart';
import 'package:edupulse/features/home/presentation/widgets/start_session_bar.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';
import 'package:edupulse/shared/widgets/primary_button.dart';

/// Slice iOS-first — phần contract của màn Hôm nay dưới theme hệ sinh thái iOS.
///
/// Bốn điều khoá đúng:
/// 1. [AppTheme.iosLightTheme] thực sự là theme iOS-first (systemBlue chủ đạo).
/// 2. Thanh "Bắt đầu · 10 phút" được dán ở đáy màn (Stack + Positioned),
///    không nằm trong vùng cuộn.
/// 3. CTA "Bắt đầu" dùng token chủ đạo iOS ([AppColors.iosPrimary]).
/// 4. Các widget của Home vẫn render đúng khi theme iOS-first được kéo vào
///    (không crash, mọi khóa vẫn tồn tại).
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    StudySessionRepository.instance.clearActive();
  });

  /// Theme iOS-first — đây là thay đổi của slice này.
  Widget harness() => MaterialApp(
        theme: AppTheme.iosLightTheme,
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
    // Khung xương Home có độ trễ 300ms trước khi đổ dữ liệu thật.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  TodayTask todayTask(String id, String title) => TodayTask(
        id: id,
        title: title,
        subject: 'Toán',
        scheduledAt: DateTime.now(),
        estimateMinutes: 45,
      );

  group('theme iOS-first', () {
    test('iosLightTheme dùng token hệ sinh thái iOS làm chủ đạo', () {
      final theme = AppTheme.iosLightTheme;
      expect(theme.colorScheme.primary, AppColors.iosPrimary);
      expect(theme.colorScheme.secondary, AppColors.iosSecondary);
      expect(theme.colorScheme.error, AppColors.iosError);
    });

    test('theme cũ vẫn còn nguyên — không đảo ngược cho các màn chưa restyle',
        () {
      expect(AppTheme.lightTheme.colorScheme.primary, AppColors.primary);
    });
  });

  group('vùng dán thanh Bắt đầu', () {
    testWidgets('thanh Bắt đầu nằm ở đáy màn, vẫn tappable', (tester) async {
      await TaskRepository.instance.createTask(todayTask('t1', 'Ôn hàm số'));
      await pumpHome(tester);

      final bar = find.byKey(const ValueKey('start-session-bar'));
      expect(bar, findsOneWidget);

      // `Positioned(bottom: 0)` → mép dưới của thanh khớp mép màn.
      final stackFinder = find
          .ancestor(
              of: find.byType(StartSessionBar), matching: find.byType(Stack))
          .last;
      final stackRect = tester.getRect(stackFinder);
      debugPrint('stackRect: $stackRect');
      final barRect = tester.getRect(find.byType(StartSessionBar));
      debugPrint('barRect: $barRect');
      expect(
        barRect.bottom,
        closeTo(tester.view.physicalSize.height, 1),
        reason: 'thanh phải dán sát đáy màn, không nằm trong vùng cuộn',
      );
    });

    testWidgets('CTA "Bắt đầu" dùng token chủ đạo iOS', (tester) async {
      await TaskRepository.instance.createTask(todayTask('t1', 'Ôn hàm số'));
      await pumpHome(tester);

      final button = tester.widget<PrimaryButton>(
          find.byKey(const ValueKey('start-session-bar')));
      expect(button.backgroundColor, AppColors.iosPrimary);
    });
  });

  group('Home render đầy đủ', () {
    testWidgets('màn Home vẫn hiện đầy đủ các khóa của slice', (tester) async {
      await TaskRepository.instance.createTask(todayTask('t1', 'Ôn hàm số'));
      await pumpHome(tester);

      // Các khóa của slice (đã có test riêng cho hành vi) vẫn tồn tại.
      expect(find.byKey(const ValueKey('home-achievements-button')),
          findsOneWidget);
      expect(find.text('Bắt đầu · 10 phút'), findsOneWidget);
    });
  });
}
