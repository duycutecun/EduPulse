import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../features/exams/domain/models/exam_model.dart';
import '../../features/exams/domain/exam_repository.dart';
import '../../features/study/domain/models/study_models.dart';
import 'auth_service.dart';
import 'storage_service.dart';

/// Hai phiên bản của cùng một kỳ thi, cần người dùng tự chọn.
///
/// Thừa ra khi khôi phục: máy và cloud đều có kỳ thi này nhưng dữ liệu khác
/// nhau. Khôi phục KHÔNG tự lấy bản cloud đè lên bản máy — mất cả hai là mất
/// cả tuần làm việc.
class ExamConflict {
  const ExamConflict({required this.local, required this.cloud});

  /// Bản đang có trên máy.
  final ExamModel local;

  /// Bản trên cloud.
  final ExamModel cloud;
}

/// Chuyển đổi an toàn giá trị từ JSON (Supabase) sang số, thay cho `as num`
/// vốn có thể throw nếu DB trả kiểu lạ (vd String). Trả về [fallback] nếu
/// không parse được.
double _toDouble(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? fallback;

int _toInt(Object? v, [int fallback = 0]) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? fallback;

class SupabaseService {
  static SupabaseClient? _client;

  /// Báo khi quá trình khởi tạo cloud hoàn tất (dù thành công hay thất bại).
  /// Khởi tạo được defer sau frame đầu trong main.dart; các màn hình cần dữ
  /// liệu cloud (vd Bảng vàng) lắng nghe notifier này để tự refresh.
  static final ValueNotifier<bool> readyNotifier = ValueNotifier(false);

  static bool get isConfigured => _client != null;

  /// Như [isConfigured] nhưng đọc được cả phần ghi đè dành cho test — dùng cho
  /// UI phụ thuộc cấu hình cloud (ví dụ con số "N thay đổi chờ đồng bộ").
  ///
  /// Cố ý KHÔNG dùng cho các lệnh mạng: giả lập "đã cấu hình" trong khi client
  /// vẫn null thì mọi lời gọi Supabase sẽ nổ ngay trong test.
  static bool get cloudSyncEnabled => _configuredOverride ?? isConfigured;

  static bool? _configuredOverride;

  /// Ghi đè trạng thái "cloud đã cấu hình" cho test. Truyền `null` để bỏ.
  @visibleForTesting
  static void setConfiguredOverride(bool? value) => _configuredOverride = value;

  /// Client Supabase đã khởi tạo (null nếu chưa cấu hình).
  ///
  /// Cần cho phần Realtime của [BackupService] — mọi thứ khác vẫn nên đi qua
  /// các hàm của service này, đừng tự gọi client ở nơi khác.
  static SupabaseClient? get client => _client;

  /// Xác thực giờ do Firebase quản lý (AuthService) — trả user Firebase hiện tại.
  static User? get currentUser => AuthService.currentUser;

  static bool get isLoggedIn => AuthService.isLoggedIn;

  /// Đăng xuất — ủy quyền cho Firebase.
  static Future<void> signOut() => AuthService.signOut();

  // ─── INITIALIZATION ───────────────────────────────────────────────────────

  static Future<bool> init({String? customUrl, String? customKey}) async {
    try {
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
    } finally {
      readyNotifier.value = true;
    }
  }

  // ─── DATA SYNC ────────────────────────────────────────────────────────────

  static String get _userId {
    // Ưu tiên dùng Firebase auth user id, fallback về local uuid
    return AuthService.persistentUserId;
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

  /// Dựng một dòng bảng `exams` từ [ExamModel].
  ///
  /// Tách riêng khỏi [syncExams] để **kiểm thử được**: đây là nơi từng âm
  /// thầm bỏ sót `current_score` / `target_score` / `subject_targets`, làm
  /// người dùng mất mục tiêu điểm mỗi lần bấm đồng bộ. Mọi trường của
  /// ExamModel phải xuất hiện ở đây — thêm trường mới mà quên thêm vào hàm
  /// này là mất dữ liệu lần nữa.
  @visibleForTesting
  static Map<String, dynamic> examRow(ExamModel e, String? primaryId) => {
        'id': '${_userId}_${e.id}',
        'user_id': _userId,
        'name': e.name,
        'date_time': e.dateTime.toIso8601String(),
        'emoji': e.emoji,
        'type': e.type.name,
        'description': e.description,
        'is_primary': e.id == primaryId,
        'current_score': e.currentScore,
        'target_score': e.targetScore,
        // Map không gửi thẳng lên Supabase được → đóng thành chuỗi JSON.
        // Khoá là tên môn ĐÃ CHUẨN HOÁ, nên khi kéo về vẫn khớp.
        'subject_targets': jsonEncode(e.subjectTargets),
        'subjects': e.subjects,
        'updated_at': e.updatedAt?.toIso8601String(),
      };

  static Future<bool> syncExams(
      List<ExamModel> exams, String? primaryId) async {
    if (!isConfigured || exams.isEmpty) return true;
    try {
      final payload = exams.map((e) => examRow(e, primaryId)).toList();
      await _client!.from('exams').upsert(payload, onConflict: 'id');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Xoá hẳn kỳ thi trên cloud.
  ///
  /// Bắt buộc cho "xoá là xoá thật": `syncExams` chỉ upsert nên khoá bản ghi
  /// đã xoá ở máy, và lần khôi phục sau sẽ **mang nó quay lại**.
  ///
  /// Khoá `user_id` trong điều kiện xoá là bắt buộc: không có nó thì một id
  /// trùng ở tài khoản khác cũng bị xoá.
  static Future<bool> deleteExams(List<String> localIds) async {
    if (!isConfigured || localIds.isEmpty) return true;
    try {
      final remoteIds = localIds.map((id) => '${_userId}_$id').toList();
      await _client!
          .from('exams')
          .delete()
          .eq('user_id', _userId)
          .inFilter('id', remoteIds);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> syncTasks(List<TodayTask> tasks) async {
    if (!isConfigured || tasks.isEmpty) return true;
    try {
      final payload = tasks
          .map((t) => {
                'id': '${_userId}_${t.id}',
                'user_id': _userId,
                'title': t.title,
                'subject': t.subject,
                'priority': t.priority,
                'estimate_minutes': t.estimateMinutes,
                'is_done': t.isDone,
              })
          .toList();
      await _client!.from('today_tasks').upsert(payload, onConflict: 'id');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> syncStudyLogs(List<StudyLog> logs) async {
    if (!isConfigured || logs.isEmpty) return true;
    try {
      final payload = logs
          .map((l) => {
                'id': '${_userId}_${l.id}',
                'user_id': _userId,
                'subject': l.subject,
                'hours': l.hours,
                'note': l.note,
                'logged_at': l.date.toIso8601String(),
              })
          .toList();
      await _client!.from('study_logs').upsert(payload, onConflict: 'id');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> syncAll() async {
    if (!isConfigured) return false;
    try {
      // Chạy đồng bộ trong parallel để giảm total latency (4 RTT → 1 RTT).
      await Future.wait([
        syncProfile(),
        _syncExamsLocal(),
        _syncTasksLocal(),
        _syncStudyLogsLocal(),
      ]);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _syncExamsLocal() async {
    final examIds = StorageService.getExamIds();
    final exams = examIds
        .map((id) {
          final json = StorageService.getExamJson(id);
          if (json == null) return null;
          return ExamModel.fromJsonString(json);
        })
        .whereType<ExamModel>()
        .toList();
    final primaryId = StorageService.getPrimaryExamId();
    if (exams.isEmpty) return true;
    return syncExams(exams, primaryId);
  }

  static Future<bool> _syncTasksLocal() async {
    final taskIds = StorageService.getTodayTaskIds();
    final tasks = taskIds
        .map((id) {
          final json = StorageService.getTodayTaskJson(id);
          if (json == null) return null;
          return TodayTask.fromJsonString(json);
        })
        .whereType<TodayTask>()
        .toList();
    if (tasks.isEmpty) return true;
    return syncTasks(tasks);
  }

  static Future<bool> _syncStudyLogsLocal() async {
    final logIds = StorageService.getStudyLogIds();
    final logs = logIds
        .map((id) {
          final json = StorageService.getStudyLogJson(id);
          if (json == null) return null;
          return StudyLog.fromJsonString(json);
        })
        .whereType<StudyLog>()
        .toList();
    if (logs.isEmpty) return true;
    return syncStudyLogs(logs);
  }

  /// Khôi phục toàn bộ dữ liệu từ Supabase Cloud về Local Storage
  /// Kỳ thi bị TRÙNG PHIÊN BẢN giữa máy và cloud.
  ///
  /// Giữ cả hai bản để người dùng tự chọn — không bao giờ tự lấy bản cloud
  /// đè lên bản máy.
  static final List<ExamConflict> examConflicts = [];

  /// Hai bản là cùng một phiên bản?
  ///
  /// Cùng mốc sửa → coi như một (an toàn khi lưu lại không nội dung nào đổi).
  /// Thiếu mốc ở một bên → KHÔNG đoán: coi là khác nhau để hỏi. Dữ liệu cũ
  /// không có mốc, nếu đoán bừa sẽ âm thầm mất việc người dùng đã làm.
  static bool _isSameVersion(ExamModel a, ExamModel b) {
    final at = a.updatedAt;
    final bt = b.updatedAt;
    if (at == null || bt == null) return false;
    return at.isAtSameMomentAs(bt);
  }

  static Future<bool> restoreAll() async {
    if (!isConfigured) return false;
    examConflicts.clear();
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
        if (profileRes['is_email_verified'] == true) {
          StorageService.setEmailVerified(true);
        }
      }

      // 2. Restore Exams — trước đây CHỈ có chiều đẩy: kỳ thi lưu trên máy
      // này không bao giờ hiện trên máy khác, dù đã bấm đồng bộ đầy đủ.
      final examsRes =
          await _client!.from('exams').select().eq('user_id', _userId);

      if (examsRes.isNotEmpty) {
        final List<String> examIds = [];
        String? primaryFromCloud;
        for (final row in examsRes) {
          final rawId = row['id'] as String;
          final id = rawId.startsWith('${_userId}_')
              ? rawId.replaceFirst('${_userId}_', '')
              : rawId;
          final targets = <String, double>{};
          final rawTargets = row['subject_targets'];
          if (rawTargets is String && rawTargets.isNotEmpty) {
            try {
              final decoded = jsonDecode(rawTargets);
              if (decoded is Map) {
                decoded.forEach((k, v) {
                  if (v is num) targets['$k'] = v.toDouble();
                });
              }
            } catch (_) {
              // JSON hỏng → bỏ trống, KHÔNG làm hỏng cả danh sách kỳ thi.
            }
          }
          final subjects = row['subjects'];
          final cloud = ExamModel(
            id: id,
            name: row['name'] ?? '',
            dateTime:
                DateTime.tryParse(row['date_time'] ?? '') ?? DateTime.now(),
            emoji: row['emoji'] ?? '🎯',
            description: row['description'],
            currentScore: (row['current_score'] as num?)?.toDouble(),
            targetScore: (row['target_score'] as num?)?.toDouble(),
            subjectTargets: targets,
            subjects:
                subjects is List ? subjects.map((e) => '$e').toList() : null,
            updatedAt: row['updated_at'] == null
                ? null
                : DateTime.tryParse(row['updated_at'] as String),
          );

          final local = ExamRepository.instance.getById(id);
          // ── Quy tắc xung đột ───────────────────────────────────────────
          // Mất cả hai bản là mất cả tuần làm việc, nên **KHÔNG BAO GIỜ**
          // ghi đè bản máy khi chưa hỏi. Ba trường hợp:
          //  • Máy chưa có           → lấy về, không hỏi (không mất gì).
          //  • Hai bản CÙNG mốc sửa → là một phiên bản, lấy về bình thường.
          //  • Khác nhau, hoặc thiếu mốc → XUNG ĐỘT: giữ bản máy, báo lên
          //    để người dùng tự quyết.
          if (local != null && !_isSameVersion(local, cloud)) {
            examConflicts.add(ExamConflict(local: local, cloud: cloud));
            examIds.add(local.id);
            continue;
          }

          StorageService.setExamJson(cloud.id, cloud.toJsonString());
          examIds.add(cloud.id);
          if (row['is_primary'] == true) primaryFromCloud ??= cloud.id;
        }
        StorageService.setExamIds(examIds);
        // Chỉ dùng khi máy này CHƯA ghim — không ghi đè lựa chọn cục bộ.
        if (StorageService.getPrimaryExamId() == null &&
            primaryFromCloud != null) {
          StorageService.setPrimaryExamId(primaryFromCloud);
        }
        // Bắn tín hiệu cho UI vẽ lại (đã ghi thẳng qua StorageService nên
        // repository không tự biết). Không đẩy ngược lên cloud.
        ExamRepository.instance.notifyExternalChange();
      }

      // 3. Restore Tasks
      final tasksRes =
          await _client!.from('today_tasks').select().eq('user_id', _userId);

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
      final logsRes =
          await _client!.from('study_logs').select().eq('user_id', _userId);

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
