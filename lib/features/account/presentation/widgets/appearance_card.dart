import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/theme/appearance_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/glass_card.dart';

/// Thẻ Hiển thị (đặc tả mục 20): font size adaptive S/M/L toàn app.
///
/// Dark mode chưa cung cấp - palette tối chưa đạt chuẩn production, không fake
/// switch (nguyên tắc trung thực với người dùng). Tự lắng nghe
/// [AppearanceService.fontScale] / [AppearanceService.highContrast] nên không
/// cần màn cha gọi setState.
class AppearanceCard extends StatefulWidget {
  const AppearanceCard({super.key});

  @override
  State<AppearanceCard> createState() => _AppearanceCardState();
}

class _AppearanceCardState extends State<AppearanceCard> {
  bool _quietStreak = false;
  bool _quietMascot = false;
  bool _quietSound = false;

  @override
  void initState() {
    super.initState();
    _quietStreak = StorageService.getBool('quiet_mode_streak') ?? false;
    _quietMascot = StorageService.getBool('quiet_mode_mascot') ?? false;
    _quietSound = StorageService.getBool('quiet_mode_sound') ?? false;
  }

  Widget _quietSwitch(String label, String sublabel, bool value,
      ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13.0, fontWeight: FontWeight.w700)),
                Text(sublabel,
                    style: TextStyle(
                        fontSize: 11.0, color: AppColors.textMuted)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

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
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: Text('Chế độ yên lặng',
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Chỉ ẩn hiển thị XP/streak/mascot/âm thanh - dữ liệu vẫn được ghi.',
            style: TextStyle(fontSize: 11.0, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          _quietSwitch(
            'Ẩn rim streak',
            'Vẫn giữ streak cho lá bùa',
            _quietStreak,
            (v) {
              _quietStreak = v;
              StorageService.setBool('quiet_mode_streak', v);
              setState(() {});
            },
          ),
          _quietSwitch(
            'Mascot yên lặng',
            'Mascot chỉ hiện sau phiên',
            _quietMascot,
            (v) {
              _quietMascot = v;
              StorageService.setBool('quiet_mode_mascot', v);
              setState(() {});
            },
          ),
          _quietSwitch(
            'Tắt âm thanh phản hồi',
            'Âm chirp/pop/equip không phát',
            _quietSound,
            (v) {
              _quietSound = v;
              StorageService.setBool('quiet_mode_sound', v);
              setState(() {});
            },
          ),
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