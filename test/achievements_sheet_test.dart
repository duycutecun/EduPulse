import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/gamification/achievement_service.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/gamification/domain/achievements.dart';
import 'package:edupulse/features/gamification/presentation/sheets/achievements_sheet.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';

/// Widget test cho sheet thành tích (P2 — gamification).
void main() {
  final now = DateTime(2026, 3, 18, 10, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    // Mở khoá đã lưu có thể dính giữa các test → dọn sạch.
    StorageService.setStringList(kAchievementsUnlockedKey, []);
  });

  Widget host() => MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showAchievementsSheet(context, clock: () => now),
                child: const Text('Mở'),
              ),
            ),
          ),
        ),
      );

  testWidgets('chưa có dữ liệu → hiện tiêu đề, 0 huy hiệu, nhiều ổ khoá',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();

    expect(find.text('Thành tích & huy hiệu'), findsOneWidget);
    expect(find.text('0/${kAchievements.length}'), findsOneWidget);
    expect(find.text('🔒'), findsWidgets);
  });

  testWidgets('có phiên đầu → Bước chân đầu mở, không còn ổ khoá cho nó',
      (tester) async {
    await StudySessionRepository.instance.save(StudySession(
      id: 's1',
      completedAt: now,
      subject: 'Toán',
      plannedMinutes: 30,
      actualMinutes: 30,
    ));

    await tester.pumpWidget(host());
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();

    expect(find.text('Bước chân đầu'), findsOneWidget);
    expect(find.text('👣'), findsOneWidget);
    // Toast huy hiệu mới được bắn khi sheet reconcile.
    expect(find.textContaining('Huy hiệu mới'), findsOneWidget);
  });
}
