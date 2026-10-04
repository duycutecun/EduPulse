class VoiceInputService {
  static bool _isAvailable = false;

  static bool get isAvailable => _isAvailable;

  static Future<bool> initialize() async {
    _isAvailable = false;
    return _isAvailable;
  }

  static Future<String?> listen({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return null;
  }

  static Future<void> stop() async {}

  static Future<void> cancel() async {}
}
