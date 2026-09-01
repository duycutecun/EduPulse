import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'package:flutter/material.dart';

// ---------- JS globals exposed from web/index.html ----------

@JS('navigator.userAgent')
external String get _userAgent;

@JS('window.pwaCanInstall')
external bool _pwaCanInstall();

@JS('window.pwaInstall')
external bool _pwaInstall();

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

bool _isIosSafariCache = false;

bool get isInstallable => _installable;

bool get isOnline => _online;

bool get isWeb => true;

bool get hasInitialized => _hasInitialized;

bool get offlineWarningFlag => _hasShownOfflineWarning;

set offlineWarningFlag(bool value) {
  _hasShownOfflineWarning = value;
}

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

// ---------- Offline tracking state ----------

int _offlineStartTime = 0;

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

      // Khi chuyển từ online → offline, ghi thời gian bắt đầu
      if (!_online) {
        _offlineStartTime = DateTime.now().millisecondsSinceEpoch;
      }
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

/// Kiểm tra xem app có đang ở chế độ offline dài thời gian (dùng cho warning)
/// Trả về true nếu offline hơn 30s và là iOS Safari.
bool _isProlongedOffline() {
  if (_online) return false;
  final now = DateTime.now().millisecondsSinceEpoch;
  final duration = now - _offlineStartTime;
  return duration > 30000; // 30 seconds
}

Future<bool> install() async {
  try {
    return _pwaInstall();
  } catch (_) {
    return false;
  }
}