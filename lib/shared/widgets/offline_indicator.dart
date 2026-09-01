import 'package:flutter/material.dart';

/// Widget hiển thị trạng thái online/offline cho PWA trên web/iOS.
///
/// Sử dụng màu sắc và icon để chỉ trạng thái kết nối.
/// Widget này không phụ thuộc trực tiếp vào PwaService - cha/widgets sẽ
/// cung cấp trạng thái thông qua các parameter.
class OfflineIndicator extends StatelessWidget {
  final bool isOnline;
  final bool isIosSafari;
  final bool offlineWarning;
  final Widget? child;
  final Color? onlineColor;
  final Color? offlineColor;
  final double size;
  final EdgeInsetsGeometry? margin;

  const OfflineIndicator({
    super.key,
    required this.isOnline,
    required this.isIosSafari,
    required this.offlineWarning,
    this.child,
    this.onlineColor,
    this.offlineColor,
    this.size = 24.0,
    this.margin,
  });

  Color _getColor(BuildContext context) {
    if (isOnline) {
      if (isIosSafari && offlineWarning) {
        return Colors.orange;
      }
      return Colors.green;
    }
    if (isIosSafari && offlineWarning) {
      return Colors.red;
    }
    return Colors.red;
  }

  IconData _getIcon() {
    if (isOnline) {
      if (isIosSafari && offlineWarning) {
        return Icons.wifi;
      }
      return Icons.wifi;
    }
    return Icons.wifi_off;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);
    final icon = _getIcon();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: isOnline
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.6,
        ),
      ),
    );
  }
}