import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/app/main_shell.dart';
import 'package:edupulse/app/desktop_sidebar.dart';
import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';

/// FE-6.1 + QA-6.1 — Ma trận kiểm thử Responsive.
///
/// Duyệt app thật (MainShell) qua 4 tab chính và các trang phụ ở đủ nhóm kích
/// thước mục tiêu: mobile nhỏ/tiêu chuẩn, tablet và desktop. Mỗi bước đều khẳng
/// định **không có ngoại lệ layout** (overflow) — đây là "vỡ layout" mà đặc tả
/// Sprint 6 yêu cầu chặn.
///
/// Lưu ý: KHÔNG dùng `pumpAndSettle` — HomeScreen có `Timer.periodic` nên sẽ treo.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'streak': 12,
      'user_name': 'Sĩ tử 2k9',
      'user_target': 'ĐH Bách Khoa Hà Nội',
    });
    await StorageService.init();
    // Một phiên học hôm nay để tất cả màn có dữ liệu thật (không rơi vào
    // nhánh rỗng, tránh bỏ sót lỗi chỉ xuất hiện khi có nội dung).
    StorageService.setStudyLogJson(
      'log-today',
      StudyLog(
        id: 'log-today',
        date: DateTime.now(),
        subject: 'Toán',
        hours: 2.0,
      ).toJsonString(),
    );
    StorageService.setStudyLogIds(['log-today']);
  });

  Widget host() => MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MainShellScreen(),
      );

  Future<void> pumpShell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Bấm mục điều hướng qua icon — hoạt động cho cả bottom nav (có nhãn) lẫn
  /// sidebar rail thu gọn (nhãn ẩn).
  Future<void> tapNav(WidgetTester tester, IconData icon) async {
    final finder = find.byIcon(icon);
    expect(finder, findsWidgets, reason: 'Không tìm thấy icon nav $icon');
    // Sidebar đứng trước nội dung trong cây; bottom nav đứng sau.
    final wide = find.byType(DesktopSidebar).evaluate().isNotEmpty;
    await tester.tap(wide ? finder.first : finder.last);
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Kích thước mục tiêu: mobile nhỏ, mobile chuẩn, tablet, desktop.
  const sizes = <String, Size>{
    'mobile nhỏ 320x568': Size(320, 568),
    'mobile chuẩn 390x844': Size(390, 844),
    'tablet 768x1024': Size(768, 1024),
    'desktop 1280x800': Size(1280, 800),
  };

  for (final entry in sizes.entries) {
    testWidgets('${entry.key}: 4 tab + các trang phụ không tràn',
        (tester) async {
      await pumpShell(tester, entry.value);

      // Tab 0 — Hôm nay.
      expect(tester.takeException(), isNull);
      expect(find.text('Nhiệm vụ hôm nay'), findsOneWidget);

      // Tab Tiến độ (icon inactive khi chưa active).
      await tapNav(tester, Icons.trending_up_rounded);
      expect(tester.takeException(), isNull);
      expect(find.text('Tiến độ học tập'), findsOneWidget);

      // Tab AI.
      await tapNav(tester, Icons.auto_awesome_outlined);
      expect(tester.takeException(), isNull);

      // Tab Tôi.
      await tapNav(tester, Icons.person_outline);
      expect(tester.takeException(), isNull);

      // Về Hôm nay rồi mở trang phụ qua nút/quick action.
      await tapNav(tester, Icons.today_outlined);
      expect(tester.takeException(), isNull);

      // Mở trang Mục tiêu (kỳ thi) — mobile bấm chip, desktop bấm sidebar.
      final goals = find.text('Mục tiêu');
      final target = goals.evaluate().isNotEmpty
          ? goals.last
          : find.text('Chưa chọn kỳ thi mục tiêu');
      if (target.evaluate().isNotEmpty) {
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Đóng trang phụ (fullscreenDialog dùng nút Close).
        final close = find.byTooltip('Close');
        if (close.evaluate().isNotEmpty) {
          await tester.tap(close);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('breakpoint đổi layout: phone → tablet(768) → desktop(1024)',
      (tester) async {
    // Ngay dưới ngưỡng tablet → mobile (bottom nav, không sidebar).
    await pumpShell(tester, const Size(767, 800));
    expect(find.byType(DesktopSidebar), findsNothing);
    expect(tester.takeException(), isNull);

    // Đúng ngưỡng tablet → sidebar (rail thu gọn).
    tester.view.physicalSize = const Size(768, 1024);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(DesktopSidebar), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Đúng ngưỡng desktop.
    tester.view.physicalSize = const Size(1024, 800);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(DesktopSidebar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('touch target điều hướng đạt chuẩn ≥44px ở 320px',
      (tester) async {
    await pumpShell(tester, const Size(320, 568));

    // Mỗi mục bottom nav phải đủ lớn để bấm thoải mái (chuẩn 44x44).
    for (final icon in const [
      Icons.today_rounded,
      Icons.auto_awesome_outlined,
      Icons.trending_up_rounded,
      Icons.person_outline,
    ]) {
      final target = find
          .ancestor(
              of: find.byIcon(icon), matching: find.byType(GestureDetector))
          .first;
      final size = tester.getSize(target);
      expect(size.width, greaterThanOrEqualTo(44),
          reason: 'Mục nav $icon hẹp hơn 44px');
      expect(size.height, greaterThanOrEqualTo(44),
          reason: 'Mục nav $icon thấp hơn 44px');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('bàn phím ảo không đẩy tràn layout nhập liệu (viewInsets)',
      (tester) async {
    await pumpShell(tester, const Size(390, 844));
    // Giả lập bàn phím ảo cao 300px.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });
}
