import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/share/share_service.dart';
import '../../../../core/utils/feedback_service.dart';
import '../../domain/achievement_data.dart';
import '../widgets/achievement_card.dart';

/// Màn "Ảnh thành tựu tuần": xem trước đúng tấm ảnh sẽ gửi đi, rồi chia sẻ.
///
/// Vì sao phải xem trước chứ không chia sẻ thẳng: ảnh là thứ người khác nhìn
/// thấy thay mình — học sinh phải thấy trước khi nó rời khỏi máy. Cũng nhờ vậy
/// mà việc chụp ảnh dùng đúng widget đang hiển thị, không phải dựng lại lần
/// hai ở một nơi khác rồi lệch nhau.
class AchievementShareScreen extends StatefulWidget {
  const AchievementShareScreen({super.key, this.data});

  /// Cho phép test truyền số liệu cố định; mặc định dựng từ dữ liệu local.
  final AchievementData? data;

  static Future<void> open(BuildContext context, {AchievementData? data}) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AchievementShareScreen(data: data),
    ));
  }

  @override
  State<AchievementShareScreen> createState() => _AchievementShareScreenState();
}

class _AchievementShareScreenState extends State<AchievementShareScreen> {
  final GlobalKey _cardKey = GlobalKey();
  AchievementData? _data;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _data = widget.data ?? AchievementData.build();
  }

  /// Chụp đúng widget trong [RepaintBoundary] thành PNG.
  ///
  /// Trả về null nếu boundary chưa vẽ xong hoặc nền tảng không hỗ trợ (một số
  /// trình duyệt chặn ghi canvas) — người gọi phải nói thật là không tạo được
  /// ảnh, không được im lặng coi như đã chia sẻ.
  Future<Uint8List?> _captureCard() async {
    final object = _cardKey.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) return null;
    if (object.debugNeedsPaint) {
      // Vừa build xong chưa kịp paint → chờ một frame rồi chụp lại.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return null;
    }
    try {
      // pixelRatio 3 → ảnh 1080x1920, đủ nét cho story và newsfeed.
      final image = await object.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareImage() async {
    final data = _data;
    if (data == null || _busy) return;
    setState(() => _busy = true);
    FeedbackService.selection();

    // Lấy rect neo TRƯỚC khi await: đọc `context` sau async gap là lỗi thật
    // (widget có thể đã bị gỡ), còn iPad cần rect này để bung popover.
    final box = context.findRenderObject();
    final origin =
        box is RenderBox ? box.localToGlobal(Offset.zero) & box.size : null;

    final bytes = await _captureCard();
    var ok = false;
    if (bytes != null) {
      ok = await ShareService.shareImage(
        bytes,
        text: achievementShareText(data),
        subject: 'Thành tựu học tập — EduPulse',
        sharePositionOrigin: origin,
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(bytes == null
          ? 'Chưa tạo được ảnh trên nền tảng này — thử lại sau nhé.'
          : ok
              ? 'Chọn ứng dụng để gửi ảnh thành tựu nhé!'
              : 'Không chia sẻ được lúc này — thử lại sau nhé.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _copyCaption() async {
    final data = _data;
    if (data == null) return;
    await Clipboard.setData(ClipboardData(text: achievementShareText(data)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Đã sao chép lời nhắn — dán kèm ảnh khi đăng bài nhé!'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return Scaffold(
      backgroundColor: AppColors.bgPageSoft,
      appBar: AppBar(
        title: const Text('Ảnh thành tựu tuần',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        backgroundColor: AppColors.cardWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: data == null ? _emptyState() : _preview(data),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text(
              'Tuần này chưa có gì để khoe',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Học xong một phiên tập trung hoặc hoàn thành một nhiệm vụ rồi '
              'quay lại — ảnh thành tựu sẽ có số liệu thật của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Về trang chủ học tiếp',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(AchievementData data) {
    return LayoutBuilder(builder: (context, constraints) {
      // Xem trước theo tỉ lệ màn hình nhưng KHÔNG vượt quá kích thước thật —
      // chụp ở widget gốc nên ảnh luôn là 360x640 logic (1080x1920 ở 3x).
      final maxWidth = constraints.maxWidth - 40;
      final maxHeight = constraints.maxHeight - 130;
      // Chặn dưới/trên phải hợp lệ (`clamp` ném lỗi khi lower > upper), và
      // khung quá thấp (bàn phím/bản web nhỏ) vẫn phải xem trước được.
      final upper = (maxHeight / AchievementCard.logicalHeight).clamp(0.1, 1.0);
      final scale = (maxWidth / AchievementCard.logicalWidth).clamp(0.1, upper);

      return Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                // THỨ TỰ QUAN TRỌNG: `RepaintBoundary` ôm thẻ ở khổ THẬT
                // (360×640), `FittedBox` mới là thứ vẽ nó nhỏ lại cho vừa khung.
                // Nếu để thẻ tự co theo tỉ lệ xem trước thì ảnh chụp ra cũng
                // nhỏ theo (mất nét khi chia sẻ).
                child: SizedBox(
                  width: AchievementCard.logicalWidth * scale,
                  height: AchievementCard.logicalHeight * scale,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: RepaintBoundary(
                        key: _cardKey,
                        child: AchievementCard(data: data),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _busy ? null : _copyCaption,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(
                            color: AppColors.border, width: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Sao chép lời nhắn',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _shareImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Chia sẻ ảnh',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}
