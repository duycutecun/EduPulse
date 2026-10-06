import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/ai/ai_config.dart';
import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/account/presentation/widgets/cloud_ai_card.dart';
import 'package:edupulse/features/account/presentation/widgets/native_experience_card.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    // flutter_test vốn chạy như Android — trùng đúng nền tảng app thật, nên
    // các test "trên app" không cần ghim gì thêm.
    expect(defaultTargetPlatform, TargetPlatform.android);
  });

  /// Màn hình cao rộng như điện thoại thật để mọi ô nhập đều chạm tới được.
  Future<void> pumpCard(WidgetTester tester, Widget card) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(child: card),
      ),
    ));
    await tester.pump();
  }

  group('Thẻ Trải nghiệm riêng trên app', () {
    testWidgets('liệt kê đủ 4 khác biệt app vs web', (tester) async {
      await pumpCard(tester, const NativeExperienceCard());

      expect(find.textContaining('Chia sẻ qua Zalo'), findsOneWidget);
      expect(find.textContaining('Nhắc học & tóm tắt'), findsOneWidget);
      expect(find.textContaining('Widget màn hình chính'), findsOneWidget);
      expect(find.textContaining('Rung & âm thanh'), findsOneWidget);
    });

    testWidgets('trên app: cả 4 tính năng đều đang chạy và có nút gửi thử',
        (tester) async {
      await pumpCard(tester, const NativeExperienceCard());

      expect(find.text('Đang chạy'), findsNWidgets(4));
      expect(find.text('Chỉ trên app'), findsNothing);
      expect(find.textContaining('Bạn đang dùng bản web'), findsNothing);
      expect(find.byKey(const Key('native-share-invite')), findsOneWidget);
      expect(find.byKey(const Key('native-test-notification')), findsOneWidget);
      expect(find.textContaining('Đang chạy trên: Ứng dụng Android'),
          findsOneWidget);
    });

    testWidgets('trên máy tính: nói rõ web/máy tính thiếu gì', (tester) async {
      // flutter_test bắt buộc biến debug phải được trả lại trước khi test
      // kết thúc, nên reset ngay trong thân test chứ không dùng tearDown.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await pumpCard(tester, const NativeExperienceCard());
      debugDefaultTargetPlatformOverride = null;

      // Nhắc học, widget và rung đều không có trên nền không phải mobile.
      expect(find.text('Chỉ trên app'), findsNWidgets(3));
      expect(find.textContaining('Web không có widget'), findsOneWidget);
      expect(find.textContaining('Bạn đang dùng bản web'), findsOneWidget);
      // Không có thông báo thì không hứa "gửi thử".
      expect(find.byKey(const Key('native-test-notification')), findsNothing);
      expect(find.byKey(const Key('native-share-invite')), findsOneWidget);
    });
  });

  group('Thẻ Cloud & AI', () {
    testWidgets('mặc định thu gọn, bấm Thiết lập mới hiện ô nhập',
        (tester) async {
      await pumpCard(tester, const CloudAiCard());

      expect(find.byKey(const Key('cloud-supabase-url')), findsNothing);

      await tester.tap(find.byKey(const Key('cloud-ai-toggle')));
      await tester.pump();

      expect(find.byKey(const Key('cloud-supabase-url')), findsOneWidget);
      expect(find.byKey(const Key('cloud-openrouter-key')), findsOneWidget);
      expect(find.byKey(const Key('cloud-supabase-anon')), findsOneWidget);
    });

    testWidgets('lưu cấu hình thì ghi vào máy và AI dùng được ngay',
        (tester) async {
      await pumpCard(tester, const CloudAiCard());

      await tester.tap(find.byKey(const Key('cloud-ai-toggle')));
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('cloud-supabase-url')), 'https://demo.supabase.co');
      await tester.enterText(
          find.byKey(const Key('cloud-supabase-anon')), 'anon-key-123');
      await tester.enterText(
          find.byKey(const Key('cloud-openrouter-key')), 'sk-or-v1-demo');

      await tester.tap(find.byKey(const Key('cloud-ai-save')));
      await tester.pump();

      expect(StorageService.getSupabaseUrl(), 'https://demo.supabase.co');
      expect(StorageService.getSupabaseAnonKey(), 'anon-key-123');
      expect(AiConfig.openRouterApiKey, 'sk-or-v1-demo');
      // Cấu hình cloud chỉ đọc lúc khởi động → phải nói rõ cần mở lại app.
      expect(find.textContaining('Mở lại app'), findsOneWidget);
    });

    testWidgets('xoá khoá đã dán trả app về cấu hình của bản build',
        (tester) async {
      AiConfig.setOpenRouterApiKey('sk-or-v1-demo');
      StorageService.setSupabaseUrl('https://demo.supabase.co');

      await pumpCard(tester, const CloudAiCard());
      await tester.tap(find.byKey(const Key('cloud-ai-toggle')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('cloud-ai-clear')));
      await tester.pump();

      expect(AiConfig.hasStoredOpenRouter, isFalse);
      expect(StorageService.getSupabaseUrl(), isNot('https://demo.supabase.co'));
      expect(find.textContaining('xoá cấu hình bạn dán'), findsOneWidget);
    });
  });
}
