import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

import '../config.dart';
import '../utils/runtime_env.dart';
import '../utils/secure_store.dart';
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
///
/// **Lưu an toàn (đặc tả mục 8, dòng 211):** khoá người dùng dán được lưu
/// trong Keychain/Keystore qua [SecureStore], KHÔNG nằm dạng plaintext trong
/// SharedPreferences. Getter vẫn đồng bộ nhờ cache trong bộ nhớ, được nạp một
/// lần bởi [loadSecure] lúc khởi động.
class AiConfig {
  AiConfig._();

  static const String openRouterKeyPref = 'ai_openrouter_key';
  static const String geminiKeyPref = 'ai_gemini_key';
  static const String tavilyKeyPref = 'ai_tavily_key';

  static const List<String> _byokKeys = [
    openRouterKeyPref,
    geminiKeyPref,
    tavilyKeyPref,
  ];

  /// Cache khoá đã nạp từ kho an toàn để getter chạy đồng bộ.
  static final Map<String, String> _secureCache = {};

  /// Tập key đã có giá trị "chốt" trong cache (kể cả rỗng = người dùng đã xoá),
  /// giúp [storedOpenRouterKey] không đọc nhầm bản plaintext còn sót.
  static final Set<String> _secureLoaded = {};

  /// Nạp khoá BYOK từ kho an toàn vào cache và **di trú** khoá cũ từng lưu dạng
  /// plaintext trong SharedPreferences (bản ≤ 2.0). Gọi một lần trong `main()`
  /// ngay sau `StorageService.init()`.
  static Future<void> loadSecure() async {
    for (final key in _byokKeys) {
      final secure = await SecureStore.read(key);
      if (secure != null && secure.trim().isNotEmpty) {
        _secureCache[key] = secure.trim();
        _secureLoaded.add(key);
      } else {
        final legacy = (StorageService.getString(key) ?? '').trim();
        if (legacy.isNotEmpty) {
          _secureCache[key] = legacy;
          _secureLoaded.add(key);
          await SecureStore.write(key, legacy);
        }
      }
      // Không để lại khoá dạng rõ trong SharedPreferences.
      StorageService.removeString(key);
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _secureCache.clear();
    _secureLoaded.clear();
  }

  /// OpenRouter — model chat/AI Coach. Rỗng = tính năng AI tạm tắt.
  static String get openRouterApiKey =>
      _pick(_stored(openRouterKeyPref), AppConfig.openRouterApiKey);

  /// Gemini — model dự phòng/đa phương thức.
  static String get geminiApiKey =>
      _pick(_stored(geminiKeyPref), AppConfig.geminiApiKey);

  /// Tavily — tra cứu web cho AI Coach (tùy chọn).
  static String get tavilyApiKey =>
      _pick(_stored(tavilyKeyPref), AppConfig.tavilyApiKey);

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

  static bool get hasStoredOpenRouter => _stored(openRouterKeyPref).isNotEmpty;

  static void setOpenRouterApiKey(String value) =>
      _set(openRouterKeyPref, value);

  static void setGeminiApiKey(String value) => _set(geminiKeyPref, value);

  static void setTavilyApiKey(String value) => _set(tavilyKeyPref, value);

  /// Giá trị người dùng đã dán (rỗng nếu chưa dán) — để UI hiện lại trong ô
  /// nhập mà không lộ key đóng gói trong bản build.
  static String get storedOpenRouterKey => _stored(openRouterKeyPref);

  static String get storedGeminiKey => _stored(geminiKeyPref);

  static String get storedTavilyKey => _stored(tavilyKeyPref);

  static String _stored(String key) {
    if (_secureLoaded.contains(key)) return _secureCache[key] ?? '';
    // Chưa gọi [loadSecure] (ví dụ trong test) — đọc tạm bản plaintext cũ.
    return StorageService.getString(key) ?? '';
  }

  static void _set(String key, String value) {
    final v = value.trim();
    _secureLoaded.add(key);
    _secureCache[key] = v;
    // Ghi kho an toàn ở hậu trường. Nền tảng không hỗ trợ (test/web thiếu
    // crypto) thì giữ trong SharedPreferences để không mất cấu hình.
    unawaited(SecureStore.write(key, v).then((ok) {
      if (ok) {
        StorageService.removeString(key);
      } else {
        StorageService.setString(key, v);
      }
    }));
  }

  static String _pick(String stored, String fallback) {
    final value = stored.trim();
    return value.isEmpty ? fallback : value;
  }
}
