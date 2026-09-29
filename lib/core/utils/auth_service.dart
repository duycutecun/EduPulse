import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import 'storage_service.dart';

/// AuthService — toàn bộ xác thực của EduPulse dựa trên Firebase Auth.
///
/// Firebase được chọn vì "Đăng nhập bằng Google" chạy ngay cho mọi người dùng
/// mà KHÔNG cần tự xác minh domain / publish OAuth client như khi tự tạo
/// Google OAuth bên Supabase. Email đăng ký được xác minh bằng MÃ 8 CHỮ SỐ
/// gửi qua SMTP (serverless API cùng origin); Firebase xác minh email kiểu
/// link mặc định được bỏ qua. Supabase giờ chỉ còn đảm nhận phần dữ liệu
/// (database, bảng xếp hạng, sao lưu/khôi phục).
class AuthService {
  AuthService._();

  static FirebaseAuth? _auth;
  static bool _initializing = false;

  /// Đã có config Firebase hợp lệ và sẵn sàng dùng.
  static bool get isConfigured => _auth != null;

  static User? get currentUser => _auth?.currentUser;

  static bool get isLoggedIn => currentUser != null;

  /// Email đã xác minh khi: Firebase tự đánh dấu (vd tài khoản Google / bấm
  /// link), hoặc người dùng đã nhập đúng mã 8 chữ số (đánh dấu local), hoặc
  /// đăng nhập bằng Google.
  static bool get isEmailVerified {
    if (currentUser?.emailVerified == true) return true;
    if (StorageService.getEmailVerified()) return true;
    final providerIds =
        currentUser?.providerData.map((p) => p.providerId).toList() ?? [];
    return providerIds.contains('google.com');
  }

  /// Id người dùng dùng cho tầng dữ liệu (Sync): Firebase UID khi đã đăng
  /// nhập, fallback về UUID cục bộ khi chưa đăng nhập.
  static String get persistentUserId =>
      currentUser?.uid ?? StorageService.getUserId();

  static Stream<User?>? get authStateChanges => _auth?.authStateChanges();

  // ─── INITIALIZATION ───────────────────────────────────────────────────────

  static Future<bool> init() async {
    if (_auth != null) return true;
    if (_initializing) return false;
    _initializing = true;
    try {
      if (AppConfig.firebaseApiKey.isEmpty ||
          AppConfig.firebaseProjectId.isEmpty) {
        return false;
      }
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: AppConfig.firebaseApiKey,
          appId: AppConfig.firebaseAppId,
          messagingSenderId: AppConfig.firebaseMessagingSenderId,
          projectId: AppConfig.firebaseProjectId,
          storageBucket: AppConfig.firebaseStorageBucket.isEmpty
              ? null
              : AppConfig.firebaseStorageBucket,
          authDomain: AppConfig.firebaseAuthDomain.isEmpty
              ? null
              : AppConfig.firebaseAuthDomain,
        ),
      );
      _auth = FirebaseAuth.instance;
      return true;
    } catch (_) {
      return false;
    } finally {
      _initializing = false;
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
      return AuthResult.error('Chưa cấu hình Firebase. Vào Cài đặt để thiết lập.');
    }
    try {
      final res = await _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (name.trim().isNotEmpty) {
        await res.user?.updateDisplayName(name.trim());
      }
      if (StorageService.getUserName() == 'Sĩ tử EduPulse') {
        StorageService.setUserName(name.trim());
      }
      return AuthResult.success(
        'Đăng ký thành công! Nhập mã xác minh gửi qua email để kích hoạt tài khoản 📧',
      );
    } on FirebaseAuthException catch (e) {
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
      return AuthResult.error('Chưa cấu hình Firebase. Vào Cài đặt để thiết lập.');
    }
    try {
      final res = await _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final name = res.user?.displayName;
      if (name != null && name.isNotEmpty) {
        StorageService.setUserName(name);
      }
      return AuthResult.success('Đăng nhập thành công! Chào mừng trở lại 👋');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_mapAuthError(e));
    } catch (_) {
      return AuthResult.error('Lỗi kết nối. Kiểm tra mạng và thử lại.');
    }
  }

  /// Đăng ký / đăng nhập bằng Google. Trên web mở popup Google (không cần
  /// xác minh domain), trên native mở cửa sổ trình duyệt rồi quay về.
  static Future<AuthResult> signInWithGoogle() async {
    if (!isConfigured) {
      return AuthResult.error('Chưa cấu hình Firebase. Vào Cài đặt để thiết lập.');
    }
    try {
      User? user;
      if (kIsWeb) {
        final cred = await _auth!.signInWithPopup(GoogleAuthProvider());
        user = cred.user;
      } else {
        await _auth!.signInWithProvider(GoogleAuthProvider());
        user = _auth!.currentUser;
      }
      if (user != null) {
        final name = user.displayName;
        if (name != null && name.isNotEmpty) {
          StorageService.setUserName(name);
        }
        return AuthResult.success('Đăng nhập Google thành công! 🎉');
      }
      return AuthResult.error('Đăng nhập Google không thành công. Thử lại sau.');
    } on FirebaseAuthException catch (e) {
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

  /// Bước 2 quên mật khẩu: gửi mã lên `/api/reset_password`. Mã đúng thì server
  /// kích hoạt email đặt lại mật khẩu của Firebase (người dùng bấm link để đặt
  /// mật khẩu mới) — không cần service account Firebase.
  static Future<AuthResult> resetPasswordByCode({
    required String email,
    required String code,
  }) async {
    final clean = code.trim();
    if (clean.isEmpty || clean.length != 8) {
      return AuthResult.error('Mã đặt lại gồm 8 chữ số.');
    }
    try {
      final body = await _postApi('/api/reset_password', {
        'email': email.trim(),
        'code': clean,
      });
      if (body['ok'] == true) {
        return AuthResult.success(
            'Mã chính xác! Email đặt lại mật khẩu đã gửi — bấm link trong email để đặt mật khẩu mới 🔗');
      }
      if (body['error'] == 'EMAIL_NOT_FOUND') {
        return AuthResult.error('Email này chưa đăng ký EduPulse.',
            code: 'EMAIL_NOT_FOUND');
      }
      return AuthResult.error(_apiError(body));
    } catch (_) {
      return AuthResult.error('Xác nhận mã thất bại. Kiểm tra mạng và thử lại.');
    }
  }

  /// Gửi (hoặc gửi lại) email xác minh chứa mã 8 chữ số qua serverless API
  /// cùng origin `/api/send_verification` (server xác thực token bằng Firebase
  /// REST, gửi email qua SMTP). Không cần service account Firebase.
  static Future<AuthResult> sendVerificationCode() async {
    final user = _auth?.currentUser;
    if (!isConfigured || user == null) {
      return AuthResult.error('Chưa có tài khoản để gửi mã xác minh.');
    }
    try {
      final token = await user.getIdToken();
      final body = await _postApi('/api/send_verification', {'idToken': token});
      if (body['ok'] == true) {
        return AuthResult.success(
            'Đã gửi mã xác minh 8 chữ số! Kiểm tra hộp thư 📧');
      }
      return AuthResult.error(_apiError(body));
    } catch (e) {
      return AuthResult.error('Không gửi được mã. Kiểm tra mạng và thử lại.');
    }
  }

  /// Gửi mã lên server xác nhận (`/api/verify_email`). Nếu đúng, server đánh
  /// dấu verified trong user_profiles; app nhớ cờ local rồi reload từ Firebase.
  static Future<AuthResult> verifyEmailWithCode(String code) async {
    final user = _auth?.currentUser;
    if (!isConfigured || user == null) {
      return AuthResult.error('Chưa có tài khoản để xác minh.');
    }
    final clean = code.trim();
    if (clean.isEmpty || clean.length != 8) {
      return AuthResult.error('Mã xác minh gồm 8 chữ số.');
    }
    try {
      final token = await user.getIdToken();
      final body =
          await _postApi('/api/verify_email', {'idToken': token, 'code': clean});
      if (body['ok'] == true) {
        StorageService.setEmailVerified(true);
        try {
          await user.reload();
        } catch (_) {}
        return AuthResult.success('Xác minh email thành công! Chào mừng bạn 🎉');
      }
      return AuthResult.error(_apiError(body));
    } catch (e) {
      return AuthResult.error('Xác minh không thành công. Kiểm tra mạng và thử lại.');
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

  /// Đăng xuất.
  static Future<void> signOut() async {
    try {
      await _auth?.signOut();
    } catch (_) {}
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  static String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email không hợp lệ. Kiểm tra lại!';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Email hoặc mật khẩu không đúng. Thử lại!';
      case 'email-already-in-use':
        return 'Email này đã được đăng ký. Chọn "Đăng nhập".';
      case 'weak-password':
        return 'Mật khẩu phải có ít nhất 6 ký tự.';
      case 'operation-not-allowed':
        return 'Phương thức đăng nhập này chưa được bật.';
      case 'too-many-requests':
        return 'Quá nhiều lần thử. Vui lòng đợi một lúc rồi thử lại.';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng. Kiểm tra internet và thử lại.';
      case 'popup-closed-by-user':
        return 'Bạn đã đóng cửa sổ Google. Thử lại khi sẵn sàng.';
      case 'account-exists-with-different-credential':
        return 'Tài khoản này đã liên kết với email/mật khẩu. Hãy đăng nhập bằng cách khác.';
      default:
        final msg = e.message;
        if (msg != null && msg.isNotEmpty) return 'Lỗi: $msg';
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