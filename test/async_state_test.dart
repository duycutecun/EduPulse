import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/shared/state/async_state.dart';
import 'package:edupulse/shared/widgets/state_views.dart';

/// Unit + widget test cho mô hình trạng thái async thống nhất (§6.3).
void main() {
  group('AsyncState', () {
    test('các hằng trạng thái có cờ đúng', () {
      expect(const AsyncState<int>.loading().isLoading, isTrue);
      expect(const AsyncState<int>.data(5).hasData, isTrue);
      expect(const AsyncState<int>.data(5).data, 5);
      expect(const AsyncState<int>.empty().isEmpty, isTrue);
      expect(const AsyncState<int>.error('lỗi').hasError, isTrue);
      expect(const AsyncState<int>.error('lỗi').error, 'lỗi');
    });
  });

  group('AsyncStateController', () {
    test('bắt đầu ở trạng thái loading', () {
      final c = AsyncStateController<int>();
      expect(c.value.isLoading, isTrue);
      c.dispose();
    });

    test('load thành công → data', () async {
      final c = AsyncStateController<int>();
      await c.load(() async => 42);
      expect(c.value.hasData, isTrue);
      expect(c.value.data, 42);
      c.dispose();
    });

    test('kết quả là Iterable rỗng → empty (mặc định)', () async {
      final c = AsyncStateController<List<int>>();
      await c.load(() async => <int>[]);
      expect(c.value.isEmpty, isTrue);
      c.dispose();
    });

    test('Iterable không rỗng → data', () async {
      final c = AsyncStateController<List<int>>();
      await c.load(() async => [1, 2]);
      expect(c.value.hasData, isTrue);
      expect(c.value.data, [1, 2]);
      c.dispose();
    });

    test('isEmpty tuỳ biến được ưu tiên', () async {
      final c = AsyncStateController<int>(isEmpty: (v) => v == 0);
      await c.load(() async => 0);
      expect(c.value.isEmpty, isTrue);
      c.dispose();
    });

    test('load ném lỗi → error, gỡ tiền tố "Exception:"', () async {
      final c = AsyncStateController<int>();
      await c.load(() async => throw Exception('mất mạng'));
      expect(c.value.hasError, isTrue);
      expect(c.value.error, 'mất mạng');
      c.dispose();
    });

    test('describeError tuỳ biến được dùng', () async {
      final c =
          AsyncStateController<int>(describeError: (e) => 'Lỗi thân thiện');
      await c.load(() async => throw StateError('x'));
      expect(c.value.error, 'Lỗi thân thiện');
      c.dispose();
    });

    test('sau dispose không ghi đè trạng thái (không ném)', () async {
      final c = AsyncStateController<int>();
      final future = c.load(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 1;
      });
      c.dispose();
      await future; // không được ném dù notifier đã hủy
    });
  });

  group('AsyncStateView', () {
    Widget wrap(AsyncState<int> state, {VoidCallback? onRetry}) => MaterialApp(
          home: Scaffold(
            body: AsyncStateView<int>(
              state: state,
              onRetry: onRetry,
              builder: (context, data) => Text('giá trị $data'),
            ),
          ),
        );

    testWidgets('loading → LoadingStateView', (tester) async {
      await tester.pumpWidget(wrap(const AsyncState<int>.loading()));
      expect(find.byType(LoadingStateView), findsOneWidget);
    });

    testWidgets('data → builder', (tester) async {
      await tester.pumpWidget(wrap(const AsyncState<int>.data(7)));
      expect(find.text('giá trị 7'), findsOneWidget);
    });

    testWidgets('empty → EmptyStatePanel', (tester) async {
      await tester.pumpWidget(wrap(const AsyncState<int>.empty()));
      expect(find.byType(EmptyStatePanel), findsOneWidget);
    });

    testWidgets('error → ErrorStatePanel có nút thử lại', (tester) async {
      var retried = false;
      await tester.pumpWidget(wrap(
        const AsyncState<int>.error('hỏng'),
        onRetry: () => retried = true,
      ));
      expect(find.byType(ErrorStatePanel), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      expect(retried, isTrue);
    });
  });
}
