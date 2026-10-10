import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ai/weekly_report.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/family/family_models.dart';
import '../../../../core/family/family_service.dart';
import '../../../../core/family/live_progress_service.dart';
import '../../../../core/utils/auth_service.dart';
import '../../../../core/utils/feedback_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../features/family/presentation/screens/achievement_share_screen.dart';

/// "Cửa sổ tin cậy" — nơi học sinh chia sẻ tiến độ với gia đình.
///
/// Bản chất đã đổi: ba mẹ là người ĐỒNG HÀNH nên khi đã liên kết sẽ thấy toàn bộ
/// tiến độ (bốn mục), không còn để con tự quyết từng hạng mục. Sheet gồm:
/// 1. **Gia đình**: liên kết tài khoản ba mẹ bằng mã mời 8 chữ số.
/// 2. **Lời nhắn**: một dòng con muốn gửi kèm (tuỳ chọn).
/// 3. **Gửi đi**: gửi báo cáo tuần, tạo ảnh thành tựu, hoặc sao chép văn bản.
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
  final TextEditingController _checkinController = TextEditingController();

  FamilyState? _family;
  bool _familyLoading = false;
  bool _sending = false;
  FamilyInvite? _invite;

  /// Con có đang bật "cập nhật trực tiếp" cho ba mẹ hay không.
  bool _liveOn = false;
  bool _liveSaving = false;

  @override
  void initState() {
    super.initState();
    _liveOn = LiveProgressService.enabled;
    _checkinController.text = LiveProgressService.lastCheckin ?? '';
    // Hiện ngay trạng thái đã biết (nếu có) để sheet không nháy, rồi cập nhật.
    _family = FamilyService.cachedState;
    _loadFamily();
  }

  @override
  void dispose() {
    _checkinController.dispose();
    super.dispose();
  }

  Future<void> _loadFamily() async {
    if (!AuthService.isLoggedIn) return;
    if (mounted && _family == null) setState(() => _familyLoading = true);
    final state = await FamilyService.fetchState();
    if (!mounted) return;
    setState(() {
      _familyLoading = false;
      if (state != null) _family = state;
    });
  }

  /// Bật/tắt cập nhật trực tiếp cho ba mẹ.
  ///
  /// Bật (mặc định) = app tự đẩy báo cáo đầy đủ mỗi khi số liệu đổi. Tắt =
  /// tạm dừng đẩy (thu hồi bản trực tiếp đang có).
  Future<void> _toggleLive(bool value) async {
    if (_liveSaving) return;
    FeedbackService.selection();
    setState(() => _liveSaving = true);
    final ok = await LiveProgressService.setEnabled(value);
    if (!mounted) return;
    setState(() {
      _liveOn = value;
      _liveSaving = false;
    });
    if (ok) {
      _snack(value
          ? 'Ba mẹ sẽ thấy tiến độ cập nhật liên tục 💚'
          : 'Đã tạm dừng — ba mẹ không còn thấy cập nhật trực tiếp.');
    } else {
      _snack(
        value
            ? 'Đã bật. Sẽ tự gửi ngay khi có mạng.'
            : 'Chưa tắt được trên máy chủ — kiểm tra mạng rồi thử lại nhé.',
        error: !value,
      );
    }
  }

  // ─── Liên kết gia đình ─────────────────────────────────────────────────────

  Future<void> _createInvite() async {
    FeedbackService.selection();
    setState(() => _familyLoading = true);
    FamilyInvite? invite;
    String? serverError;
    try {
      invite = await FamilyService.createInvite(
        studentName: StorageService.getUserName(),
      );
    } on FamilyActionException catch (e) {
      serverError = e.message;
    }
    if (!mounted) return;
    setState(() {
      _familyLoading = false;
      if (invite != null) _invite = invite;
    });
    if (invite == null) {
      _snack(serverError ?? 'Không tạo được mã mời — kiểm tra mạng rồi thử lại nhé.',
          error: true);
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    _snack('Đã sao chép mã mời — gửi cho ba mẹ nhé!');
  }

  Future<void> _unlinkParent(FamilyMember parent) async {
    final result = await FamilyService.unlink(parent.linkId, asParent: false);
    if (!mounted) return;
    _snack(result.message, error: !result.ok);
    await _loadFamily();
  }

  Future<void> _sendToFamily(WeeklyReportData report) async {
    if (_sending) return;
    setState(() => _sending = true);
    FeedbackService.selection();

    // Nuốt lỗi banging: không có mạng chứ không phải học sinh làm sai.
    // Khi đó báo cáo vẫn được gửi đi trong quá trình — người dùng không cần
    // biết raw HTTP fail; chỉ cần biết “đã gửi” hoặc “đã lưu, đợi ba mẹ
    // liên kết rồi sẽ hiện”. Server trả `sentTo` cho cả trường hợp chưa ai
    // liên kết (0) — đó không phải lỗi.
    try {
      final sent = await FamilyService.shareReport(
        report,
        studentName: StorageService.getUserName(),
      );
      if (sent != null) {
        // Nhớ lời nhắn để bản "cập nhật trực tiếp" cũng mang theo.
        await LiveProgressService.rememberCheckin(report.checkin);
      }
      if (!mounted) return;
      setState(() => _sending = false);
      if (sent == null) {
        _snack('Chưa gửi được — kiểm tra mạng rồi thử lại nhé.', error: true);
        return;
      }
      _snack(sent == 0
          ? 'Đã lưu báo cáo tuần. Khi ba mẹ liên kết, báo cáo này sẽ hiện cho ba mẹ xem 💚'
          : 'Đã gửi báo cáo tuần cho $sent thành viên gia đình 💚');
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      _snack('Gửi thất bại — thử lại sau nhé.', error: true);
    }
    await _loadFamily();
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.red : AppColors.primary,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final checkin = _checkinController.text.trim();
    final report = WeeklyReport.build(
      enabled: WeeklyReport.defaultChoices,
      checkin: checkin.isEmpty ? null : checkin,
    );
    final name = StorageService.getUserName().trim();

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.96,
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
                'Ba mẹ đã liên kết sẽ thấy tiến độ học tập của con.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 18),

            _familySection(),
            const SizedBox(height: 16),

            // --- Lời nhắn gửi kèm (tuỳ chọn) ---
            const Text('Lời nhắn cho ba mẹ (không bắt buộc)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              key: const Key('family-checkin-field'),
              controller: _checkinController,
              maxLines: 2,
              maxLength: 140,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Ví dụ: “Tuần này con hơi mệt, ba mẹ đừng lo nhé.”',
                hintStyle: const TextStyle(fontSize: 12.5),
                filled: true,
                fillColor: AppColors.bgPage,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // --- Xem trước ---
            const Text('Xem trước',
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
                      'Con chưa có dữ liệu học tập để tạo báo cáo tuần này.',
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

            // --- Gửi cho gia đình (cần đăng nhập + đã liên kết) ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                key: const Key('family-send-report'),
                onPressed:
                    (report == null || _sending || !AuthService.isLoggedIn)
                        ? null
                        : () => _sendToFamily(report),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.family_restroom_rounded, size: 18),
                label: const Text('Gửi cho gia đình',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
            if (!AuthService.isLoggedIn) ...[
              const SizedBox(height: 6),
              const Text(
                'Đăng nhập (tab Tôi) rồi tạo mã mời để ba mẹ nhận được báo cáo.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 10),

            // --- Ảnh thành tựu tuần để chia sẻ ra ngoài ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                key: const Key('family-share-achievement'),
                onPressed: () => AchievementShareScreen.open(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.primary, width: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.auto_awesome_rounded,
                    size: 18, color: AppColors.primary),
                label: const Text('Tạo ảnh thành tựu tuần',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 10),

            // --- Sao chép để gửi (cách cũ, không cần liên kết) ---
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton.icon(
                onPressed: report == null
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(
                            text: report.toPlainText(studentName: name)));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Đã sao chép báo cáo — dán vào Zalo/SMS gửi ba mẹ nhé!'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                icon: const Icon(Icons.copy_rounded,
                    size: 17, color: AppColors.textSecondary),
                label: const Text('Sao chép báo cáo dạng chữ',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Khối "Gia đình": liên kết tài khoản ba mẹ bằng mã mời.
  Widget _familySection() {
    final state = _family;
    final parents = state?.parents ?? const <FamilyMember>[];
    final invite = _invite ?? state?.invite;

    // Gợi ý vị trí phụ huynh — chỉ cần một dòng khi học sinh đang xem trước
    // lúc chưa liên kết, để người dùng biết phía nhận báo cáo ở đâu.
    final hasParents = parents.isNotEmpty || (state?.hasLinkedParents ?? false);

    if (!AuthService.isLoggedIn) {
      return _card(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.family_restroom_rounded,
                size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tài khoản phụ huynh: đăng nhập (tab Tôi) để tạo mã mời 8 chữ số '
                'cho ba mẹ. Sau khi liên kết, ba mẹ thấy tiến độ học tập của con.',
                style: TextStyle(
                    fontSize: 12, height: 1.4, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.family_restroom_rounded,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Tài khoản phụ huynh',
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w800)),
              ),
              if (_familyLoading)
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 8),

          // Đã liên kết với ai
          if (parents.isEmpty)
            Text(
              'Chưa liên kết với ba mẹ nào. Tạo mã mời rồi đọc cho ba mẹ nhập. '
              'Ba mẹ đăng nhập rồi vào Cửa sổ tin cậy sẽ thấy tiến độ học tập '
              'của con 💚',
              style: TextStyle(
                  fontSize: 12, height: 1.4, color: AppColors.textSecondary),
            )
          else
            ...parents.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                      TextButton(
                        onPressed: () => _unlinkParent(p),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 30),
                        ),
                        child: const Text('Ngắt',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.red)),
                      ),
                    ],
                  ),
                )),

          const SizedBox(height: 8),

          // Mã mời
          if (invite != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('MÃ MỜI CHO BA MẸ',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: AppColors.primaryDark)),
                        const SizedBox(height: 2),
                        Text(_spacedCode(invite.code),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                                color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sao chép mã',
                    onPressed: () => _copyCode(invite.code),
                    icon: const Icon(Icons.copy_rounded,
                        size: 20, color: AppColors.primaryDark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mã có hiệu lực 2 ngày. Nhập lại mã cũ sẽ không dùng được — mỗi lần tạo mới là mã cũ hết hiệu lực.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
          ],

          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              key: const Key('family-create-invite'),
              onPressed: _familyLoading ? null : _createInvite,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.greenSoft,
                foregroundColor: AppColors.primaryDark,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.vpn_key_rounded, size: 17),
              label: Text(invite == null ? 'Tạo mã mời' : 'Tạo mã mời mới',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 10),
          _liveCard(linked: hasParents),
        ],
      ),
    );
  }

  /// Công tắc "Cập nhật trực tiếp": ba mẹ thấy tiến độ liền tay mà con không
  /// phải bấm gửi lại từng lần.
  Widget _liveCard({required bool linked}) {
    final String hint;
    if (!linked) {
      hint = 'Liên kết với ba mẹ trước đã, rồi tiến độ sẽ được cập nhật liên tục.';
    } else if (_liveOn) {
      hint = 'Đang bật: mỗi khi số liệu đổi, ba mẹ thấy ngay toàn bộ tiến độ. '
          'Con có thể tạm dừng bất cứ lúc nào.';
    } else {
      hint = 'Đang tạm dừng. Bật lại để ba mẹ thấy tiến độ liên tục, không phải '
          'chờ con bấm gửi.';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 6, 8),
      decoration: BoxDecoration(
        color: _liveOn ? AppColors.greenSoft : AppColors.bgPageSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _liveOn ? AppColors.primary : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_liveOn ? Icons.podcasts_rounded : Icons.podcasts_outlined,
                  size: 18,
                  color: _liveOn ? AppColors.primaryDark : AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Cập nhật trực tiếp cho ba mẹ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _liveOn
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                    )),
              ),
              if (_liveSaving)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                Switch(
                  key: const Key('family-live-switch'),
                  value: _liveOn,
                  activeThumbColor: AppColors.primary,
                  onChanged: linked ? _toggleLive : null,
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 26, right: 10, bottom: 2),
            child: Text(
              hint,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: _liveOn
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  /// "12345678" → "1234 5678": dễ đọc cho ba mẹ hơn hẳn một dãy liền.
  static String _spacedCode(String code) =>
      code.length == 8 ? '${code.substring(0, 4)} ${code.substring(4)}' : code;
}
