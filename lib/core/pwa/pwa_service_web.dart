import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

// ---------- JS globals exposed from web/index.html ----------

@JS('navigator.userAgent')
external String get _userAgent;

@JS('window.pwaCanInstall')
external bool _pwaCanInstall();

@JS('window.pwaInstall')
external bool _pwaInstall();

// ---------- State ----------

bool _installable = false;

/// Notifier public để UI lắng nghe trạng thái installable.
final ValueNotifier<bool> installableNotifier = ValueNotifier<bool>(false);

bool get isInstallable => _installable;

bool get isWeb => true;

bool get isIosSafari {
  try {
    final ua = _userAgent.toLowerCase();
    final isIos = ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
    // Loại trừ Chrome iOS (crios) và các webview; iOS Safari không có "crios".
    final isSafari = !ua.contains('crios') && ua.contains('safari');
    return isIos && isSafari;
  } catch (_) {
    return false;
  }
}

void init() {
  _poll();
}

/// Poll trạng thái installable (JS bắn `beforeinstallprompt` → `pwaCanInstall() = true`).
void _poll() {
  try {
    final val = _pwaCanInstall();
    if (val != _installable) {
      _installable = val;
      installableNotifier.value = val;
    }
  } catch (_) {
    // JS functions chưa sẵn sàng — bỏ qua.
  }
  Timer(const Duration(seconds: 1), _poll);
}

Future<bool> install() async {
  try {
    return _pwaInstall();
  } catch (_) {
    return false;
  }
}
