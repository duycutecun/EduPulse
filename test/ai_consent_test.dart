// Test cổng quyền riêng tư AI dùng chung (§8) — `AiConsent`.
//
// Vì sao quan trọng: mọi luồng AI đọc/phân tích dữ liệu học tập phải đi qua
// cổng này; nếu cổng hỏng, dữ liệu của học sinh bị gửi đi dù đã tắt quyền.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edupulse/core/ai/ai_consent.dart';
import 'package:edupulse/core/utils/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  test('mặc định: cho phép đọc + phân tích dữ liệu', () {
    expect(AiConsent.mayRead, isTrue);
    expect(AiConsent.mayAnalyze, isTrue);
    expect(AiConsent.canAnalyzeData, isTrue);
  });

  test('tắt một trong hai cờ là chặn toàn bộ phân tích dữ liệu', () async {
    StorageService.setBool('ai_permission_read', false);
    expect(AiConsent.canAnalyzeData, isFalse);

    StorageService.setBool('ai_permission_read', true);
    StorageService.setBool('ai_permission_analyze', false);
    expect(AiConsent.canAnalyzeData, isFalse);
  });

  testWidgets('ensure: đủ quyền → trả true, không hiện thông báo',
      (WidgetTester tester) async {
    var allowed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => allowed = AiConsent.ensure(context),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(allowed, isTrue);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('ensure: bị tắt quyền → trả false + SnackBar hướng dẫn bật lại',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'ai_permission_read': false});
    await StorageService.init();

    var allowed = true;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => allowed = AiConsent.ensure(context),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(allowed, isFalse);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Bật lại ở Tôi'), findsOneWidget);
  });
}
