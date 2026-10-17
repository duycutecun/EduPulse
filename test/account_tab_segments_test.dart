import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/account/presentation/screens/account_screen.dart';

/// Test tổ chức lại tab "Tôi" thành 3 tab con (segmented control kiểu iOS):
///
/// 1. Đổi tab con đổi nội dung (Hồ sơ / Cài đặt / Thông tin app).
/// 2. Unlock nhóm "Chủ app": bấm 7 lần hàng "Phiên bản" → hiện; 6 lần → ẩn;
///    re-pump (restart) → ẩn lại (unlock không sống qua session).
/// 3. Guard chống mất mục: mỗi entry của 7 nhóm phẳng cũ phải còn xuất hiện
///    (duy nhất) trong tổng 3 tab con.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  /// Màn cao như điện thoại thật để mọi hàng đều nằm trong viewport.
  ///
  /// `freshState: true` mô phỏng restarting app — AccountScreen gắn UniqueKey
  /// để Flutter tạo State mới thay vì tái sử dụng State cũ (trên app thật,
  /// restart luôn khởi chạy process mới → State luôn mới).
  Future<void> pumpAccount(WidgetTester tester,
      {bool freshState = false}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: AccountScreen(
          key: freshState ? UniqueKey() : null,
          onDataChanged: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> goSegment(WidgetTester tester, int index) async {
    await tester.tap(find.byKey(Key('ios-segment-$index')));
    await tester.pumpAndSettle();
  }

  Future<Set<String>> collectAllTexts(WidgetTester tester) async {
    final texts = <String>{};
    tester.allWidgets
        .whereType<Text>()
        .where((t) => t.data != null)
        .forEach((t) => texts.add(t.data!));
    return texts;
  }

  group('Segmented control 3 tab con', () {
    testWidgets('mở tab Tôi mặc định vào tab Hồ sơ — hiện đăng nhập',
        (tester) async {
      await pumpAccount(tester);

      expect(find.byKey(const Key('account-segments')), findsOneWidget);
      expect(find.byKey(const Key('ios-segment-0')), findsOneWidget);
      expect(find.byKey(const Key('account-version-row')), findsNothing);
      // Hồ sơ: chưa đăng nhập → hàng "Tạo tài khoản".
      expect(find.text('Tạo tài khoản'), findsOneWidget);
      expect(find.byKey(const Key('account-sync-card')), findsOneWidget);
    });

    testWidgets('đổi sang Cài đặt — hiện nhóm AI, ẩn phần đăng nhập',
        (tester) async {
      await pumpAccount(tester);
      await goSegment(tester, 1);

      expect(find.text('Cài đặt'), findsWidgets);
      expect(find.text('AI nâng cao'), findsOneWidget);
      expect(find.text('Nhắc học hằng ngày'), findsOneWidget);
      expect(find.text('Cỡ chữ'), findsOneWidget);
      // Đăng nhập chỉ thuộc tab Hồ sơ.
      expect(find.text('Tạo tài khoản'), findsNothing);
    });

    testWidgets('đổi sang Thông tin app — hiện hàng Phiên bản', (tester) async {
      await pumpAccount(tester);
      await goSegment(tester, 2);

      expect(find.text('Phiên bản'), findsOneWidget);
      expect(find.text('Gửi phản hồi beta'), findsOneWidget);
      expect(find.text('AI nâng cao'), findsNothing);
      expect(find.text('Tạo tài khoản'), findsNothing);
    });
  });

  group('Unlock nhóm "Chủ app"', () {
    testWidgets('bấm 6 lần hàng Phiên bản — KHÔNG hiện nhóm Chủ app',
        (tester) async {
      await pumpAccount(tester);
      await goSegment(tester, 2);

      final row = find.byKey(const Key('account-version-row'));
      expect(row, findsOneWidget);
      for (var i = 0; i < 6; i++) {
        await tester.tap(row);
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('account-owner-section')), findsNothing);
    });

    testWidgets('bấm 7 lần hàng Phiên bản — hiện nhóm Chủ app kèm cấu hình',
        (tester) async {
      await pumpAccount(tester);
      await goSegment(tester, 2);

      final row = find.byKey(const Key('account-version-row'));
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

    testWidgets('restart (re-pump widget mới) — nhóm Chủ app ẩn lại',
        (tester) async {
      await pumpAccount(tester);
      await goSegment(tester, 2);

      final row = find.byKey(const Key('account-version-row'));
      for (var i = 0; i < 7; i++) {
        await tester.tap(row);
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-owner-section')), findsOneWidget);

      // Re-pump đặt lãi state cũ — mô phỏng restart app (process mới → State
      // mới): unlock phải mất, đếm bấm lại từ 0.
      await pumpAccount(tester, freshState: true);
      await goSegment(tester, 2);
      expect(find.byKey(const Key('account-owner-section')), findsNothing);
    });
  });

  group('Guard chống mất mục — 7 nhóm cũ phải còn đủ trong 3 tab con', () {
    testWidgets('mỗi entry cũ xuất hiện duy nhất trong đúng tab của nó',
        (tester) async {
      await pumpAccount(tester);

      /// Entry cũ → (nội dung phải tìm thấy, chỉ thuộc tab con này).
      ///
      /// Chỉ nhóm TRỢ GIÚP & GIỚI THIỆU cũ chuyển tab (sang Thông tin app) —
      /// mục "Gửi phản hồi beta" vẫn giữ nguyên nội dung.
      const entries = <String, int>{
        // Tab Hồ sơ (đăng nhập + đồng bộ + hồ sơ + học tập + gia đình)
        'Tạo tài khoản': 0,
        'Hồ sơ học tập': 0,
        'Báo cáo học tập sâu': 0,
        'Bảng vàng kỷ lục': 0,
        'Thành tích & huy hiệu': 0,
        'Cửa sổ tin cậy': 0,
        'Chế độ phụ huynh': 0,
        // Tab Cài đặt (cảnh báo & nhắc + giao diện & âm thanh + dữ liệu & riêng tư)
        'Nhắc học hằng ngày': 1,
        'Cỡ chữ': 1,
        'Tương phản cao': 1,
        'Chế độ yên lặng': 1,
        'Hiện linh vật': 1,
        'Giảm chuyển động': 1,
        'Rung': 1,
        'Âm thanh': 1,
        'AI đọc nhiệm vụ và phiên học': 1,
        'AI phân tích tiến độ': 1,
        'AI nâng cao': 1,
        'Xuất / nhập dữ liệu': 1,
        'Quyền riêng tư & dữ liệu': 1,
        'Xóa lịch sử trò chuyện AI': 1,
        // Tab Thông tin app (trợ giúp & giới thiệu cũ)
        'Gửi phản hồi beta': 2,
      };

      for (var segment = 0; segment < 3; segment++) {
        if (segment != 0) await goSegment(tester, segment);
        final texts = await collectAllTexts(tester);

        final inThisTab = entries.entries
            .where((e) => e.value == segment)
            .map((e) => e.key)
            .toList();
        for (final entry in inThisTab) {
          expect(texts, contains(entry),
              reason: 'Mục "$entry" phải còn ở tab con $segment');
          // Đếm số Text widget trùng — phải DUY NHẤT trong tab đó.
          final count = tester.allWidgets
              .whereType<Text>()
              .where((t) => t.data == entry)
              .length;
          expect(count, 1,
              reason: 'Mục "$entry" không được lặp trong tab con $segment');
        }
      }
    });

    testWidgets('tổng các entry cũ phải >= 20 mục tồn tại trong cả 3 tab',
        (tester) async {
      await pumpAccount(tester);

      final all = <String>{};
      for (var segment = 0; segment < 3; segment++) {
        if (segment != 0) await goSegment(tester, segment);
        all.addAll(await collectAllTexts(tester));
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
        'Gửi phản hồi beta',
      ];
      final found = required.where(all.contains).length;
      expect(found, required.length,
          reason: 'Thiếu mục cũ trong tab "Tôi" sau khi tổ chức lại: '
              '${required.where((r) => !all.contains(r)).toSet()}');
    });
  });
}
