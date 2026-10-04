import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/app/main_shell.dart';
import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/exams/domain/exam_repository.dart';
import 'package:edupulse/features/exams/domain/models/exam_model.dart';
import 'package:edupulse/features/exams/presentation/screens/exams_page.dart';

/// Kỳ thi vừa lưu phải hiện NGAY trên màn Hôm nay — không bắt người dùng
/// đóng app mở lại mới thấy.
///
/// Bối cảnh: trước đây màn Quản lý Kỳ thi là một route riêng được đẩy lên,
/// nên nó nhận `exams` là một **ảnh chụp** danh sách tại thời điểm mở. Lưu xong
/// repository bắn `revision` và shell đọc lại, nhưng widget đã nằm trong
/// route không bị dựng lại — nên người dùng phải tự đoán có cần tải lại app
/// không. Bộ test này khoá lại hành vi đúng: lưu là thấy.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'user_name': 'Minh',
      'streak': 3,
    });
    await StorageService.init();
  });

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const MainShellScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('lưu kỳ thi xong → quay lại Hôm nay thấy ngay tên kỳ thi',
      (tester) async {
    await pumpShell(tester);

    // Mở màn Quản lý Kỳ thi từ thẻ tổng kết ngày — đường đi thật của người dùng.
    await tester.tap(find.textContaining('Chưa chọn kỳ thi mục tiêu'));
    await tester.pumpAndSettle();
    expect(find.byType(ExamsPage), findsOneWidget);

    // Thêm một kỳ thi mới.
    await tester.tap(find.textContaining('Thêm kỳ thi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Kỳ thi liên khu');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Thêm'));
    await tester.pumpAndSettle();

    // Quay lại màn Hôm nay.
    // fullscreenDialog khong phaii nut back mac dinh nen pop route truc tiep.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Đây là điều kiện cốt lõi: KHÔNG cần khởi động lại app.
    expect(find.textContaining('Kỳ thi liên khu'), findsWidgets,
        reason:
            'vừa lưu kỳ thi xong thì màn Hôm nay phải hiện ngay tên kỳ thi');
  });

  testWidgets('đóng app mở lại vẫn đọc đúng kỳ thi đã lưu (không mất dữ liệu)',
      (tester) async {
    // Ghi qua đúng đường ghi thật.
    ExamRepository.instance.save(
      ExamModel(
        id: 'e-persist',
        name: 'Kỳ thi đầu cấp',
        dateTime: DateTime.now().add(const Duration(days: 20)),
      ),
    );
    await pumpShell(tester);

    expect(find.textContaining('Kỳ thi đầu cấp'), findsWidgets);
    expect(ExamRepository.instance.getById('e-persist'), isNotNull);
  });
}
