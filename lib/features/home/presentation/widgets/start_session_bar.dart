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
