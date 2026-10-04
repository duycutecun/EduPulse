import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../tasks/domain/repositories/task_repository.dart';
import '../../domain/distribute_day.dart';
import '../../domain/models/study_models.dart';

/// Sheet "Phân bố lại cho vừa sức" — dùng chung cho Home và Quick Action
/// "Điều chỉnh lịch" của AI Coach (AI mục 22 + 24).
///
/// **Không gọi LLM**: đây là bài toán sort + tính tổng thời gian trên quỹ ngày,
/// thuộc đúng danh sách "Không gọi AI khi…" của AI-24. Rule engine
/// [proposeDayBalance] đủ để trả lời và luôn chạy được cả ngoại tuyến.
///
/// Trả về số nhiệm vụ đã được dời (0 nếu người dùng bỏ qua). [onChanged] gọi
/// sau khi ghi để màn gọi refresh.
Future<int> showDayBalanceSheet(
  BuildContext context, {
  List<TodayTask>? tasks,
  String title = 'Phân bố lại cho vừa sức 🧺',
  String subtitle =
      'Hôm nay hơi nặng — đề xuất dời bớt sang ngày còn quỹ. Con chốt từng dòng nhé.',
  VoidCallback? onChanged,
}) async {
  final all = tasks ?? TaskRepository.instance.getAllTasks();
  final proposals = proposeDayBalance(tasks: all, now: DateTime.now());
  if (proposals.isEmpty) return 0;

  final accepted = List<bool>.filled(proposals.length, true);

  final result = await showAppBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.4),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < proposals.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ProposalRow(
                    proposal: proposals[i],
                    accepted: accepted[i],
                    onChanged: (v) => setSheetState(() => accepted[i] = v),
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, 0),
                      child: const Text('Để nguyên'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Gom việc cần ghi TRƯỚC, đóng sheet sau: giữ phản
                        // hồi tức thì và không dùng context đã ngắm khi await.
                        final targets = <TodayTask>[];
                        final shifts = <DateTime>[];
                        for (var i = 0; i < proposals.length; i++) {
                          if (!accepted[i]) continue;
                          targets.add(proposals[i].task);
                          shifts.add(proposals[i].proposedStart);
                        }
                        for (var i = 0; i < targets.length; i++) {
                          targets[i].scheduledAt = shifts[i];
                          await TaskRepository.instance.updateTask(targets[i]);
                        }
                        if (!sheetContext.mounted) return;
                        Navigator.pop(sheetContext, targets.length);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(accepted.any((a) => a)
                          ? 'Dời ${accepted.where((a) => a).length} nhiệm vụ'
                          : 'Dời'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  final moved = result ?? 0;
  if (moved > 0) onChanged?.call();
  return moved;
}

class _ProposalRow extends StatelessWidget {
  final MoveProposal proposal;
  final bool accepted;
  final ValueChanged<bool> onChanged;

  const _ProposalRow({
    required this.proposal,
    required this.accepted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = proposal;
    final d = p.proposedStart;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accepted
            ? AppColors.greenSoft.withValues(alpha: 0.4)
            : AppColors.bgPage,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: accepted ? AppColors.primary : AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '→ ${d.day}/${d.month} • ${p.task.estimateMinutes} phút • ${p.reason}',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: accepted,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
