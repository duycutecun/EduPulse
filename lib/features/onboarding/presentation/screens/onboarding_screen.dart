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
import '../../domain/onboarding_response_parser.dart';
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

  bool _conversationalMode = false;
  int _chatStage = 0; // 0: name, 1: exam, 2: weak subject, 3: time, 4: complete
  String _chatWeakSubject = 'Toán';
  double _chatBaselineScore = 6.0;
  final _chatInputCtrl = TextEditingController();
  final List<Map<String, dynamic>> _chatMessages = [];

  @override
  void initState() {
    super.initState();
    // Rebuild khi tên thay đổi để nút "Tiếp tục" bật/tắt đúng.
    _nameCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _chatMessages.add({
      'isAi': true,
      'text':
          'Chào bạn! Mình là AI Coach của EduPulse 🦉\nMình sẽ giúp bạn lên lộ trình học tập phù hợp nhất. Bạn muốn mình gọi bạn là gì?',
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _chatInputCtrl.dispose();
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

    // Không duyệt đề xuất nào (hoặc AI lỗi hoặc qua chat) → seed mẫu để có gì đó bắt đầu.
    if (created.isEmpty) {
      final samplePreset = _preset ?? PresetExams.all.first;
      for (final t in samplePreset.sampleTasks) {
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

    final ids = StorageService.getTodayTaskIds()
      ..addAll(created.map((t) => t.id));
    StorageService.setTodayTaskIds(ids);

    // Lưu điểm xuất phát môn yếu (để AiCopilotService và Home nhận diện ngay)
    if (_chatWeakSubject.isNotEmpty) {
      final mock = MockScore(
        id: _uuid.v4(),
        subject: _chatWeakSubject,
        score: _chatBaselineScore,
        date: DateTime.now(),
        note: 'Điểm xuất phát khi khởi tạo',
      );
      StorageService.setMockScoreJson(mock.id, mock.toJsonString());
      final mIds = StorageService.getMockScoreIds()..add(mock.id);
      StorageService.setMockScoreIds(mIds);
    }

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
              title: _step == 0
                  ? GestureDetector(
                      onTap: () => setState(
                          () => _conversationalMode = !_conversationalMode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _conversationalMode
                              ? AppColors.purple.withValues(alpha: 0.15)
                              : AppColors.cardLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _conversationalMode
                                ? AppColors.purple
                                : AppColors.border,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _conversationalMode
                                  ? Icons.format_list_bulleted_rounded
                                  : Icons.auto_awesome_rounded,
                              size: 15,
                              color: _conversationalMode
                                  ? AppColors.purple
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _conversationalMode
                                  ? 'Dùng Biểu mẫu'
                                  : 'Trò chuyện AI',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _conversationalMode
                                    ? AppColors.purple
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : null,
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
            : _conversationalMode
                ? _buildConversationalOnboarding()
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
                  fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
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
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: GestureDetector(
              onTap: () => setState(() => _conversationalMode = true),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.purpleSoft.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.purple.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.auto_awesome_rounded,
                        color: AppColors.purple, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Trò chuyện thiết lập cùng AI Coach',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.purple)),
                          Text('Để AI hỏi thăm và tự động tạo lộ trình',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 13, color: AppColors.purple),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
      initialDate:
          _examDate.isAfter(now) ? _examDate : now.add(const Duration(days: 1)),
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
              child: Center(
                  child:
                      Text(preset.emoji, style: const TextStyle(fontSize: 24))),
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
                for (final m in const [60, 120, 180, 240]) _timeOption(m),
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
    final label = minutes < 120 ? '$minutes phút' : '${minutes ~/ 60} giờ';
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
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
          for (var i = 0; i < _plan.length; i++) _planRow(i),
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

  String _priorityLabel(String priority) => priority == 'high'
      ? '🔥 Quan trọng'
      : (priority == 'low' ? '🌱 Nhẹ' : '⭐ Vừa');

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

  // ------------------------------------------------------------------
  // Chế độ Onboarding trò chuyện cùng AI Coach
  // ------------------------------------------------------------------

  void _handleChatSubmit(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;

    _chatInputCtrl.clear();
    setState(() {
      _chatMessages.add({'isAi': false, 'text': clean});

      if (_chatStage == 0) {
        _nameCtrl.text = clean;
        StorageService.setUserName(clean);
        _chatStage = 1;
        _chatMessages.add({
          'isAi': true,
          'text':
              'Rất vui được gặp ${clean}! 🎯 Bạn đang chuẩn bị cho kỳ thi nào?',
        });
      } else if (_chatStage == 1) {
        final lower = clean.toLowerCase();
        PresetExam matched = PresetExams.all.first;
        for (final p in PresetExams.all) {
          if (lower.contains(p.name.toLowerCase()) ||
              lower.contains(p.id.toLowerCase())) {
            matched = p;
            break;
          }
        }

        _preset = matched;
        _examDate =
            OnboardingResponseParser.examDate(clean) ?? matched.defaultDate();
        _chatStage = 2;
        _chatMessages.add({
          'isAi': true,
          'text':
              'Mục tiêu tuyệt vời! Môn học nào bạn thấy cần tăng điểm nhất để AI ưu tiên hỗ trợ?',
        });
      } else if (_chatStage == 2) {
        _chatWeakSubject = clean
            .replaceFirst(RegExp(r'\s*\d+(?:[.,]\d+)?(?:\s*điểm)?'), '')
            .replaceAll(RegExp(r'[,;:]'), '')
            .trim();
        if (_chatWeakSubject.isEmpty) _chatWeakSubject = 'Toán';
        _chatBaselineScore = OnboardingResponseParser.score(clean) ?? 6.0;
        _chatStage = 3;
        _chatMessages.add({
          'isAi': true,
          'text':
              'Đã ghi nhận môn $_chatWeakSubject! Mỗi ngày bạn có thể dành khoảng bao nhiêu thời gian học?',
        });
      } else if (_chatStage == 3) {
        _dailyMinutes = OnboardingResponseParser.dailyMinutes(clean) ?? 120;
        _chatStage = 4;
        _chatMessages.add({
          'isAi': true,
          'text':
              'Hoàn tất phân tích! AI Coach đã tạo xong hồ sơ và phân bổ kế hoạch học tập đầu tiên cho bạn:',
        });
      }
    });
  }

  Widget _buildConversationalOnboarding() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: _chatMessages.length + 1,
            itemBuilder: (context, index) {
              if (index == _chatMessages.length) {
                return _buildChatQuickOptions();
              }
              final msg = _chatMessages[index];
              final isAi = msg['isAi'] as bool;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment:
                      isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isAi) ...[
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.purpleSoft,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.purple.withValues(alpha: 0.3)),
                        ),
                        child: const Center(
                          child: Icon(Icons.school_rounded,
                              size: 18, color: AppColors.purple),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: isAi ? AppColors.cardWhite : AppColors.primary,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isAi ? 4 : 16),
                            bottomRight: Radius.circular(isAi ? 16 : 4),
                          ),
                          border: Border.all(
                            color: isAi ? AppColors.border : AppColors.primary,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          msg['text'] as String,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            fontWeight:
                                isAi ? FontWeight.w500 : FontWeight.w700,
                            color: isAi ? AppColors.textPrimary : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_chatStage < 4)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatInputCtrl,
                    decoration: InputDecoration(
                      hintText: _chatStage == 0
                          ? 'Nhập tên của bạn...'
                          : 'Nhập câu trả lời...',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                    onSubmitted: _handleChatSubmit,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppColors.purple),
                  onPressed: () => _handleChatSubmit(_chatInputCtrl.text),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildChatQuickOptions() {
    if (_chatStage == 0) {
      return _quickChipsRow(['Minh', 'Sĩ tử 2k8', 'Sĩ tử 2k9', 'Học sinh']);
    } else if (_chatStage == 1) {
      return _quickChipsRow([
        'Tốt nghiệp THPT 2026',
        'IELTS 7.0+',
        'Đánh giá năng lực ĐHQG',
        'Tuyển sinh vào 10',
      ]);
    } else if (_chatStage == 2) {
      return _quickChipsRow(
          ['Toán', 'Tiếng Anh', 'Vật lý', 'Hóa học', 'Ngữ văn', 'Sinh học']);
    } else if (_chatStage == 3) {
      return _quickChipsRow([
        '60 phút/ngày',
        '90 phút/ngày',
        '120 phút/ngày',
        '180 phút/ngày',
      ]);
    } else {
      final days = _examDate.difference(DateTime.now()).inDays;
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.purpleSoft.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: AppColors.purple, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Hồ sơ học tập của ${_nameCtrl.text.isEmpty ? "bạn" : _nameCtrl.text}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.purple),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
                '🎯 Kỳ thi: ${_preset?.name ?? "Kỳ thi mục tiêu"} ($days ngày nữa)',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            Text('📈 Môn ưu tiên tăng điểm: $_chatWeakSubject',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            Text('⏰ Quỹ học mục tiêu: $_dailyMinutes phút/ngày',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                label: const Text('Bắt đầu hành trình cùng AI Coach',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                onPressed: _finish,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _quickChipsRow(List<String> options) {
    return Container(
      margin: const EdgeInsets.only(left: 42, top: 4, bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: options.map((opt) {
          return ActionChip(
            label: Text(opt),
            backgroundColor: AppColors.cardWhite,
            side: BorderSide(color: AppColors.purple.withValues(alpha: 0.3)),
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.purple,
            ),
            onPressed: () => _handleChatSubmit(opt),
          );
        }).toList(),
      ),
    );
  }
}
