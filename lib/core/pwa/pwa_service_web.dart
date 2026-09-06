import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/material.dart';

// ---------- JS globals exposed from web/index.html ----------

@JS('navigator.userAgent')
external String get _userAgent;

@JS('window.pwaCanInstall')
external bool _pwaCanInstall();

@JS('window.pwaInstall')
external bool _pwaInstall();

@JS('window.pwaIsStandalone')
external bool _pwaIsStandalone();

@JS('window.navigator.onLine')
external bool get _navigatorOnLine;

// ---------- State ----------

bool _installable = false;
bool _hasShownOfflineWarning = false;
bool _hasInitialized = false;

/// Notifier công khai để UI lắng nghe trạng thái installable.
final ValueNotifier<bool> installableNotifier = ValueNotifier<bool>(false);

/// Đang có kết nối internet hay không (navigator.onLine).
final ValueNotifier<bool> onlineNotifier = ValueNotifier<bool>(true);

bool _online = true;

bool get isInstallable => _installable;

bool get isOnline => _online;

bool get isWeb => true;

bool get hasInitialized => _hasInitialized;

bool get offlineWarningFlag => _hasShownOfflineWarning;

set offlineWarningFlag(bool value) {
  _hasShownOfflineWarning = value;
}

/// Thiết bị có phải là iOS (iPhone / iPad / iPod) hay không.
bool get isIos {
  try {
    final ua = _userAgent.toLowerCase();
    return ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
  } catch (_) {
    return false;
  }
}

/// Đang chạy trên iOS Safari hay không.
bool get isIosSafari {
  try {
    final ua = _userAgent.toLowerCase();
    final isAppleDevice = ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
    final isThirdPartyBrowser = ua.contains('crios') || ua.contains('fxios') || ua.contains('edgios');
    final isSafari = !isThirdPartyBrowser && ua.contains('safari');
    return isAppleDevice && isSafari;
  } catch (_) {
    return false;
  }
}

/// App đang chạy ở chế độ standalone (PWA đã được cài đặt trên Màn hình chính).
bool get isStandalone {
  try {
    return _pwaIsStandalone();
  } catch (_) {
    return false;
  }
}

// ---------- Offline tracking state ----------

// ---------- Functions ----------

void init() {
  _pollInstallable();
  _pollOnline();
  _startOfflineWarningTimer();
}

/// Poll trạng thái installable (JS bắn `beforeinstallprompt` → `pwaCanInstall() = true`).
void _pollInstallable() {
  try {
    final val = _pwaCanInstall();
    if (val != _installable) {
      _installable = val;
      installableNotifier.value = val;
    }
  } catch (_) {
    // JS functions chưa sẵn sàng — bỏ qua.
  }
  Timer(const Duration(seconds: 1), _pollInstallable);
}

/// Poll trạng thái online/offline từ navigator.onLine.
void _pollOnline() {
  try {
    final val = _navigatorOnLine;
    if (val != _online) {
      _online = val;
      onlineNotifier.value = val;
    }
  } catch (_) {
    // Mặc định online khi không đọc được.
  }
  Timer(const Duration(seconds: 2), _pollOnline);
}

/// Bắt đầu timer báo warning offline sau 30s (chỉ iOS Safari).
void _startOfflineWarningTimer() {
  Timer.periodic(const Duration(seconds: 30), (timer) {
    if (!_online && !_hasShownOfflineWarning && isIosSafari) {
      // Chỉ báo warning trên iOS Safari khi offline dài hơn 30s
      offlineWarningFlag = true;
      // Có thể gửi event qua js_channel để UI hiện banner
      _notifyOfflineWarning();
      timer.cancel();
    }
  });
}

/// Gửi offline warning event đến Flutter qua JS channel.
///
/// Ghi nhận trạng thái offline để UI có thể hiển thị banner cảnh báo.
/// Trên iOS Safari, có thể sử dụng window.messageHandlers để truyền thông
/// đến native code, nhưng trên browser thường sẽ chỉ đánh dấu flag để UI check.
void _notifyOfflineWarning() {
  // Chỉ đánh dấu flag để UI có thể hiển thị banner cảnh báo offline
  // Việc gửi message đến native sẽ phụ thuộc vào môi trường webview cụ thể
  offlineWarningFlag = true;
}

Future<bool> install() async {
  try {
    return _pwaInstall();
  } catch (_) {
    return false;
  }
}