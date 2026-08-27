/// Ứng dụng config mặc định cho EduPulse.
///
/// Các giá trị ở đây được dùng làm mặc định khi người dùng chưa nhập thông
/// tin riêng trong Cài đặt. Giá trị người dùng lưu cục bộ luôn được ưu tiên
/// hơn các hằng số mặc định bên dưới.
///
/// ⚠️ ĐIỀN GIÁ TRỊ THẬT CỦA BẠN VÀO ĐÂY:
///   - `supabaseUrl`:  URL project từ Supabase Dashboard → Project Settings.
///   - `supabaseAnonKey`: Public anon key (không phải service_role key).
class AppConfig {
  AppConfig._();

  // Supabase
  static const String supabaseUrl = 'https://nygkogzdemplbfydhspd.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im55Z2tvZ3pkZW1wbGJmeWRoc3BkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc3NTMxMjEsImV4cCI6MjEwMzMyOTEyMX0.ta2-6xtXtz_Ix3m5J1YpMtMKVevg194l4f5_slvTOec';

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
}
