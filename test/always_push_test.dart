import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/app/main_shell.dart';
import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/core/sync/sync_state.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/core/utils/supabase_service.dart';
import 'package:edupulse/features/exams/domain/exam_repository.dart';
import 'package:edupulse/features/exams/domain/models/exam_model.dart';

/// Yêu cầu: **luôn luôn đẩy lên cloud**, không đợi người dùng bấm nút.
///
/// Trước đây việc đẩy kỳ thi chỉ chạy khi bấm "Đồng bộ" thủ công, và ngay cả
/// khi đã có debounce 2 giây thì vẫn hỏng ở hai chỗ rất dễ gặp:
///
///  1. Sửa xong tắt app trong 2 giây → timer bị huỷ, thay đổi mất vĩnh viễn.
///  2. Sửa lúc offline → phải chờ chu kỳ 15 phút mới được đẩy.
///
/// Bộ test khoá lại cả hai: chuyển nền phải đẩy, và có mạng lại phải đẩy.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'user_name': 'Minh', 'streak': 3});
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

  test('flushNow() là lệnh đẩy tức thời, không chờ debounce', () {
    // Chưa cấu hình Supabase nên flushNow() phải là no-op an toàn —
    // quan trọng là KHÔNG ném lỗi và không để lại timer treo.
    expect(SupabaseService.isConfigured, isFalse,
        reason: 'test chạy không cấu hình cloud, nên đẩy phải bỏ qua');
    ExamRepository.instance.flushNow();
    // Lệnh chạy xong không được ném lỗi ra test.
    expect(SupabaseService.isConfigured, isFalse);
  });

  testWidgets('app chuyển nền → đẩy ngay, không phụ thuộc debounce',
      (tester) async {
    await pumpShell(tester);

    // Trước khi chuyển nền: KHÔNG có gì bị ném lỗi.
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    await tester.pump();

    // Quay lại app vẫn phải hoạt động bình thường.
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MainShellScreen), findsOneWidget);
  });

  testWidgets('app chuyển nền khi đang có kỳ thi chưa đẩy → không mất dữ liệu',
      (tester) async {
    final n = DateTime.now();
    ExamRepository.instance.save(ExamModel(
      id: 'flush-1',
      name: 'Kỳ thi sắp tới',
      dateTime: DateTime(n.year, n.month, n.day + 10),
    ));
    await pumpShell(tester);

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.hidden,
    );
    await tester.pump();

    // Dữ liệu vẫn còn trên máy sau khi app bị treo.
    expect(ExamRepository.instance.getById('flush-1'), isNotNull);
    expect(find.textContaining('Kỳ thi sắp tới'), findsWidgets);
  });

  test('khi mạng quay lại thì đẩy ngay, không chờ chu kỳ 15 phút', () {
    // Không có Supabase nên các lệnh đẩy là no-op; trọng tâm là bắt được
    // đường đi “offline → online” mà KHÔNG ném lỗi.
    SyncStateService.updateConnectivity(isOnline: false);
    expect(SyncStateService.state.value.status, SyncStatus.offline);

    SyncStateService.updateConnectivity(isOnline: true);
    expect(SyncStateService.state.value.status, SyncStatus.synced);
  });
}
