import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/storage_service.dart';
import '../shared/widgets/mesh_background.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/exams/domain/models/exam_model.dart';
import '../features/exams/data/preset_exams.dart';
import '../features/exams/presentation/screens/exams_screen.dart';
import '../features/ai_coach/presentation/screens/ai_coach_screen.dart';
import '../features/study/presentation/screens/study_screen.dart';
import '../features/account/presentation/screens/account_screen.dart';

class MainShellScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const MainShellScreen({
    super.key,
    required this.onToggleTheme,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;
  List<ExamModel> _exams = [];
  String? _primaryExamId;
  int _streak = 0;
  int _streakRecord = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    final ids = StorageService.getExamIds();
    if (ids.isEmpty) {
      final defaultExams = [PresetExams.all[0], PresetExams.all[1]];
      for (final e in defaultExams) {
        StorageService.setExamJson(e.id, e.toJsonString());
      }
      StorageService.setExamIds(defaultExams.map((e) => e.id).toList());
      StorageService.setPrimaryExamId(defaultExams[0].id);
      _exams = defaultExams;
      _primaryExamId = defaultExams[0].id;
    } else {
      _exams = ids.map((id) {
        final json = StorageService.getExamJson(id);
        if (json == null) return null;
        return ExamModel.fromJsonString(json);
      }).whereType<ExamModel>().toList();
      _primaryExamId = StorageService.getPrimaryExamId();
    }

    _streak = StorageService.getStreak();
    if (_streak == 0) {
      _streak = 7;
      _streakRecord = 14;
      StorageService.setStreak(_streak);
      StorageService.setStreakRecord(_streakRecord);
    } else {
      _streakRecord = StorageService.getStreakRecord();
    }

    setState(() {});
  }

  void _setPrimaryExam(ExamModel exam) {
    StorageService.setPrimaryExamId(exam.id);
    setState(() {
      _primaryExamId = exam.id;
    });
  }

  void _addExam(ExamModel exam) {
    StorageService.setExamJson(exam.id, exam.toJsonString());
    final ids = StorageService.getExamIds();
    if (!ids.contains(exam.id)) {
      ids.add(exam.id);
      StorageService.setExamIds(ids);
    }
    setState(() {
      _exams.removeWhere((e) => e.id == exam.id);
      _exams.add(exam);
    });
  }

  void _deleteExam(String id) {
    StorageService.removeExam(id);
    setState(() {
      _exams.removeWhere((e) => e.id == id);
      if (_primaryExamId == id) {
        _primaryExamId = _exams.isNotEmpty ? _exams.first.id : null;
        if (_primaryExamId != null) {
          StorageService.setPrimaryExamId(_primaryExamId!);
        }
      }
    });
  }

  ExamModel? get _primaryExam {
    try {
      return _exams.firstWhere((e) => e.id == _primaryExamId);
    } catch (_) {
      return _exams.isNotEmpty ? _exams.first : null;
    }
  }

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: MeshBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Screen Body
              IndexedStack(
                index: _currentIndex,
                children: [
                  HomeScreen(
                    primaryExam: _primaryExam,
                    onExamTap: () => _switchTab(1),
                    onOpenStudy: () => _switchTab(3),
                    onOpenAiCoach: () => _switchTab(2),
                    streak: _streak,
                    streakRecord: _streakRecord,
                  ),
                  ExamsScreen(
                    exams: _exams,
                    primaryExamId: _primaryExamId,
                    onSetPrimary: _setPrimaryExam,
                    onAddExam: _addExam,
                    onDeleteExam: _deleteExam,
                  ),
                  const AiCoachScreen(),
                  const StudyScreen(),
                  AccountScreen(
                    onThemeChanged: widget.onToggleTheme,
                    onDataChanged: _loadInitialData,
                  ),
                ],
              ),

              // Floating Capsule Bottom Navigation Dock
              Positioned(
                left: 20,
                right: 20,
                bottom: 20 + MediaQuery.of(context).padding.bottom * 0.4,
                child: _buildFloatingDock(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingDock(bool isDark) {
    final tabs = [
      {'icon': CupertinoIcons.house_fill, 'label': 'Hôm nay'},
      {'icon': CupertinoIcons.flag_fill, 'label': 'Kỳ thi'},
      {'icon': CupertinoIcons.wand_stars_inverse, 'label': 'AI Coach'},
      {'icon': CupertinoIcons.timer, 'label': 'Tập trung'},
      {'icon': CupertinoIcons.person_crop_circle_fill, 'label': 'Cá nhân'},
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF161526).withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(tabs.length, (i) {
                final active = _currentIndex == i;
                final item = tabs[i];

                return GestureDetector(
                  onTap: () => _switchTab(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: active ? 12 : 8,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient: active
                          ? const LinearGradient(
                              colors: [AppColors.appleIndigo, AppColors.appleBlue],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: AppColors.appleIndigo.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          size: 20,
                          color: active
                              ? Colors.white
                              : (isDark ? Colors.white54 : Colors.black45),
                        ),
                        if (active) ...[
                          const SizedBox(width: 5),
                          Text(
                            item['label'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
