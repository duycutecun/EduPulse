import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/app/desktop_aux_column.dart';
import 'package:edupulse/app/desktop_sidebar.dart';
import 'package:edupulse/app/main_shell.dart';
import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/exams/domain/exam_repository.dart';
import 'package:edupulse/features/exams/domain/models/exam_model.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';

/// Cột phụ desktop: chỉ hiện khi đủ rộng, đúng ngữ cảnh tab, và không làm vỡ
/// bố cục ở màn hình lớn.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'user_name': 'Sĩ tử 2k9',
      'streak': 7,
    });
    await StorageService.init();

    // Dữ liệu thật để cột phụ không rơi vào nhánh toàn số 0.
    await TaskRepository.instance.createTask(TodayTask(
      id: 'aux-task',
      title: 'Ôn chuyên đề hàm số',
      subject: 'Toán',
      scheduledAt: DateTime.now(),
    ));
    await StudySessionRepository.instance.save(StudySession(
      id: 'aux-session',
      completedAt: DateTime.now(),
      subject: 'Toán',
      plannedMinutes: 45,
      actualMinutes: 45,
      status: StudySession.statusCompleted,
    ));
    final exam = ExamModel(
      id: 'aux-exam',
      name: 'Kỳ thi THPT Quốc gia năm 2027',
      dateTime: DateTime.now().add(const Duration(days: 45)),
    );
    ExamRepository.instance.save(exam);
    ExamRepository.instance.setPrimary(exam.id);
  });

  Future<void> pumpShell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const MainShellScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Chỉ tìm trong cột phụ — nội dung chính có những nhãn trùng tên.
  Finder aux(String text) => find.descendant(
        of: find.byType(DesktopAuxColumn),
        matching: find.text(text),
      );

  Future<void> tapNav(WidgetTester tester, IconData icon) async {
    // Bấm trong sidebar: cột phụ cũng có icon AI nên bấm "icon cuối cùng" sẽ
    // trượt sang cột phụ.
    await tester.tap(find.descendant(
      of: find.byType(DesktopSidebar),
      matching: find.byIcon(icon),
    ));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('chỉ hiện cột phụ khi màn đủ rộng (≥1440px)', (tester) async {
    // Desktop nhưng hẹp → giữ bố cục một cột như trước.
    await pumpShell(tester, const Size(1280, 800));
    expect(find.byType(DesktopAuxColumn), findsNothing);
    expect(tester.takeException(), isNull);

    // Đủ rộng → có cột phụ.
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(DesktopAuxColumn), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tab Hôm nay: đếm ngược kỳ thi + tổng kết hôm nay',
      (tester) async {
    await pumpShell(tester, const Size(1440, 900));

    expect(aux('Kỳ thi chính'), findsOneWidget);
    expect(find.textContaining('ngày nữa'), findsOneWidget);
    expect(aux('Hôm nay'), findsOneWidget);
    // Nhiệm vụ 0/1 và 45m học đều lấy từ repository thật.
    expect(aux('0/1'), findsOneWidget);
    expect(aux('45m'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('đổi tab thì cột phụ đổi nội dung theo ngữ cảnh', (tester) async {
    await pumpShell(tester, const Size(1440, 900));

    // AI: giới thiệu năng lực + trạng thái mạng.
    await tapNav(tester, Icons.auto_awesome_outlined);
    expect(aux('Trợ lý AI'), findsOneWidget);
    expect(aux('Lập kế hoạch ôn tập'), findsOneWidget);

    // Tiến độ: số liệu tuần.
    await tapNav(tester, Icons.trending_up_rounded);
    expect(aux('Tuần này'), findsOneWidget);
    expect(find.textContaining('h'), findsWidgets);

    // Tôi: hồ sơ + đồng bộ.
    await tapNav(tester, Icons.person_outline);
    expect(aux('Tài khoản'), findsOneWidget);
    expect(aux('Sĩ tử 2k9'), findsOneWidget);
    expect(find.textContaining('Chuỗi học'), findsOneWidget);

    // Lối tắt dùng chung luôn có mặt.
    expect(find.text('Lịch học'), findsOneWidget);
    expect(find.text('Ghi chú'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mở trang phụ từ lối tắt trong cột phụ', (tester) async {
    await pumpShell(tester, const Size(1440, 900));

    await tester.tap(find.text('Ghi chú'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Ghi chú'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('không tràn ở màn rộng và cỡ chữ lớn', (tester) async {
    for (final size in const [Size(1440, 900), Size(1920, 1080)]) {
      await pumpShell(tester, size);
      expect(find.byType(DesktopAuxColumn), findsOneWidget,
          reason: 'thiếu cột phụ ở $size');
      expect(tester.takeException(), isNull, reason: 'tràn ở $size');
    }

    // Cỡ chữ hệ thống lớn: số liệu co lại được nhờ FittedBox/ellipsis.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      // `builder` giữ nguyên kích thước cửa sổ, chỉ nhân cỡ chữ.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.4)),
        child: child!,
      ),
      home: const MainShellScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(DesktopAuxColumn), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
