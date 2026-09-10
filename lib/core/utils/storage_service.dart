import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    if (_prefs == null) throw Exception('StorageService not initialized');
    return _prefs!;
  }

  // Onboarding
  static bool isOnboardingDone() =>
      _prefs?.getBool('onboarding_done') ?? false;
  static void setOnboardingDone() =>
      _prefs?.setBool('onboarding_done', true);

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

  // Lá bùa giữ chuỗi (streak freeze)
  static int getStreakFreezes() => _prefs?.getInt('streak_freeze_count') ?? 0;
  static void setStreakFreezes(int v) =>
      _prefs?.setInt('streak_freeze_count', v);

  /// Mua lá bùa bằng EXP gắn kết linh vật (tối đa giữ 3 lá).
  /// Trả về true nếu mua thành công.
  static bool buyStreakFreeze() {
    const cost = 100;
    if (getMascotBondExp() < cost) return false;
    if (getStreakFreezes() >= 3) return false;
    addMascotBondExp(-cost);
    setStreakFreezes(getStreakFreezes() + 1);
    return true;
  }

  /// Ghi nhận hoạt động học hôm nay và cập nhật streak theo ngày.
  ///
  /// Gọi khi user hoàn thành nhiệm vụ hoặc kết thúc phiên Pomodoro.
  /// Quy tắc:
  /// - Chưa học hôm nay → +1 nếu học liền ngày hôm qua (duy trì chuỗi).
  /// - Bỏ lỡ ĐÚNG 1 ngày và còn lá bùa → tiêu 1 lá bùa, giữ nguyên streak.
  /// - Bỏ lỡ >= 2 ngày (hoặc hết lá bùa) → reset về 1.
  /// - Đã học hôm nay → không đổi (tránh cộng nhiều lần trong ngày).
  /// Kỷ lục streak được cập nhật tự động.
  static void registerStudyActivity() {
    final now = DateTime.now();
    final today = _dayKey(now);
    final last = getString('last_study_date');
    if (last == today) return; // đã học hôm nay

    final yesterday = _dayKey(now.subtract(const Duration(days: 1)));
    final twoDaysAgo = _dayKey(now.subtract(const Duration(days: 2)));
    setString('last_study_date', today);

    if (last == yesterday) {
      final streak = getStreak() + 1;
      setStreak(streak);
      if (streak > getStreakRecord()) setStreakRecord(streak);
      return;
    }

    // Bỏ lỡ đúng 1 ngày: tiêu lá bùa để giữ chuỗi (không tăng streak).
    if (last == twoDaysAgo && getStreakFreezes() > 0) {
      setStreakFreezes(getStreakFreezes() - 1);
      return;
    }

    // Bỏ lỡ lâu hơn / hết bùa: reset về 1.
    setStreak(1);
    if (1 > getStreakRecord()) setStreakRecord(1);
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String? getString(String key) => _prefs?.getString(key);
  static void setString(String key, String v) => _prefs?.setString(key, v);

  static bool? getBool(String key) => _prefs?.getBool(key);
  static void setBool(String key, bool v) => _prefs?.setBool(key, v);

  static int? getInt(String key) => _prefs?.getInt(key);
  static void setInt(String key, int v) => _prefs?.setInt(key, v);

  // XP / Level
  static int getXp() => _prefs?.getInt('user_xp') ?? 0;
  static void setXp(int v) => _prefs?.setInt('user_xp', v);

  static void addXp(int delta) {
    if (delta <= 0) return;
    setXp(getXp() + delta);
  }

  /// Số XP cần từng cấp: 100, 250, 450, 700, 1000, 1350, 1750...
  static int xpForLevel(int level) {
    if (level <= 1) return 100;
    if (level == 2) return 250;
    if (level == 3) return 450;
    if (level == 4) return 700;
    if (level == 5) return 1000;
    return 1000 + (level - 5) * 350;
  }

  /// Cấp hiện tại (1-based).
  static int getLevel() {
    var xp = getXp();
    var level = 1;
    while (xp >= xpForLevel(level)) {
      xp -= xpForLevel(level);
      level++;
    }
    return level;
  }

  /// XP đã tích trong cấp hiện tại + tổng XP cần cấp này (0..1).
  static (int, int) getLevelProgress() {
    var xp = getXp();
    var level = 1;
    while (xp >= xpForLevel(level)) {
      xp -= xpForLevel(level);
      level++;
    }
    return (xp, xpForLevel(level));
  }



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
  static String getThemeMode() =>
      _prefs?.getString('theme_mode') ?? 'system'; // 'system' | 'light' | 'dark'
  static void setThemeMode(String v) =>
      _prefs?.setString('theme_mode', v);

  // Profile
  static String getUserName() =>
      _prefs?.getString('user_name') ?? 'Sĩ tử EduPulse';
  static void setUserName(String v) => _prefs?.setString('user_name', v);

  static String getUserTarget() =>
      _prefs?.getString('user_target') ?? '';
  static void setUserTarget(String v) => _prefs?.setString('user_target', v);

  static String getAiModel() => _prefs?.getString('ai_model') ?? '';
  static void setAiModel(String v) => _prefs?.setString('ai_model', v);

  // Danh sách model miễn phí của OpenRouter (cache 24h, FreeModelsCatalog).
  static String? getFreeModelsCache() =>
      _prefs?.getString('free_models_cache_v1');
  static void setFreeModelsCache(String json) =>
      _prefs?.setString('free_models_cache_v1', json);
  static String? getFreeModelsCacheTime() =>
      _prefs?.getString('free_models_cache_time_v1');
  static void setFreeModelsCacheTime(String v) =>
      _prefs?.setString('free_models_cache_time_v1', v);

  // AI Coach Chat History (cục bộ, miễn phí, lưu tối đa 40 tin)
  static String? getAiChatHistory() => _prefs?.getString('ai_chat_history_v1');
  static void setAiChatHistory(String json) =>
      _prefs?.setString('ai_chat_history_v1', json);
  static void clearAiChatHistory() => _prefs?.remove('ai_chat_history_v1');

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

  // Mock Scores (điểm thi thử)
  static List<String> getMockScoreIds() =>
      _prefs?.getStringList('mock_score_ids') ?? [];
  static void setMockScoreIds(List<String> ids) =>
      _prefs?.setStringList('mock_score_ids', ids);
  static String? getMockScoreJson(String id) =>
      _prefs?.getString('mock_score_$id');
  static void setMockScoreJson(String id, String json) =>
      _prefs?.setString('mock_score_$id', json);
  static void removeMockScore(String id) {
    _prefs?.remove('mock_score_$id');
    final ids = getMockScoreIds()..remove(id);
    setMockScoreIds(ids);
  }

  // Supabase Cloud Config
  // Giá trị người dùng nhập cục bộ được ưu tiên; nếu chưa có thì dùng config
  // mặc định trong lib/core/config.dart (giúp app kết nối ngay khi khởi động).
  static String getSupabaseUrl() {
    final stored = _prefs?.getString('supabase_url');
    return (stored == null || stored.isEmpty) ? AppConfig.supabaseUrl : stored;
  }
  static void setSupabaseUrl(String v) =>
      _prefs?.setString('supabase_url', v);

  static String getSupabaseAnonKey() {
    final stored = _prefs?.getString('supabase_anon_key');
    return (stored == null || stored.isEmpty)
        ? AppConfig.supabaseAnonKey
        : stored;
  }
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

  // Mascot Companionship & Wardrobe
  static String getMascotAccessory() =>
      _prefs?.getString('mascot_equipped_accessory') ?? 'sprout';

  static void setMascotAccessory(String id) =>
      _prefs?.setString('mascot_equipped_accessory', id);

  static String? getLastFortuneDate() =>
      _prefs?.getString('mascot_last_fortune_date');

  static void setLastFortuneDate(String dateStr) =>
      _prefs?.setString('mascot_last_fortune_date', dateStr);

  static String? getLastFortuneText() =>
      _prefs?.getString('mascot_last_fortune_text');

  static void setLastFortuneText(String text) =>
      _prefs?.setString('mascot_last_fortune_text', text);

  static int getMascotBondExp() =>
      _prefs?.getInt('mascot_bond_exp') ?? 120;

  static void setMascotBondExp(int v) =>
      _prefs?.setInt('mascot_bond_exp', v);

  static void addMascotBondExp(int delta) {
    final cur = getMascotBondExp();
    _prefs?.setInt('mascot_bond_exp', cur + delta);
  }
}
