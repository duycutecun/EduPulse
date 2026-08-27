import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    if (_prefs == null) throw Exception('StorageService not initialized');
    return _prefs!;
  }

  // Exam operations
  static List<String> getExamIds() =>
      _prefs?.getStringList('exam_ids') ?? [];

  static void setExamIds(List<String> ids) =>
      _prefs?.setStringList('exam_ids', ids);

  static String? getExamJson(String id) =>
      _prefs?.getString('exam_$id');

  static void setExamJson(String id, String json) =>
      _prefs?.setString('exam_$id', json);

  static void removeExam(String id) {
    _prefs?.remove('exam_$id');
    final ids = getExamIds()..remove(id);
    setExamIds(ids);
  }

  static String? getPrimaryExamId() =>
      _prefs?.getString('primary_exam_id');

  static void setPrimaryExamId(String id) =>
      _prefs?.setString('primary_exam_id', id);

  // Streak
  static int getStreak() => _prefs?.getInt('streak') ?? 0;
  static void setStreak(int v) => _prefs?.setInt('streak', v);

  static int getStreakRecord() => _prefs?.getInt('streak_record') ?? 0;
  static void setStreakRecord(int v) => _prefs?.setInt('streak_record', v);

  static String? getLastStudyDate() =>
      _prefs?.getString('last_study_date');
  static void setLastStudyDate(String d) =>
      _prefs?.setString('last_study_date', d);

  // Study Logs
  static List<String> getStudyLogIds() =>
      _prefs?.getStringList('study_log_ids') ?? [];
  static void setStudyLogIds(List<String> ids) =>
      _prefs?.setStringList('study_log_ids', ids);
  static String? getStudyLogJson(String id) =>
      _prefs?.getString('study_log_$id');
  static void setStudyLogJson(String id, String json) =>
      _prefs?.setString('study_log_$id', json);
  static void removeStudyLog(String id) {
    _prefs?.remove('study_log_$id');
    final ids = getStudyLogIds()..remove(id);
    setStudyLogIds(ids);
  }

  // Theme
  static String getThemeMode() => _prefs?.getString('theme_mode') ?? 'system';
  static void setThemeMode(String v) => _prefs?.setString('theme_mode', v);

  // Profile
  static String getUserName() =>
      _prefs?.getString('user_name') ?? 'Sĩ tử EduPulse';
  static void setUserName(String v) => _prefs?.setString('user_name', v);

  static String getUserTarget() =>
      _prefs?.getString('user_target') ?? '';
  static void setUserTarget(String v) => _prefs?.setString('user_target', v);

  static String getGeminiApiKey() =>
      _prefs?.getString('gemini_api_key') ?? '';
  static void setGeminiApiKey(String v) =>
      _prefs?.setString('gemini_api_key', v);

  // Today mission
  static List<String> getTodayTaskIds() =>
      _prefs?.getStringList('today_task_ids') ?? [];
  static void setTodayTaskIds(List<String> ids) =>
      _prefs?.setStringList('today_task_ids', ids);
  static String? getTodayTaskJson(String id) =>
      _prefs?.getString('task_$id');
  static void setTodayTaskJson(String id, String json) =>
      _prefs?.setString('task_$id', json);
  static void removeTodayTask(String id) {
    _prefs?.remove('task_$id');
    final ids = getTodayTaskIds()..remove(id);
    setTodayTaskIds(ids);
  }

  // Supabase Cloud Config
  static String getSupabaseUrl() =>
      _prefs?.getString('supabase_url') ?? '';
  static void setSupabaseUrl(String v) =>
      _prefs?.setString('supabase_url', v);

  static String getSupabaseAnonKey() =>
      _prefs?.getString('supabase_anon_key') ?? '';
  static void setSupabaseAnonKey(String v) =>
      _prefs?.setString('supabase_anon_key', v);

  static String getUserId() {
    var uid = _prefs?.getString('user_uuid');
    if (uid == null || uid.isEmpty) {
      uid = 'user_${DateTime.now().millisecondsSinceEpoch}';
      _prefs?.setString('user_uuid', uid);
    }
    return uid;
  }
}
