import 'dart:async';

import 'ai_config.dart';
import '../pwa/pwa_service.dart';
import '../utils/storage_service.dart';
import 'ai_daily_briefing.dart';
import 'ai_insights.dart';

/// Cầu nối "dữ liệu vừa thay đổi → AI tính lại" — mảnh ghép khiến các phần
/// của app thành MỘT chu trình thay vì các tính năng rời rạc.
///
/// Vòng lặp:
///   học sinh hành động (xong task, làm quiz, nhập điểm, ôn flashcard,
///   đổi kỳ thi mục tiêu...)
///   → [notifyDataChanged] (gọi ở MỌI điểm ghi dữ liệu lớn)
///   → bản tin AI + gợi ý AI bị vô hiệu hoá ngay (UI không còn dẫn dắt bằng
///     dữ liệu cũ)
///   → sau 5 giây im lặng, AI được mời tính lại NGÔI (nếu online & được phép)
///   → bản tin/gợi ý mới xuất hiện trên Home qua `revision` notifier
///   → học sinh thấy gợi ý mới → hành động tiếp → lặp lại.
///
/// Nguyên tắc:
/// - **Debounce 5s**: một buổi học sinh bấm liên tiếp 10 task chỉ gây đúng 1
///   lần gọi model (lần cuối), không spam quota.
/// - **Không bao giờ ném lỗi**: gọi model thất bại thì giữ bản offline —
///   chu trình vẫn chạy, chỉ là lời văn thô hơn.
/// - **An toàn môi trường test**: giống [AiDailyBriefing], chỉ gọi AI khi có
///   kênh gọi thật (web đi proxy, native cần API key). Trong `flutter test`
///   không có kênh nên vòng lặp thuần local, không để lại timer treo.
class AiRefreshService {
  AiRefreshService._();

  /// Khoảng lặng trước khi mời AI tính lại nền.
  static const Duration debounceDelay = Duration(seconds: 5);

  static Timer? _timer;

  /// Báo hiệu dữ liệu học tập vừa thay đổi. An toàn gọi bao nhiêu lần cũng
  /// được — các lời gọi dồn nén thành đúng 1 lần tính lại.
  static void notifyDataChanged() {
    // 1. Vô hiệu hoá NGAY — mọi card AI trên Home đổi sang chế độ chờ dữ
    //    liệu mới thay vì tiếp tục khoe phân tích cũ.
    AiInsights.invalidate();
    AiDailyBriefing.invalidate();

    // 2. Hẹn tính lại nền sau [debounceDelay]. Không có kênh gọi AI thật
    //    (test, native chưa có key) thì dừng ở invalidate — không đặt timer
    //    để không bao giờ để lại timer treo trong môi trường test.
    if (!_canCallAi) return;
    _timer?.cancel();
    _timer = Timer(debounceDelay, _regenerateInBackground);
  }

  /// Đồng bộ luôn (không debounce) — dùng lúc khởi động app hoặc khi muốn
  /// chắc chắn AI nhìn thấy dữ liệu mới trước khi render.
  static Future<void> refreshNow() async {
    _timer?.cancel();
    _timer = null;
    await AiDailyBriefing.load(force: true);
    await AiInsights.refresh();
  }

  /// Còn một lần tính lại đang chờ debounce không?
  static bool get hasPendingRefresh => _timer != null && _timer!.isActive;

  /// Huỷ lần tính lại đang chờ (dùng trong test để dọn timer).
  static void cancelPending() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _regenerateInBackground() async {
    _timer = null;
    if (!_canCallAi) return;

    // Tắt mạng thì AI không thể trả lời — đừng gọi cho tốn thời gian.
    if (!PwaService.isOnline) return;

    try {
      // Bản tin sinh lại trước (nó cũng đụng vào readiness — mạch dữ liệu
      // tổng), gợi ý đi sau. Cả hai tự ghi cache và bắn `revision`.
      await AiDailyBriefing.load(force: true);
      await AiInsights.refresh();
    } catch (_) {
      // Fallback offline đã được `load()` lo — ở đây chỉ cần không văng lỗi.
    }
  }

  /// Điều kiện gọi AI thật — nhất quán với [AiDailyBriefing._canCallAi]:
  /// web đi proxy serverless, native cần API key build-time; người dùng tắt
  /// quyền phân tích thì tôn trọng. Trong `flutter test` không đủ điều kiện
  /// nên vòng lặp chạy thuần local.
  static bool get _canCallAi {
    if (StorageService.getBool('ai_permission_analyze') == false) return false;
    return PwaService.isWeb || AiConfig.openRouterApiKey.isNotEmpty;
  }
}
