import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/account/presentation/screens/account_screen.dart';

/// Test drill-down kiểu iOS Settings thật cho tab "Tôi" (thay cho segmented
/// control v2.6.0):
///
/// 1. Trang chính = menu gốc gọn: card hồ sơ lớn + 2 row nhóm (Cài đặt |
///    Thông tin app) với chevron phải.
/// 2. Bấm row/card → PUSH trang con riêng (MaterialPageRoute) — nội dung
///    CHI TIẾT nằm trên màn của nó, không phải đổi tại chỗ; nút back quay lại.
/// 3. Unlock nhóm "Chủ app": bấm 7 lần hàng "Phiên bản" (ở trang con Thông
///    tin app) → hiện; 6 lần → ẩn; restart (re-pump) → ẩn lại.
/// 4. Guard chống mất mục: 23 entry cũ phải còn — mỗi entry nằm ở đúng 1
///    trong 3 trang con (2 mục user tab Cài đặt; 12 mục nâng cao trong nhóm
///    CHỦ APP ẨN của Thông tin app), KHÔNG mất mục, KHÔNG trúng 2 lần.
void main() {
  setUp(() async {
    // Tên/mục tiêu mock giống các test shell — card hồ sơ trên trang chính
    // hiện tên này mà không cần mở trang con.
    SharedPreferences.setMockInitialValues({
      'user_name': 'Sĩ tử 2k9',
      'user_target': 'ĐH Bách Khoa Hà Nội',
    });
    await StorageService.init();
  });

  /// Màn cao như điện thoại thật để mọi hàng đều nằm trong viewport.
  Future<void> pumpAccount(WidgetTester tester,
      {bool freshState = false}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      // `freshState: true` mô phỏng restarting app — AccountScreen gắn
      // UniqueKey để Flutter tạo State mới thay vì tái sử dụng State cũ.
      home: Scaffold(
        body: AccountScreen(
          key: freshState ? UniqueKey() : null,
          onDataChanged: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Mở trang con "Cài đặt" từ trang chính (bấm row nhóm chevron phải).
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('account-row-settings')));
    await tester.pumpAndSettle();
  }

  /// Mở trang con "Thông tin app" từ trang chính.
  Future<void> openAbout(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('account-row-about')));
    await tester.pumpAndSettle();
  }

  /// Mở trang con "Hồ sơ" (bấm card hồ sơ lớn trên đầu trang chính).
  Future<void> openProfileDetail(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('account-profile-card')));
    await tester.pumpAndSettle();
  }

  /// Unlock nhóm "Chủ app": bấm 7 lần liên tục vào hàng "Phiên bản"
  /// (trong trang "Thông tin app"; unlock chỉ sống trong session).
  Future<void> unlockOwner(WidgetTester tester) async {
    final row = find.byKey(const Key('account-version-row'));
    for (var i = 0; i < 7; i++) {
      await tester.tap(row);
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pumpAndSettle();
  }

  Future<Set<String>> collectTexts(WidgetTester tester) async {
    final texts = <String>{};
    tester.allWidgets
        .whereType<Text>()
        .where((t) => t.data != null)
        .forEach((t) => texts.add(t.data!));
    return texts;
  }

  group('Trang chính kiểu iOS Settings', () {
    testWidgets('có card hồ sơ lớn + 2 row nhóm chevron phải', (tester) async {
      await pumpAccount(tester);

      // Card hồ sơ lớn trên đầu (như row Apple-ID của iOS Settings).
      expect(find.byKey(const Key('account-profile-card')), findsOneWidget);
      // Tên + badge "Sĩ tử 2026" ngay trên card — không cần mở trang con.
      expect(find.text('Sĩ tử 2k9'), findsOneWidget);
      expect(find.textContaining('Sĩ tử 2026'), findsOneWidget);
      // 2 row nhóm drill-down.
      expect(find.byKey(const Key('account-row-settings')), findsOneWidget);
      expect(find.byKey(const Key('account-row-about')), findsOneWidget);
      // Nội dung chi tiết KHÔNG nằm tại chỗ trang chính nữa — phải push.
      expect(find.text('Cỡ chữ'), findsNothing);
      expect(find.text('Phiên bản'), findsNothing);
      expect(find.byKey(const Key('account-version-row')), findsNothing);
    });

    testWidgets('tap row "Cài đặt" → PUSH trang Cài đặt; back → về card hồ sơ',
        (tester) async {
      await pumpAccount(tester);
      await openSettings(tester);

      // Đã sang trang con: chỉ còn 2 mục user — ① Nhắc học hằng ngày,
      // ② Cỡ chữ (card riêng, tách khỏi AppearanceCard cũ).
      expect(find.text('Cỡ chữ'), findsOneWidget);
      expect(find.text('Nhắc học hằng ngày'), findsOneWidget);
      // Phần nâng cao (AI nâng cao...) đã chuyển sang nhóm CHỦ APP trong
      // trang "Thông tin app" — không còn ở trang Cài đặt.
      expect(find.text('AI nâng cao'), findsNothing);
      // Card hồ sơ không còn trên top — thật sự là push, không phải đổi tại chỗ.
      expect(find.byKey(const Key('account-profile-card')), findsNothing);

      // Bấm nút back của AppBar → quay về trang chính, card hồ sơ vẫn đó.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-profile-card')), findsOneWidget);
      expect(find.text('Cỡ chữ'), findsNothing);
    });

    testWidgets(
        'tap row "Thông tin app" → PUSH trang có hàng Phiên bản + unlock 7 bấm → nhóm CHỦ APP',
        (tester) async {
      await pumpAccount(tester);
      await openAbout(tester);

      // Hàng "Phiên bản" giờ nằm trong trang con Thông tin app.
      final row = find.byKey(const Key('account-version-row'));
      expect(row, findsOneWidget);

      // Bấm 7 lần → mở nhóm "Chủ app" (unlock session-only như cũ).
      for (var i = 0; i < 7; i++) {
        await tester.tap(row);
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('account-owner-section')), findsOneWidget);
      expect(find.text('CHỦ APP'), findsOneWidget);
      // Công cụ chủ app: thẻ dán cấu hình Cloud & AI.
      expect(find.text('Cloud & AI của bản cài này'), findsOneWidget);
    });

    testWidgets(
        'bấm 6 lần hàng Phiên bản — KHÔNG hiện nhóm Chủ app (ngưỡng 7 giữ nguyên)',
        (tester) async {
      await pumpAccount(tester);
      await openAbout(tester);

      final row = find.byKey(const Key('account-version-row'));
      for (var i = 0; i < 6; i++) {
        await tester.tap(row);
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('account-owner-section')), findsNothing);
    });

    testWidgets('unlock chỉ sống trong session — restart app ẩn lại',
        (tester) async {
      await pumpAccount(tester);
      await openAbout(tester);

      final row = find.byKey(const Key('account-version-row'));
      for (var i = 0; i < 7; i++) {
        await tester.tap(row);
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-owner-section')), findsOneWidget);

      // "Restart" app: quay về trang chính rồi gắn lại State mới (trên app
      // thật, restart luôn khởi chạy process mới → State mới + navigator
      // trống). Unlock phải mất, phải bấm lại từ 0.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await pumpAccount(tester, freshState: true);
      await openAbout(tester);
      expect(find.byKey(const Key('account-owner-section')), findsNothing);
    });

    testWidgets('tap card hồ sơ → PUSH trang Hồ sơ: Tạo tài khoản + đồng bộ',
        (tester) async {
      await pumpAccount(tester);
      await openProfileDetail(tester);

      // Trang con Hồ sơ: đăng nhập (chưa đăng nhập → "Tạo tài khoản") và
      // SyncStatusCard chuyển vào đây cùng tóm tắt hồ sơ.
      expect(find.text('Tạo tài khoản'), findsOneWidget);
      expect(find.byKey(const Key('account-sync-card')), findsOneWidget);
      // Hai nhóm học tập & gia đình cũng thuộc trang Hồ sơ.
      expect(find.text('HỌC TẬP'), findsOneWidget);
      expect(find.text('GIA ĐÌNH'), findsOneWidget);

      // Back → về trang chính.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-profile-card')), findsOneWidget);
    });
  });

  group('Guard chống mất mục — entry cũ phải còn đúng 1 trang con duy nhất',
      () {
    testWidgets('mỗi entry cũ xuất hiện duy nhất trong đúng trang con của nó',
        (tester) async {
      await pumpAccount(tester);

      /// Entry cũ → trang con chứa nó (0 Hồ sơ · 1 Cài đặt · 2 Thông tin app).
      ///
      /// Toàn bộ 23 mục của tab "Tôi" cũ phải sống sót qua việc tái cấu trúc
      /// drill-down — không mất mục nào, không lặp ở 2 nơi. v2.8: trang Cài
      /// đặt gọn còn 2 mục user; phần nâng cao nằm trong nhóm CHỦ APP của
      /// trang "Thông tin app" (cần unlock 7 bấm mới thấy).
      const entries = <String, int>{
        // Trang con Hồ sơ (đăng nhập + đồng bộ + học tập + gia đình)
        'Tạo tài khoản': 0,
        'Hồ sơ học tập': 0,
        'Báo cáo học tập sâu': 0,
        'Bảng vàng kỷ lục': 0,
        'Thành tích & huy hiệu': 0,
        'Cửa sổ tin cậy': 0,
        'Chế độ phụ huynh': 0,
        // Trang con Cài đặt — chỉ 2 mục user (Nhắc học + Cỡ chữ card riêng)
        'Nhắc học hằng ngày': 1,
        'Cỡ chữ': 1,
        // Trang con Thông tin app: mục tĩnh + nhóm CHỦ APP ẨN (12 mục chuyển
        // từ Cài đặt xuống: tương phản, yên lặng, giao diện & âm thanh, AI,
        // dữ liệu & riêng tư)
        'Phiên bản': 2,
        'Gửi phản hồi beta': 2,
        'Tương phản cao': 2,
        'Chế độ yên lặng': 2,
        'Hiện linh vật': 2,
        'Giảm chuyển động': 2,
        'Rung': 2,
        'Âm thanh': 2,
        'AI đọc nhiệm vụ và phiên học': 2,
        'AI phân tích tiến độ': 2,
        'AI nâng cao': 2,
        'Xuất / nhập dữ liệu': 2,
        'Quyền riêng tư & dữ liệu': 2,
        'Xóa lịch sử trò chuyện AI': 2,
      };

      final screenOpeners = [openProfileDetail, openSettings, openAbout];

      for (var screen = 0; screen < 3; screen++) {
        await screenOpeners[screen](tester);
        // Trang "Thông tin app": 12 mục nâng cao nằm trong nhóm CHỦ APP ẨN —
        // phải unlock 7 bấm trước khi kiểm tra.
        if (screen == 2) await unlockOwner(tester);
        final texts = await collectTexts(tester);

        final inThisScreen =
            entries.entries.where((e) => e.value == screen).map((e) => e.key);
        for (final entry in inThisScreen) {
          expect(texts, contains(entry),
              reason: 'Mục "$entry" phải còn ở trang con $screen');
          // Đếm số Text widget trùng — phải DUY NHẤT trong trang đó.
          final count = tester.allWidgets
              .whereType<Text>()
              .where((t) => t.data == entry)
              .length;
          expect(count, 1,
              reason: 'Mục "$entry" không được lặp trong trang con $screen');
        }

        // Quay về trang chính trước khi mở trang con kế tiếp.
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('tổng các entry cũ phải còn đủ 23 mục tồn tại qua 3 trang con',
        (tester) async {
      await pumpAccount(tester);

      final all = <String>{};
      for (final opener in [openProfileDetail, openSettings, openAbout]) {
        await opener(tester);
        // Trang "Thông tin app": unlock 7 bấm để nhóm CHỦ APP hiển thị.
        if (opener == openAbout) await unlockOwner(tester);
        all.addAll(await collectTexts(tester));
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
      }

      const required = [
        'Tạo tài khoản',
        'Hồ sơ học tập',
        'Báo cáo học tập sâu',
        'Bảng vàng kỷ lục',
        'Thành tích & huy hiệu',
        'Cửa sổ tin cậy',
        'Chế độ phụ huynh',
        'Nhắc học hằng ngày',
        'Cỡ chữ',
        'Tương phản cao',
        'Chế độ yên lặng',
        'Hiện linh vật',
        'Giảm chuyển động',
        'Rung',
        'Âm thanh',
        'AI đọc nhiệm vụ và phiên học',
        'AI phân tích tiến độ',
        'AI nâng cao',
        'Xuất / nhập dữ liệu',
        'Quyền riêng tư & dữ liệu',
        'Xóa lịch sử trò chuyện AI',
        'Phiên bản',
        'Gửi phản hồi beta',
      ];
      final found = required.where(all.contains).length;
      expect(found, required.length,
          reason: 'Thiếu mục cũ trong tab "Tôi" sau khi drill-down: '
              '${required.where((r) => !all.contains(r)).toSet()}');
    });
  });
}
