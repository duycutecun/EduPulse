import 'package:flutter/services.dart';
import 'audio_synth_stub.dart' if (dart.library.js_interop) 'audio_synth_web.dart';

/// Dịch vụ phát âm thanh tương tác Duolingo-style micro-synth (0KB asset, 0 billing)
class AudioSynthService {
  /// Tiếng kêu chíp chíp đáng yêu khi chạm vào mascot
  static void playChirp() {
    HapticFeedback.lightImpact();
    playWebAudio('chirp');
  }

  /// Tiếng pop bóng nước khi hoàn thành bài / tap combo
  static void playPop() {
    HapticFeedback.selectionClick();
    playWebAudio('pop');
  }

  /// Tiếng nhạc hòa âm khi đổi trang phục / bốc quẻ thành công
  static void playEquip() {
    HapticFeedback.mediumImpact();
    playWebAudio('equip');
  }
}
