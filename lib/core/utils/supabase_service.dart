import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/exams/domain/models/exam_model.dart';
import '../../features/study/domain/models/study_models.dart';
import 'storage_service.dart';

/// Chuyển đổi an toàn giá trị từ JSON (Supabase) sang số, thay cho `as num`
/// vốn có thể throw nếu DB trả kiểu lạ (vd String). Trả về [fallback] nếu
/// không parse được.
double _toDouble(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? fallback;

int _toInt(Object? v, [int fallback = 0]) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? fallback;

class SupabaseService {
  static SupabaseClient? _client;

  static bool get isConfigured => _client != null;

  static User? get currentUser => _client?.auth.currentUser;

  static bool get isLoggedIn => currentUser != null;

  static Stream<AuthState>? get authStateChanges =>
      _client?.auth.onAuthStateChange;

  // ─── INITIALIZATION ───────────────────────────────────────────────────────

  static Future<bool> init({String? customUrl, String? customKey}) async {
    final url = (customUrl ?? StorageService.getSupabaseUrl()).trim();
    final anonKey = (customKey ?? StorageService.getSupabaseAnonKey()).trim();

    if (url.isEmpty || anonKey.isEmpty) return false;

    try {
      await Supabase.initialize(url: url, publishableKey: anonKey);
      _client = Supabase.instance.client;
      return true;
    } catch (_) {
      try {
        _client = Supabase.instance.client;
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  // ─── AUTH ─────────────────────────────────────────────────────────────────

  /// Đăng ký tài khoản mới
  static Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    if (!isConfigured) return AuthResult.error('Chưa cấu hình Supabase. Vào Cài đặt → Supabase để thiết lập.');
    try {
      final res = await _client!.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim()},
      );
      if (res.user != null) {
        // Lưu tên vào local nếu chưa có
        if (StorageService.getUserName() == 'Sĩ tử EduPulse') {
          StorageService.setUserName(name.trim());
        }
        return AuthResult.success(
          res.session != null
              ? 'Đăng ký thành công! Chào mừng ${name.trim()} 🎉'
              : 'Đăng ký thành công! Kiểm tra email để xác minh tài khoản 📧',
        );
      }
      return AuthResult.error('Đăng ký không thành công. Thử lại sau.');
    } on AuthException catch (e) {
      return AuthResult.error(_mapAuthError(e.message));
    } catch (_) {
      return AuthResult.error('Lỗi kết nối. Kiểm tra mạng và thử lại.');
    }
  }

  /// Đăng nhập
  static Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    if (!isConfigured) return AuthResult.error('Chưa cấu hình Supabase. Vào Cài đặt → Supabase để thiết lập.');
    try {
      final res = await _client!.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (res.user != null) {
        // Đồng bộ tên từ metadata nếu có
        final metaName = res.user!.userMetadata?['name'] as String?;
        if (metaName != null && metaName.isNotEmpty) {
          StorageService.setUserName(metaName);
        }
        return AuthResult.success('Đăng nhập thành công! Chào mừng trở lại 👋');
      }
      return AuthResult.error('Đăng nhập thất bại. Thử lại sau.');
    } on AuthException catch (e) {
      return AuthResult.error(_mapAuthError(e.message));
    } catch (_) {
      return AuthResult.error('Lỗi kết nối. Kiểm tra mạng và thử lại.');
    }
  }

  /// Đặt lại mật khẩu qua email
  static Future<AuthResult> resetPassword(String email) async {
    if (!isConfigured) return AuthResult.error('Chưa cấu hình Supabase.');
    try {
      await _client!.auth.resetPasswordForEmail(email.trim());
      return AuthResult.success('Email đặt lại mật khẩu đã được gửi! Kiểm tra hộp thư 📧');
    } on AuthException catch (e) {
      return AuthResult.error(_mapAuthError(e.message));
    } catch (_) {
      return AuthResult.error('Không gửi được email. Thử lại sau.');
    }
  }

  /// Đăng xuất
  static Future<void> signOut() async {
    try {
      await _client?.auth.signOut();
    } catch (_) {}
  }

  static String _mapAuthError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('email already') || m.contains('user already')) {
      return 'Email này đã được đăng ký. Hãy đăng nhập hoặc dùng email khác.';
    }
    if (m.contains('invalid login') || m.contains('invalid credentials')) {
      return 'Email hoặc mật khẩu không đúng. Thử lại!';
    }
    if (m.contains('password') && m.contains('characters')) {
      return 'Mật khẩu phải có ít nhất 6 ký tự.';
    }
    if (m.contains('email not confirmed')) {
      return 'Email chưa được xác minh. Kiểm tra hộp thư!';
    }
    if (m.contains('rate limit')) {
      return 'Quá nhiều lần thử. Vui lòng đợi một lúc rồi thử lại.';
    }
    if (m.contains('network') || m.contains('connection')) {
      return 'Lỗi kết nối mạng. Kiểm tra internet và thử lại.';
    }
    return 'Lỗi: $msg';
  }

  // ─── DATA SYNC ────────────────────────────────────────────────────────────

  static String get _userId {
    // Ưu tiên dùng Supabase auth user id, fallback về local uuid
    return currentUser?.id ?? StorageService.getUserId();
  }

  static Future<bool> syncProfile() async {
    if (!isConfigured) return false;
    try {
      await _client!.from('user_profiles').upsert({
        'user_id': _userId,
        'name': StorageService.getUserName(),
        'target_school': StorageService.getUserTarget(),
        'streak': StorageService.getStreak(),
        'streak_record': StorageService.getStreakRecord(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> syncExams(List<ExamModel> exams, String? primaryId) async {
    if (!isConfigured) return false;
    try {
      for (final e in exams) {
        await _client!.from('exams').upsert({
          'id': '${_userId}_${e.id}',
          'user_id': _userId,
          'name': e.name,
          'date_time': e.dateTime.toIso8601String(),
          'emoji': e.emoji,
          'type': e.type.name,
          'description': e.description,
          'is_primary': e.id == primaryId,
        }, onConflict: 'id');
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> syncTasks(List<TodayTask> tasks) async {
    if (!isConfigured) return false;
    try {
      for (final t in tasks) {
        await _client!.from('today_tasks').upsert({
          'id': '${_userId}_${t.id}',
          'user_id': _userId,
          'title': t.title,
          'subject': t.subject,
          'priority': t.priority,
          'estimate_minutes': t.estimateMinutes,
          'is_done': t.isDone,
        }, onConflict: 'id');
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> syncStudyLogs(List<StudyLog> logs) async {
    if (!isConfigured) return false;
    try {
      for (final l in logs) {
        await _client!.from('study_logs').upsert({
          'id': '${_userId}_${l.id}',
          'user_id': _userId,
          'subject': l.subject,
          'hours': l.hours,
          'note': l.note,
          'logged_at': l.date.toIso8601String(),
        }, onConflict: 'id');
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<CommunityUser>?> fetchLeaderboard() async {
    if (!isConfigured) return null;
    try {
      final res = await _client!
          .from('leaderboard')
          .select()
          .order('streak', ascending: false)
          .limit(20);

      final List<CommunityUser> list = [];
      int rank = 1;
      for (final row in res) {
        list.add(CommunityUser(
          rank: rank++,
          name: row['name'] ?? '',
          target: row['target'] ?? '',
          streak: row['streak'] ?? 0,
          weeklyHours: _toDouble(row['weekly_hours']),
          emoji: row['emoji'] ?? '🦁',
          badge: row['badge'] ?? '🔥 Sĩ tử',
          cheers: row['cheers'] ?? 0,
        ));
      }
      return list;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> syncAll() async {
    if (!isConfigured) return false;
    try {
      await syncProfile();
      // Sync tasks
      final taskIds = StorageService.getTodayTaskIds();
      final tasks = taskIds.map((id) {
        final json = StorageService.getTodayTaskJson(id);
        if (json == null) return null;
        return TodayTask.fromJsonString(json);
      }).whereType<TodayTask>().toList();
      if (tasks.isNotEmpty) await syncTasks(tasks);

      // Sync study logs
      final logIds = StorageService.getStudyLogIds();
      final logs = logIds.map((id) {
        final json = StorageService.getStudyLogJson(id);
        if (json == null) return null;
        return StudyLog.fromJsonString(json);
      }).whereType<StudyLog>().toList();
      if (logs.isNotEmpty) await syncStudyLogs(logs);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Khôi phục toàn bộ dữ liệu từ Supabase Cloud về Local Storage
  static Future<bool> restoreAll() async {
    if (!isConfigured) return false;
    try {
      // 1. Restore Profile
      final profileRes = await _client!
          .from('user_profiles')
          .select()
          .eq('user_id', _userId)
          .maybeSingle();

      if (profileRes != null) {
        if (profileRes['name'] != null) {
          StorageService.setUserName(profileRes['name']);
        }
        if (profileRes['target_school'] != null) {
          StorageService.setUserTarget(profileRes['target_school']);
        }
        if (profileRes['streak'] != null) {
          StorageService.setStreak(_toInt(profileRes['streak']));
        }
        if (profileRes['streak_record'] != null) {
          StorageService.setStreakRecord(_toInt(profileRes['streak_record']));
        }
      }

      // 2. Restore Tasks
      final tasksRes = await _client!
          .from('today_tasks')
          .select()
          .eq('user_id', _userId);

      if (tasksRes.isNotEmpty) {
        final List<String> taskIds = [];
        for (final row in tasksRes) {
          final rawId = row['id'] as String;
          final id = rawId.startsWith('${_userId}_')
              ? rawId.replaceFirst('${_userId}_', '')
              : rawId;
          final task = TodayTask(
            id: id,
            title: row['title'] ?? '',
            subject: row['subject'] ?? '📐 Toán',
            priority: row['priority'] ?? 'medium',
            estimateMinutes: _toInt(row['estimate_minutes'], 45),
            isDone: row['is_done'] ?? false,
          );
          StorageService.setTodayTaskJson(task.id, task.toJsonString());
          taskIds.add(task.id);
        }
        StorageService.setTodayTaskIds(taskIds);
      }

      // 3. Restore Study Logs
      final logsRes = await _client!
          .from('study_logs')
          .select()
          .eq('user_id', _userId);

      if (logsRes.isNotEmpty) {
        final List<String> logIds = [];
        for (final row in logsRes) {
          final rawId = row['id'] as String;
          final id = rawId.startsWith('${_userId}_')
              ? rawId.replaceFirst('${_userId}_', '')
              : rawId;
          final log = StudyLog(
            id: id,
            subject: row['subject'] ?? '',
            hours: _toDouble(row['hours'], 1.0),
            date: DateTime.tryParse(row['logged_at'] ?? '') ?? DateTime.now(),
            note: row['note'] ?? '',
          );
          StorageService.setStudyLogJson(log.id, log.toJsonString());
          logIds.add(log.id);
        }
        StorageService.setStudyLogIds(logIds);
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Kết quả trả về của các thao tác Auth
class AuthResult {
  final bool success;
  final String message;

  const AuthResult._({required this.success, required this.message});

  factory AuthResult.success(String message) =>
      AuthResult._(success: true, message: message);

  factory AuthResult.error(String message) =>
      AuthResult._(success: false, message: message);
}
