import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ai/weekly_report.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';

/// "Cửa sổ tin cậy" — học sinh chủ động tạo báo cáo tuần gửi gia đình.
///
/// Thiết kế:
/// - Học sinh bật/tắt từng mục; lựa chọn được NHỚ cho các tuần sau.
/// - Xem trước cập nhật tức thì theo lựa chọn.
/// - Không có mục nào bật → không có gì để gửi (không ép chia sẻ).
/// - Sao chép văn bản → dán vào Zalo/SMS; không cần tài khoản phụ huynh.
class FamilyReportSheet extends StatefulWidget {
  const FamilyReportSheet({super.key});

  /// Mở sheet từ bất kỳ đâu trong app.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const FamilyReportSheet(),
    );
  }

  @override
  State<FamilyReportSheet> createState() => _FamilyReportSheetState();
}

class _FamilyReportSheetState extends State<FamilyReportSheet> {
  late Map<String, bool> _choices;

  static const Map<String, String> _labels = {
    'study_time': 'Thời gian tập trung trong tuần',
    'readiness': 'Chỉ số sẵn sàng thi (0–100)',
    'mock_score': 'Điểm thi thử mới nhất',
    'exam_countdown': 'Đếm ngược kỳ thi',
  };

  @override
  void initState() {
    super.initState();
    _choices = WeeklyReport.savedChoices() ?? WeeklyReport.defaultChoices;
  }

  void _toggle(String key) {
    setState(() => _choices[key] = !(_choices[key] ?? false));
    // Lưu lựa chọn — tuần sau không phải chọn lại. Fire-and-forget.
    WeeklyReport.saveChoices(_choices);
  }

  @override
  Widget build(BuildContext context) {
    final report = WeeklyReport.build(enabled: _choices);
    final name = StorageService.getUserName().trim();

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.94,
        builder: (ctx, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text('💚 Cửa sổ tin cậy',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'Con chọn chia sẻ gì — gia đình chỉ thấy những mục được bật.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 18),

            // --- Công tắc từng mục ---
            ..._labels.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgPage,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SwitchListTile(
                      dense: true,
                      activeThumbColor: AppColors.primary,
                      value: _choices[e.key] ?? false,
                      onChanged: (_) => _toggle(e.key),
                      title: Text(e.value,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                    ),
                  ),
                )),
            const SizedBox(height: 12),

            // --- Xem trước ---
            Text('Xem trước',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: report == null
                  ? const Text(
                      'Chưa có mục nào được bật — bật ít nhất 1 mục để tạo báo cáo.',
                      style:
                          TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(report.headline,
                            style: const TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 10),
                        ...report.items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary)),
                                  Expanded(
                                    child: Text(
                                      '${item.title}: ${item.value}'
                                      '${item.detail == null ? '' : ' — ${item.detail}'}',
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          height: 1.45,
                                          color: AppColors.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // --- Sao chép để gửi ---
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: report == null
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(
                            text: report.toPlainText(studentName: name)));
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Đã sao chép báo cáo — dán vào Zalo/SMS gửi ba mẹ nhé!'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Sao chép báo cáo tuần',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
