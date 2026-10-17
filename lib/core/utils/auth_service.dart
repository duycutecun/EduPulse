import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'storage_service.dart';

/// AuthService — toàn bộ xác thực của EduPulse dựa trên Supabase Auth.
///
/// Trước đây xác thực do Firebase Auth phụ trách; giờ hợp nhất về Supabase
/// luôn (tài khoản = UUID Supabase dùng cho toàn bộ database/RLS, mọi API
/// serverless nhận `Bearer <access_token>` của Supabase). Email đăng ký được
/// xác minh bằng MÃ 8 CHỮ SỐ gửi qua SMTP (serverless API cùng origin /
/// `/api/send_verification` + `/api/verify_email`, server tự xác thực bằng
/// `auth.getUser(jwt)`); email-link kiểu Firebase đã được bỏ.
///
/// Cần thêm nếu triển khai Google OAuth trên native: dashboard Supabase cấu
/// hình Google provider + Redirect URLs, và iOS Info.plist khai báo URL
/// scheme `io.supabase.flutter` (xem docs/CHECK_SUPABASE.md).
class AuthService {
  AuthService._();

  static bool _initDone = false;
  static bool _initializing = false;

  /// GoTrueClient của Supabase (null khi chưa `Supabase.initialize`).
  ///
  /// Đọc LAZY mỗi lần gọi — main.dart khởi SupabaseService ngay trước
  /// AuthService.init, nhưng test/màn hình độc lập có thể gọi trước và ở đó
  /// Supabase chưa sẵn sàng: trả null (giống `isConfigured` false) thay vì
  /// crash, đúng hành vi "chưa cấu hình" cũ của AuthService.
  static GoTrueClient? get _auth {
    try {
      return Supabase.instance.client.auth;
    } catch (_) {
      return null;
    }
  }

  /// Hoàn tất khi [init] chạy xong lần đầu (dù thành công hay thất bại).
  ///
  /// UI ở chế độ phụ huynh cần biết "đã biết chắc chưa đăng nhập chưa" để
  /// không hiện lời mời đăng nhập với người vừa đăng nhập xong (main.dart khởi
  /// tạo AuthService SAU frame đầu cho app mở nhanh, nên frame đầu chưa có auth).
  static final Completer<void> _ready = Completer<void>();

  static Future<void> get whenReady => _ready.future;

  static void _markReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Đã có phiên bản Supabase client sẵn sàng dùng.
  static bool get isConfigured => _auth != null;

  static User? get currentUser => _auth?.currentUser;

  static bool get isLoggedIn => currentUser != null;

  /// Email đã xác minh khi: Supabase đánh dấu (`email_confirmed_at` — tài
  /// khoản OAuth như Google được xác minh sẵn), người dùng đã nhập đúng mã 8
  /// chữ số (đánh dấu local), hoặc provider không phải email/password.
  static bool get isEmailVerified {
    final user = currentUser;
    if (user?.emailConfirmedAt != null) return true;
    if (StorageService.getEmailVerified()) return true;
    final provider = user?.appMetadata['provider'];
    return user != null && provider is String && provider != 'email';
  }

  /// Id người dùng dùng cho tầng dữ liệu (Sync): UUID Supabase khi đã đăng
  /// nhập, fallback về UUID cục bộ khi chưa đăng nhập.
  static String get persistentUserId =>
      currentUser?.id ?? StorageService.getUserId();

  static Stream<User?>? get authStateChanges =>
      _auth?.onAuthStateChange.map((state) => state.session?.user);

  /// Access token Supabase hiện tại (null nếu chưa đăng nhập).
  ///
  /// Dùng để gọi các API serverless cần xác thực — `/api/openrouter`,
  /// `/api/gemini`, `/api/search`, `/api/backup` — server tự xác thực bằng
  /// `auth.getUser(jwt)`. Access token của Supabase ngắn hạn (auto refresh
  /// bởi client) nên không cache: nếu sắp hết hạn (< 60s) thì chủ động
  /// refresh trước khi trả về.
  static Future<String?> idToken() async {
    final auth = _auth;
    if (auth == null) return null;
    try {
      final session = auth.currentSession;
      if (session == null) return null;
      final expiresAt = session.expiresAt;
      final deadline = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60;
      if (expiresAt != null && expiresAt < deadline) {
        final refreshed = await auth.refreshSession();
        final fresh = refreshed.session ?? auth.currentSession;
        return fresh?.accessToken;
      }
      return session.accessToken;
    } catch (_) {
      return null;
    }
  }

  // ─── INITIALIZATION ───────────────────────────────────────────────────────

  /// Gắn vào Supabase client đã khởi tạo (bởi `SupabaseService.init`) và đợi
  /// phiên đầu tiên được khôi phục từ local storage/URL.
  ///
  /// KHÔNG init Firebase nữa — SupabaseUrl + anon key có sẵn trong app (dart
  /// -define hoặc người dùng nhập trong Cài đặt). Supabase tự restore phiên
  /// ngay lúc `Supabase.initialize`, nên câu hỏi "người dùng đã đăng nhập chưa"
  /// có thể trả lời ngay sau khi client sẵn sàng; ta vẫn đợi tối đa vài giây
  /// event đầu của `onAuthStateChange` (INITIAL_SESSION/SIGNED_IN) để chắc
  /// chắn trạng thái cuối cùng đã được đóng dấu.
  static Future<bool> init() async {
    if (_initDone) return isConfigured;
    if (_initializing) return false;
    _initializing = true;
    try {
      final auth = _auth;
      if (auth == null) return false;
      if (auth.currentSession == null) {
        // Đợi event đầu (thường đến tức thì vì restore là đồng bộ); timeout
        // phòng trường hợp stream chưa phát gì — vẫn coi là "xong".
        try {
          await auth.onAuthStateChange.first
              .timeout(const Duration(seconds: 3));
        } on TimeoutException {
          // Bỏ qua — client vẫn dùng được.
        }
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      _initDone = true;
      _initializing = false;
      // Đánh dấu ở ĐÂY (sau khi đã biết kết quả): báo "xong" khi client chưa
      // sẵn sẽ khiến UI tưởng người dùng chưa đăng nhập.
      _markReady();
    }
  }

  // ─── AUTH ─────────────────────────────────────────────────────────────────

  /// Đăng ký tài khoản mới (email + password). Email xác minh gửi sau bằng mã
  /// 8 chữ số qua [sendVerificationCode] (màn Xác minh).
  static Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    if (!isConfigured) {
      return AuthResult.error(
          'Chưa cấu hình Supabase. Vào Cài đặt để thiết lập.');
    }
    try {
      final res = await _auth!.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': name.trim()},
      );
      if (StorageService.getUserName() == 'Sĩ tử EduPulse') {
        StorageService.setUserName(name.trim());
      }
      // "Confirm email" bật trong Supabase hay KHÔNG đều chạy đúng: có session
      // ngay (auto confirm) → coi như đăng nhập xong; chưa có session → chờ
      // người dùng nhập mã xác minh.
      if (res.session != null && (res.user?.emailConfirmedAt != null)) {
        StorageService.setEmailVerified(true);
        return AuthResult.success(
            'Đăng ký thành công! Chào mừng đến EduPulse 👋');
      }
      return AuthResult.success(
          'Đăng ký thành công! Nhập mã xác minh gửi qua email để kích hoạt tài khoản 📧');
    } on AuthException catch (e) {
      return AuthResult.error(_mapAuthError(e));
    } catch (_) {
      return AuthResult.error('Lỗi kết nối. Kiểm tra mạng và thử lại.');
    }
  }

  /// Đăng nhập bằng email + mật khẩu.
  static Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    if (!isConfigured) {
      return AuthResult.error(
          'Chưa cấu hình Supabase. Vào Cài đặt để thiết lập.');
    }
    try {
      final res = await _auth!
          .signInWithPassword(email: email.trim(), password: password);
      final name = _displayNameFrom(res.user?.userMetadata);
      if (name != null && name.isNotEmpty) {
        StorageService.setUserName(name);
      }
      if (res.user?.emailConfirmedAt != null) {
        StorageService.setEmailVerified(true);
      }
      return AuthResult.success('Đăng nhập thành công! Chào mừng trở lại 👋');
    } on AuthException catch (e) {
      return AuthResult.error(_mapAuthError(e));
    } catch (_) {
      return AuthResult.error('Lỗi kết nối. Kiểm tra mạng và thử lại.');
    }
  }

  /// Đăng ký / đăng nhập bằng Google.
  ///
  /// - Web: mở giao diện Google (mặc định supabase_flutter dùng trang hiện
  ///   tại → quay lại cùng origin sau khi Google xác thực, phiên được khôi
  ///   phục từ URL).
  /// - Native: mở trình duyệt rồi quay về app bằng deep-link scheme
  ///   `io.supabase.flutter://...` (cần khai báo scheme trong Info.plist /
  ///   Android intent + Redirect URL trong dashboard Supabase).
  static Future<AuthResult> signInWithGoogle() async {
    if (!isConfigured) {
      return AuthResult.error(
          'Chưa cấu hình Supabase. Vào Cài đặt để thiết lập.');
    }
    try {
      // Native phải trả redirect_to về deep link `io.supabase.flutter://` để
      // quay lại app (supabase_flutter KHÔNG chèn scheme mặc định; trên web
      // để trống → server về Site URL cấu hình trong dashboard, cùng origin).
      await _auth!.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.flutter://login-callback',
      );
      if (currentUser == null) {
        // Web mở trang Google ngay tại đây (redirect away) hoặc native đã
        // mở trình duyệt — phiên chỉ có sau khi quay lại.
        if (kIsWeb) {
          return AuthResult.error(
              'Đăng nhập Google không thành công. Thử lại sau.');
        }
        return AuthResult.success(
            'Đã mở Google để xác thực. Hoàn tất đăng nhập trong trình duyệt 🌐');
      }
      final user = currentUser;
      if (user != null) {
        final name = _displayNameFrom(user.userMetadata);
        if (name != null && name.isNotEmpty) {
          StorageService.setUserName(name);
        }
        // Google đã xác minh email tại Google → coi như đã xác minh.
        StorageService.setEmailVerified(true);
        return AuthResult.success('Đăng nhập Google thành công! 🎉');
      }
      return AuthResult.error(
          'Đăng nhập Google không thành công. Thử lại sau.');
    } on AuthException catch (e) {
      return AuthResult.error(_mapAuthError(e));
    } catch (_) {
      return AuthResult.error('Không mở được Google. Thử lại sau.');
    }
  }

  /// Bước 1 quên mật khẩu: kiểm tra email đã đăng ký chưa + gửi mã 8 chữ số về
  /// email (không cần đăng nhập — người dùng đã quên mật khẩu nên không có ID
  /// token). Gọi serverless API cùng origin `/api/send_reset_code`.
  ///
  /// Trả về [AuthResult.code] == `EMAIL_NOT_FOUND` khi email chưa đăng ký để
  /// màn hình rẽ sang phần đăng ký.
  static Future<AuthResult> sendResetCode(String email) async {
    final clean = email.trim();
    if (clean.isEmpty || !clean.contains('@')) {
      return AuthResult.error('Email không hợp lệ.');
    }
    try {
      final body = await _postApi('/api/send_reset_code', {'email': clean});
      if (body['ok'] == true) {
        return AuthResult.success(
            'Đã gửi mã 8 chữ số! Kiểm tra hộp thư Email 📧');
      }
      return AuthResult.error(_apiError(body));
    } catch (_) {
      return AuthResult.error('Không gửi được mã. Kiểm tra mạng và thử lại.');
    }
  }

  /// Bước 2 quên mật khẩu: gửi mã + mật khẩu mới lên `/api/reset_password`.
  /// Mã đúng (purpose='reset') thì server đặt lại mật khẩu trực tiếp qua admin
  /// API của Supabase (service role) — KHÔNG còn email link/oobCode. Sau đó
  /// client tự đăng nhập lại bằng mật khẩu vừa đặt.
  static Future<AuthResult> resetPasswordByCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final clean = code.trim();
    if (clean.isEmpty || clean.length != 8) {
      return AuthResult.error('Mã đặt lại gồm 8 chữ số.');
    }
    if (newPassword.length < 6) {
      return AuthResult.error('Mật khẩu phải có ít nhất 6 ký tự.');
    }
    try {
      final body = await _postApi('/api/reset_password', {
        'email': email.trim(),
        'code': clean,
        'newPassword': newPassword,
      });
      if (body['ok'] == true) {
        // Đã chứng minh quyền sở hữu email qua mã reset → coi như xác minh.
        StorageService.setEmailVerified(true);
        final login = await signIn(email: email.trim(), password: newPassword);
        if (login.success) {
          return AuthResult.success(
              'Mật khẩu đã được đặt lại và bạn đã được đăng nhập lại ✅');
        }
        return AuthResult.success(
            'Mật khẩu đã được đặt lại! Hãy đăng nhập bằng mật khẩu mới 🔑');
      }
      if (body['error'] == 'EMAIL_NOT_FOUND') {
        return AuthResult.error('Email này chưa đăng ký EduPulse.',
            code: 'EMAIL_NOT_FOUND');
      }
      return AuthResult.error(_apiError(body));
    } catch (_) {
      return AuthResult.error(
          'Xác nhận mã thất bại. Kiểm tra mạng và thử lại.');
    }
  }

  /// Gửi (hoặc gửi lại) email xác minh chứa mã 8 chữ số qua serverless API
  /// cùng origin `/api/send_verification` (server xác thực access token
  /// Supabase, gửi email qua SMTP).
  static Future<AuthResult> sendVerificationCode() async {
    if (!isConfigured || currentUser == null) {
      return AuthResult.error('Chưa có tài khoản để gửi mã xác minh.');
    }
    try {
      final token = await idToken();
      if (token == null) {
        return AuthResult.error('Phiên đăng nhập đã hết. Đăng nhập lại nhé.');
      }
      final body = await _postApi('/api/send_verification', {'idToken': token});
      if (body['ok'] == true) {
        return AuthResult.success(
            'Đã gửi mã xác minh 8 chữ số! Kiểm tra hộp thư 📧');
      }
      return AuthResult.error(_apiError(body));
    } catch (_) {
      return AuthResult.error('Không gửi được mã. Kiểm tra mạng và thử lại.');
    }
  }

  /// Gửi mã lên server xác nhận (`/api/verify_email`). Nếu đúng, server đánh
  /// dấu verified trong user_profiles (và Supabase xác minh email); app nhớ cờ
  /// local để dùng được cả trong offline.
  static Future<AuthResult> verifyEmailWithCode(String code) async {
    final user = currentUser;
    if (!isConfigured || user == null) {
      return AuthResult.error('Chưa có tài khoản để xác minh.');
    }
    final clean = code.trim();
    if (clean.isEmpty || clean.length != 8) {
      return AuthResult.error('Mã xác minh gồm 8 chữ số.');
    }
    try {
      final token = await idToken();
      if (token == null) {
        return AuthResult.error('Phiên đăng nhập đã hết. Đăng nhập lại nhé.');
      }
      final body = await _postApi(
          '/api/verify_email', {'idToken': token, 'code': clean});
      if (body['ok'] == true) {
        StorageService.setEmailVerified(true);
        return AuthResult.success(
            'Xác minh email thành công! Chào mừng bạn 🎉');
      }
      return AuthResult.error(_apiError(body));
    } catch (_) {
      return AuthResult.error(
          'Xác minh không thành công. Kiểm tra mạng và thử lại.');
    }
  }

  /// Gọi POST endpoint serverless cùng origin (web) và parse JSON response.
  static Future<Map<String, dynamic>> _postApi(
      String path, Map<String, dynamic> payload) async {
    final base = Uri.base.resolve(path);
    final resp = await http
        .post(
          base,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));
    final data = jsonDecode(resp.body);
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  static String _apiError(Map<String, dynamic> body) {
    final err = body['error'];
    if (err is String && err.isNotEmpty) return err;
    return 'Có lỗi xảy ra. Thử lại sau.';
  }

  /// Đọc tên hiển thị từ user_metadata của Supabase (đặt lúc đăng ký via
  /// `data: {'display_name': ...}`, hoặc do Google cung cấp).
  static String? _displayNameFrom(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    for (final key in ['display_name', 'full_name', 'name']) {
      final v = metadata[key];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  /// Đăng xuất.
  static Future<void> signOut() async {
    try {
      await _auth?.signOut();
    } catch (_) {}
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  /// Map lỗi AuthException của Supabase tiếng Việt, tương đương bảng lỗi cũ
  /// của Firebase để các màn hình Auth không phải đổi câu chữ.
  static String _mapAuthError(AuthException e) {
    switch (e.code) {
      case 'email_address_invalid' || 'validation_failed':
        return 'Email không hợp lệ. Kiểm tra lại!';
      case 'invalid_credentials' ||
            'user_not_found' ||
            'user_banned' ||
            'id_token_grant_invalid':
        return 'Email hoặc mật khẩu không đúng. Thử lại!';
      case 'email_not_confirmed':
        return 'Email chưa được xác minh. Nhập mã xác minh đã gửi qua email!';
      case 'user_already_exists' || 'email_exists':
        return 'Email này đã được đăng ký. Chọn "Đăng nhập".';
      case 'signup_disabled':
        return 'Đăng ký tạm thời bị tắt. Liên hệ quản trị app.';
      case 'weak_password':
        return 'Mật khẩu phải có ít nhất 6 ký tự.';
      case 'provider_disabled':
        return 'Phương thức đăng nhập này chưa được bật.';
      case 'over_email_send_rate_limit' ||
            'over_request_rate_limit' ||
            'over_sms_send_rate_limit':
        return 'Quá nhiều lần thử. Vui lòng đợi một lúc rồi thử lại.';
      case 'bad_jwt' || 'session_expired' || 'refresh_token_not_found':
        return 'Phiên đăng nhập đã hết hạn. Đăng nhập lại nhé.';
      case 'network_request_failed':
        return 'Lỗi kết nối mạng. Kiểm tra internet và thử lại.';
      default:
        if (e.message.isNotEmpty) return 'Lỗi: ${e.message}';
        return 'Có lỗi xảy ra. Thử lại sau.';
    }
  }
}

/// Kết quả trả về của các thao tác Auth — giữ nguyên kiểu cũ để các màn hình
/// Auth không phải sửa cấu trúc.
class AuthResult {
  final bool success;
  final String message;

  /// Mã lỗi có chủ đích (vd `EMAIL_NOT_FOUND`) để app rẽ nhánh logic.
  final String? code;

  const AuthResult._({
    required this.success,
    required this.message,
    this.code,
  });

  factory AuthResult.success(String message) =>
      AuthResult._(success: true, message: message);

  factory AuthResult.error(String message, {String? code}) =>
      AuthResult._(success: false, message: message, code: code);
}
