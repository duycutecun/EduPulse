import 'package:flutter/material.dart';

import '../../../../core/ai/ai_copilot_service.dart';
import '../../../../core/ai/readiness_score.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/utils/feedback_service.dart';

/// Một hàng hành động duy nhất cho phần AI + công cụ trên trang chủ.
///
/// **Vì sao gộp (U-03):** trước đây Home có ba card AI liên tiếp — card hub
/// Copilot, card quick action và card readiness — chiếm ~340px và chen giữa
/// nhiệm vụ với bản tin. Ba card ấy cạnh tranh chỗ dưới fold và làm loãng điểm
/// nhấn. Nay gộp thành:
///
/// ```text
/// ┌────────────────────────────────────────┐
/// │ ⚡ Hỏi nhanh            [Sẵn sàng thi 62]│  ← dải trạng thái 1 dòng
/// │ [Tập trung][Lộ trình][Hỏi AI][Lịch][Thẻ]│  ← 1 hàng nút
/// └────────────────────────────────────────┘
/// ```
///
/// Dải trạng thái vẫn đọc dữ liệu thật ([AiCopilotService.buildSituationReport]
/// + [ReadinessScore.compute]) nên không mất thông tin nào so với ba card cũ —
/// chỉ là thông tin phụ nằm đúng chỗ và không chen giữa nhiệm vụ với nội dung.
class AiActionsRow extends StatefulWidget {
  final VoidCallback onOpenStudy;
  final VoidCallback onOpenAiChat;
  final ValueChanged<String>? onOpenAiChatWith;
  final VoidCallback onOpenAiPlan;
  final VoidCallback onOpenCalendar;
  final VoidCallback? onTasksChanged;
  final VoidCallback? onStreakChanged;
  final VoidCallback? onOpenFlashcards;

  const AiActionsRow({
    super.key,
    required this.onOpenStudy,
    required this.onOpenAiChat,
    required this.onOpenAiPlan,
    required this.onOpenCalendar,
    this.onOpenAiChatWith,
    this.onTasksChanged,
    this.onStreakChanged,
    this.onOpenFlashcards,
  });

  @override
  State<AiActionsRow> createState() => _AiActionsRowState();
}

class _AiActionsRowState extends State<AiActionsRow> {
  late AiSituationReport _report;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(AiActionsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _report = AiCopilotService.buildSituationReport());
  }

  @override
  Widget build(BuildContext context) {
    final readiness = ReadinessScore.compute();
    final topAction = _report.actions.isEmpty ? null : _report.actions.first;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Dải trạng thái: 1 dòng, đọc nhanh, không chiếm chỗ ──────────
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    FeedbackService.light();
                    widget.onOpenAiChat();
                  },
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          size: 16, color: _report.badgeColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _report.statusTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTokens.bodySubtle.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (readiness != null) ...[
                const SizedBox(width: 8),
                _ReadinessChip(score: readiness.score, band: readiness.band),
              ],
            ],
          ),
          // Hành động 1 chạm do AI chọn theo dữ liệu thật — chỉ hiện khi có.
          if (topAction != null) ...[
            const SizedBox(height: 8),
            _InlineAiAction(
              label: topAction.label,
              icon: topAction.icon,
              color: topAction.color ?? _report.badgeColor,
              onTap: () {
                FeedbackService.light();
                final prompt = _promptFor(topAction);
                final openWith = widget.onOpenAiChatWith;
                if (prompt != null && openWith != null) {
                  openWith(prompt);
                } else {
                  widget.onOpenAiChat();
                }
              },
            ),
          ],
          const SizedBox(height: 10),
          // ── Hàng nút công cụ: một tầm, cuộn ngang, không card nặng ──────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ActionChip(
                  icon: Icons.timer_outlined,
                  label: 'Tập trung',
                  color: AppColors.primary,
                  onTap: widget.onOpenStudy,
                ),
                _ActionChip(
                  icon: Icons.route_outlined,
                  label: 'Lộ trình AI',
                  color: AppColors.purple,
                  onTap: widget.onOpenAiPlan,
                ),
                _ActionChip(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Hỏi AI',
                  color: AppColors.blue,
                  onTap: widget.onOpenAiChat,
                ),
                _ActionChip(
                  icon: Icons.calendar_month_outlined,
                  label: 'Lịch',
                  color: AppColors.orangeDark,
                  onTap: widget.onOpenCalendar,
                ),
                if (widget.onOpenFlashcards != null)
                  _ActionChip(
                    icon: Icons.style_outlined,
                    label: 'Flashcard',
                    color: AppColors.redDark,
                    onTap: widget.onOpenFlashcards!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Câu hỏi gửi kèm khi bấm hành động AI — dùng payload có sẵn thay vì đoán
  /// lại ở UI (đặc tả: AI dẫn tới hành động cụ thể, không dẫn tới 10 đoạn hội
  /// thoại rồi không làm gì).
  String? _promptFor(AiCopilotAction action) {
    final title = action.payload['title']?.toString();
    if (title == null || title.isEmpty) return null;
    return 'Cho tôi gợi ý cụ thể cho "$title" trong kế hoạch hôm nay.';
  }
}

/// Chip điểm sẵn sàng thi — số + nhãn, luôn có màu **và** chữ để không phụ
/// thuộc màu đơn thuần.
class _ReadinessChip extends StatelessWidget {
  final int score;
  final String band;

  const _ReadinessChip({required this.score, required this.band});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.blueLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flag_rounded, size: 11, color: AppColors.blueDark),
          const SizedBox(width: 4),
          Text(
            '$score',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.blueDark,
            ),
          ),
          const SizedBox(width: 3),
          Text('sẵn sàng', style: AppTokens.caption),
        ],
      ),
    );
  }
}

/// Hành động AI 1 chạm, hiện ngay dưới dải trạng thái.
class _InlineAiAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _InlineAiAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTokens.bodySubtle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Nút công cụ dạng chip ngang — nhẹ hơn card vuông cũ, cuộn ngang khi màn
/// hẹp nên không bao giờ tràn.
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FeedbackService.selection();
          onTap();
        },
        // 44px chiều cao tối thiểu — chạm được bằng ngón cái trên mobile.
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTokens.bodySubtle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
