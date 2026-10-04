import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/app/main_shell.dart';
import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/home/presentation/widgets/today_mission_card.dart';
import 'package:edupulse/features/home/presentation/widgets/daily_summary_card.dart';
import 'package:edupulse/features/progress/presentation/screens/progress_screen.dart';
import 'package:edupulse/features/study/domain/models/study_models.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';

/// `UI phát triển.md` — Tiêu chí kiểm tra (Acceptance Criteria).
///
/// Bốn giai đoạn cải tiến chỉ có giá trị nếu đo được sau khi sửa. Mỗi tiêu chí
/// dưới đây gắn với đúng một dòng tick trong đặc tả:
///
///  1. Fold test — nhiệm vụ đầu tiên hiện ngay, không cần cuộn (iPhone SE).
///  2. 3-second test — người mới hiểu màn Hôm nay dùng để làm gì.
///  3. Empty state — luôn có lối ra bằng nút bấm, không chỉ giải thích.
///  4. Feedback nhất quán — mọi SnackBar trọng yếu có icon + màu.
///
/// Máy nhắc: dùng font Ahem nên `RenderFlex overflowed` có thể xuất hiện ở
/// đây dù trên máy thật không tràn. Vẫn phải sửa tới khi sạch — đó là cách duy
/// nhất bảo đảm mọi font đều không tràn.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'user_name': 'Minh',
      'user_target': 'ĐH Bách Khoa Hà Nội',
      'streak': 9,
      'streak_record': 21,
    });
    await StorageService.init();
  });

  /// Mốc giả 08:00 hôm nay — giữa ngày nên các khẳng định “hôm nay” ổn định.
  DateTime todayAt8() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, 8);
  }

  void sizeTo(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Không cài `FlutterError.onError` riêng: `flutter_test` đã tự báo lỗi
  /// layout (kể cả `RenderFlex overflowed`) và làm test đỏ. Dán đè handler là
  /// chi cách làm test chạy xong rồi im lặng — che mất lỗi thật.
  ///
  /// Vì vậy muốn “không tràn” chỉ cần dựng UI và để framework phán quyết.

  Future<void> pumpShell(
    WidgetTester tester, {
    Size size = const Size(375, 667),
  }) async {
    sizeTo(tester, size);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: MainShellScreen(clock: todayAt8),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Nhiệm vụ được lên lịch **hôm nay** — `TodayService` chỉ lấy task có
  /// `scheduledAt` rơi vào ngày hiện tại, nên lịch sai ngày thì task tạo ra
  /// sẽ không bao giờ hiện ở màn Hôm nay.
  TodayTask task(String id, String title, {int minutes = 45}) => TodayTask(
        id: id,
        title: title,
        subject: '📐 Toán',
        estimateMinutes: minutes,
        scheduledAt: todayAt8(),
      );

  group('Fold test — iPhone SE 375×667', () {
    testWidgets('nhiệm vụ đầu tiên hiện NGAY, không phải cuộn mới thấy',
        (tester) async {
      await TaskRepository.instance
          .createTask(task('t1', 'Giải đề hàm số giữa kỳ'));
      await pumpShell(tester);

      // Tiêu đề “Nhiệm vụ hôm nay” nằm trên màn hình đầu, không cần cuộn.
      final heading = find.text('Nhiệm vụ hôm nay');
      expect(heading, findsOneWidget);
      expect(
        tester.getTopLeft(heading).dy,
        lessThan(667),
        reason: 'tiêu đề nhiệm vụ phải nằm trong màn hình đầu tiên',
      );

      // Và nhiệm vụ đầu tiên phải hiện được, không chỉ tiêu đề.
      final first = find.text('Giải đề hàm số giữa kỳ');
      expect(first, findsOneWidget);
      expect(
        tester.getTopLeft(first).dy,
        lessThan(667),
        reason: 'nhiệm vụ đầu tiên phải hiện ngay ở iPhone SE',
      );
    });

    testWidgets('không tràn khi tiêu đề nhiệm vụ dài và có nhiều chip',
        (tester) async {
      await TaskRepository.instance.createTask(
        task('t1',
            'Ôn tập rất nhiều kiến thức Toán và Vật lý trong một nhiệm vụ dài'),
      );
      await pumpShell(tester);

      // Đừng có khẳng định "không tràn" bằng cách nuốt lỗi: framework tự đỏ
      // test khi có overflow — ở đây chỉ cần chắc nội dung vẫn hiện được.
      expect(find.textContaining('Ôn tập rất nhiều'), findsOneWidget);
    });
  });

  group('3-second test — mục đích màn Hôm nay phải tự nói ra', () {
    testWidgets('có lời chào tên + tổng kết ngày + khối nhiệm vụ ngay trên cùng',
        (tester) async {
      await TaskRepository.instance.createTask(task('t1', 'Ôn tập Văn'));
      await pumpShell(tester);

      // 1. Ai đang học.
      expect(find.textContaining('Minh'), findsWidgets);
      // 2. Hôm nay đã học được bao nhiêu (tổng kết). Khẳng định theo WIDGET
      // chứ không theo chữ “phút”: khi chưa học gì thì thẻ hiển thị chữ khác,
      // và đó là hành vi đúng — test không được đòi một chữ cụ thể.
      expect(find.byType(DailySummaryCard), findsOneWidget,
          reason: 'tổng kết ngày phải nằm ở đầu màn Hôm nay');
      // 3. Phải làm gì hôm nay — nhãn nhiệm vụ nằm trên màn hình đầu.
      final heading = find.text('Nhiệm vụ hôm nay');
      expect(tester.getTopLeft(heading).dy, lessThan(400),
          reason: 'việc cần làm phải lọt vào nửa trên màn hình, không phải '
              'đẩy xuống dưới các thẻ tóm tắt');
    });
  });

  group('Empty state — luôn có lối ra', () {
    testWidgets('Màn Hôm nay chưa có nhiệm vụ → có nút tạo kế hoạch',
        (tester) async {
      await pumpShell(tester);
      expect(find.text('+ Thêm nhiệm vụ'), findsOneWidget);
      expect(find.textContaining('AI lập kế hoạch'), findsOneWidget);
    });

    testWidgets('Màn Tiến độ chưa có dữ liệu → có nút "Bắt đầu học ngay" (G4-B)',
        (tester) async {
      var started = 0;
      sizeTo(tester, const Size(390, 844));
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: ProgressScreen(
          clock: todayAt8,
          onStartStudy: () => started++,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Chưa có dữ liệu học trong tuần này.'), findsOneWidget);
      final cta = find.byKey(const Key('progress-start-study'));
      expect(cta, findsOneWidget, reason: 'giải thích mà không có nút bấm thì '
          'người học vẫn phải tự mò');

      await tester.tap(cta);
      await tester.pump();
      expect(started, 1);
    });
  });

  group('G3-C — khung xương khi chưa có dữ liệu', () {
    testWidgets('màn Hôm nay không bao giờ mở ra trống trơn', (tester) async {
      await TaskRepository.instance.createTask(task('t1', 'Ôn tập Sử'));
      await pumpShell(tester);

      // Khung xương chỉ tồn tại một khung hình rồi bị dữ liệu thật thay thế —
      // sau khi ổn định phải thấy nhiệm vụ, không còn khung xương.
      expect(find.byType(TodayMissionCard), findsOneWidget);
      expect(find.text('Ôn tập Sử'), findsOneWidget);
    });
  });

  group('G3-A — phản hồi nhất quán có icon + màu', () {
    testWidgets('tạo nhiệm vụ → SnackBar có icon ngữ nghĩa, không chỉ chữ',
        (tester) async {
      await pumpShell(tester);

      await tester.tap(find.text('+ Thêm nhiệm vụ'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField).first, 'Luyện đề Hình');
      await tester.tap(find.text('Thêm'));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Đã thêm vào hôm nay'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget,
          reason: 'phải đọc được phản hồi mà không cần nhìn màu');
    });
  });
}
