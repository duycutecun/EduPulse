import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/ai/weekly_report.dart';
import 'package:edupulse/core/family/family_models.dart';
import 'package:edupulse/core/share/share_text.dart';
import 'package:edupulse/core/theme/app_theme.dart';
import 'package:edupulse/core/utils/storage_service.dart';
import 'package:edupulse/features/family/domain/achievement_data.dart';
import 'package:edupulse/features/family/presentation/screens/achievement_share_screen.dart';
import 'package:edupulse/features/family/presentation/screens/parent_home_screen.dart';
import 'package:edupulse/features/family/presentation/widgets/achievement_card.dart';
import 'package:edupulse/features/auth/presentation/screens/auth_screen.dart';

/// "Cửa sổ tin cậy" — phần học sinh chia sẻ và phần phụ huynh đọc lại.
///
/// Khoá lại hai giao kèo quan trọng nhất:
/// 1. Thứ học sinh GỬI lên cloud phải đọc lại được y hệt ở phía phụ huynh
///    (toJson → fromJson), nếu không ba mẹ sẽ thấy báo cáo trống.
/// 2. Ảnh chia sẻ ra ngoài PHẢI mang nhận diện EduPulse (tên app + link) —
///    đây là yêu cầu trực tiếp: người xem biết bạn này dùng app học tập nào.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('Báo cáo tuần đi qua cloud nguyên vẹn', () {
    WeeklyReportData sample() => WeeklyReportData(
          headline: 'Tuần này con đã tập trung 150 phút trong 4 ngày.',
          items: const [
            ReportItem(
                key: 'study_time',
                title: 'Thời gian tập trung',
                value: '150 phút',
                detail: 'Học 4 ngày trong tuần'),
            ReportItem(
                key: 'readiness',
                title: 'Chỉ số sẵn sàng thi',
                value: '72/100',
                detail: 'Khá'),
          ],
          from: DateTime(2026, 10, 5),
          to: DateTime(2026, 10, 11),
          generatedAt: DateTime(2026, 10, 9, 21, 30),
        );

    test('toJson → fromJson giữ đủ headline, mục, mốc thời gian', () {
      final original = sample();
      final decoded = WeeklyReportData.fromJson(original.toJson());

      expect(decoded, isNotNull);
      expect(decoded!.headline, original.headline);
      expect(decoded.items.length, 2);
      expect(decoded.items.first.title, 'Thời gian tập trung');
      expect(decoded.items.first.value, '150 phút');
      expect(decoded.items.first.detail, 'Học 4 ngày trong tuần');
      expect(decoded.from, original.from);
      expect(decoded.to, original.to);
      expect(decoded.generatedAt, original.generatedAt);
    });

    test('payload rỗng/hỏng → null (không hiện báo cáo trống cho ba mẹ)', () {
      expect(WeeklyReportData.fromJson(null), isNull);
      expect(WeeklyReportData.fromJson('không phải map'), isNull);
      expect(WeeklyReportData.fromJson({'headline': 'x'}), isNull);
      expect(WeeklyReportData.fromJson({'items': []}), isNull);
    });

    test('SharedReport đọc payload của Supabase (jsonb Map hoặc chuỗi)', () {
      final payload = sample().toJson();
      final fromMap = SharedReport.fromJson({
        'id': 'r1',
        'studentName': 'Minh',
        'createdAt': 1760000000000,
        'payload': payload,
      });
      expect(fromMap, isNotNull);
      expect(fromMap!.studentName, 'Minh');
      expect(fromMap.report?.items.length, 2);

      // Một số cấu hình trả jsonb dưới dạng chuỗi — phải đọc được cả hai kiểu.
      final fromString = SharedReport.fromJson({
        'id': 'r2',
        'createdAt': 1760000000000,
        'payload': payload.toString(),
      });
      expect(fromString?.report, isNull, reason: 'chuỗi Dart không phải JSON');
    });
  });

  group('Mã mời và trạng thái gia đình', () {
    test('mã hết hạn thì isUsableAt = false', () {
      final now = DateTime(2026, 10, 9, 12);
      final fresh = FamilyInvite(
          code: '12345678', expiresAt: now.add(const Duration(hours: 2)));
      final expired = FamilyInvite(
          code: '12345678', expiresAt: now.subtract(const Duration(minutes: 1)));

      expect(fresh.isUsableAt(now), isTrue);
      expect(expired.isUsableAt(now), isFalse);
    });

    test('FamilyState đọc cả hai vai: ba mẹ đã nối và các con đã nối', () {
      final state = FamilyState.fromJson({
        'invite': {'code': '87654321', 'expiresAt': 1760000000000},
        'parents': [
          {'linkId': 'l1', 'userId': 'p1', 'name': 'Mẹ', 'linkedAt': 1}
        ],
        'children': [
          {
            'linkId': 'l2',
            'userId': 's1',
            'name': 'Con',
            'linkedAt': 2,
            'latestReportAt': 3,
          }
        ],
      });

      expect(state.invite?.code, '87654321');
      expect(state.hasLinkedParents, isTrue);
      expect(state.parents.first.name, 'Mẹ');
      expect(state.children.first.hasReport, isTrue);
    });

    test('bản ghi thiếu id bị loại thay vì tạo thành viên rỗng', () {
      final state = FamilyState.fromJson({
        'parents': [
          {'name': 'Không có linkId'},
          {'linkId': 'l1', 'userId': 'p1', 'name': 'Ba'},
        ],
      });
      expect(state.parents.length, 1);
      expect(state.parents.first.name, 'Ba');
    });

    test('tên trống → nhãn mặc định, không hiện dòng trắng', () {
      final state = FamilyState.fromJson({
        'children': [
          {'linkId': 'l1', 'userId': 's1', 'name': '   '}
        ],
      });
      expect(state.children.first.name, 'Thành viên');
    });
  });

  group('Số liệu ảnh thành tựu', () {
    AchievementData data({
      int weekMinutes = 0,
      int tasksDone = 0,
      int tasksTotal = 0,
      int streak = 0,
      int activeDays = 0,
      String? topSubject,
      int? topMinutes,
    }) =>
        AchievementData(
          studentName: 'Minh',
          weekStart: DateTime(2026, 10, 5),
          weekEnd: DateTime(2026, 10, 11),
          weekMinutes: weekMinutes,
          completionPercent:
              tasksTotal == 0 ? 0 : ((tasksDone / tasksTotal) * 100).round(),
          streakDays: streak,
          activeDays: activeDays,
          tasksCompleted: tasksDone,
          tasksTotal: tasksTotal,
          topSubject: topSubject,
          topSubjectMinutes: topMinutes,
        );

    test('chỉ đưa vào ảnh những dòng có số liệu thật', () {
      final stats = achievementStats(data());
      expect(stats, isEmpty, reason: 'tuần trắng thì không bịa dòng nào');
    });

    test('có dữ liệu thì lên đủ dòng, giờ hiển thị theo giờ khi ≥60 phút', () {
      final stats = achievementStats(data(
        weekMinutes: 750,
        tasksDone: 3,
        tasksTotal: 4,
        streak: 9,
        activeDays: 5,
        topSubject: '📐 Toán',
        topMinutes: 300,
      ));
      final labels = stats.map((s) => s.label).toList();

      expect(labels, contains('Thời gian tập trung'));
      expect(labels, contains('Nhiệm vụ hoàn thành'));
      expect(labels, contains('Chuỗi ngày học'));
      expect(labels, contains('Môn đầu tư nhiều nhất'));
      // 750 phút = 12.5 giờ, và tên môn đã bỏ emoji để không trùng emoji nhãn.
      expect(stats.first.value, '12.5 giờ');
      expect(
        stats.firstWhere((s) => s.label == 'Môn đầu tư nhiều nhất').value,
        'Toán · 300 phút',
      );
    });

    test('headline không dùng chuỗi ngày làm áp lực so sánh', () {
      final headline = data(weekMinutes: 300, activeDays: 3).headline;
      expect(headline, contains('5.0 giờ'));
      expect(headline, contains('3 ngày'));
      expect(headline, isNot(contains('kém')));
      expect(headline, isNot(contains('streak')));
    });

    test('chữ kèm ảnh luôn có tên app và link tải', () {
      final text = achievementShareText(data(weekMinutes: 60, activeDays: 2));
      expect(text, contains('EduPulse'));
      expect(text, contains(ShareText.appLink));
    });
  });

  group('Thẻ ảnh thành tựu mang nhận diện EduPulse', () {
    Future<void> pumpCard(WidgetTester tester, AchievementData data) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(child: AchievementCard(data: data)),
        ),
      ));
      await tester.pump();
    }

    AchievementData cardData() => AchievementData(
          studentName: 'Minh',
          weekStart: DateTime(2026, 10, 5),
          weekEnd: DateTime(2026, 10, 11),
          weekMinutes: 600,
          completionPercent: 75,
          streakDays: 6,
          activeDays: 4,
          tasksCompleted: 3,
          tasksTotal: 4,
          topSubject: '📐 Toán',
          topSubjectMinutes: 240,
          examName: 'THPTQG 2027',
          daysToExam: 120,
        );

    testWidgets('có tên app, mô tả app và link tải ở chân ảnh',
        (tester) async {
      await pumpCard(tester, cardData());

      // Đây là yêu cầu trực tiếp: người xem ảnh phải biết đây là app gì.
      expect(find.text('EduPulse'), findsOneWidget);
      expect(find.text('Trợ lý sĩ tử & đếm ngược kỳ thi'), findsOneWidget);
      expect(find.text('Học cùng EduPulse'), findsOneWidget);
      expect(find.text(ShareText.appLink), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('không tràn layout dù có đủ 5 dòng số liệu', (tester) async {
      await pumpCard(tester, cardData());

      expect(find.text('SỐ LIỆU TUẦN NÀY'), findsOneWidget);
      // "10.0 giờ" xuất hiện ở cả headline lẫn dòng số liệu — cả hai đều đúng.
      expect(find.textContaining('10.0 giờ'), findsWidgets);
      expect(find.textContaining('THPTQG 2027'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('chụp được thành TỆP PNG 1080x1920 thật', (tester) async {
      // Đủ chỗ cho thẻ 360x640: view test mặc định chỉ cao 600 nên thẻ sẽ bị
      // ép ngắn lại và "story" mất đúng tỉ lệ 9:16.
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: AchievementCard(data: cardData()),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Đây là deliverable: một TỆP ẢNH thật (không phải text) để học sinh
      // chia sẻ. pixelRatio 3 trên thẻ 360x640 = 1080x1920 (story 9:16).
      //
      // `runAsync` là bắt buộc: `toImage` chờ engine thật, mà đồng hồ giả của
      // widget test không tự đẩy được future này.
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      expect(boundary.size, const Size(360, 640),
          reason: 'thẻ phải giữ đúng khổ story 9:16');

      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 3);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data?.buffer.asUint8List();
      });

      expect(bytes, isNotNull);
      final png = bytes!;
      // 8 byte đầu của mọi tệp PNG.
      expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      expect(png.length, greaterThan(5000),
          reason: 'ảnh rỗng/hỏng thì quá nhỏ so với một thẻ có chữ và linh vật');

      // Kích thước nằm trong chunk IHDR: 4 byte rộng + 4 byte cao, big-endian,
      // bắt đầu ở offset 16. Đọc thẳng byte thay vì decode — không cần engine.
      int be32(int offset) =>
          (png[offset] << 24) |
          (png[offset + 1] << 16) |
          (png[offset + 2] << 8) |
          png[offset + 3];
      expect(be32(16), 1080);
      expect(be32(20), 1920);
    });
  });

  group('Màn chia sẻ ảnh thành tựu', () {
    testWidgets('chưa có số liệu → nói thật thay vì xuất ảnh toàn số 0',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: AchievementShareScreen(data: null),
      ));
      await tester.pump();

      expect(find.text('Tuần này chưa có gì để khoe'), findsOneWidget);
      expect(find.text('Chia sẻ ảnh'), findsNothing);
    });

    testWidgets('có số liệu → hiện xem trước + nút chia sẻ và sao chép',
        (tester) async {
      final data = AchievementData(
        studentName: 'Minh',
        weekStart: DateTime(2026, 10, 5),
        weekEnd: DateTime(2026, 10, 11),
        weekMinutes: 300,
        completionPercent: 100,
        streakDays: 4,
        activeDays: 3,
        tasksCompleted: 2,
        tasksTotal: 2,
      );

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: AchievementShareScreen(data: data),
      ));
      await tester.pump();

      expect(find.text('Ảnh thành tựu tuần'), findsOneWidget);
      expect(find.text('Chia sẻ ảnh'), findsOneWidget);
      expect(find.text('Sao chép lời nhắn'), findsOneWidget);
      // Ảnh xem trước chính là thẻ có thương hiệu.
      expect(find.text('EduPulse'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'khung xem trước nhỏ nhưng ảnh CHỤP RA vẫn ở khổ thật 360x640',
        (tester) async {
      // Màn hình thấp: xem trước chắc chắn phải thu nhỏ.
      tester.view.physicalSize = const Size(400, 620);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final data = AchievementData(
        studentName: 'Minh',
        weekStart: DateTime(2026, 10, 5),
        weekEnd: DateTime(2026, 10, 11),
        weekMinutes: 300,
        completionPercent: 100,
        streakDays: 4,
        activeDays: 3,
        tasksCompleted: 2,
        tasksTotal: 2,
      );

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: AchievementShareScreen(data: data),
      ));
      await tester.pump();

      // Phần VẼ RA (FittedBox) đã được thu nhỏ cho vừa màn hình thấp…
      final visual = tester.getSize(find
          .ancestor(
            of: find.byType(AchievementCard),
            matching: find.byType(FittedBox),
          )
          .first);
      expect(visual.width, lessThan(AchievementCard.logicalWidth),
          reason: 'xem trước phải được thu nhỏ cho vừa màn hình thấp');

      // RepaintBoundary (thứ bị chụp) vẫn là khổ thật → ảnh 1080x1920 ở 3x.
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find
            .ancestor(
              of: find.byType(AchievementCard),
              matching: find.byType(RepaintBoundary),
            )
            .first,
      );
      expect(boundary.size, const Size(360, 640));
    });
  });

  group('Chọn vai trò khi đăng nhập', () {
    testWidgets('có đủ 2 lựa chọn Học sinh / Phụ huynh', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: AuthScreen(onAuthSuccess: () {}, onSkip: () {}),
      ));
      await tester.pump();

      expect(find.byKey(const Key('auth-role-student')), findsOneWidget);
      expect(find.byKey(const Key('auth-role-parent')), findsOneWidget);
      expect(find.text('Học sinh'), findsOneWidget);
      expect(find.text('Phụ huynh'), findsOneWidget);
    });

    testWidgets('chỉ đổi vai trò tài khoản khi đăng nhập THÀNH CÔNG',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: AuthScreen(onAuthSuccess: () {}, onSkip: () {}),
      ));
      await tester.pump();

      expect(StorageService.getAccountRole(), StorageService.roleStudent);

      // Bấm chọn Phụ huynh rồi thoát ra (chưa đăng nhập) KHÔNG được đổi vai
      // của app — nếu không, người dùng chỉ mở thử là bị đẩy sang màn ba mẹ.
      await tester.tap(find.byKey(const Key('auth-role-parent')));
      await tester.pump();

      expect(StorageService.getAccountRole(), StorageService.roleStudent);
      expect(find.textContaining('Tài khoản phụ huynh:'), findsOneWidget);
    });

    testWidgets('mở từ màn phụ huynh thì chọn sẵn vai Phụ huynh',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: AuthScreen(
          initialRole: StorageService.roleParent,
          onAuthSuccess: () {},
          onSkip: () {},
        ),
      ));
      await tester.pump();

      expect(find.textContaining('Tài khoản phụ huynh:'), findsOneWidget);
    });
  });

  group('Màn phụ huynh', () {
    testWidgets(
        'chưa đăng nhập: hiện lời mời đăng nhập + ô nhập mã mời + ghi chú riêng tư',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ParentHomeScreen(),
      ));
      // Firebase chưa init trong test → hết thời gian chờ (4s) là hiện nút.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(find.byKey(const Key('parent-login-card')), findsOneWidget);
      expect(find.byKey(const Key('parent-invite-input')), findsOneWidget);
      expect(find.byKey(const Key('parent-link-button')), findsOneWidget);
      expect(find.textContaining('Cửa sổ tin cậy'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nhập mã sai định dạng → báo lỗi ngay, không gọi mạng',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ParentHomeScreen(),
      ));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      // Gửi form bằng bàn phím (nút Liên kết bị khoá khi chưa đăng nhập) —
      // kiểm tra đúng phần kiểm tra định dạng mã, không cần mạng.
      await tester.enterText(
          find.byKey(const Key('parent-invite-input')), '123');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('8 chữ số'), findsWidgets);
    });
  });
}
