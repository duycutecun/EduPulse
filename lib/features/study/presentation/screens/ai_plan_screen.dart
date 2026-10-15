import 'package:flutter/material.dart';

import '../../../../core/ai/ai_sprint4_planner.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/pwa/pwa_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/state/async_state.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../exams/domain/models/exam_model.dart';

/// Màn hình "Lộ trình AI": chọn quỹ thời gian → AI sinh kế hoạch học nhiều
/// ngày → xem trước → người dùng duyệt để áp dụng vào kế hoạch.
///
/// Đây là **cùng một luồng** với Quick Action "Lập kế hoạch" ở tab AI: cả hai
/// đều gọi [AiStudyPlannerService] rồi hiển thị [AiPlanPreviewSheet]. Trước đây
/// màn này dùng bộ parser riêng trong `features/study/domain/ai_plan.dart` —
/// hai luồng song song, hai cách bóc JSON, hai cách đặt ngày. Nay đã gộp.
///
/// Mục C3 của kế hoạch cải tổ: nối rõ nhánh "phân tích điểm thi thử → đề xuất
/// kế hoạch". [AiStudyPlannerService.generatePlan] vốn đã nạp điểm thử qua
/// `_buildProgressContext`; màn này nay (1) cho người dùng thấy AI sẽ đọc bao
/// nhiêu điểm, (2) chặn khi người dùng tắt quyền cho AI đọc/phân tích, và
/// (3) dùng mô hình trạng thái thống nhất [AsyncStateController] cho
/// loading/data/empty/error (kế hoạch §6.3).
class AiPlanScreen extends StatefulWidget {
  const AiPlanScreen({super.key});

  @override
  State<AiPlanScreen> createState() => _AiPlanScreenState();
}

/// Mô tả lỗi AI thân thiện cho [AiStudyPlannerService.generatePlan].
String _describePlanError(Object error) {
  final text = error.toString();
  if (text.contains('offline')) {
    return 'AI cần kết nối mạng — hãy thử lại khi online!';
  }
  return 'AI chưa trả về lộ trình đúng định dạng — thử lại nhé!';
}

class _AiPlanScreenState extends State<AiPlanScreen> {
  int _dailyMinutes = 120;
  int _planDays = 7;

  /// Chỉ hiển thị vùng kết quả sau lần sinh đầu tiên (mặc định ẩn, không hiện
  /// vòng xoay khi người dùng chưa bấm gì).
  bool _started = false;

  late final AsyncStateController<AiStudyPlan> _plans =
      AsyncStateController<AiStudyPlan>(
    isEmpty: (plan) => plan.isEmpty,
    describeError: _describePlanError,
  );

  @override
  void dispose() {
    _plans.dispose();
    super.dispose();
  }

  ExamModel? get _primaryExam {
    final id = StorageService.getPrimaryExamId();
    if (id == null) return null;
    final json = StorageService.getExamJson(id);
    if (json == null) return null;
    return ExamModel.fromJsonString(json);
  }

  Future<void> _generate() async {
    if (_started && _plans.value.isLoading) return;

    // Quyền riêng tư (§8): AI chỉ đọc/phân tích dữ liệu khi người dùng cho phép.
    final readOk = StorageService.getBool('ai_permission_read') ?? true;
    final analyzeOk = StorageService.getBool('ai_permission_analyze') ?? true;
    if (!readOk || !analyzeOk) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Bạn đã tắt quyền cho AI đọc/phân tích dữ liệu. Bật lại ở Tôi → Cloud & AI để AI lập lộ trình.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ));
      return;
    }

    if (!PwaService.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('AI cần kết nối mạng — hãy thử lại khi online!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ));
      return;
    }

    setState(() => _started = true);

    await _plans.load(() => AiStudyPlannerService.generatePlan(
          daysAhead: _planDays,
          dailyMinutes: _dailyMinutes,
        ));
  }

  /// Mở Preview chung để người dùng tick/bỏ từng nhiệm vụ trước khi áp dụng.
  Future<void> _openPreview() async {
    final plan = _plans.value.data;
    if (plan == null || plan.isEmpty) return;

    await AiPlanPreviewSheet.show(
      context,
      plan: plan,
      onApplied: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _reject() {
    setState(() => _started = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Đã bỏ đề xuất. Kế hoạch hiện tại không thay đổi.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final exam = _primaryExam;
    final scoreCount = StorageService.getMockScoreIds().length;
    final generating = _started && _plans.value.isLoading;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Lộ trình AI',
            style: TextStyle(fontWeight: FontWeight.w800)),
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
                    child: const Center(
                        child: Text('🎯', style: TextStyle(fontSize: 24))),
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
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _scoreAnalysisCard(scoreCount),
            const SizedBox(height: 16),
            Text('Quỹ thời gian mỗi ngày',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
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
            Text('Độ dài lộ trình',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
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
                  boxShadow: const [
                    BoxShadow(
                        color: AppColors.primaryDark,
                        blurRadius: 0,
                        offset: Offset(0, 4))
                  ],
                ),
                child: Center(
                  child: generating
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white))),
                            SizedBox(width: 10),
                            Text('AI đang lập lộ trình...',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('PHÂN TÍCH ĐIỂM THỬ & SINH LỘ TRÌNH',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13)),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_started)
              ValueListenableBuilder<AsyncState<AiStudyPlan>>(
                valueListenable: _plans,
                builder: (context, state, _) => AsyncStateView<AiStudyPlan>(
                  state: state,
                  loadingMessage: 'AI đang đọc điểm thi thử và lập lộ trình...',
                  onRetry: _generate,
                  emptyIcon: Icons.auto_awesome_outlined,
                  emptyTitle: 'AI chưa trả về lộ trình',
                  emptyDescription:
                      'Thử lại, hoặc đổi quỹ thời gian / độ dài lộ trình rồi sinh lại.',
                  emptyActionLabel: 'Thử lại',
                  onEmptyAction: _generate,
                  builder: (context, plan) => _planResult(plan),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _scoreAnalysisCard(int scoreCount) {
    final hasScores = scoreCount > 0;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📊', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phân tích điểm thi thử',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  hasScores
                      ? 'AI sẽ đọc $scoreCount điểm thi thử gần đây để ưu tiên môn còn yếu và chia thời gian hợp lý.'
                      : 'Chưa có điểm thi thử. Thêm ở tab Tiến độ để AI cá nhân hoá lộ trình theo điểm thật.',
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _planResult(AiStudyPlan plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Xem trước thay đổi',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            GestureDetector(
              onTap: _openPreview,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Chấp nhận',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
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
            'Trước: giữ nguyên kế hoạch hiện tại.\nSau khi chấp nhận: thêm ${plan.tasks.length} nhiệm vụ vào từng ngày trong lộ trình. AI không tự áp dụng thay đổi.',
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              for (var i = 0; i < plan.tasks.length; i++) ...[
                if (i > 0) Divider(color: AppColors.border, height: 14),
                _planRow(plan.tasks[i], i + 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: _reject,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Từ chối đề xuất'),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
          ),
        ),
      ],
    );
  }

  Widget _planRow(AiPlannedTask task, int index) {
    final priorityLabel = task.priority == 'high'
        ? '🔥 Quan trọng'
        : (task.priority == 'low' ? '🌱 Nhẹ' : '⭐ Vừa');

    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.blue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text('T${task.day}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.blue)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${task.subject} ${task.title}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                'Ngày ${task.day} • ⏱ ${task.estimateMinutes} phút • $priorityLabel',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
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
            border: Border.all(
                color: sel ? AppColors.primary : AppColors.border, width: 2),
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
            border: Border.all(
                color: sel ? AppColors.blue : AppColors.border, width: 2),
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
