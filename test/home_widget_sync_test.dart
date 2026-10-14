import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/core/widget/home_widget_service.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';

/// Unit test cho đồng bộ widget Android (P3). Chỉ chạy trên giả lập Android để
/// [HomeWidgetService.sync] không bị guard nền tảng chặn.
void main() {
  final now = DateTime(2026, 3, 18, 10, 0);

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('sync ghi đủ key gamification (streak/level/xp/huy hiệu)', () async {
    await StudySessionRepository.instance.save(StudySession(
      id: 's1',
      completedAt: now,
      subject: 'Toán',
      plannedMinutes: 50,
      actualMinutes: 50,
    ));

    await HomeWidgetService.sync();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('widget_streak'), isTrue);
    expect(prefs.containsKey('widget_level'), isTrue);
    expect(prefs.containsKey('widget_xp'), isTrue);
    expect(prefs.containsKey('widget_achievements_unlocked'), isTrue);
    // 50 phút → xp = 100, level = 100~/200 + 1 = 1.
    expect(prefs.getInt('widget_xp'), 100);
    expect(prefs.getInt('widget_level'), 1);
  });

  test('sync không có phiên học → xp 0 nhưng vẫn ghi đủ key', () async {
    await HomeWidgetService.sync();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('widget_xp'), 0);
    expect(prefs.getInt('widget_level'), 1);
    expect(prefs.getInt('widget_streak'), 0);
  });
}
