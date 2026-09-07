import 'dart:js_interop';

@JS('playEduPulseSound')
external void _playEduPulseSound(JSString type);

/// Gọi hàm Web Audio synthesizer đã khai báo trong index.html
void playWebAudio(String type) {
  try {
    _playEduPulseSound(type.toJS);
  } catch (_) {}
}
