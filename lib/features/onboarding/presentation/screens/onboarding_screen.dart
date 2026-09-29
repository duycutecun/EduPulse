import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/main_shell.dart';
import '../../../../core/ai/ai_models.dart';
import '../../../../core/ai/ai_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/pwa/pwa_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../exams/domain/models/exam_model.dart';
import '../../../exams/domain/preset_exams.dart';
import '../../../study/domain/ai_plan.dart';
import '../../../study/domain/models/study_models.dart';

/// Onboarding theo đặc tả mục 46: flow 3–5 phút, adaptive, thu thập
///
/// - Tên, kỳ thi (preset), ngày thi, target score, quỹ thời gian học/ngày.
///
/// Kết thúc bằng **AI Plan Preview + Countdown**: user xác nhận trước khi
/// task được tạo (AI không tự áp dụng thay đổi). Ai cũng có thể "Bỏ qua"
/// ở bất kỳ bước nào — không ép cấu hình nhiều.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _uuid = Uuid();

  int _step = 0; // 0 tên → 1 kỳ thi → 2 quỹ thời gian → 3 xem trước
  final bool _busy = false;
  bool _generating = false;
  bool _aiFailed = false;

  final _nameCtrl = TextEditingController();

  PresetExam? _preset;
  DateTime _examDate = DateTime.now().add(const Duration(days: 60));
  double? _targetScore;
  int _dailyMinutes = 120;

  List<AiPlanTask> _plan = const [];

  @override
  void initState() {
    super.initState();
    // Rebuild khi tên thay đổi để nút "Tiếp tục" bật/tắt đúng.
    _nameCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Hoàn tất onboarding
  // ------------------------------------------------------------------

  /// Lưu kỳ thi + (nếu có) task từ lộ trình đã duyệt. Nếu không có task
  /// nào được duyệt, seed nhiệm vụ mẫu của preset để Home không trống.
  void _finish() {
    final exam = ExamModel(
      id: _preset?.id ?? _uuid.v4(),
      name: _preset?.name ?? 'Kỳ thi mục tiêu',
      dateTime: _examDate,
      type: _preset != null ? ExamType.preset : ExamType.custom,
      description: _preset?.description,
      emoji: _preset?.emoji ?? '🎯',
      targetScore: _targetScore,
    );
    StorageService.setExamJson(exam.id, exam.toJsonString());
    StorageService.setExamIds([exam.id]);
    StorageService.setPrimaryExamId(exam.id);

    final name = _nameCtrl.text.trim();
    if (name.isNotEmpty) StorageService.setUserName(name);

    // Lấy đề xuất còn lại trong preview (user có thể đã bỏ bớt task).
    final accepted = _plan;
    final List<TodayTask> created = [];
    for (final t in accepted) {
      final assignedDay = t.day.clamp(1, 7);
      final task = TodayTask(
        id: _uuid.v4(),
        title: t.title,
        subject: t.subject,
        priority: t.priority,
        estimateMinutes: t.minutes,
        goalId: exam.id,
        scheduledAt: DateTime(
          _examDate.year,
          _examDate.month,
          _examDate.day,
        ).subtract(Duration(days: 7 - assignedDay)),
      );
      StorageService.setTodayTaskJson(task.id, task.toJsonString());
      created.add(task);
    }

    // Không duyệt đề xuất nào (hoặc AI lỗi) → seed mẫu để có gì đó bắt đầu.
    if (created.isEmpty && _preset != null) {
      for (final t in _preset!.sampleTasks) {
        final task = TodayTask(
          id: _uuid.v4(),
          title: t.title,
          subject: t.subject,
          priority: t.priority,
          estimateMinutes: t.minutes,
          goalId: exam.id,
        );
        StorageService.setTodayTaskJson(task.id, task.toJsonString());
        created.add(task);
      }
    }

    final ids = StorageService.getTodayTaskIds()..addAll(created.map((t) => t.id));
    StorageService.setTodayTaskIds(ids);

    StorageService.setOnboardingDone();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShellScreen()),
    );
  }

  Future<void> _skip() async {
    StorageService.setOnboardingDone();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShellScreen()),
    );
  }

  Future<void> _generatePlan() async {
    if (_generating) return;
    if (!PwaService.isOnline) {
      setState(() => _aiFailed = true);
      return;
    }
    setState(() {
      _generating = true;
      _aiFailed = false;
    });

    final daysLeft = _examDate.difference(DateTime.now()).inDays;
    final prompt = buildAiPlanPrompt(
      examName: _preset?.name ?? 'kỳ thi của bạn',
      daysLeft: daysLeft > 0 ? daysLeft : 180,
      dailyMinutes: _dailyMinutes,
      planDays: 7,
    );

    try {
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
        if (_plan.isEmpty) _aiFailed = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _aiFailed = true;
      });
    }
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: _busy
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                TextButton(
                  onPressed: _skip,
                  child: const Text('Bỏ qua',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
      body: SafeArea(
        child: _busy
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildStep(),
              ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _stepName(key: const ValueKey('step-name'));
      case 1:
        return _stepExam(key: const ValueKey('step-exam'));
      case 2:
        return _stepTime(key: const ValueKey('step-time'));
      default:
        return _stepPreview(key: const ValueKey('step-preview'));
    }
  }

  Widget _header(String emoji, String title, String subtitle, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: ClipOval(
              child: Image.asset(
                'assets/images/mascot.png',
                width: 72,
                height: 72,
                fit: BoxFit.contain,
                cacheWidth: 216,
                errorBuilder: (_, __, ___) => Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.greenSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: AppColors.primary, size: 36),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4)),
          const SizedBox(height: 4),
          Text('$emoji Bước ${_step + 1}/4',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Bước 1: Tên
  // ------------------------------------------------------------------

  Widget _stepName({Key? key}) {
    return SingleChildScrollView(
      key: key,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      child: Column(
        children: [
          _header('👋', 'Chào sĩ tử!',
              'EduPulse giúp bạn đếm ngược kỳ thi và giữ vững đà học mỗi ngày.'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bạn muốn EduPulse gọi bạn là gì?',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'VD: Minh',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) {
                      if (_nameCtrl.text.trim().isNotEmpty) {
                        setState(() => _step = 1);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: _primaryButton(
              label: 'Tiếp tục',
              enabled: _nameCtrl.text.trim().isNotEmpty,
              onTap: () => setState(() => _step = 1),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Bước 2: Kỳ thi + ngày + target
  // ------------------------------------------------------------------

  Widget _stepExam({Key? key}) {
    return SingleChildScrollView(
      key: key,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      child: Column(
        children: [
          _header('🎯', 'Kỳ thi mục tiêu của bạn là gì?',
              'Chọn một kỳ thi mẫu — ngày thi và nhiệm vụ có thể chỉnh sau.'),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                for (final preset in PresetExams.all) ...[
                  _presetCard(preset),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          if (_preset != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ngày thi
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _pickExamDate,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.event_rounded,
                                color: AppColors.blue, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Ngày thi: ${_examDate.day}/${_examDate.month}/${_examDate.year}',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary),
                              ),
                            ),
                            const Icon(Icons.edit_rounded,
                                size: 18, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 16),
                    // Target score (tùy chọn)
                    Row(
                      children: [
                        const Icon(Icons.flag_rounded,
                            color: AppColors.orange, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Mục tiêu điểm (tùy chọn)',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                        ),
                        Switch.adaptive(
                          value: _targetScore != null,
                          onChanged: (v) => setState(() {
                            _targetScore = v ? 8.0 : null;
                          }),
                        ),
                      ],
                    ),
                    if (_targetScore != null)
                      Slider(
                        value: _targetScore!,
                        min: 4,
                        max: 10,
                        divisions: 12,
                        label: _targetScore!.toStringAsFixed(1),
                        onChanged: (v) => setState(() => _targetScore = v),
                      ),
                  ],
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: _primaryButton(
              label: 'Tiếp tục',
              enabled: _preset != null,
              onTap: () {
                setState(() {
                  // Reset ngày theo preset mới chọn.
                  _examDate = _preset!.defaultDate();
                  _step = 2;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickExamDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _examDate.isAfter(now) ? _examDate : now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      helpText: 'Chọn ngày thi',
    );
    if (selected != null) setState(() => _examDate = selected);
  }

  Widget _presetCard(PresetExam preset) {
    final selected = _preset?.id == preset.id;
    return GestureDetector(
      onTap: () => setState(() {
        _preset = preset;
        _examDate = preset.defaultDate();
      }),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppColors.greenSoft,
                shape: BoxShape.circle,
              ),
              child:
                  Center(child: Text(preset.emoji, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(preset.name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(preset.description,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Bước 3: Quỹ thời gian
  // ------------------------------------------------------------------

  Widget _stepTime({Key? key}) {
    return SingleChildScrollView(
      key: key,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      child: Column(
        children: [
          _header('⏱', 'Mỗi ngày bạn học được bao lâu?',
              'EduPulse dùng quỹ thời gian này để chia lộ trình vừa sức — không ép bạn học theo lịch cứng.'),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                for (final m in const [60, 120, 180, 240])
                  _timeOption(m),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: _primaryButton(
              label: 'Xem lộ trình đề xuất',
              enabled: true,
              onTap: () {
                setState(() => _step = 3);
                _generatePlan();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeOption(int minutes) {
    final selected = _dailyMinutes == minutes;
    final label =
        minutes < 120 ? '$minutes phút' : '${minutes ~/ 60} giờ';
    return GestureDetector(
      onTap: () => setState(() => _dailyMinutes = minutes),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const Spacer(),
            if (selected)
              const Text('Mỗi ngày',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Bước 4: Xem trước lộ trình AI + xác nhận
  // ------------------------------------------------------------------

  Widget _stepPreview({Key? key}) {
    final daysLeft = _examDate.difference(DateTime.now()).inDays;
    return SingleChildScrollView(
      key: key,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      child: Column(
        children: [
          _header('🚀', 'Lộ trình mở đầu cho bạn',
              'AI đề xuất nhiệm vụ tuần đầu. Bạn có thể chỉnh từng nhiệm vụ trước khi bắt đầu.'),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GlassCard(
              child: Row(
                children: [
                  Text(_preset?.emoji ?? '🎯',
                      style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_preset?.name ?? 'Kỳ thi mục tiêu',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        Text(
                          'Còn ${daysLeft > 0 ? daysLeft : 0} ngày • $_dailyMinutes phút/ngày',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildPlanArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanArea() {
    if (_generating) {
      return GlassCard(
        child: Column(
          children: const [
            SizedBox(height: 8),
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text('AI đang lập lộ trình...',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            SizedBox(height: 8),
          ],
        ),
      );
    }

    if (_aiFailed || _plan.isEmpty) {
      return GlassCard(
        child: Column(
          children: [
            const Text('😢', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            const Text(
              'Chưa tạo được lộ trình AI lúc này.',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              _aiFailed && !PwaService.isOnline
                  ? 'Bạn đang offline — vẫn có thể bắt đầu với nhiệm vụ mẫu.'
                  : 'Bạn vẫn có thể bắt đầu với nhiệm vụ mẫu cho tuần đầu.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _aiFailed = false;
                });
                _generatePlan();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
            ),
            const SizedBox(height: 2),
            TextButton.icon(
              onPressed: _finish,
              icon: const Icon(Icons.rocket_launch_rounded, size: 18),
              label: const Text('Bắt đầu với nhiệm vụ mẫu'),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Đề xuất tuần đầu (${_plan.length} nhiệm vụ)',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text(
            'Chạm X để bỏ nhiệm vụ bạn không muốn. Không có thay đổi nào được áp dụng cho tới khi bạn bấm "Bắt đầu".',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _plan.length; i++)
            _planRow(i),
          const SizedBox(height: 12),
          _primaryButton(
            label: 'Bắt đầu học',
            enabled: true,
            onTap: _finish,
          ),
        ],
      ),
    );
  }

  Widget _planRow(int index) {
    final t = _plan[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('T${t.day}',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blue)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t.subject} ${t.title}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text('⏱ ${t.minutes} phút • ${_priorityLabel(t.priority)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Bỏ nhiệm vụ này',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _plan.removeAt(index)),
            icon: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  String _priorityLabel(String priority) =>
      priority == 'high' ? '🔥 Quan trọng' : (priority == 'low' ? '🌱 Nhẹ' : '⭐ Vừa');

  Widget _primaryButton({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: enabled ? AppColors.primary : AppColors.border,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                      color: AppColors.primaryDark,
                      blurRadius: 0,
                      offset: Offset(0, 4))
                ]
              : null,
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: enabled ? Colors.white : AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
        ),
      ),
    );
  }
}
