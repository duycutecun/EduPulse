import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/progress/presentation/screens/progress_screen.dart';
import 'package:edupulse/shared/widgets/primary_button.dart';

/// FE-6.4 — Tinh chỉnh phân cấp thị giác.
///
/// Mỗi màn hình chính phải có **một điểm nhấn hành động rõ ràng**: nút CTA nổi
/// bật nhất, dùng chung [PrimaryButton] thay vì chỉ là pill nhỏ lẫn trong tiêu
/// đề. Test này khoá lại quy ước đó để không bị bào mòn khi thêm tính năng.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  testWidgets('Màn Tiến độ có CTA chính rõ ràng (PrimaryButton)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ProgressScreen(clock: () => DateTime(2026, 3, 18, 10, 0)),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    // CTA chính là PrimaryButton và nhãn nói rõ hành động.
    expect(find.byType(PrimaryButton), findsOneWidget);
    expect(find.text('Hỏi AI phân tích'), findsOneWidget);
    // CTA là nút nêu (ElevatedButton) — không phải TextButton/GestureDetector.
    expect(
      find.descendant(
          of: find.byType(PrimaryButton), matching: find.byType(ElevatedButton)),
      findsOneWidget,
    );

    // Hành động nằm SAU phần thông tin (nhận định) — thứ tự đúng của phân cấp.
    final textY = tester.getTopLeft(find.text('Nhận định tiến độ')).dy;
    final ctaY = tester.getTopLeft(find.byType(PrimaryButton)).dy;
    expect(ctaY, greaterThan(textY));
    expect(tester.takeException(), isNull);
  });
}
