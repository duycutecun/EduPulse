import 'package:flutter/foundation.dart' show kIsWeb;

/// Ứng dụng config mặc định cho EduPulse.
///
/// Các giá trị ở đây được dùng làm mặc định khi người dùng chưa nhập thông
/// tin riêng trong Cài đặt. Giá trị người dùng lưu cục bộ luôn được ưu tiên
/// hơn các hằng số mặc định bên dưới.
///
/// Các bí mật (Supabase, AI keys) KHÔNG hardcode trong repo. Chúng được truyền
/// lúc build qua `--dart-define=...` (Vercel đọc từ biến môi trường, xem
/// `build.sh` và `vercel.json`); nếu để trống, app sẽ dùng config do người dùng
/// nhập trong Cài đặt.
class AppConfig {
  AppConfig._();

  // Supabase — URL + Public anon key, truyền lúc build qua
  // `--dart-define=SUPABASE_URL=...` và `--dart-define=SUPABASE_ANON_KEY=...`.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // AI Coach — OpenRouter API key (chủ app nhúng; user không cần nhập).
  // OpenRouter cấp quyền truy cập nhiều model (kể cả free `:free`) qua một key
  // duy nhất, và tự động failover giữa các provider khi một nguồn hết quota.
  //
  // Key KHÔNG được hardcode trong repo công khai. Nó được truyền vào lúc build
  // qua `--dart-define=OPENROUTER_API_KEY=...` (Vercel đọc từ biến môi trường
  // `OPENROUTER_API_KEY`). Xem vercel.json.
  static const String openRouterApiKey = String.fromEnvironment(
    'OPENROUTER_API_KEY',
    defaultValue: '',
  );

  // Gemini trực tiếp — key do chủ app cấu hình (liên hệ aistudio.google.com).
  // Dùng làm key dùng chung cho toàn app, truyền lúc build qua
  // `--dart-define=GEMINI_API_KEY=...` (Vercel đọc từ biến môi trường tương ứng).
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  // Tavily Search API — tra cứu web thời gian thực cho AI Coach (mọi model).
  // Key do chủ app cấp (tavily.com), truyền lúc build qua
  // `--dart-define=TAVILY_API_KEY=...` (Vercel đọc từ biến môi trường tương ứng).
  static const String tavilyApiKey = String.fromEnvironment(
    'TAVILY_API_KEY',
    defaultValue: '',
  );

  // Firebase Auth — web app config (các giá trị này vốn "công khai" ở phía
  // client của Firebase, không phải bí mật). Truyền lúc build qua
  // `--dart-define=FIREBASE_*` (Vercel đọc từ biến môi trường `Firebase*`),
  // giống Supabase bên trên.
  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );
  static const String firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: '',
  );
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: '',
  );
  static const String firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: '',
  );
  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '',
  );
  static const String firebaseAppId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '',
  );

  // Firebase Auth iOS — app ID dành riêng cho nền tảng iOS (định dạng
  // `1:<projectNo>:ios:<hex>`), tạo bằng cách thêm app iOS trong Firebase
  // console với bundle id `com.edu.edupulse`. Truyền lúc build iOS qua
  // `--dart-define=FIREBASE_IOS_APP_ID=...` (xem .github/workflows/ios-ipa.yml).
  // Nếu trống, app dùng `FIREBASE_APP_ID` (web `:web:`) và AuthService sẽ BỎ
  // QUA đăng nhập Firebase trên iOS (không crash) vì app ID web không hợp lệ
  // cho iOS.
  static const String firebaseIosAppId = String.fromEnvironment(
    'FIREBASE_IOS_APP_ID',
    defaultValue: '',
  );

  // Máy chủ API serverless (`.js` hàm Vercel: `/api/family`, `/api/backup`, ...).
  // - Web: đi cùng origin trang đang mở (bỏ qua CORS) nên dùng `Uri.base`.
  // - App mobile KHÔNG có "origin" đi cùng: `Uri.base` là URI file:// của app
  //   (resolve('/api/...') → `file:///api/...` → mạng vỡ). Phải cố định về bản
  //   deploy production; ghi đè được bằng `--dart-define=API_BASE_URL=...`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://edu-pulse-five-gamma.vercel.app',
  );

  /// Gốc để `resolve('/api/...')` — đúng on web, đúng on native.
  static Uri apiBase() => kIsWeb ? Uri.base : Uri.parse(apiBaseUrl);
}
