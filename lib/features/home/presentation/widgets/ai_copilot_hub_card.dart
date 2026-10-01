import 'package:flutter/material.dart';
import '../../../../core/ai/ai_copilot_service.dart';
import '../../../../core/constants/app_colors.dart';

/// Thẻ Trợ Lý Học Tập Thông Minh (AI Copilot Hub)
///
/// Thay thế thẻ gợi ý tĩnh cũ. Trợ lý đọc trực tiếp dữ liệu học tập thực tế
/// (kỳ thi, điểm thi thử từng môn, nhiệm vụ chưa làm, chuỗi học) và đưa ra:
/// 1. Tình huống thực tế tức thì (Contextual Briefing).
/// 2. Các nút hành động 1 chạm (1-click actionable) liên kết thẳng vào các
///    phần khác của app: bắt đầu Pomodoro, thêm nhiệm vụ, test trắc nghiệm 5 câu.
/// 3. Các gợi ý câu hỏi thông minh giúp mở nhanh Trợ lý AI.
class AiCopilotHubCard extends StatefulWidget {
  final VoidCallback onOpenAiChat;
  final ValueChanged<String>? onOpenAiChatWith;
  final VoidCallback? onTasksChanged;
  final VoidCallback? onStreakChanged;

  const AiCopilotHubCard({
    super.key,
    required this.onOpenAiChat,
    this.onOpenAiChatWith,
    this.onTasksChanged,
    this.onStreakChanged,
  });

  @override
  State<AiCopilotHubCard> createState() => _AiCopilotHubCardState();
}

class _AiCopilotHubCardState extends State<AiCopilotHubCard> {
  late AiSituationReport _report;

  @override
  void initState() {
    super.initState();
    _refreshReport();
  }

  void _refreshReport() {
    setState(() {
      _report = AiCopilotService.buildSituationReport();
    });
  }

  @override
  void didUpdateWidget(AiCopilotHubCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshReport();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _report.badgeColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _report.badgeColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Badge tình huống + Nút mở chat trợ lý
          Row(
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _report.badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _report.badgeColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_report.badgeIcon,
                          size: 13, color: _report.badgeColor),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _report.badgeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _report.badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onOpenAiChat,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.purpleSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 13, color: AppColors.purple),
                      SizedBox(width: 5),
                      Text(
                        'Hỏi Trợ lý',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tiêu đề phân tích tình huống
          Text(
            _report.headline,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),

          // Lời khuyên dựa trên dữ liệu thật
          Text(
            _report.details,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),

          // Các nút hành động liên kết trực tiếp (1-Click Actionable Buttons)
          if (_report.actions.isNotEmpty) ...[
            const Text(
              'HÀNH ĐỘNG ĐỀ XUẤT (1 CHẠM):',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _report.actions.map((act) {
                final btnColor = act.color ?? AppColors.primary;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      AiCopilotService.executeAction(
                        context,
                        act,
                        onTasksChanged: () {
                          _refreshReport();
                          widget.onTasksChanged?.call();
                        },
                        onStreakChanged: () {
                          _refreshReport();
                          widget.onStreakChanged?.call();
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: btnColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: btnColor.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(act.icon, size: 15, color: btnColor),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              act.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: btnColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Câu hỏi gợi ý để trò chuyện với Trợ lý
          if (_report.promptSuggestions.isNotEmpty) ...[
            const Divider(height: 18, color: AppColors.border),
            const Text(
              'GỢI Ý HỎI TRỢ LÝ:',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            ..._report.promptSuggestions.take(2).map((prompt) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () {
                    if (widget.onOpenAiChatWith != null) {
                      widget.onOpenAiChatWith!(prompt);
                    } else {
                      widget.onOpenAiChat();
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.arrow_right_rounded,
                            size: 18, color: AppColors.purple),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            prompt,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
