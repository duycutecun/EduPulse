import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/ai/ai_config.dart';
import 'package:edupulse/core/config.dart';
import 'package:edupulse/core/utils/runtime_env.dart';
import 'package:edupulse/core/utils/secure_store.dart';
import 'package:edupulse/core/utils/storage_service.dart';

/// Bản cài từ `.ipa`/`.apk` không có `--dart-define` (chỉ web trên Vercel có),
/// nên AI từng báo "Chưa cấu hình OpenRouter API Key" mà người dùng không có
/// cách nào sửa. [AiConfig] mở đường dán khoá tại chỗ — khoá người dùng luôn
/// thắng khoá đóng gói trong bản build. Khoá dán được lưu trong kho an toàn
/// (mục 8, dòng 211), không để lại plaintext.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Kho an toàn giả lập trong bộ nhớ để test được luồng ghi/đọc/đọc lẫn.
    FlutterSecureStorage.setMockInitialValues({});
    await StorageService.init();
    AiConfig.resetForTesting();
  });

  group('AiConfig — khoá dán trong app thắng khoá của bản build', () {
    test('chưa dán gì thì dùng đúng giá trị build-time', () {
      expect(AiConfig.openRouterApiKey, AppConfig.openRouterApiKey);
      expect(AiConfig.geminiApiKey, AppConfig.geminiApiKey);
      expect(AiConfig.tavilyApiKey, AppConfig.tavilyApiKey);
      expect(AiConfig.hasStoredOpenRouter, isFalse);
    });

    test('dán key thì có hiệu lực ngay, không cần build lại', () {
      AiConfig.setOpenRouterApiKey('  sk-or-v1-test  ');

      expect(AiConfig.openRouterApiKey, 'sk-or-v1-test');
      expect(AiConfig.hasOpenRouter, isTrue);
      expect(AiConfig.hasStoredOpenRouter, isTrue);
      expect(AiConfig.storedOpenRouterKey, 'sk-or-v1-test');
    });

    test('xoá key (chuỗi rỗng) thì quay về giá trị của bản build', () {
      AiConfig.setOpenRouterApiKey('sk-or-v1-test');
      AiConfig.setOpenRouterApiKey('   ');

      expect(AiConfig.openRouterApiKey, AppConfig.openRouterApiKey);
      expect(AiConfig.hasStoredOpenRouter, isFalse);
    });

    test('ba khoá độc lập, không ghi đè lẫn nhau', () {
      AiConfig.setOpenRouterApiKey('or-key');
      AiConfig.setGeminiApiKey('gem-key');
      AiConfig.setTavilyApiKey('tav-key');

      expect(AiConfig.openRouterApiKey, 'or-key');
      expect(AiConfig.geminiApiKey, 'gem-key');
      expect(AiConfig.tavilyApiKey, 'tav-key');
    });
  });

  group('Không còn chỗ nào đọc thẳng AppConfig cho AI', () {
    test('các service AI phải đi qua AiConfig', () {
      const files = [
        'lib/core/ai/openrouter_service.dart',
        'lib/core/ai/ai_router.dart',
        'lib/core/ai/ai_daily_briefing.dart',
        'lib/core/ai/ai_insights.dart',
        'lib/core/ai/ai_refresh_service.dart',
      ];

      for (final path in files) {
        final source = File(path).readAsStringSync();
        expect(source.contains('AppConfig.openRouterApiKey'), isFalse,
            reason: '$path đọc thẳng AppConfig — bản cài sẽ mất AI '
                'vì không có --dart-define');
        expect(source.contains('AppConfig.geminiApiKey'), isFalse,
            reason: '$path đọc thẳng AppConfig.geminiApiKey');
      }
    });
  });

  group('AI managed đi qua backend — khoá không nhúng vào bundle', () {
    test('managed khả dụng khi có backend cấu hình (native/SDK thật)', () {
      // Native release: apiBaseUrl có mặc định, KHÔNG phải môi trường test.
      expect(
        AiConfig.managedAiAvailable(
            isWeb: false, apiBaseConfigured: true, isTest: false),
        isTrue,
      );
    });

    test('web luôn managed kể cả khi chạy test trên web', () {
      expect(
        AiConfig.managedAiAvailable(
            isWeb: true, apiBaseConfigured: false, isTest: true),
        isTrue,
      );
    });

    test('test VM tắt managed để không gọi mạng', () {
      expect(
        AiConfig.managedAiAvailable(
            isWeb: false, apiBaseConfigured: true, isTest: true),
        isFalse,
      );
    });

    test('không có backend (bản build rỗng) → không managed', () {
      expect(
        AiConfig.managedAiAvailable(
            isWeb: false, apiBaseConfigured: false, isTest: false),
        isFalse,
      );
    });

    test('trong flutter test, managed tự tắt (an toàn mặc định)', () {
      expect(RuntimeEnv.isFlutterTest, isTrue);
      expect(AiConfig.hasManagedAi, isFalse);
    });
  });

  group('BYOK lưu trong kho an toàn (mục 8, dòng 211)', () {
    test('di trú khoá cũ dạng plaintext sang kho an toàn rồi xoá plaintext',
        () async {
      StorageService.setString(AiConfig.openRouterKeyPref, 'legacy-key');
      AiConfig.resetForTesting();

      await AiConfig.loadSecure();

      expect(AiConfig.storedOpenRouterKey, 'legacy-key');
      expect(await SecureStore.read(AiConfig.openRouterKeyPref), 'legacy-key');
      expect(StorageService.getString(AiConfig.openRouterKeyPref), isNull,
          reason: 'Không được để lại khoá dạng rõ trong SharedPreferences');
    });

    test('dán khoá thì ghi vào kho an toàn, không ghi plaintext', () async {
      AiConfig.setOpenRouterApiKey('sk-or-secure');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(
          await SecureStore.read(AiConfig.openRouterKeyPref), 'sk-or-secure');
      expect(StorageService.getString(AiConfig.openRouterKeyPref), isNull);
      expect(AiConfig.openRouterApiKey, 'sk-or-secure');
    });

    test('xoá khoá (chuỗi rỗng) xoá luôn khỏi kho an toàn', () async {
      AiConfig.setOpenRouterApiKey('sk-or-secure');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      AiConfig.setOpenRouterApiKey('   ');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(await SecureStore.read(AiConfig.openRouterKeyPref), isNull);
      expect(AiConfig.hasStoredOpenRouter, isFalse);
      expect(AiConfig.openRouterApiKey, AppConfig.openRouterApiKey);
    });

    test('loadSecure ưu tiên bản trong kho an toàn hơn bản plaintext cũ',
        () async {
      await SecureStore.write(AiConfig.geminiKeyPref, 'secure-gem');
      StorageService.setString(AiConfig.geminiKeyPref, 'plain-gem');
      AiConfig.resetForTesting();

      await AiConfig.loadSecure();

      expect(AiConfig.storedGeminiKey, 'secure-gem');
      expect(StorageService.getString(AiConfig.geminiKeyPref), isNull);
    });
  });
}
