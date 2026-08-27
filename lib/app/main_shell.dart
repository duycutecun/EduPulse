import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/storage_service.dart';
import '../shared/widgets/mesh_background.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/exams/domain/models/exam_model.dart';
import '../features/exams/presentation/screens/exams_screen.dart';
import '../features/ai_coach/presentation/screens/ai_coach_screen.dart';
import '../features/study/presentation/screens/study_screen.dart';
import '../features/account/presentation/screens/account_screen.dart';

class MainShellScreen extends StatefulWidget {
  final String themeMode;
  final ValueChanged<String> onThemeModeChanged;

  const MainShellScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
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
      _exams = [];
      _primaryExamId = null;
    } else {
      _exams = ids
          .map((id) {
            final json = StorageService.getExamJson(id);
            if (json == null) return null;
            return ExamModel.fromJsonString(json);
          })
          .whereType<ExamModel>()
          .toList();
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
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: MeshBackground(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
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
                themeMode: widget.themeMode,
                onThemeModeChanged: widget.onThemeModeChanged,
                onDataChanged: _loadInitialData,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      {
        'icon': Icons.school_outlined,
        'activeIcon': Icons.school,
        'label': 'Học'
      },
      {
        'icon': Icons.flag_outlined,
        'activeIcon': Icons.flag,
        'label': 'Mục tiêu'
      },
      {
        'icon': Icons.auto_awesome_outlined,
        'activeIcon': Icons.auto_awesome,
        'label': 'AI'
      },
      {
        'icon': Icons.timer_outlined,
        'activeIcon': Icons.timer,
        'label': 'Tập trung'
      },
      {
        'icon': Icons.person_outline,
        'activeIcon': Icons.person,
        'label': 'Tôi'
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final active = _currentIndex == i;
              final item = items[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => _switchTab(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        active
                            ? item['activeIcon'] as IconData
                            : item['icon'] as IconData,
                        size: 26,
                        color: active ? AppColors.green : AppColors.textMuted,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w600,
                          color: active ? AppColors.green : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
