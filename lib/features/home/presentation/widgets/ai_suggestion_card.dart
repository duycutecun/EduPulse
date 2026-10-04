import 'package:flutter/material.dart';
import '../../../../core/utils/feedback_service.dart';

import '../../../../core/ai/ai_insights.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/pwa/pwa_service.dart';

/// Card gợi ý của AI ở Home: AI tự phân tích dữ liệu học tập và đưa ra
/// 2–3 việc cụ thể nên làm, thay vì bắt học sinh tự nghĩ xem nên học gì.
///
/// Nguyên tắc UI:
/// - **Không bao giờ chặn Home.** Gợi ý cũ (quy tắc) hiện ngay, AI thay thế
///   khi có kết quả. Lỗi mạng / hết quota thì giữ nguyên gợi ý cũ, không
///   hiện thẻ lỗi cho người dùng.
/// - Cache 6 giờ ([AiInsights.ttl]) nên mở Home nhiều lần không phát sinh
///   gọi model liên tục.
/// - Bấm vào một gợi ý thì mở AI Coach với câu hỏi đó — gợi ý không phải
///   dòng chữ chết, mà là đầu mối của một cuộc trò chuyện có context.
class AiSuggestionCard extends StatefulWidget {
  const AiSuggestionCard({
    super.key,
    required this.fallback,
    required this.onAskAi,
    this.onOpenInsight,
  });

  /// Gợi ý quy tắc dùng khi AI chưa có kết quả (hoặc không gọi được).
  final String fallback;

  /// Mở AI Coach không kèm câu hỏi (nút "Hỏi AI Coach" như trước).
  final VoidCallback onAskAi;

  /// Mở AI Coach với gợi ý được bấm.
  final ValueChanged<String>? onOpenInsight;

  @override
  State<AiSuggestionCard> createState() => _AiSuggestionCardState();
}

class _AiSuggestionCardState extends State<AiSuggestionCard> {
  AiInsightBundle? _bundle;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // CHỈ đọc cache, không gọi model ở đây. Việc phân tích được kích hoạt
    // một lần mỗi lần mở app từ `main.dart` — nếu gọi trong initState thì mỗi
    // lần dựng Home lại lại bắn request, và Home bị chặn chờ mạng.
    _bundle = AiInsights.cached();
    AiInsights.revision.addListener(_onNewInsights);
  }

  @override
  void dispose() {
    AiInsights.revision.removeListener(_onNewInsights);
    super.dispose();
  }

  /// Có phân tích mới (phân tích nền ở `main.dart` vừa xong, hoặc sau khi
  /// học sinh đổi dữ liệu lớn) → đọc lại cache để hiện ngay.
  void _onNewInsights() {
    if (!mounted) return;
    setState(() => _bundle = AiInsights.cached());
  }

  /// Gọi model. Chỉ chạy khi học sinh bấm nút làm mới — đây là hành động do
  /// người dùng chủ động, nên không phát sinh request ẩn.
  Future<void> _load({bool force = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    final result = await AiInsights.load(force: force);
    if (!mounted) return;
    setState(() {
      _bundle = result ?? _bundle;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    if (!PwaService.isOnline) {
      _toast('Bạn đang ngoại tuyến — cần mạng để AI phân tích lại.');
      return;
    }
    FeedbackService.selection();
    await _load(force: true);
    if (!mounted) return;
    if (_bundle == null) {
      // Có thể hết quota hoặc AI trả về gì đó không đọc được. Nói rõ thay vì
      // im lặng, nhưng vẫn giữ gợi ý quy tắc.
      _toast('AI chưa phân tích được lúc này. Thử lại sau ít phút nhé.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _open(String text) {
    FeedbackService.selection();
    if (widget.onOpenInsight != null) {
      widget.onOpenInsight!(text);
    } else {
      widget.onAskAi();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _bundle?.items ?? const <AiInsight>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.yellow, AppColors.orange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.yellow, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.yellow.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 16, color: AppColors.purple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  items.isEmpty ? 'Gợi ý cho bạn' : 'AI nghĩ bạn nên làm',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
              _RefreshButton(busy: _loading, onTap: _refresh),
            ],
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            Text(
              widget.fallback,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            )
          else
            ...items.map((item) => _InsightRow(
                  insight: item,
                  onTap: () => _open(item.text),
                )),
          const SizedBox(height: 4),
          Row(
            children: [
              GestureDetector(
                onTap: () => _open(items.isEmpty ? '' : items.first.text),
                child: const Text('Hỏi AI Coach',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.purple)),
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(width: 10),
                Text(
                  'Bấm gợi ý để hỏi tiếp',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.insight, required this.onTap});

  final AiInsight insight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, right: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              insight.text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
            if (insight.evidence != null) ...[
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.insights_rounded,
                      size: 11, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      insight.evidence!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const Padding(
        padding: EdgeInsets.all(4),
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.purple,
          ),
        ),
      );
    }
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      padding: EdgeInsets.zero,
      tooltip: 'Phân tích lại',
      icon:
          const Icon(Icons.refresh_rounded, size: 17, color: AppColors.purple),
    );
  }
}
