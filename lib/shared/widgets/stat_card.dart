import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Thẻ số liệu nhỏ (giá trị lớn + nhãn) dùng chung giữa các tab trong app.
///
/// Tách riêng để nhiều màn hình (Nhật ký, Điểm thi…) dùng cùng một chuẩn hiển
/// thị, tránh mỗi nơi tự dựng một thẻ gần giống nhau rồi lệch nhau về sau.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  final String value;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.iosCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.iosSeparator, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.iosTextMuted,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
