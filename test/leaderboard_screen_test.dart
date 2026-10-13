import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/leaderboard/presentation/screens/leaderboard_screen.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';

/// Widget test cho Bảng vàng kỷ lục (P2 — mở rộng leaderboard).
void main() {
  final now = DateTime(2026, 3, 18, 10, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  Widget host() => MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: LeaderboardScreen(clock: () => now),
      );

  testWidgets('chưa có dữ liệu → trạng thái rỗng', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Bảng vàng kỷ lục'), findsOneWidget);
    expect(find.text('Chưa có kỷ lục nào'), findsOneWidget);
    expect(find.text('Bảng vàng của bạn'), findsNothing);
  });

  testWidgets('có phiên học → hiện kỷ lục và tổng quan', (tester) async {
    await StudySessionRepository.instance.save(StudySession(
      id: 's1',
      completedAt: now,
      subject: 'Toán',
      plannedMinutes: 45,
      actualMinutes: 45,
    ));

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Bảng vàng của bạn'), findsOneWidget);
    expect(find.text('Phiên học dài nhất'), findsOneWidget);
    expect(find.text('45 phút'), findsWidgets);
    expect(find.text('Chưa có kỷ lục nào'), findsNothing);
  });

  testWidgets('dữ liệu mới đẩy vào → màn tự vẽ lại (lắng nghe revision)',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('Chưa có kỷ lục nào'), findsOneWidget);

    await StudySessionRepository.instance.save(StudySession(
      id: 's2',
      completedAt: now,
      subject: 'Lý',
      plannedMinutes: 30,
      actualMinutes: 30,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bảng vàng của bạn'), findsOneWidget);
    expect(find.text('Phiên học dài nhất'), findsOneWidget);
  });
}
