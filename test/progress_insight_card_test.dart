import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/home/presentation/widgets/progress_insight_card.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';

/// Nối AI-5.1 vào Home: thẻ "Nhận định tuần" phải đọc số liệu thật từ
/// [StudySessionRepository], ẩn khi tuần trắng, và không tràn ở bề rộng iPhone.
void main() {
  // Thứ Tư 18/03/2026 — tuần bắt đầu Thứ Hai 16/03.
  final now = DateTime(2026, 3, 18, 10, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  Future<void> seedSession(DateTime at, {int minutes = 30, String subject = '📐 Toán'}) {
    return StudySessionRepository.instance.save(StudySession(
      id: 's-${at.microsecondsSinceEpoch}',
      completedAt: at,
      subject: subject,
      plannedMinutes: minutes,
      actualMinutes: minutes,
    ));
  }

  Widget host({
    VoidCallback? onOpenProgress,
    ValueChanged<String>? onAskAi,
  }) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: ProgressInsightCard(
          clock: () => now,
          onOpenProgress: onOpenProgress,
          onAskAi: onAskAi,
        ),
      ),
    );
  }

  testWidgets('tuần trắng → không hiện thẻ (không bịa động viên)',
      (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('Nhận định tuần'), findsNothing);
  });

  testWidgets('có phiên học → hiện nhận định + số liệu tuần', (tester) async {
    await seedSession(DateTime(2026, 3, 17, 20, 0), minutes: 30);
    await seedSession(DateTime(2026, 3, 10, 20, 0), minutes: 30);

    await tester.pumpWidget(host(onOpenProgress: () {}));

    expect(find.text('Nhận định tuần'), findsOneWidget);
    expect(find.textContaining('dẫn đầu'), findsOneWidget);
    expect(find.text('0.5h'), findsOneWidget);
    expect(find.text('Xem tuần'), findsOneWidget);
  });

  testWidgets('bấm "Xem tuần" → mở tab Tiến độ', (tester) async {
    await seedSession(DateTime(2026, 3, 17, 20, 0));
    var opened = 0;
    await tester.pumpWidget(host(onOpenProgress: () => opened++));

    await tester.tap(find.text('Xem tuần'));
    expect(opened, 1);
  });

  testWidgets('bấm "Hỏi AI" → gửi prompt kèm số liệu thật', (tester) async {
    await seedSession(DateTime(2026, 3, 17, 20, 0), minutes: 45);
    String? prompt;
    await tester.pumpWidget(host(onAskAi: (p) => prompt = p));

    await tester.tap(find.text('Hỏi AI phân tích tuần'));
    expect(prompt, isNotNull);
    expect(prompt, contains('SỐ LIỆU THẬT'));
    expect(prompt, contains('45 phút'));
  });

  testWidgets('không tràn ở bề rộng iPhone 390px', (tester) async {
    await seedSession(DateTime(2026, 3, 17, 20, 0), minutes: 75);
    await seedSession(DateTime(2026, 3, 10, 20, 0), minutes: 30);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 390,
            child: ProgressInsightCard(clock: () => now),
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('Nhận định tuần'), findsOneWidget);
  });
}
