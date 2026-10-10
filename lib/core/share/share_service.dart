import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Chia sẻ nội dung học tập (tiến độ, streak, task, điểm) ra ngoài app.
///
/// - **Mobile (Android/iOS)**: mở share sheet hệ thống — người dùng gửi qua
///   Zalo, Messenger, SMS, email… (đúng kỳ vọng "chia sẻ" trên điện thoại).
/// - **Web/PWA**: share_plus tự dùng Web Share API nếu browser hỗ trợ;
///   fallback là copy vào clipboard + caller hiển thị toast.
///
/// Mọi màn hình gọi một API duy nhất [ShareService.shareText] — không phải
/// mỗi nơi tự xử lý platform.
class ShareService {
  ShareService._();

  /// Chia sẻ đoạn [text] với [subject] (tiêu đề trên một số target).
  ///
  /// Trả về `true` nếu người dùng đã chia sẻ (hoặc copy fallback thành công).
  static Future<bool> shareText(
    String text, {
    String? subject,
  }) async {
    if (text.isEmpty) return false;

    // Web vẫn chạy được qua share_plus (Web Share API bên dưới), giữ nhánh
    // riêng chỉ để fallback clipboard khi Share API bị chặn.
    try {
      final result = await SharePlus.instance.share(
        ShareParams(text: text, subject: subject, title: subject),
      );
      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.unavailable;
    } catch (_) {
      return _copyToClipboard(text);
    }
  }

  /// Chia sẻ một ẢNH (PNG bytes) ra ngoài app.
  ///
  /// Dùng cho "ảnh thành tựu tuần": người dùng gửi ảnh thật qua Zalo/Messenger/
  /// Facebook chứ không phải dán chữ. Ảnh được truyền dưới dạng bytes —
  /// `share_plus` tự ghi ra thư mục tạm trên Android/iOS, còn web dùng blob,
  /// nên KHÔNG cần `path_provider` và không phải tự quản lý tệp tạm.
  ///
  /// [fileNameOverrides] là cách duy nhất giữ đúng tên tệp khi tạo `XFile`
  /// từ bytes (`name` của cross_file bị bỏ qua trên mọi nền tảng trừ web).
  static Future<bool> shareImage(
    Uint8List bytes, {
    String fileName = 'edupulse-thanh-tuu.png',
    String? text,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    if (bytes.isEmpty) return false;
    try {
      final file = XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: fileName,
      );
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [file],
          fileNameOverrides: [fileName],
          text: text,
          subject: subject,
          title: subject,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.unavailable;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (_) {
      return false;
    }
  }
}
