import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/ai/ai_models.dart';
import '../../../../core/ai/ai_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/pwa/pwa_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../exams/domain/models/exam_model.dart';
import '../../domain/ai_plan.dart';
import '../../domain/models/study_models.dart';

/// Màn hình "Lộ trình AI": chọn quỹ thời gian → AI sinh kế hoạch học nhiều
/// ngày → xem trước → người dùng duyệt để áp dụng vào kế hoạch.
class AiPlanScreen extends StatefulWidget {
  const AiPlanScreen({super.key});

  @override
  State<AiPlanScreen> createState() => _AiPlanScreenState();
}

class _AiPlanScreenState extends State<AiPlanScreen> {
  final _uuid = const Uuid();
  int _dailyMinutes = 120;
  int _planDays = 7;
  bool _generating = false;
  List<AiPlanTask> _plan = [];
  bool _added = false;

  ExamModel? get _primaryExam {
    final id = StorageService.getPrimaryExamId();
    if (id == null) return null;
    final json = StorageService.getExamJson(id);
    if (json == null) return null;
    return ExamModel.fromJsonString(json);
  }

  Future<void> _generate() async {
    if (_generating) return;
    if (!PwaService.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('AI cần kết nối mạng — hãy thử lại khi online!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ));
      return;
    }

    final exam = _primaryExam;
    setState(() {
      _generating = true;
      _added = false;
    });

    final prompt = buildAiPlanPrompt(
      examName: exam?.name ?? 'kỳ thi của bạn',
      daysLeft: exam != null && exam.daysLeft > 0 ? exam.daysLeft : 180,
      dailyMinutes: _dailyMinutes,
      planDays: _planDays,
    );

    final raw = await AiRouter.chat(
      model: AIModel.defaultModel,
      history: const [],
      userMessage: prompt,
      searchWeb: false,
    );

    if (!mounted) return;
    setState(() {
      _generating = false;
      _plan = parseAiPlan(raw);
    });

    if (_plan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('AI chưa trả về lộ trình đúng định dạng — thử lại nhé!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ));
    }
  }

  /// Áp dụng đề xuất sau khi người dùng đã xem trước.
  ///
  /// Không ghi đè nhiệm vụ hiện có: các đề xuất có cùng tiêu đề được giữ
  /// nguyên ở kế hoạch cũ và chỉ những nhiệm vụ mới mới được thêm vào.
  void _acceptPlan() {
    final start = DateTime.now();
    final existingTitles = StorageService.getTodayTaskIds()
        .map((id) => StorageService.getTodayTaskJson(id))
        .whereType<String>()
        .map((json) {
          try {
            return TodayTask.fromJsonString(json).title.toLowerCase();
          } catch (_) {
            return '';
          }
        })
        .toSet();

    var added = 0;
    for (final t in _plan) {
      if (existingTitles.contains(t.title.toLowerCase())) continue;
      final assignedDay = t.day > _planDays ? _planDays : t.day;
      final task = TodayTask(
        id: _uuid.v4(),
        title: t.title,
        subject: t.subject,
        priority: t.priority,
        estimateMinutes: t.minutes,
        goalId: _primaryExam?.id,
        scheduledAt: DateTime(start.year, start.month, start.day)
            .add(Duration(days: assignedDay - 1)),
      );
      StorageService.setTodayTaskJson(task.id, task.toJsonString());
      final ids = StorageService.getTodayTaskIds()..add(task.id);
      StorageService.setTodayTaskIds(ids);
      existingTitles.add(t.title.toLowerCase());
      added++;
    }

    if (added == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Các nhiệm vụ trong đề xuất đã có trong kế hoạch hiện tại.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ));
      return;
    }

    setState(() => _added = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Đã áp dụng: thêm $added nhiệm vụ vào kế hoạch! 🎉'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.primary,
      duration: const Duration(seconds: 2),
    ));
  }

  void _rejectPlan() {
    setState(() => _plan = []);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Đã bỏ đề xuất. Kế hoạch hiện tại không thay đổi.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _editPlanTask(int index) {
    final original = _plan[index];
    final titleController = TextEditingController(text: original.title);
    final minutesController = TextEditingController(text: '${original.minutes}');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chỉnh sửa đề xuất'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Nhiệm vụ'),
              autofocus: true,
            ),
            TextField(
              controller: minutesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Thời lượng (phút)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              final title = titleController.text.trim();
              final minutes = int.tryParse(minutesController.text.trim());
              if (title.isEmpty ||
                  minutes == null ||
                  minutes <= 0 ||
                  minutes > 480) {
                return;
              }
              setState(() {
                _plan[index] = AiPlanTask(
                  title: title,
                  subject: original.subject,
                  priority: original.priority,
                  minutes: minutes,
                  day: original.day,
                );
              });
              Navigator.pop(dialogContext);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exam = _primaryExam;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Lộ trình AI', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: AppColors.greenSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(child: Text('🎯', style: TextStyle(fontSize: 24))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exam?.name ?? 'Chưa có kỳ thi mục tiêu',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          exam != null
                              ? 'Còn ${exam.daysLeft > 0 ? exam.daysLeft : 0} ngày nữa'
                              : 'Thêm kỳ thi ở tab Mục tiêu để AI tối ưu lộ trình',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text('Quỹ thời gian mỗi ngày', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Row(
              children: [
                _durationChip(60, '1 giờ'),
                const SizedBox(width: 8),
                _durationChip(120, '2 giờ'),
                const SizedBox(width: 8),
                _durationChip(180, '3 giờ'),
                const SizedBox(width: 8),
                _durationChip(240, '4 giờ'),
              ],
            ),
            const SizedBox(height: 16),

            Text('Độ dài lộ trình', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Row(
              children: [
                _daysChip(3, '3 ngày'),
                const SizedBox(width: 8),
                _daysChip(7, '7 ngày'),
                const SizedBox(width: 8),
                _daysChip(14, '14 ngày'),
              ],
            ),
            const SizedBox(height: 18),

            GestureDetector(
              onTap: _generate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: AppColors.primaryDark, blurRadius: 0, offset: Offset(0, 4))],
                ),
                child: Center(
                  child: _generating
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
                            SizedBox(width: 10),
                            Text('AI đang lập lộ trình...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('SINH LỘ TRÌNH AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_plan.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Xem trước thay đổi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  if (!_added)
                    GestureDetector(
                        onTap: _acceptPlan,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Chấp nhận', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('✓ Đã thêm', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
              ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.purpleLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Trước: giữ nguyên kế hoạch hiện tại.\nSau khi chấp nhận: thêm ${_plan.length} nhiệm vụ vào từng ngày trong lộ trình. AI không tự áp dụng thay đổi.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 10),
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    for (var i = 0; i < _plan.length; i++) ...[
                      if (i > 0) Divider(color: AppColors.border, height: 14),
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.blue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.blue))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_plan[i].subject} ${_plan[i].title}',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ngày ${_plan[i].day} • ⏱ ${_plan[i].minutes} phút • ${_plan[i].priority == 'high' ? '🔥 Quan trọng' : (_plan[i].priority == 'low' ? '🌱 Nhẹ' : '⭐ Vừa')}',
                                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          if (!_added)
                            IconButton(
                              tooltip: 'Chỉnh sửa đề xuất',
                              onPressed: () => _editPlanTask(i),
                              icon: const Icon(Icons.edit_outlined,
                                  size: 18, color: AppColors.textMuted),
                            ),
                          if (!_added)
                            IconButton(
                              tooltip: 'Bỏ nhiệm vụ khỏi đề xuất',
                              onPressed: () => setState(() => _plan.removeAt(i)),
                              icon: const Icon(Icons.close_rounded,
                                  size: 18, color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (!_added) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: _rejectPlan,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Từ chối đề xuất'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.red),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _durationChip(int minutes, String label) {
    final sel = _dailyMinutes == minutes;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _dailyMinutes = minutes),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : AppColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: 2),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: sel ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _daysChip(int days, String label) {
    final sel = _planDays == days;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _planDays = days),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: sel ? AppColors.blue : AppColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? AppColors.blue : AppColors.border, width: 2),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: sel ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
