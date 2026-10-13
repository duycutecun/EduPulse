import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/gamification/achievement_service.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/gamification/domain/achievements.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';

/// Huy hiệu (P2 — gamification): xét thuần trên thống kê + dịch vụ mở khoá &
/// lưu prefs. Toàn bộ dữ liệu nằm cục bộ, không có gì gửi đi.
void main() {
  // Helpers tạm không dùng nhưng giữ để mô phỏng cấu trúc test.
  // (được bỏ khỏi reference để tránh warning).

  group('AchievementStats', () {
    test('totalMinutes cộng đúng và allTasksToday cần có nhiệm vụ', () {
      expect(
        AchievementStats(
          scores: const [],
          sessions: [
            StudySession(
                id: 'a',
                completedAt: DateTime(2026, 1, 1),
                subject: 'Toán',
                plannedMinutes: 30,
                actualMinutes: 20),
            StudySession(
                id: 'b',
                completedAt: DateTime(2026, 1, 2),
                subject: 'Lý',
                plannedMinutes: 40,
                actualMinutes: 40),
          ],
          streak: 0,
          streakRecord: 0,
          notesCount: 0,
          tasksCompletedToday: 0,
          tasksTotalToday: 0,
        ).totalMinutes,
        60,
      );
      // Không có nhiệm vụ nào thì không thể "trọn vẹn một ngày".
      const noTasks = AchievementStats(
        scores: [],
        sessions: [],
        streak: 0,
        streakRecord: 0,
        notesCount: 0,
        tasksCompletedToday: 0,
        tasksTotalToday: 0,
      );
      expect(noTasks.allTasksToday, isFalse);
    });
  });

  group('evaluateAchievements', () {
    const empty = AchievementStats(
      scores: [],
      sessions: [],
      streak: 0,
      streakRecord: 0,
      notesCount: 0,
      tasksCompletedToday: 0,
      tasksTotalToday: 0,
    );

    test('dữ liệu trống → toàn bộ huy hiệu khoá', () {
      final states = evaluateAchievements(empty);
      expect(states.length, kAchievements.length);
      expect(states.every((s) => !s.unlocked), isTrue);
    });

    test('một phiên focus 5 & 25 phút → mở Bước chân đầu + Tâm trí sâu', () {
      final states = evaluateAchievements(AchievementStats(
        scores: const [],
        sessions: [
          StudySession(
            id: 's1',
            completedAt: DateTime(2026, 3, 18),
            subject: 'Toán',
            plannedMinutes: 30,
            actualMinutes: 30,
            focus: 5,
          ),
        ],
        streak: 0,
        streakRecord: 0,
        notesCount: 0,
        tasksCompletedToday: 0,
        tasksTotalToday: 0,
      ));
      final unlocked = states.where((s) => s.unlocked).map((s) => s.achievement.id);
      expect(unlocked, containsAll(['first_session', 'deep_focus']));
      expect(states.firstWhere((s) => s.achievement.id == 'ten_hours').unlocked,
          isFalse);
    });

    test('600 phút → mở 10 giờ đồng hồ', () {
      final sessions = List.generate(
        10,
        (i) => StudySession(
          id: 's$i',
          completedAt: DateTime(2026, 3, 1 + i),
          subject: 'Toán',
          plannedMinutes: 60,
          actualMinutes: 60,
        ),
      );
      final states = evaluateAchievements(AchievementStats(
        scores: const [],
        sessions: sessions,
        streak: 0,
        streakRecord: 0,
        notesCount: 0,
        tasksCompletedToday: 0,
        tasksTotalToday: 0,
      ));
      expect(
          states.firstWhere((s) => s.achievement.id == 'ten_hours').unlocked,
          isTrue);
    });

    test('streak/record/notes/điểm mở đúng huy hiệu tương ứng', () {
      final states = evaluateAchievements(AchievementStats(
        scores: List.generate(
          10,
          (i) => MockScore(
            id: 'm$i',
            date: DateTime(2026, 3, 1 + i),
            subject: 'Toán',
            score: i == 0 ? 8.5 : 6.0,
          ),
        ),
        sessions: const [],
        streak: 7,
        streakRecord: 10,
        notesCount: 5,
        tasksCompletedToday: 2,
        tasksTotalToday: 2,
      ));
      final unlocked = states.where((s) => s.unlocked).map((s) => s.achievement.id).toSet();
      expect(
        unlocked,
        containsAll([
          'first_score',
          'score_8',
          'ten_scores',
          'streak_3',
          'streak_7',
          'streak_record',
          'notes_5',
          'all_today',
        ]),
      );
    });

    test('phiên bắt đầu trước 7 giờ → mở Chim sớm', () {
      final states = evaluateAchievements(AchievementStats(
        scores: const [],
        sessions: [
          StudySession(
            id: 's1',
            completedAt: DateTime(2026, 3, 18, 7),
            subject: 'Toán',
            plannedMinutes: 30,
            actualMinutes: 30,
            startedAt: DateTime(2026, 3, 18, 6, 15),
          ),
        ],
        streak: 0,
        streakRecord: 0,
        notesCount: 0,
        tasksCompletedToday: 0,
        tasksTotalToday: 0,
      ));
      expect(
          states.firstWhere((s) => s.achievement.id == 'early_bird').unlocked,
          isTrue);
    });

    test('unlockedFor giữ nguyên thứ tự danh bạ', () {
      final list = unlockedFor(empty);
      expect(list, isEmpty);
      final ids = kAchievements.map((a) => a.id).toList();
      final stats = AchievementStats(
        scores: const [],
        sessions: const [],
        streak: 10,
        streakRecord: 10,
        notesCount: 0,
        tasksCompletedToday: 0,
        tasksTotalToday: 0,
      );
      final unlockedIds = unlockedFor(stats).map((a) => a.id).toList();
      expect(unlockedIds, ids.where(unlockedIds.contains).toList());
    });
  });

  group('AchievementService.reconcile', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
    });

    Future<void> seedSession({int minutes = 30, int? focus}) =>
        StudySessionRepository.instance.save(StudySession(
          id: 's-${DateTime.now().microsecondsSinceEpoch}',
          completedAt: DateTime.now(),
          subject: 'Toán',
          plannedMinutes: minutes,
          actualMinutes: minutes,
          focus: focus,
        ));

    test('không có dữ liệu → trả rỗng và không ghi gì', () {
      final newly = AchievementService.instance.reconcile();
      expect(newly, isEmpty);
      expect(StorageService.getStringList(kAchievementsUnlockedKey), isNull);
    });

    test('có phiên đầu → mở Bước chân đầu, lưu lại, gọi lại không lặp', () async {
      await seedSession();
      final first = AchievementService.instance.reconcile();
      expect(first.map((a) => a.id), contains('first_session'));
      expect(StorageService.getStringList(kAchievementsUnlockedKey),
          contains('first_session'));
      expect(AchievementService.instance.unlockedCount, greaterThan(0));

      final second = AchievementService.instance.reconcile();
      expect(second, isEmpty);
    });

    test('điểm 8 → mở Cú mở màn + Phá mốc 8 điểm', () {
      final score = MockScore(
        id: 'm1',
        date: DateTime.now(),
        subject: 'Toán',
        score: 8.5,
      );
      StorageService.setMockScoreJson(score.id, score.toJsonString());
      StorageService.setMockScoreIds([score.id]);

      final newly = AchievementService.instance.reconcile();
      final ids = newly.map((a) => a.id);
      expect(ids, containsAll(['first_score', 'score_8']));
    });

    test('reconcile cập nhật revision để UI vẽ lại', () async {
      final before = AchievementService.instance.revision.value;
      await seedSession();
      AchievementService.instance.reconcile();
      expect(AchievementService.instance.revision.value, greaterThan(before));
    });

    test('buildStats phản ánh streak, ghi chú và nhiệm vụ', () {
      StorageService.setStreak(4);
      StorageService.setStreakRecord(9);
      StorageService.setStudyNoteIds(['n1', 'n2']);
      final task = TodayTask(id: 't1', title: 'Học Toán', status: 'completed');
      StorageService.setTodayTaskJson(task.id, task.toJsonString());
      StorageService.setTodayTaskIds(['t1']);

      final stats = AchievementService.instance.buildStats();
      expect(stats.streak, 4);
      expect(stats.streakRecord, 9);
      expect(stats.notesCount, 2);
      expect(stats.tasksTotalToday, 1);
      expect(stats.tasksCompletedToday, 1);
      expect(stats.allTasksToday, isTrue);
    });
  });
}
