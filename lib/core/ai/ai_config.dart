import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

import '../config.dart';
import '../utils/runtime_env.dart';
import '../utils/storage_service.dart';

/// Khoá AI **đang có hiệu lực**: ưu tiên bản người dùng dán trong app
/// (Tôi → Cloud & AI), nếu trống thì dùng bản đóng gói lúc build
/// (`--dart-define`, xem `build.sh` cho web và `.github/workflows/ios-ipa.yml`
/// cho bản iOS).
///
/// Vì sao cần lớp này: web trên Vercel luôn có sẵn biến môi trường, còn bản
/// cài từ `.ipa`/`.apk` chỉ có key nếu người build truyền `--dart-define`.
/// Thiếu key thì `OpenRouterService` từ chối ngay ("Chưa cấu hình OpenRouter
/// API Key") và người dùng **không có đường nào sửa** — bản cài coi như mất
/// toàn bộ tính năng AI. Cho phép dán key tại chỗ biến một bản cài sẵn thành
/// dùng được ngay, không cần build lại.
class AiConfig {
  AiConfig._();

  static const String openRouterKeyPref = 'ai_openrouter_key';
  static const String geminiKeyPref = 'ai_gemini_key';
  static const String tavilyKeyPref = 'ai_tavily_key';

  /// OpenRouter — model chat/AI Coach. Rỗng = tính năng AI tạm tắt.
  static String get openRouterApiKey => _pick(
      StorageService.getString(openRouterKeyPref), AppConfig.openRouterApiKey);

  /// Gemini — model dự phòng/đa phương thức.
  static String get geminiApiKey =>
      _pick(StorageService.getString(geminiKeyPref), AppConfig.geminiApiKey);

  /// Tavily — tra cứu web cho AI Coach (tùy chọn).
  static String get tavilyApiKey =>
      _pick(StorageService.getString(tavilyKeyPref), AppConfig.tavilyApiKey);

  static bool get hasOpenRouter => openRouterApiKey.isNotEmpty;

  static bool get hasGemini => geminiApiKey.isNotEmpty;

  /// Backend managed khả dụng? (hàm thuần để kiểm thử được mọi tổ hợp môi
  /// trường mà không phụ thuộc nền tảng đang chạy test).
  @visibleForTesting
  static bool managedAiAvailable({
    required bool isWeb,
    required bool apiBaseConfigured,
    required bool isTest,
  }) =>
      isWeb || (apiBaseConfigured && !isTest);

  /// AI managed đi qua backend serverless (`/api/openrouter`, `/api/gemini`,
  /// `/api/search`) — khoá chủ app giữ phía server, KHÔNG nhúng vào bundle.
  ///
  /// Trên web dùng cùng origin; trên native dùng bản deploy cố định trong
  /// [AppConfig.apiBaseUrl]. Vì `apiBaseUrl` có mặc định nên managed AI luôn
  /// khả dụng kể cả bản cài không kèm khoá nào. Trong `flutter test` thì tắt
  /// để test chạy thuần local, không gọi mạng.
  static bool get hasManagedAi => managedAiAvailable(
        isWeb: kIsWeb,
        apiBaseConfigured: AppConfig.apiBaseUrl.isNotEmpty,
        isTest: RuntimeEnv.isFlutterTest,
      );

  /// Có thể gọi AI? Managed qua backend luôn có, hoặc người dùng tự dán key
  /// (BYOK) để gọi thẳng nhà cung cấp.
  static bool get canUseAi => hasManagedAi || openRouterApiKey.isNotEmpty;

  /// Đã có key nào đó đóng gói lúc build chưa (để UI phân biệt "key của bản
  /// build" với "key người dùng tự dán").
  static bool get hasBuildTimeOpenRouter =>
      AppConfig.openRouterApiKey.isNotEmpty;

  static bool get hasStoredOpenRouter =>
      (StorageService.getString(openRouterKeyPref) ?? '').trim().isNotEmpty;

  static void setOpenRouterApiKey(String value) =>
      StorageService.setString(openRouterKeyPref, value.trim());

  static void setGeminiApiKey(String value) =>
      StorageService.setString(geminiKeyPref, value.trim());

  static void setTavilyApiKey(String value) =>
      StorageService.setString(tavilyKeyPref, value.trim());

  /// Giá trị người dùng đã dán (rỗng nếu chưa dán) — để UI hiện lại trong ô
  /// nhập mà không lộ key đóng gói trong bản build.
  static String get storedOpenRouterKey =>
      StorageService.getString(openRouterKeyPref) ?? '';

  static String get storedGeminiKey =>
      StorageService.getString(geminiKeyPref) ?? '';

  static String get storedTavilyKey =>
      StorageService.getString(tavilyKeyPref) ?? '';

  static String _pick(String? stored, String fallback) {
    final value = (stored ?? '').trim();
    return value.isEmpty ? fallback : value;
  }
}
