import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../study/domain/models/study_models.dart';

/// Thanh "Bắt đầu" dính ở đáy màn Hôm nay (V2 M1' mục 4).
///
/// Vì sao phải là thanh dính chứ không phải một nút trong danh sách: gate M1'
/// đo "mở app → phiên học đầu tiên trong **<15 giây**, **≤2 chạm**". Một CTA
/// nằm trong vùng cuộn thì với người có 8 nhiệm vụ nó vẫn ở ngoài màn hình đầu
/// — đúng thứ tự do thất bại mà cổng này muốn bắt.
///
/// Thanh này **không** hiển thị khi đang có phiên bỏ dở: lúc đó thẻ "phiên đang
/// học" đã là hành động đúng, hai CTA cạnh tranh nhau chỉ làm người học do dự.
///
/// Bố cục hai hàng (nhãn việc ở trên, hai nút co giãn ở dưới) là để không tràn
/// ngang trên máy 360–390dp: nhãn nút dài hơn bề rộng còn lại sẽ bị cắt bằng
/// ellipsis trong `PrimaryButton`, nhưng bản thân hàng thì không được tràn.
///
/// Slice iOS-first: màu token của theme iOS-first (`ios*`); token cũ vẫn còn
/// nếu màn này chưa được restyle xong.
class StartSessionBar extends StatelessWidget {
  /// Việc ưu tiên còn lại hôm nay; `null` khi hôm nay không còn việc nào.
  final TodayTask? task;

  /// Số phút phiên mặc định — V2 chốt 10.
  final int minutes;

  final VoidCallback onStart;

  /// Dời việc ưu tiên sang ngày khác; `null` thì không hiện nút Hoãn.
  final VoidCallback? onDefer;

  /// Chiều cao tối đa thực của thanh, bẻ trực tiếp từ đúng các số liệu mà
  /// [build] dùng (viền trên 1px, padding dọc space10×2, dòng nhãn việc
  /// caption 12×1.3, kẽ space8, thân nút chuẩn standardTouchTarget) — không
  /// ghi sẵn một con số "đo tay".
  ///
  /// Vì sao cần công khai số này: thanh nằm trên danh sách cuộn bằng
  /// `Positioned` (đè lên nội dung), nên phía chứa danh sách buộc phải chừa
  /// đáy đủ cao để thẻ cuối cùng luôn **trượt qua trọn thân thanh** khi cuộn
  /// hết. Thiếu cái này, khoảng đuôi thanh ngang đỉnh của thẻ sát đáy (vd.
  /// thẻ "CẢNH BÁO MÔN YẾU" tạo bởi `AiActionsRow`) che mất phần dưới thẻ —
  /// CTA bấm không được vì đã rơi vào vùng bị thanh vẽ đè.
  static double maxBarHeight({TextScaler? textScaler}) {
    // Dòng nhãn việc: caption 12px × height 1.3, scale theo cỡ chữ hệ thống
    // (cỡ chữ lớn làm dòng nhãn cao hơn — clearance phải theo).
    final double captionLine =
        AppTokens.caption.fontSize! * AppTokens.caption.height!;
    final double scaledLine =
        textScaler == null ? captionLine : textScaler.scale(captionLine);
    return const BorderSide().width + // viền trên của BoxDecoration
        AppTokens.space10 * 2 + // padding dọc của Container
        scaledLine + // dòng "Việc tiếp theo: …"
        AppTokens.space8 + // kẽ giữa nhãn và hàng nút
        AppTokens.standardTouchTarget; // thân nút CTA / hàng nút
  }

  /// Khoảng đệm đáy tối thiểu cần chừa cho danh sách cuộn của tab Hôm nay:
  /// toàn bộ chiều cao thanh [maxBarHeight] cộng một quãng thở space12 để
  /// thẻ cuối không dính sát mép thanh.
  ///
  /// Không cộng `MediaQuery.padding.bottom`: khoảng inset hệ thống phía đáy
  /// đã được thanh điều hướng `TabChrome` tiêu trước (SafeArea top:false),
  /// cộng thêm sẽ đúp đệm.
  static double listEndClearance({TextScaler? textScaler}) =>
      maxBarHeight(textScaler: textScaler) + AppTokens.space12;

  const StartSessionBar({
    super.key,
    required this.task,
    required this.minutes,
    required this.onStart,
    this.onDefer,
  });

  @override
  Widget build(BuildContext context) {
    final current = task;
    final canDefer = current != null && onDefer != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space16,
        AppTokens.space10,
        AppTokens.space16,
        AppTokens.space10,
      ),
      decoration: const BoxDecoration(
        color: AppColors.iosCard,
        border: Border(top: BorderSide(color: AppColors.iosSeparator)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Việc tiếp theo: ${current?.title ?? 'Focus tự do'}',
            key: const ValueKey('start-bar-task'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTokens.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.iosTextPrimary,
            ),
          ),
          const SizedBox(height: AppTokens.space8),
          Row(
            children: [
              if (canDefer) ...[
                Expanded(
                  child: SecondaryButton(
                    key: const ValueKey('defer-priority-task'),
                    label: 'Hoãn',
                    onPressed: onDefer,
                  ),
                ),
                const SizedBox(width: AppTokens.space8),
              ],
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  key: const ValueKey('start-session-bar'),
                  label: 'Bắt đầu · $minutes phút',
                  icon: Icons.play_arrow_rounded,
                  // Slice iOS-first: CTA chủ đạo dùng token systemBlue.
                  backgroundColor: AppColors.iosPrimary,
                  onPressed: onStart,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
