import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/feedback_service.dart';
import '../../../study/domain/active_study_session.dart';

/// Đặc tả 5.2 — thẻ "phiên đang dở" trên màn Hôm nay.
///
/// Vì sao cần: nếu app bị hệ điều hành kill giữa một vòng focus (hoặc người
/// học thoát ra rồi quên), ảnh chụp phiên vẫn nằm trong storage nhưng màn Hôm
/// nay không hề nhắc — người học mở lại app chỉ thấy danh sách nhiệm vụ và dễ
/// bắt đầu một phiên mới, làm mất quãng thời gian đã học. Thẻ này là lối quay
/// lại duy nhất nhìn thấy được ngay khi mở app.
///
/// Không tự khôi phục: chỉ mời, việc chốt "Tiếp tục / Kết thúc" vẫn do người
/// học quyết ở phiên bản đầy đủ trong màn Tập trung (BE-3.2).
class ActiveSessionResumeCard extends StatelessWidget {
  final ActiveStudySession session;
  final DateTime Function() clock;

  /// Mở màn Tập trung — nơi sẽ hỏi "tiếp tục hay kết thúc phiên".
  final VoidCallback onResume;

  const ActiveSessionResumeCard({
    super.key,
    required this.session,
    required this.clock,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = session.remainingAt(clock());
    final minutes = (remaining / 60).ceil();
    final label = session.taskTitle?.trim().isNotEmpty == true
        ? session.taskTitle!
        : session.subject;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.iosWarningSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.iosWarning.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined,
              size: 22, color: AppColors.iosWarningDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bạn có phiên học đang dở',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.iosWarningDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  session.isBreak
                      ? 'Đang nghỉ • còn $minutes phút'
                      : '$label • còn $minutes phút',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.iosTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {
              FeedbackService.selection();
              onResume();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.iosWarningDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(
              'Tiếp tục',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
