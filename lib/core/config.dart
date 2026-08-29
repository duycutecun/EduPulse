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
}
