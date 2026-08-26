import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/exams/domain/models/exam_model.dart';
import '../../features/study/domain/models/study_models.dart';
import 'storage_service.dart';

class SupabaseService {
  static SupabaseClient? _client;

  static bool get isConfigured => _client != null;

  static Future<bool> init({String? customUrl, String? customKey}) async {
    final url = (customUrl ?? StorageService.getSupabaseUrl()).trim();
    final anonKey = (customKey ?? StorageService.getSupabaseAnonKey()).trim();

    if (url.isEmpty || anonKey.isEmpty) {
      return false;
    }

    try {
      // ignore: deprecated_member_use
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
      _client = Supabase.instance.client;
      return true;
    } catch (e) {
      // If already initialized or connection error
      try {
        _client = Supabase.instance.client;
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  // --- SYNC PROFILE ---
  static Future<bool> syncProfile() async {
    if (!isConfigured) return false;
    try {
      final userId = StorageService.getUserId();
      final name = StorageService.getUserName();
      final target = StorageService.getUserTarget();
      final streak = StorageService.getStreak();
      final streakRecord = StorageService.getStreakRecord();

      await _client!.from('user_profiles').upsert({
        'user_id': userId,
        'name': name,
        'target_school': target,
        'streak': streak,
        'streak_record': streakRecord,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      return true;
    } catch (_) {
      return false;
    }
  }

  // --- SYNC EXAMS ---
  static Future<bool> syncExams(List<ExamModel> exams, String? primaryId) async {
    if (!isConfigured) return false;
    try {
      final userId = StorageService.getUserId();

      for (final e in exams) {
        await _client!.from('exams').upsert({
          'id': '${userId}_${e.id}',
          'user_id': userId,
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

  // --- SYNC TODAY TASKS ---
  static Future<bool> syncTasks(List<TodayTask> tasks) async {
    if (!isConfigured) return false;
    try {
      final userId = StorageService.getUserId();

      for (final t in tasks) {
        await _client!.from('today_tasks').upsert({
          'id': '${userId}_${t.id}',
          'user_id': userId,
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

  // --- SYNC STUDY LOGS ---
  static Future<bool> syncStudyLogs(List<StudyLog> logs) async {
    if (!isConfigured) return false;
    try {
      final userId = StorageService.getUserId();

      for (final l in logs) {
        await _client!.from('study_logs').upsert({
          'id': '${userId}_${l.id}',
          'user_id': userId,
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

  // --- FETCH LEADERBOARD ---
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
          weeklyHours: ((row['weekly_hours'] ?? 0) as num).toDouble(),
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

  // --- FULL ONE-CLICK SYNC ---
  static Future<bool> syncAll() async {
    if (!isConfigured) return false;
    try {
      await syncProfile();
      return true;
    } catch (_) {
      return false;
    }
  }
}
