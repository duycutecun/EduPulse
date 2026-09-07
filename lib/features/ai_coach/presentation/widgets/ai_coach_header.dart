import 'package:flutter/material.dart';
import '../../../../core/ai/ai_models.dart';
import '../../../../core/constants/app_colors.dart';

class AICoachHeader extends StatelessWidget {
  final AIModel model;
  final VoidCallback onModelTap;
  final VoidCallback onRefresh;
  final bool showRefresh;

  const AICoachHeader({
    super.key,
    required this.model,
    required this.onModelTap,
    required this.onRefresh,
    required this.showRefresh,
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
              color: AppColors.green,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.greenDark, blurRadius: 0, offset: Offset(0, 3))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset('assets/images/mascot.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('AI Coach',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onModelTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.green.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(aiModelIcon(model.slug), size: 11, color: AppColors.green),
                            const SizedBox(width: 4),
                            Text(model.label.split(' ').first,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.green)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
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
                  model.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
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
        ],
      ),
    );
  }
}
