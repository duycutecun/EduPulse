import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/ai/ai_config.dart';
import 'package:edupulse/core/config.dart';
import 'package:edupulse/core/utils/storage_service.dart';

/// Bản cài từ `.ipa`/`.apk` không có `--dart-define` (chỉ web trên Vercel có),
/// nên AI từng báo "Chưa cấu hình OpenRouter API Key" mà người dùng không có
/// cách nào sửa. [AiConfig] mở đường dán khoá tại chỗ — khoá người dùng luôn
/// thắng khoá đóng gói trong bản build.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
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
}
