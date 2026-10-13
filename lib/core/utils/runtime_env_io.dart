import 'dart:io' show Platform;

/// VM (native/desktop): `flutter test` đặt biến môi trường `FLUTTER_TEST`.
bool get isFlutterTest => Platform.environment.containsKey('FLUTTER_TEST');
