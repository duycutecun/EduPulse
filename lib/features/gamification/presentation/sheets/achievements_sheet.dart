import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../../../core/gamification/achievement_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../domain/achievements.dart';

/// Mở bottom-sheet "Thành tích & huy hiệu".
///
/// Sheet tự lắng nghe `AchievementService.revision` nên khi có huy hiệu mới
/// mở khoá ở nơi khác (ví dụ hoàn task rồi mở sheet) lưới tự dựng lại.
Future<void> showAchievementsSheet(
  BuildContext context, {
  DateTime Function()? clock,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => AchievementsSheet(
      clock: clock ?? DateTime.now,
    ),
  );
}

class AchievementsSheet extends StatefulWidget {
  final DateTime Function() clock;

  const AchievementsSheet({super.key, required this.clock});

  @override
  State<AchievementsSheet> createState() => _AchievementsSheetState();
}

class _AchievementsSheetState extends State<AchievementsSheet> {
  late AchievementStats _stats;
  late List<AchievementState> _states;

  @override
  void initState() {
    super.initState();
    // Dựng lưới đồng bộ trước (không cần context) để màn mở là có nội dung.
    _stats = AchievementService.instance.buildStats(now: widget.clock());
    _states = evaluateAchievements(_stats);
    AchievementService.instance.revision.addListener(_refresh);
    // Reconcile + toast cần ScaffoldMessenger → chỉ gọi sau frame đầu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    AchievementService.instance.revision.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    // Huy hiệu mới có thể sinh ra từ bất kỳ hook nào — khi mở sheet, xét lại
    // để không phải chờ lần hook tiếp theo (mở sheet cũng là một lần reconcile).
    final newly = AchievementService.instance.reconcile(now: widget.clock());
    if (newly.isNotEmpty) {
      // Toast nổi gọn thay vì dialog — không phá trải nghiệm xem lưới.
      ScaffoldMessenger.maybeOf(context)
        ?..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${newly.first.emoji} Huy hiệu mới: ${newly.first.title}',
              style: AppTokens.body,
            ),
            duration: const Duration(seconds: 2),
          ),
        );
    }
    setState(() {
      _stats = AchievementService.instance.buildStats(now: widget.clock());
      _states = evaluateAchievements(_stats);
    });
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCount = _states.where((s) => s.unlocked).length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        // Cuộn được để lưới 12 huy hiệu không tràn trên máy nhỏ.
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                const Text('🏅', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thành tích & huy hiệu',
                    style: AppTokens.heading2,
                  ),
                ),
                Text(
                  '$unlockedCount/${kAchievements.length}',
                  style: AppTokens.body.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SummaryRow(stats: _stats),
            const SizedBox(height: 8),
            Text(
              'Huy hiệu theo hành vi bền vững — không ai thưởng "cày điểm" cả.',
              style: AppTokens.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
              ),
              itemCount: _states.length,
              itemBuilder: (context, i) => _AchievementTile(
                state: _states[i],
                isNewest: false,
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dòng tóm tắt: cấp hiện tại, XP, chuỗi ngày, kỷ lục.
class _SummaryRow extends StatelessWidget {
  final AchievementStats stats;

  const _SummaryRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final xp = StorageService.getXp();
    final level = StorageService.getLevel();
    final (inLevel, need) = StorageService.getLevelProgress();
    final progress = need == 0 ? 1.0 : (inLevel / need).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Cấp $level',
                  style: AppTokens.body.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$xp XP',
                style: AppTokens.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '🔥 ${stats.streak} ngày',
                style: AppTokens.body.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '🏆 Kỷ lục ${stats.streakRecord}',
                style: AppTokens.caption.copyWith(
                    color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Còn $need XP lên Cấp ${level + 1}',
            style: AppTokens.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Một ô huy hiệu: đạt = nền màu + mô tả đọc được; chưa đạt = mờ + "?".
class _AchievementTile extends StatelessWidget {
  final AchievementState state;
  final bool isNewest;

  const _AchievementTile({required this.state, required this.isNewest});

  @override
  Widget build(BuildContext context) {
    final unlocked = state.unlocked;
    final a = state.achievement;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.cardWhite : AppColors.bgPage,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unlocked ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            unlocked ? a.emoji : '🔒',
            style: const TextStyle(fontSize: 26),
          ),
          const SizedBox(height: 6),
          Text(
            a.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTokens.body.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: unlocked ? AppTokens.body.color : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          // `Expanded` để mô tả luôn nằm trong ô — máy nhỏ không tràn ra ngoài.
          Expanded(
            child: Text(
              unlocked ? a.description : 'Hãy học đều sẽ mở khoá',
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
              textAlign: TextAlign.center,
              style: AppTokens.caption.copyWith(
                fontSize: 11,
                color: unlocked
                    ? AppColors.textSecondary
                    : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
