import 'package:flutter/foundation.dart';

/// Native (iOS/Android app) — không hỗ trợ cài PWA, trả về trạng thái không
/// installable để UI không hiện banner cài đặt web.
final ValueNotifier<bool> installableNotifier = ValueNotifier<bool>(false);

bool get isInstallable => false;

bool get isWeb => false;

bool get isIosSafari => false;

bool get hasInitialized => false;

bool get offlineWarningFlag => false;

void init() {}

Future<bool> install() async => false;
