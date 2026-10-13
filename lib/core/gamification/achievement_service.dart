import 'package:flutter/foundation.dart';

import '../../features/gamification/domain/achievements.dart';
import '../../features/study/domain/models/study_models.dart';
import '../../features/study/domain/repositories/study_session_repository.dart';
import '../../features/tasks/domain/repositories/task_repository.dart';
import '../utils/storage_service.dart';

/// Huy hiệu đã mở khoá — prefs key (P2: gamification). Lưu **danh sách id**, UI
/// luôn xét lại theo dữ liệu hiện tại (thuần + tái tính được).
const String kAchievementsUnlockedKey = 'achievements_unlocked';

/// Dịch vụ xét/mở khoá huy hiệu (toàn cục, không stateful save toàn khối).
///
/// Tách hẳn khỏi UI: hook gọi `reconcile()` sau mỗi biến đổi dữ liệu học tập
/// (hoàn task, lưu điểm, kết thúc phiên, lưu ghi chú) mà không cần biết huy
/// hiệu nào — service trả về danh sách mới mở để UI hiện toast.
class AchievementService {
  AchievementService._();

  static final AchievementService instance = AchievementService._();

  /// Tăng mỗi lần có huy hiệu mới — UI (sheet thành tích) lắng nghe để dựng lại.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Số huy hiệu đã **mở khoá & đã lưu** — dùng cho header/lưới.
  int get unlockedCount => readUnlockedIds().length;

  Set<String> readUnlockedIds() =>
      (StorageService.getStringList(kAchievementsUnlockedKey) ?? const [])
          .toSet();

  /// Nhóm "chất liệu" hiện tại từ nguồn dữ liệu cục bộ.
  AchievementStats buildStats({DateTime? now}) {
    final sessions = StudySessionRepository.instance.getAll();
    final tasks = TaskRepository.instance.getAllTasks();
    return AchievementStats(
      scores: _loadScores(),
      sessions: sessions,
      streak: StorageService.getStreak(),
      streakRecord: StorageService.getStreakRecord(),
      notesCount: StorageService.getStudyNoteIds().length,
      tasksCompletedToday:
          tasks.where((t) => t.isDone || t.status == 'completed').length,
      tasksTotalToday: tasks.length,
    );
  }

  List<MockScore> _loadScores() {
    final scores = StorageService.getMockScoreIds()
        .map(StorageService.getMockScoreJson)
        .whereType<String>()
        .map((v) {
          try {
            return MockScore.fromJsonString(v);
          } catch (_) {
            return null;
          }
        })
        .whereType<MockScore>()
        .toList();
    return scores;
  }

  /// Xét lại toàn bộ huy hiệu, lưu những cái mới đạt và **trả về danh sách mới
  /// mở** để caller hiện thông báo. Không mở lại cái đã có.
  List<Achievement> reconcile({DateTime? now}) {
    final unlocked = readUnlockedIds();
    final newly = <Achievement>[];
    for (final a in unlockedFor(buildStats(now: now))) {
      if (unlocked.add(a.id)) newly.add(a);
    }
    if (newly.isNotEmpty) {
      StorageService.setStringList(
          kAchievementsUnlockedKey, unlocked.toList());
      revision.value++;
    }
    return newly;
  }
}