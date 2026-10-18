import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/theme/appearance_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/glass_card.dart';

/// Thẻ **Cỡ chữ** (đặc tả mục 20): font size adaptive S/M/L toàn app.
///
/// v2.8: tách khỏi AppearanceCard cũ — trang "Cài đặt" cho user phổ thông
/// chỉ còn 2 mục (Nhắc học hằng ngày + Cỡ chữ); phần nâng cao (tương phản
/// cao, chế độ yên lặng) chuyển xuống nhóm CHỦ APP ở trang "Thông tin app"
/// ([AdvancedAppearanceCard]).
///
/// Dark mode chưa cung cấp - palette tối chưa đạt chuẩn production, không fake
/// switch (nguyên tắc trung thực với người dùng). Tự lắng nghe
/// [AppearanceService.fontScale] nên không cần màn cha gọi setState.
class FontSizeCard extends StatelessWidget {
  const FontSizeCard({super.key});

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
                color: AppColors.iosInfo,
                bg: AppColors.iosInfoSoft,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text('Cỡ chữ',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.iosTextPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Áp dụng cho toàn app. Cỡ chữ hệ thống vẫn được tôn trọng.',
            style: TextStyle(fontSize: 11.5, color: AppColors.iosTextMuted),
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
          color: selected ? AppColors.iosInfoSoft : AppColors.iosBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.iosInfo : AppColors.iosSeparator,
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
                    color: selected
                        ? AppColors.iosInfoDark
                        : AppColors.iosTextPrimary)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppColors.iosInfoDark
                        : AppColors.iosTextMuted)),
          ],
        ),
      ),
    );
  }
}

/// Thẻ hiển thị **nâng cao** — thành viên nhóm CHỦ APP (trang "Thông tin
/// app", mở bằng unlock 7 bấm vào hàng "Phiên bản"):
///
/// - Tương phản cao (lắng nghe [AppearanceService.highContrast])
/// - Chế độ yên lặng: ẩn rim streak / mascot / âm thanh phản hồi — dữ liệu
///   vẫn được ghi nên không "nói dối" về tiến độ.
///
/// Tách khỏi [FontSizeCard] để trang Cài đặt giữ gọn cho user phổ thông.
class AdvancedAppearanceCard extends StatefulWidget {
  const AdvancedAppearanceCard({super.key});

  @override
  State<AdvancedAppearanceCard> createState() => _AdvancedAppearanceCardState();
}

class _AdvancedAppearanceCardState extends State<AdvancedAppearanceCard> {
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

  Widget _quietSwitch(
      String label, String sublabel, bool value, ValueChanged<bool> onChanged) {
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
                        fontSize: 11.0, color: AppColors.iosTextMuted)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.iosPrimary,
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
                activeThumbColor: AppColors.iosPrimary,
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
            style: TextStyle(fontSize: 11.0, color: AppColors.iosTextMuted),
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
}
