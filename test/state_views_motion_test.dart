import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edupulse/core/ui/app_motion.dart';
import 'package:edupulse/shared/widgets/state_views.dart';

/// FE-6.5 (States Polish) + FE-6.6 (Reduced Motion).
void main() {
  Widget host(Widget child, {bool disableAnimations = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(body: child),
        ),
      );

  group('AppMotion — FE-6.6', () {
    testWidgets('tắt khi hệ điều hành không yêu cầu giảm chuyển động',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(host(Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })));
      expect(AppMotion.reduced(ctx), isFalse);
      expect(AppMotion.duration(ctx, const Duration(milliseconds: 300)),
          const Duration(milliseconds: 300));
    });

    testWidgets('bật khi disableAnimations=true → thời lượng về 0',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(host(
        Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
        disableAnimations: true,
      ));
      expect(AppMotion.reduced(ctx), isTrue);
      expect(AppMotion.duration(ctx, const Duration(milliseconds: 300)),
          Duration.zero);
    });
  });

  group('Skeleton — FE-6.5', () {
    testWidgets('SkeletonList hiển thị đúng số dòng', (tester) async {
      await tester.pumpWidget(host(const SkeletonList(lines: 3)));
      expect(find.byType(SkeletonBox), findsNWidgets(3));
    });

    testWidgets(
        'giảm chuyển động → skeleton tĩnh, không có AnimationController',
        (tester) async {
      await tester
          .pumpWidget(host(const SkeletonBox(), disableAnimations: true));
      expect(find.byType(SkeletonBox), findsOneWidget);
      // Không có ticker chạy → pumpAndSettle kết thúc ngay.
      await tester.pumpAndSettle();
    });

    testWidgets('shimmer chạy khi không giảm chuyển động', (tester) async {
      await tester.pumpWidget(host(const SkeletonBox()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  });

  group('EmptyStateView — FE-6.5', () {
    testWidgets('hiện tiêu đề, mô tả và nút hành động; bấm gọi callback',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(host(EmptyStateView(
        icon: Icons.sticky_note_2_outlined,
        title: 'Chưa có ghi chú',
        description: 'Lưu công thức để ôn lại sau.',
        actionLabel: 'Tạo ghi chú',
        onAction: () => tapped++,
      )));

      expect(find.text('Chưa có ghi chú'), findsOneWidget);
      expect(find.text('Lưu công thức để ôn lại sau.'), findsOneWidget);
      await tester.tap(find.text('Tạo ghi chú'));
      expect(tapped, 1);
    });

    testWidgets('không có hành động → không hiện nút', (tester) async {
      await tester.pumpWidget(host(const EmptyStateView(
        icon: Icons.inbox_rounded,
        title: 'Trống',
        description: 'Chưa có gì ở đây.',
      )));
      expect(find.text('Trống'), findsOneWidget);
    });
  });

  group('ErrorStateView — FE-6.5', () {
    testWidgets('hiện lỗi thân thiện + nút thử lại gọi callback',
        (tester) async {
      var retried = 0;
      await tester.pumpWidget(host(ErrorStateView(
        message: 'Không tải được dữ liệu. Thử lại nhé.',
        onRetry: () => retried++,
      )));
      expect(find.text('Không tải được dữ liệu. Thử lại nhé.'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      expect(retried, 1);
    });
  });

  group('LoadingStateView — FE-6.5', () {
    testWidgets('hiện thông điệp khi được truyền', (tester) async {
      await tester.pumpWidget(host(const LoadingStateView(
        message: 'Đang tải…',
      )));
      expect(find.text('Đang tải…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
