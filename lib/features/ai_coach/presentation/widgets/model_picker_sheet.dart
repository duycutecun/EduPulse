import 'package:flutter/material.dart';
import '../../../../core/ai/ai_models.dart';
import '../../../../core/ai/free_models_catalog.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';

void showModelPickerSheet({
  required BuildContext context,
  required AIModel currentModel,
  required ValueChanged<AIModel> onSelect,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.cardWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                'Chọn model AI',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Model miễn phí từ OpenRouter, tự cập nhật mỗi ngày.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ValueListenableBuilder<List<AIModel>?>(
                valueListenable: FreeModelsCatalog.runtimeModels,
                builder: (ctx, runtime, _) {
                  final list = runtime ?? AIModel.definitions;
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) {
                      final m = list[i];
                      final selected = m.slug == currentModel.slug;
                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        borderColor:
                            selected ? AppColors.primary : AppColors.border,
                        customColor: selected
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : AppColors.cardWhite,
                        onTap: () {
                          onSelect(m);
                          Navigator.pop(ctx);
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.bgPage,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(aiModelIcon(m.slug),
                                  size: 18,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textSecondary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: selected
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    m.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              const Icon(Icons.check_circle,
                                  color: AppColors.primary, size: 20),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
