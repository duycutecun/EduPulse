import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/progress/presentation/screens/deep_report_screen.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/study/domain/repositories/study_session_repository.dart';

/// P2 — Báo cáo học tập sâu: render đúng các khối phân tích, empty state có
/// lối ra, và không gọi AI / không cần mạng.
void main() {
  // Thứ Tư 18/03/2026.
  final now = DateTime(2026, 3, 18, 10, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  void seedScore({
    required String id,
    required double value,
    String subject = 'Toán',
    String? topic,
  }) {
    StorageService.setMockScoreJson(
      id,
      MockScore(
        id: id,
        date: now,
        subject: subject,
        score: value,
        topic: topic,
      ).toJsonString(),
    );
    StorageService.setMockScoreIds([...StorageService.getMockScoreIds(), id]);
  }

  Future<void> seedSession(String id, DateTime at, {int minutes = 30}) {
    return StudySessionRepository.instance.save(StudySession(
      id: id,
      completedAt: at,
      subject: 'Toán',
      plannedMinutes: minutes,
      actualMinutes: minutes,
    ));
  }

  Widget host({VoidCallback? onStartStudy}) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: DeepReportScreen(clock: () => now, onStartStudy: onStartStudy),
    );
  }

  testWidgets('không có điểm và phiên → empty state toàn màn, nút có lối ra',
      (tester) async {
    var studied = 0;
    await tester.pumpWidget(host(onStartStudy: () => studied++));

    expect(find.text('Chưa có dữ liệu để phân tích'), findsOneWidget);
    expect(find.text('Bắt đầu học'), findsOneWidget);

    await tester.tap(find.text('Bắt đầu học'));
    expect(studied, 1);
  });

  testWidgets('chỉ có điểm → hiện khối điểm, ẩn khối thời gian',
      (tester) async {
    seedScore(id: 'm1', value: 4, topic: 'Hàm số');
    seedScore(id: 'm2', value: 6, topic: 'Hàm số');
    seedScore(id: 'm3', value: 8, topic: 'Hình học');

    await tester.pumpWidget(host());

    expect(find.text('Xu hướng điểm theo tuần'), findsOneWidget);
    expect(find.text('Điểm theo môn'), findsOneWidget);
    expect(find.text('Chủ đề cần ưu tiên ôn'), findsOneWidget);
    expect(find.text('Hàm số'), findsOneWidget);
    expect(find.text('Thời gian học tuần này'), findsNothing);
    expect(find.textContaining('chạy hoàn toàn trên thiết bị'), findsOneWidget);
  });

  testWidgets('chỉ có phiên học → hiện khối thời gian, banner nhắc thêm điểm',
      (tester) async {
    await seedSession('s1', DateTime(2026, 3, 17, 20, 0));

    await tester.pumpWidget(host());

    expect(find.text('Thời gian học tuần này'), findsOneWidget);
    expect(find.text('Xu hướng điểm theo tuần'), findsNothing);
    expect(find.textContaining('Chưa có điểm thi thử'), findsOneWidget);
  });

  testWidgets('có cả điểm và phiên → render đủ, không tràn layout',
      (tester) async {
    seedScore(id: 'm1', value: 4, topic: 'Hàm số');
    seedScore(id: 'm2', value: 6, topic: 'Hàm số');
    seedScore(id: 'm3', value: 8, topic: 'Hình học');
    await seedSession('s1', DateTime(2026, 3, 10, 20, 0));
    await seedSession('s2', DateTime(2026, 3, 17, 20, 0));

    await tester.pumpWidget(host());
    await tester.scrollUntilVisible(find.text('Thời gian học tuần này'), 300);

    expect(find.text('Thời gian học tuần này'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('màn nhà bỏ qua dữ liệu khi nguồn cập nhật qua revision',
      (tester) async {
    seedScore(id: 'm1', value: 5, topic: 'Hàm số');
    await tester.pumpWidget(host());

    expect(find.text('Xu hướng điểm theo tuần'), findsOneWidget);

    // Khi một phiên được lưu, màn reload và hiện thêm khối thời gian.
    await seedSession('s1', DateTime(2026, 3, 17, 20, 0));
    await tester.pump();

    expect(find.text('Thời gian học tuần này'), findsOneWidget);
  });
}
