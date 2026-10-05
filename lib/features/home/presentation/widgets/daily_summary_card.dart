import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../exams/domain/models/exam_model.dart';
import '../../domain/services/today_service.dart';

/// Widget tổng kết trong ngày (FE-1.4) kèm ngữ cảnh kỳ thi súc tích (FE-1.2).
///
/// Khối dưới cùng là **đếm ngược ngày thi** (ngày/giờ/phút/giây) — thay cho
/// thanh "Tiến độ hôm nay" trước đây. Tiến độ nhiệm vụ vẫn hiển thị đầy đủ ở
/// tiêu đề [TodayMissionCard] ("x/y"), nên không mất thông tin; đổi lại kỳ thi
/// mục tiêu có con số chạy từng giây, đúng thứ giữ nhịp ôn.
class DailySummaryCard extends StatelessWidget {
  final DailySummary summary;
  final ExamModel? primaryExam;
  final VoidCallback onExamTap;

  /// Khoảng thời gian còn lại tới kỳ thi chính. Dùng khi không có
  /// [remainingListenable] (ví dụ test dựng tĩnh).
  final Duration remaining;

  /// Nguồn thời gian còn lại cập nhật mỗi giây từ màn chứa — có nó thì các ô
  /// đếm tự chạy mà không cần cha phải rebuild.
  final ValueListenable<Duration>? remainingListenable;

  const DailySummaryCard({
    super.key,
    required this.summary,
    required this.primaryExam,
    required this.onExamTap,
    this.remaining = Duration.zero,
    this.remainingListenable,
  });

  @override
  Widget build(BuildContext context) {
    final daysLeft = primaryExam?.daysLeft;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: AppTokens.brXl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppTokens.shadowSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Ngữ cảnh kỳ thi súc tích
              Flexible(
                child: InkWell(
                  onTap: onExamTap,
                  borderRadius: AppTokens.brFull,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.space12,
                      vertical: AppTokens.space4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.blueSoft,
                      borderRadius: AppTokens.brFull,
                      border: Border.all(
                          color: AppColors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flag_rounded,
                            size: 14, color: AppColors.blueDark),
                        const SizedBox(width: AppTokens.space4),
                        Flexible(
                          child: Text(
                            primaryExam == null
                                ? 'Chưa chọn kỳ thi mục tiêu'
                                : 'Còn $daysLeft ngày · ${primaryExam!.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTokens.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.blueDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTokens.space2),
                        const Icon(Icons.chevron_right_rounded,
                            size: 14, color: AppColors.blueDark),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space8),
              // Thời gian học thực tế
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space8,
                  vertical: AppTokens.space4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: AppTokens.brSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 14, color: AppColors.primaryDark),
                    const SizedBox(width: AppTokens.space4),
                    Text(
                      summary.studyDurationFormatted,
                      style: AppTokens.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _buildCountdown(),
        ],
      ),
    );
  }

  /// Khối đếm ngược kỳ thi.
  ///
  /// Chỉ hiện khi còn đếm ngược thật (bình thường / ôn tập). Ẩn hẳn khi chưa
  /// chọn kỳ thi, khi đang là ngày thi, hoặc đã thi xong — những lúc đó đã có
  /// thẻ riêng của Exam Mode nói rõ tình trạng, thêm số 0 ở đây chỉ gây nhiễu
  /// và trùng chữ.
  Widget _buildCountdown() {
    final exam = primaryExam;
    if (exam == null) return const SizedBox.shrink();
    final phase = exam.examPhase;
    if (phase == ExamPhase.examDay || phase == ExamPhase.postExam) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTokens.space14),
        Row(
          children: [
            const Icon(Icons.hourglass_bottom_rounded,
                size: AppTokens.iconSm, color: AppColors.primary),
            const SizedBox(width: AppTokens.space6),
            Expanded(
              child: Text(
                'Đếm ngược ngày thi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTokens.sectionTitle,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.space10),
        _buildTiles(),
      ],
    );
  }

  Widget _buildTiles() {
    final listenable = remainingListenable;
    if (listenable == null) {
      return _CountdownTiles(remaining: remaining);
    }
    return ValueListenableBuilder<Duration>(
      valueListenable: listenable,
      builder: (context, rem, _) => _CountdownTiles(remaining: rem),
    );
  }
}

/// 4 ô đều nhau: ngày · giờ · phút · giây. Số âm được kẹp về 0 để không bao
/// giờ hiện "-1" khi kỳ thi vừa qua mốc.
class _CountdownTiles extends StatelessWidget {
  final Duration remaining;

  const _CountdownTiles({required this.remaining});

  @override
  Widget build(BuildContext context) {
    var rem = remaining;
    if (rem.isNegative) rem = Duration.zero;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tile(rem.inDays.toString(), 'ngày'),
        const SizedBox(width: AppTokens.space8),
        _tile((rem.inHours % 24).toString().padLeft(2, '0'), 'giờ'),
        const SizedBox(width: AppTokens.space8),
        _tile((rem.inMinutes % 60).toString().padLeft(2, '0'), 'phút'),
        const SizedBox(width: AppTokens.space8),
        _tile((rem.inSeconds % 60).toString().padLeft(2, '0'), 'giây'),
      ],
    );
  }

  Widget _tile(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cardLight,
              borderRadius: AppTokens.brMd,
              border: Border.all(color: AppColors.border),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: AppTokens.heading1.copyWith(
                  height: 1.1,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTokens.caption,
          ),
        ],
      ),
    );
  }
}
