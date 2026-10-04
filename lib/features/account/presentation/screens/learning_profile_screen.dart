import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../study/domain/learning_profile.dart';
import '../../../study/domain/models/study_models.dart';
import '../../../study/domain/repositories/study_session_repository.dart';

/// Hồ sơ học tập (đặc tả mục 17): personalization + learning dashboard.
///
/// Hiển thị các suy luận của AI kèm **Confidence** và **Evidence** để
/// phân biệt fact/inference (mục 10.7), và cho phép **user sửa inference**
/// (mục 17): giá trị tự chỉnh luôn thắng suy luận.
class LearningProfileScreen extends StatefulWidget {
  const LearningProfileScreen({super.key});

  @override
  State<LearningProfileScreen> createState() => _LearningProfileScreenState();
}

class _LearningProfileScreenState extends State<LearningProfileScreen> {
  Map<String, String> get _overrides => {
        'best_time': StorageService.getString('profile_best_time') ?? '',
        'session_minutes':
            StorageService.getString('profile_session_minutes') ?? '',
      };

  List<LearningTrait> _buildTraits() {
    final sessions = StudySessionRepository.instance.getAll();

    final tasks = StorageService.getTodayTaskIds()
        .map(StorageService.getTodayTaskJson)
        .whereType<String>()
        .map((json) {
          try {
            return TodayTask.fromJsonString(json);
          } catch (_) {
            return null;
          }
        })
        .whereType<TodayTask>()
        .toList();

    return buildLearningProfile(
      sessions: sessions,
      tasks: tasks,
      overrides: _overrides,
    );
  }

  Future<void> _editTrait(String key, String currentLabel) async {
    final controller = TextEditingController(
      text: StorageService.getString('profile_$key') ?? '',
    );

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chỉnh sửa: $currentLabel',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'Giá trị bạn đặt sẽ được ưu tiên thay vì suy luận của AI.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: key == 'best_time'
                        ? 'VD: Tối (17h–23h)'
                        : 'VD: 45 phút',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(sheetContext, controller.text.trim()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        child: const Text('Lưu'),
                      ),
                    ),
                  ],
                ),
                if (StorageService.getString('profile_$key')?.isNotEmpty == true)
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext, ''),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted),
                    child: const Text('Xóa giá trị tự chỉnh — dùng suy luận AI'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == null) return;
    if (result.isEmpty) {
      await StorageService.prefs.remove('profile_$key');
    } else {
      StorageService.setString('profile_$key', result);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final traits = _buildTraits();

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Hồ sơ học tập',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: traits.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_search_rounded,
                        size: 44, color: AppColors.textMuted),
                    const SizedBox(height: 10),
                    const Text('Chưa có đủ dữ liệu để suy luận',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    const Text(
                      'Học vài phiên Focus (kèm phản hồi) và lên kế hoạch nhiệm vụ — EduPulse sẽ dần hiểu nhịp học của bạn.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                // Giải thích ngắn gọn về cách hồ sơ hoạt động.
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.psychology_rounded,
                          color: AppColors.purple, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'EduPulse học từ dữ liệu thật khi đủ mẫu. Bạn có thể sửa bất kỳ suy luận nào — giá trị của bạn luôn được ưu tiên.',
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final trait in traits) ...[
                  _TraitCard(
                    trait: trait,
                    onEdit: () => _editTrait(
                      trait.label.contains('Thời gian')
                          ? 'best_time'
                          : 'session_minutes',
                      trait.label,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _TraitCard extends StatelessWidget {
  const _TraitCard({required this.trait, required this.onEdit});

  final LearningTrait trait;
  final VoidCallback onEdit;

  Color get _confidenceColor {
    switch (trait.confidence) {
      case Confidence.high:
        return AppColors.primary;
      case Confidence.medium:
        return AppColors.blue;
      case Confidence.low:
        return AppColors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(trait.label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary)),
              ),
              // Chip confidence: phân biệt fact vs inference (mục 10.7).
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _confidenceColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trait.isUserOverride ? 'Bạn tự chỉnh' : confidenceLabel(trait.confidence),
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: _confidenceColor),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onEdit,
                child: const Icon(Icons.edit_rounded,
                    size: 17, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(trait.value,
              style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(trait.evidence,
              style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
