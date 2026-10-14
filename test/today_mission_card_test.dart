import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edupulse/features/home/domain/services/today_service.dart';
import 'package:edupulse/features/home/presentation/widgets/today_mission_card.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';

/// Đặc tả 5.2 — thẻ nhiệm vụ hôm nay.
///   * Làm nổi bật đúng MỘT "việc quan trọng nhất" kèm LÝ DO ưu tiên.
///   * Chỉ hiện 1 + tối đa 3 việc kế tiếp; phần còn lại thu gọn sau nút mở.
void main() {
  void noop() {}
  void noopTask(TodayTask _) {}

  TodayTask task(String id, {String priority = 'medium', bool done = false}) =>
      TodayTask(
        id: id,
        title: 'Việc $id',
        subject: '📐 Toán',
        priority: priority,
        isDone: done,
      );

  Future<void> pump(WidgetTester tester, List<TodayTask> tasks) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TodayMissionCard(
            tasks: tasks,
            onAddTask: noop,
            onToggle: noopTask,
            onDelete: noopTask,
            onSkip: noopTask,
            onReschedule: noopTask,
          ),
        ),
      ),
    ));
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('TodayService.priorityReason', () {
    test('ưu tiên cao → lý do tập trung trước', () {
      final t = task('a', priority: 'high');
      expect(TodayService.priorityReason(t), contains('Ưu tiên cao'));
    });

    test('quá hạn → lý do quá hạn', () {
      final t = TodayTask(
        id: 'b',
        title: 'B',
        subject: 'Toán',
        deadline: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(TodayService.priorityReason(t), contains('Quá hạn'));
    });

    test('việc đã xong → không có lý do', () {
      expect(TodayService.priorityReason(task('c', done: true)), isEmpty);
    });

    test('mặc định vẫn có lý do nhẹ nhàng', () {
      expect(TodayService.priorityReason(task('d')), isNotEmpty);
    });
  });

  group('TodayMissionCard (đặc tả 5.2)', () {
    testWidgets('làm nổi bật việc quan trọng nhất kèm lý do', (tester) async {
      await pump(tester, [
        task('a', priority: 'high'),
        task('b'),
      ]);
      await tester.pump();

      expect(find.text('Việc quan trọng nhất'), findsOneWidget);
      expect(find.textContaining('Ưu tiên cao'), findsOneWidget);
    });

    testWidgets('nhiều việc → thu gọn, hiện nút xem thêm', (tester) async {
      await pump(tester, List.generate(6, (i) => task('t$i')));
      await tester.pump();

      // 1 ưu tiên + 3 kế tiếp → chỉ 4 thẻ được dựng.
      expect(find.text('Việc t0'), findsOneWidget);
      expect(find.text('Việc t3'), findsOneWidget);
      expect(find.text('Việc t4'), findsNothing);
      expect(find.text('Xem thêm 2 việc'), findsOneWidget);
    });

    testWidgets('bấm xem thêm → hiện đủ và đổi nhãn thu gọn', (tester) async {
      await pump(tester, List.generate(6, (i) => task('t$i')));
      await tester.pump();

      await tester.tap(find.text('Xem thêm 2 việc'));
      await tester.pump();

      expect(find.text('Việc t4'), findsOneWidget);
      expect(find.text('Việc t5'), findsOneWidget);
      expect(find.text('Thu gọn'), findsOneWidget);
    });

    testWidgets('ít việc (≤4) → không có nút thu gọn', (tester) async {
      await pump(tester, [task('a'), task('b')]);
      await tester.pump();

      expect(find.text('Việc quan trọng nhất'), findsOneWidget);
      expect(find.byKey(const ValueKey('toggle-more-tasks')), findsNothing);
    });
  });
}
