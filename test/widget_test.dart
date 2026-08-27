import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/app/main_shell.dart';
import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'streak': 15,
      'streak_record': 35,
      'user_name': 'Sĩ tử 2k9',
      'user_target': 'ĐH Bách Khoa Hà Nội > 27đ',
    });
    await StorageService.init();
  });

  testWidgets('Test 1: Full Navigation Across All 6 Floating Dock Tabs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MainShellScreen(themeMode: 'dark', onThemeModeChanged: (_) {}),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // 1. Home Tab
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.textContaining('ngày học liên tiếp'), findsOneWidget);

    // 2. Exams Tab
    await tester.tap(find.byIcon(CupertinoIcons.flag_fill));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Kỳ Thi Của Tôi'), findsOneWidget);

    // 3. AI Coach Tab
    await tester.tap(find.byIcon(CupertinoIcons.wand_stars_inverse));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('AI Coach Sĩ Tử'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.camera_fill), findsOneWidget);

    // 4. Study Tab
    await tester.tap(find.byIcon(CupertinoIcons.book_fill));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('⏰ Pomodoro'), findsOneWidget);
    expect(find.text('📊 Biểu đồ'), findsOneWidget);
    expect(find.text('📓 Nhật ký'), findsOneWidget);

    // 5. Community Tab (Bảng Vàng Sĩ Tử)
    await tester.tap(find.byIcon(CupertinoIcons.star_fill));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bảng Vàng Sĩ Tử 🏆'), findsOneWidget);
    expect(find.text('Nguyễn Hoàng Minh'), findsOneWidget);

    // 6. Account Tab
    await tester.tap(find.byIcon(CupertinoIcons.person_crop_circle_fill));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sĩ tử 2k9'), findsOneWidget);
  });

  testWidgets('Test 2: Pomodoro Modes, Lo-Fi Sound & Weekly Chart Interaction', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MainShellScreen(themeMode: 'dark', onThemeModeChanged: (_) {}),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Go to Study tab
    await tester.tap(find.byIcon(CupertinoIcons.book_fill));
    await tester.pump(const Duration(milliseconds: 300));

    // Switch to 50/10 mode
    await tester.tap(find.text('50/10 Sâu'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('50:00'), findsOneWidget);

    // Toggle Lo-Fi Sound
    expect(find.textContaining('Lo-Fi Focus:'), findsOneWidget);
    await tester.tap(find.textContaining('Đổi âm thanh'));
    await tester.pump(const Duration(milliseconds: 200));

    // Switch to Weekly Chart tab
    await tester.tap(find.text('📊 Biểu đồ'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Biểu đồ giờ học trong tuần'), findsOneWidget);
    expect(find.text('Phân bổ thời gian theo môn'), findsOneWidget);
  });

  testWidgets('Test 3: Community Cheering and Task State', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MainShellScreen(themeMode: 'dark', onThemeModeChanged: (_) {}),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Go to Community tab
    await tester.tap(find.byIcon(CupertinoIcons.star_fill));
    await tester.pump(const Duration(milliseconds: 300));

    // Tap cheer button on top 1 user
    expect(find.text('342'), findsOneWidget);
    await tester.tap(find.text('342'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('343'), findsOneWidget);

    // Storage integrity check
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
}
