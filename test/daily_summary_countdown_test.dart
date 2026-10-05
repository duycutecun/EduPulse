import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/exams/domain/models/exam_model.dart';
import 'package:edupulse/features/home/domain/services/today_service.dart';
import 'package:edupulse/features/home/presentation/widgets/daily_summary_card.dart';

/// Khối "Đếm ngược ngày thi" thay cho thanh "Tiến độ hôm nay" trong
/// [DailySummaryCard]. Tiến độ nhiệm vụ vẫn nằm ở tiêu đề TodayMissionCard
/// ("x/y") nên ở đây chỉ cần khẳng định: có kỳ thi thì đồng hồ chạy thật, chưa
/// chọn kỳ thi thì không chiếm chỗ, và ngày thi không đếm 00 gây cảm giác hết.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  const summary = DailySummary(
    totalTasks: 5,
    completedTasks: 2,
    studyMinutes: 80,
    remainingTasks: 3,
  );

  ExamModel examAt(DateTime when) =>
      ExamModel(id: 'e1', name: 'Thi THPT', dateTime: when);

  Widget host({
    ExamModel? exam,
    Duration remaining = Duration.zero,
    ValueListenable<Duration>? listenable,
  }) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: DailySummaryCard(
          summary: summary,
          primaryExam: exam,
          onExamTap: () {},
          remaining: remaining,
          remainingListenable: listenable,
        ),
      ),
    );
  }

  testWidgets('có kỳ thi → hiện đếm ngược ngày/giờ/phút/giây', (tester) async {
    await tester.pumpWidget(host(
      exam: examAt(DateTime.now().add(const Duration(days: 30))),
      remaining: const Duration(days: 2, hours: 3, minutes: 4, seconds: 5),
    ));

    expect(find.text('Đếm ngược ngày thi'), findsOneWidget);
    expect(find.text('ngày'), findsOneWidget);
    expect(find.text('giờ'), findsOneWidget);
    expect(find.text('phút'), findsOneWidget);
    expect(find.text('giây'), findsOneWidget);

    expect(find.text('2'), findsOneWidget); // ngày
    expect(find.text('03'), findsOneWidget); // giờ
    expect(find.text('04'), findsOneWidget); // phút
    expect(find.text('05'), findsOneWidget); // giây
  });

  testWidgets('đồng hồ tự chạy khi nguồn thời gian đổi', (tester) async {
    final notifier = ValueNotifier<Duration>(
      const Duration(hours: 1, minutes: 0, seconds: 5),
    );
    addTearDown(notifier.dispose);

    await tester.pumpWidget(host(
      exam: examAt(DateTime.now().add(const Duration(days: 30))),
      listenable: notifier,
    ));
    expect(find.text('05'), findsOneWidget);

    notifier.value = const Duration(hours: 1, minutes: 0, seconds: 4);
    await tester.pump();
    expect(find.text('04'), findsOneWidget);
    expect(find.text('05'), findsNothing);
  });

  testWidgets('chưa chọn kỳ thi → không có khối đếm ngược', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('Đếm ngược ngày thi'), findsNothing);
    expect(find.text('ngày'), findsNothing);
  });

  testWidgets('ngày thi → ẩn đếm ngược, nhường cho thẻ Exam Day',
      (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(host(
      exam: examAt(DateTime(now.year, now.month, now.day, 23, 59)),
    ));

    // Không còn gì để đếm, và Exam Mode đã có thẻ riêng nói rõ.
    expect(find.text('Đếm ngược ngày thi'), findsNothing);
    expect(find.text('giây'), findsNothing);
  });

  testWidgets('đã thi xong → ẩn đếm ngược (kỳ thi đã qua)', (tester) async {
    await tester.pumpWidget(host(
      exam: examAt(DateTime.now().subtract(const Duration(days: 2))),
    ));

    expect(find.text('Đếm ngược ngày thi'), findsNothing);
  });

  testWidgets('không tràn ở bề rộng iPhone 390px', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 390,
            child: DailySummaryCard(
              summary: summary,
              primaryExam:
                  examAt(DateTime.now().add(const Duration(days: 3))),
              onExamTap: () {},
              remaining:
                  const Duration(days: 3, hours: 12, minutes: 34, seconds: 56),
            ),
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('Đếm ngược ngày thi'), findsOneWidget);
  });
}
