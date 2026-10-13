import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/appearance_service.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/glass_card.dart';

/// Thẻ Hiển thị (đặc tả mục 20): font size adaptive S/M/L toàn app.
///
/// Dark mode chưa cung cấp — palette tối chưa đạt chuẩn production, không fake
/// switch (nguyên tắc trung thực với người dùng). Tự lắng nghe
/// [AppearanceService.fontScale] / [AppearanceService.highContrast] nên không
/// cần màn cha gọi `setState`.
class AppearanceCard extends StatelessWidget {
  const AppearanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              AppIcon(
                Icons.format_size_rounded,
                tileSize: 36,
                iconSize: 18,
                color: AppColors.blue,
                bg: AppColors.blueSoft,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text('Cỡ chữ',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Áp dụng cho toàn app. Cỡ chữ hệ thống vẫn được tôn trọng.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<double>(
            valueListenable: AppearanceService.fontScale,
            builder: (context, scale, child) => Row(
              children: [
                for (final choice in const [
                  ('small', 'S', 'Nhỏ'),
                  ('normal', 'M', 'Vừa'),
                  ('large', 'L', 'Lớn'),
                ]) ...[
                  Expanded(child: _fontChoice(choice.$1, choice.$2, choice.$3)),
                  if (choice.$1 != 'large') const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          // High contrast (mục 21 — Accessibility): viền đậm hơn,
          // chữ phụ tối hơn — giúp người dùng nhìn yếu dễ đọc hơn.
          Row(children: [
            const Expanded(
              child: Text('Tương phản cao',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: AppearanceService.highContrast,
              builder: (context, value, _) => Switch(
                value: value,
                activeThumbColor: AppColors.primary,
                onChanged: AppearanceService.setHighContrast,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _fontChoice(String key, String letter, String label) {
    final selected = AppearanceService.fontScaleKey == key;
    return GestureDetector(
      onTap: () => AppearanceService.setFontScaleByKey(key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.blueSoft : AppColors.bgPage,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.blue : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(letter,
                style: TextStyle(
                    fontSize: key == 'small'
                        ? 14
                        : key == 'large'
                            ? 20
                            : 17,
                    fontWeight: FontWeight.w800,
                    color:
                        selected ? AppColors.blueDark : AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        selected ? AppColors.blueDark : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
