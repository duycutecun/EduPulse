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

  testWidgets('Điều hướng 5 tab (Học, Mục tiêu, AI, Tập trung, Tôi)',
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

    // 1. Home (Học) — active mặc định
    expect(find.text('Chào Sĩ tử 2k9!'), findsOneWidget);
    expect(find.text('Hôm nay là ngày tuyệt vời để học'), findsOneWidget);
    expect(find.text('Nhiệm vụ hôm nay'), findsOneWidget);

    // 2. Mục tiêu (Exams)
    await tester.tap(navIcon(Icons.flag_outlined));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Kỳ Thi Của Tôi'), findsOneWidget);

    // 3. AI Coach
    await tester.tap(navIcon(Icons.auto_awesome_outlined));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('AI Coach'), findsOneWidget);
    expect(navIcon(Icons.photo_camera_rounded), findsOneWidget);

    // 4. Tập trung (Study)
    await tester.tap(navIcon(Icons.timer_outlined));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Pomodoro'), findsOneWidget);
    expect(find.text('Biểu đồ'), findsOneWidget);
    expect(find.text('Nhật ký'), findsOneWidget);

    // 5. Tôi (Account)
    await tester.tap(navIcon(Icons.person_outline));
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

    // Vào Study tab
    await tester.tap(navIcon(Icons.timer_outlined));
    await tester.pump(const Duration(milliseconds: 300));

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
}
