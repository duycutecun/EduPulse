import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/progress/presentation/screens/progress_screen.dart';
import 'package:edupulse/features/study/presentation/screens/study_screen.dart';
import 'package:edupulse/shared/widgets/primary_button.dart';
import 'package:edupulse/shared/widgets/state_views.dart';

/// P0-3 — "Trạng thái loading/empty/error thống nhất tại các màn chính".
///
/// Trước đợt cải tổ này, mỗi màn tự dựng vùng rỗng theo một kiểu: màn Tập trung
/// có ba kiểu khác nhau (một dòng chữ trần, khối có nút, emoji 48px), màn Tiến
/// độ có spinner trần và một khối tự viết. Cùng một tình huống "chưa có dữ
/// liệu" lại trông khác nhau ở mỗi nơi, nên người dùng phải học lại cách đọc
/// nó mỗi lần gặp.
///
/// Test này khoá lại hai điều:
/// 1. [EmptyStatePanel] / [ErrorStatePanel] — khuôn chung cho vùng rỗng và vùng
///    lỗi trong thẻ, trong sheet — hoạt động đúng (có/không có nút hành động).
/// 2. Các màn chính thật sự dùng khuôn đó, và vẫn giữ nguyên nội dung + key mà
///    người dùng đã quen (đổi hình thức, không đổi hợp đồng).
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      );

  group('EmptyStatePanel — khuôn rỗng dùng chung', () {
    testWidgets('khối: đủ tiêu đề, mô tả và nút hành động gọi callback',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(host(EmptyStatePanel(
        icon: Icons.menu_book_rounded,
        title: 'Chưa có nhật ký.',
        description: 'Ghi lại vài dòng sau mỗi phiên học.',
        actionLabel: 'Bắt đầu học',
        actionIcon: Icons.play_arrow_rounded,
        actionKey: const Key('panel-cta'),
        onAction: () => tapped++,
      )));

      expect(find.text('Chưa có nhật ký.'), findsOneWidget);
      expect(find.text('Ghi lại vài dòng sau mỗi phiên học.'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);

      await tester.tap(find.byKey(const Key('panel-cta')));
      expect(tapped, 1);
    });

    testWidgets('không có hành động → không chen nút nào vào màn',
        (tester) async {
      await tester.pumpWidget(host(const EmptyStatePanel(
        icon: Icons.assignment_outlined,
        title: 'Chưa có điểm thi thử.',
        description: 'Ghi lại điểm sau mỗi lần thi.',
      )));

      expect(find.text('Chưa có điểm thi thử.'), findsOneWidget);
      // Đây là lý do panel tồn tại: vùng rỗng không tự thêm CTA khi màn không
      // có đường đi tiếp — nút giả còn tệ hơn không có nút.
      expect(find.byType(PrimaryButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('compact: hàng gọn cho sheet, vẫn có nút phụ khi cần',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(host(EmptyStatePanel(
        compact: true,
        icon: Icons.playlist_add_check_rounded,
        title: 'Chưa có nhiệm vụ chưa hoàn thành.',
        description: 'Thêm nhiệm vụ ở tab Hôm nay rồi quay lại đây.',
        actionLabel: 'Thêm',
        onAction: () => tapped++,
      )));

      expect(find.text('Chưa có nhiệm vụ chưa hoàn thành.'), findsOneWidget);
      await tester.tap(find.text('Thêm'));
      expect(tapped, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('ErrorStatePanel — lỗi tại chỗ, có nút thử lại', () {
    testWidgets('hiện thông điệp và gọi callback khi bấm thử lại',
        (tester) async {
      var retried = 0;
      await tester.pumpWidget(host(ErrorStatePanel(
        message: 'AI cần kết nối mạng — nhận định bên dưới vẫn dùng số liệu thật.',
        onRetry: () => retried++,
      )));

      expect(
        find.text(
            'AI cần kết nối mạng — nhận định bên dưới vẫn dùng số liệu thật.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Thử lại'));
      expect(retried, 1);
    });

    testWidgets('không có cách thử lại → chỉ hiện thông điệp', (tester) async {
      await tester.pumpWidget(host(const ErrorStatePanel(
        message: 'Chưa đủ dữ liệu để AI nhận định.',
      )));

      expect(find.text('Chưa đủ dữ liệu để AI nhận định.'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });
  });

  group('Màn Tiến độ', () {
    Widget progress({VoidCallback? onStartStudy}) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ProgressScreen(
              clock: () => DateTime(2026, 3, 18, 10, 0),
              onStartStudy: onStartStudy,
            ),
          ),
        );

    testWidgets('chưa có dữ liệu → EmptyStatePanel + CTA, không spinner trần',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var started = 0;
      await tester.pumpWidget(progress(onStartStudy: () => started++));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(EmptyStatePanel), findsOneWidget);
      expect(find.text('Chưa có dữ liệu học trong tuần này.'), findsOneWidget);
      // Trạng thái tải/rỗng của màn chính không còn dùng spinner trần.
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('progress-start-study')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('progress-start-study')));
      await tester.pump();
      expect(started, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('không có đường bắt đầu học → panel không chen CTA',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(progress());
      await tester.pump(const Duration(milliseconds: 300));

      // Chỉ còn đúng một CTA chính của màn (nhờ AI phân tích) — thẻ rỗng không
      // thêm nút thứ hai cạnh tranh sự chú ý.
      expect(find.byType(PrimaryButton), findsOneWidget);
      expect(find.text('Hỏi AI phân tích'), findsOneWidget);
    });

    testWidgets('AI chưa phân tích được → lỗi nằm trong vùng nhận định',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(progress());
      await tester.pump(const Duration(milliseconds: 300));

      // Tuần trắng → ProgressInsights.generate trả null ngay (không gọi mạng),
      // nên đây là ca lỗi tất định để kiểm tra cách hiển thị.
      await tester.ensureVisible(find.text('Hỏi AI phân tích'));
      await tester.pump();
      await tester.tap(find.text('Hỏi AI phân tích'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ErrorStatePanel), findsOneWidget);
      expect(find.textContaining('Chưa đủ dữ liệu để AI nhận định'),
          findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });

  group('Màn Tập trung', () {
    Future<void> pumpStudy(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: StudyScreen(clock: () => DateTime(2026, 5, 1, 8)),
        ),
      ));
      await tester.pump();
    }

    testWidgets('tab Biểu đồ: chưa có phiên → panel chung + CTA bắt đầu',
        (tester) async {
      await pumpStudy(tester);
      await tester.tap(find.text('Biểu đồ'));
      await tester.pump();

      expect(find.byType(EmptyStatePanel), findsWidgets);
      expect(find.text('Chưa có phiên học nào.'), findsOneWidget);
      expect(find.byKey(const ValueKey('start-first-session')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tab Nhật ký và Điểm thi: mỗi vùng rỗng dùng panel chung',
        (tester) async {
      await pumpStudy(tester);

      await tester.tap(find.text('Nhật ký'));
      await tester.pump();
      expect(find.text('Chưa có nhật ký.'), findsOneWidget);
      expect(find.byType(EmptyStatePanel), findsWidgets);

      await tester.tap(find.text('Điểm thi'));
      await tester.pump();
      expect(find.text('Chưa có điểm thi thử.'), findsOneWidget);
      expect(find.byType(EmptyStatePanel), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sheet chọn nhiệm vụ: vùng rỗng dùng bản compact',
        (tester) async {
      await pumpStudy(tester);

      // Ô "Nhiệm vụ hiện tại" mở sheet chọn nhiệm vụ (chưa chạy đồng hồ).
      await tester.tap(find.text('Focus tự do').first);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Chưa có nhiệm vụ chưa hoàn thành.'), findsOneWidget);
      final panel = tester.widget<EmptyStatePanel>(find.byType(EmptyStatePanel));
      expect(panel.compact, isTrue,
          reason: 'sheet hẹp phải dùng bản compact, không phải khối lớn');
      expect(tester.takeException(), isNull);
    });
  });
}
