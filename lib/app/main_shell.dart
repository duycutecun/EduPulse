import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/pwa/pwa_service.dart';
import '../core/utils/storage_service.dart';
import '../shared/widgets/mesh_background.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/exams/domain/models/exam_model.dart';
import '../features/exams/presentation/screens/exams_screen.dart';
import '../features/ai_coach/presentation/screens/ai_coach_screen.dart';
import '../features/study/presentation/screens/study_screen.dart';
import '../features/account/presentation/screens/account_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
    super.key,
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
    _streakRecord = StorageService.getStreakRecord();

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

  void _updateExam(ExamModel exam) {
    StorageService.setExamJson(exam.id, exam.toJsonString());
    setState(() {
      final index = _exams.indexWhere((e) => e.id == exam.id);
      if (index != -1) {
        _exams[index] = exam;
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
          child: Column(
            children: [
              const _InstallBanner(),
              Expanded(
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
                      onUpdateExam: _updateExam,
                      onDeleteExam: _deleteExam,
                    ),
                    const AiCoachScreen(),
                    const StudyScreen(),
                    AccountScreen(
                      onDataChanged: _loadInitialData,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    const items = <_NavItem>[
      _NavItem(Icons.school_outlined, Icons.school, 'Học'),
      _NavItem(Icons.flag_outlined, Icons.flag, 'Mục tiêu'),
      _NavItem(Icons.auto_awesome_outlined, Icons.auto_awesome, 'AI'),
      _NavItem(Icons.timer_outlined, Icons.timer, 'Tập trung'),
      _NavItem(Icons.person_outline, Icons.person, 'Tôi'),
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
                      Container(
                        width: 44,
                        height: 32,
                        decoration: BoxDecoration(
                          color: active ? AppColors.greenSoft : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          active ? item.activeIcon : item.icon,
                          size: 26,
                          color: active ? AppColors.green : AppColors.textMuted,
                          shadows: active
                              ? [
                                  Shadow(
                                    color: AppColors.green.withValues(alpha: 0.4),
                                    blurRadius: 0,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
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

/// Mô tả một mục trong bottom navigation (icon + nhãn), kiểu hóa tường minh
/// thay vì dùng Map với `as` cast để tránh lỗi runtime khi kiểu sai.
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem(this.icon, this.activeIcon, this.label);
}

/// Banner cài đặt PWA: Android/Chrome hiện nút "Cài đặt", iOS hiện hướng dẫn
/// "Add to Home Screen". Trên native (app thật) không hiện gì.
class _InstallBanner extends StatefulWidget {
  const _InstallBanner();

  @override
  State<_InstallBanner> createState() => _InstallBannerState();
}

class _InstallBannerState extends State<_InstallBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (!PwaService.isWeb) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: PwaService.installableStream,
      builder: (context, installable, _) {
        if (_dismissed) return const SizedBox.shrink();
        if (!installable && !PwaService.isIosSafari) {
          return const SizedBox.shrink();
        }

        final isAndroidInstall = installable && !PwaService.isIosSafari;
        final bg = isAndroidInstall ? AppColors.greenLight : AppColors.blueSoft;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isAndroidInstall ? AppColors.green : AppColors.blue,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isAndroidInstall
                    ? Icons.download_rounded
                    : Icons.add_to_home_screen_rounded,
                color: isAndroidInstall ? AppColors.greenDark : AppColors.blueDark,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAndroidInstall
                      ? 'Cài đặt EduPulse trên thiết bị!'
                      : 'Thêm EduPulse vào Màn hình chính',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (isAndroidInstall)
                GestureDetector(
                  onTap: () => PwaService.install(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Cài đặt',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              if (!isAndroidInstall)
                GestureDetector(
                  onTap: () => _showIosHelp(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Cách thêm',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _dismissed = true),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showIosHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border, width: 2),
        ),
        title: const Text(
          'Thêm EduPulse vào Màn hình chính',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Trên iPhone/iPad:\n\n'
          '1. Nhấn nút Chia sẻ (hình vuông + mũi tên lên) ở thanh Safari.\n\n'
          '2. Chọn "Thêm vào Màn hình chính" (Add to Home Screen).\n\n'
          '3. Nhấn "Thêm" ở góc phải.\n\n'
          'EduPulse sẽ xuất hiện như một ứng dụng riêng, dùng được cả khi offline.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Đóng',
              style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
