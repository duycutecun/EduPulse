import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../study/domain/models/study_models.dart';

/// Các thẻ trạng thái "chế độ thi" của màn Home (kế hoạch §6.2 — countdown,
/// suggestion block, mission/gamification).
///
/// Tách riêng khỏi `home_screen.dart` để mỗi thẻ có API đầu vào rõ ràng và test
/// được độc lập. Các thẻ ở đây chỉ *trình bày*: không đọc/ghi storage, không gọi
/// mạng.

/// Banner chế độ ôn tập khi còn ≤7 ngày thi (đặc tả mục 39 — 7 ngày trước thi):
/// ưu tiên weakness, high-impact topics và review, giảm workload không cần thiết.
class RevisionModeCard extends StatelessWidget {
  const RevisionModeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.orangeSoft,
              shape: BoxShape.circle,
            ),
            child:
                const Center(child: Text('📚', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chế độ ôn tập đang bật',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ưu tiên ôn điểm yếu và nội dung quan trọng. Giảm bớt nhiệm vụ mới không cần thiết.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ ngày thi (đặc tả mục 39 — Exam Day): thông tin kỳ thi + checklist chuẩn bị,
/// không hiển thị quá nhiều task để giữ Home nhẹ nhàng.
class ExamDayCard extends StatelessWidget {
  const ExamDayCard({super.key});

  @override
  Widget build(BuildContext context) {
    const checklist = [
      'CMND/CCCD + giấy báo dự thi',
      'Bút, thước, máy tính được phép',
      'Bình nước + đồ ăn nhẹ',
      'Đến sớm trước giờ thi 30 phút',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.orange, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🍀', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text(
                'Hôm nay là ngày thi — làm tốt nhé!',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Chỉ cần tập trung ôn nhẹ và chuẩn bị. EduPulse tạm ẩn danh sách nhiệm vụ dài.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          ...checklist.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

/// Phiên bản rút gọn của danh sách nhiệm vụ cho ngày thi (tối đa 3 task).
class TodayMissionCardCompact extends StatelessWidget {
  const TodayMissionCardCompact({
    super.key,
    required this.tasks,
    required this.onToggle,
  });

  final List<TodayTask> tasks;
  final ValueChanged<TodayTask> onToggle;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ôn nhẹ hôm nay (tùy chọn)',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          ...tasks.map(
            (task) => InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onToggle(task),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      task.isDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: task.isDone ? AppColors.primary : AppColors.blue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          decoration:
                              task.isDone ? TextDecoration.lineThrough : null,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '⏱ ${task.estimateMinutes}p',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
