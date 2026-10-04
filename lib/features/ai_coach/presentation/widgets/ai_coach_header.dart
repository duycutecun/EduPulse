import 'package:flutter/material.dart';
import '../../../../core/ai/ai_models.dart';
import '../../../../core/constants/app_colors.dart';

class AICoachHeader extends StatelessWidget {
  final AIModel model;

  /// Học sinh đã ghim model ở Tôi → Cài đặt → AI nâng cao hay chưa.
  final bool pinned;

  /// Bấm chip AI → giải thích nơi đổi model (không mở picker tại màn chat).
  final VoidCallback onModelTap;
  final VoidCallback onRefresh;
  final VoidCallback onAnalyze;
  final bool showRefresh;
  final bool showAnalyze;
  final VoidCallback? onClose;

  const AICoachHeader({
    super.key,
    required this.model,
    required this.pinned,
    required this.onModelTap,
    required this.onRefresh,
    required this.onAnalyze,
    required this.showRefresh,
    this.showAnalyze = false,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.primaryDark, blurRadius: 0, offset: Offset(0, 3))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset('assets/images/mascot.png',
                  fit: BoxFit.contain,
                  cacheWidth: 120),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wrap thay vì Row: tiêu đề + 2 chip model/Web xuống dòng khi
                // màn hẹp (320px) thay vì tràn ngang.
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('AI Coach',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    // UX 5.11: "Normal users should not need to understand…
                    // model names, provider details." Nên header chỉ nói
                    // "AI tự động" / "AI đã ghim", KHÔNG lộ tên model/nhà
                    // cung cấp. Đổi model nằm ở Tôi → Cài đặt → AI nâng cao.
                    GestureDetector(
                      onTap: onModelTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 11, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(pinned ? 'AI đã ghim' : 'AI tự động',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.blue.withValues(alpha: 0.3), width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.public, size: 11, color: AppColors.blue),
                          SizedBox(width: 4),
                          Text('Web', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.blue)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  pinned
                      ? 'Bạn đã ghim model — bấm để đổi trong Cài đặt.'
                      : 'EduPulse tự chọn model phù hợp câu hỏi.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (showAnalyze)
            GestureDetector(
              onTap: onAnalyze,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.purple, width: 2),
                ),
                child: const Icon(Icons.insights_rounded, size: 18, color: AppColors.purple),
              ),
            ),
          if (showAnalyze) const SizedBox(width: 8),
          if (showRefresh)
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: Icon(Icons.refresh, size: 18, color: AppColors.textMuted),
              ),
            ),
          if (onClose != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClose,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: const Icon(Icons.close_rounded, size: 20, color: AppColors.textPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
