import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edupulse/core/analytics/product_analytics.dart';
import 'package:edupulse/core/family/family_notify_service.dart';
import 'package:edupulse/core/family/live_progress_service.dart';
import 'package:edupulse/core/privacy/share_audit_log.dart';
import 'package:edupulse/core/utils/storage_service.dart';

/// Test nhật ký thay đổi quyền chia sẻ (đặc tả mục 8, dòng 213).
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    ShareAuditLog.clear();
  });

  group('ShareAuditLog', () {
    test('ghi và đọc lại mốc, mới nhất trước', () {
      ShareAuditLog.log(ShareAuditKinds.familyLive, 'bật');
      ShareAuditLog.log(ShareAuditKinds.familyLive, 'tắt');

      final recent = ShareAuditLog.recent();
      expect(recent.length, 2);
      expect(recent.first.action, 'tắt');
      expect(recent.last.action, 'bật');
    });

    test('bỏ qua kind/action rỗng', () {
      ShareAuditLog.log('', 'bật');
      ShareAuditLog.log(ShareAuditKinds.aiRead, '   ');
      expect(ShareAuditLog.recent(), isEmpty);
    });

    test('lưu detail và nhãn hiển thị tiếng Việt', () {
      ShareAuditLog.log(ShareAuditKinds.familyReport, 'gửi báo cáo tuần',
          detail: 'tới 2 người');
      final e = ShareAuditLog.recent().single;
      expect(e.detail, 'tới 2 người');
      expect(ShareAuditKinds.labelOf(ShareAuditKinds.familyReport),
          'Gửi báo cáo tuần cho gia đình');
      expect(ShareAuditKinds.isKnown(ShareAuditKinds.familyReport), isTrue);
      expect(ShareAuditKinds.labelOf('lạ'), 'lạ');
    });

    test('giới hạn số mục theo maxEntries', () {
      for (var i = 0; i < ShareAuditLog.maxEntries + 25; i++) {
        ShareAuditLog.log(ShareAuditKinds.analyticsConsent, 'bật #$i');
      }
      expect(ShareAuditLog.recent().length, ShareAuditLog.maxEntries);
      // Mục cũ nhất bị cắt, chỉ giữ 200 gần nhất.
      expect(ShareAuditLog.recent().first.action, 'bật #224');
    });

    test('clear xoá sạch và tăng revision', () {
      ShareAuditLog.log(ShareAuditKinds.parentMode, 'bật');
      final before = ShareAuditLog.revision.value;
      ShareAuditLog.clear();
      expect(ShareAuditLog.recent(), isEmpty);
      expect(ShareAuditLog.revision.value, greaterThan(before));
    });

    test('exportText chứa tiêu đề và nội dung mốc', () {
      ShareAuditLog.log(ShareAuditKinds.aiAnalyze, 'bật');
      final text = ShareAuditLog.exportText();
      expect(text, contains('Nhật ký thay đổi quyền chia sẻ'));
      expect(text, contains('AI phân tích tiến độ'));
      expect(text, contains('bật'));
    });

    test('exportText khi rỗng vẫn có thông báo', () {
      expect(ShareAuditLog.exportText(), contains('chưa có mục nào'));
    });
  });

  group('Gắn nhật ký vào các công tắc', () {
    test('ProductAnalytics.setEnabled ghi mốc đồng ý', () {
      ProductAnalytics.instance.setEnabled(true);
      expect(
        ShareAuditLog.recent().any((e) =>
            e.kind == ShareAuditKinds.analyticsConsent && e.action == 'bật'),
        isTrue,
      );
    });

    test('LiveProgressService.setEnabled ghi mốc cập nhật trực tiếp', () async {
      await LiveProgressService.setEnabled(false);
      expect(
        ShareAuditLog.recent().any(
            (e) => e.kind == ShareAuditKinds.familyLive && e.action == 'tắt'),
        isTrue,
      );
    });

    test('FamilyNotifyService.setEnabled(false) ghi mốc tắt', () async {
      await FamilyNotifyService.setEnabled(false);
      expect(
        ShareAuditLog.recent().any(
            (e) => e.kind == ShareAuditKinds.familyNotify && e.action == 'tắt'),
        isTrue,
      );
    });
  });
}
