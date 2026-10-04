import '../../core/utils/feedback_service.dart';
import 'audio_synth_stub.dart'
    if (dart.library.js_interop) 'audio_synth_web.dart';

/// Dịch vụ phát âm thanh tương tác Duolingo-style micro-synth (0KB asset, 0 billing).
///
/// Đặc tả 5.14 liệt kê mục cài đặt **Âm thanh** và FE-6.6 yêu cầu âm thanh tắt
/// được — mọi lời gọi đi qua [FeedbackService] nên tắt trong Cài đặt là tắt thật.
class AudioSynthService {
  /// Tiếng kêu chíp chíp đáng yêu khi chạm vào mascot.
  static void playChirp() {
    FeedbackService.light();
    if (!FeedbackService.soundEnabled) return;
    playWebAudio('chirp');
  }

  /// Tiếng pop bóng nước khi hoàn thành bài / tap combo.
  static void playPop() {
    FeedbackService.selection();
    if (!FeedbackService.soundEnabled) return;
    playWebAudio('pop');
  }

  /// Tiếng nhạc hòa âm khi đổi trang phục / bốc quẻ thành công.
  static void playEquip() {
    FeedbackService.medium();
    if (!FeedbackService.soundEnabled) return;
    playWebAudio('equip');
  }
}
