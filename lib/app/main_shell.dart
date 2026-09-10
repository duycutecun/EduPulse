import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import '../core/pwa/pwa_service.dart';
import '../core/utils/storage_service.dart';
import '../core/utils/supabase_service.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/exams/domain/models/exam_model.dart';
import '../features/exams/presentation/screens/exams_page.dart';
import '../features/ai_coach/presentation/screens/ai_coach_screen.dart';
import '../features/study/presentation/screens/study_page.dart';
import '../features/account/presentation/screens/account_screen.dart';
import 'tab_chrome.dart';

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

  // Lazy tab: các tab chỉ được tạo (chạy initState + build lần đầu) khi user
  // mở lần đầu tiên, sau đó giữ nguyên trong IndexedStack. Tránh khởi động
  // chậm vì phải dựng đồng thời cả 3 màn hình (AI chat, Bảng vàng...).
  final List<bool> _visited = List.filled(3, false);
  Widget? _cachedAiCoach;
  Widget? _cachedAccount;

  @override
  void initState() {
    super.initState();
    _visited[0] = true;
    _loadInitialData();
    PwaService.onlineNotifier.addListener(_onNetworkChanged);
  }

  void _onNetworkChanged() {
    if (PwaService.isOnline && SupabaseService.isConfigured) {
      SupabaseService.syncAll();
    }
  }

  @override
  void dispose() {
    PwaService.onlineNotifier.removeListener(_onNetworkChanged);
    super.dispose();
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

  /// Đọc lại streak từ storage (gọi khi task hoàn thành / Pomodoro xong).
  void _reloadStreak() {
    if (!mounted) return;
    setState(() {
      _streak = StorageService.getStreak();
    });
  }

  void _switchTab(int index) {
    if (_currentIndex != index) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentIndex = index;
        _visited[index] = true;
      });
    }
  }

  /// Mở "Mục tiêu" (kỳ thi) và "Tập trung" (Pomodoro/Nhật ký) dưới dạng
  /// full-screen page có nút back — giữ nội dung gốc, chỉ gọn điều hướng.
  void _openExamsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ExamsPage(
          exams: _exams,
          primaryExamId: _primaryExamId,
          onSetPrimary: _setPrimaryExam,
          onAddExam: _addExam,
          onUpdateExam: _updateExam,
          onDeleteExam: _deleteExam,
        ),
      ),
    );
  }

  void _openStudyPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StudyPage(onStreakChanged: _reloadStreak),
      ),
    );
  }

  /// Tạo widget của tab [index]. Các tab chưa từng mở hiển thị rỗng để không
  /// tốn chi phí initState/build khi khởi động; tab đã mở giữ nguyên state.
  Widget _tabAt(int index) {
    switch (index) {
      case 0:
        // Tab mặc định — luôn tạo mới để nhận streak/exam cập nhật từ MainShell.
        return HomeScreen(
          primaryExam: _primaryExam,
          onExamTap: _openExamsPage,
          onOpenStudy: _openStudyPage,
          onOpenAiCoach: () => _switchTab(1),
          streak: _streak,
          isActive: _currentIndex == 0,
          onStreakChanged: _reloadStreak,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _InstallBanner(),
            const _OfflineBanner(),
            Expanded(
              child: TabChrome(
                index: _currentIndex,
                onChanged: _switchTab,
                items: const [
                  NavItem(Icons.home_outlined, Icons.home_rounded, 'Học'),
                  NavItem(Icons.auto_awesome_outlined, Icons.auto_awesome,
                      'AI'),
                  NavItem(Icons.person_outline, Icons.person_rounded, 'Tôi'),
                ],
                children: [
                  _tabAt(0),
                  _visited[1]
                      ? (_cachedAiCoach ??= const AiCoachScreen())
                      : const SizedBox.shrink(),
                  _visited[2]
                      ? (_cachedAccount ??=
                          AccountScreen(onDataChanged: _loadInitialData))
                      : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner cài đặt PWA: Android/Chrome hiện nút "Cài đặt", iOS hiện hướng dẫn
/// "Thêm vào MH chính". Khi đã cài đặt (standalone) hoặc trên native sẽ tự ẩn.
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
    if (PwaService.isStandalone) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: PwaService.installableStream,
      builder: (context, installable, _) {
        if (_dismissed) return const SizedBox.shrink();
        final isIosPlatform = PwaService.isIos || PwaService.isIosSafari;

        if (!installable && !isIosPlatform) {
          return const SizedBox.shrink();
        }

        final isAndroidInstall = installable && !isIosPlatform;
        final bg = isAndroidInstall ? AppColors.greenLight : AppColors.blueSoft;
        final borderColor = isAndroidInstall ? AppColors.green : AppColors.blue;
        final iconColor =
            isAndroidInstall ? AppColors.greenDark : AppColors.blueDark;

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isAndroidInstall
                    ? Icons.download_rounded
                    : Icons.add_to_home_screen_rounded,
                color: iconColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAndroidInstall
                      ? 'Cài đặt EduPulse trên thiết bị!'
                      : 'Cài EduPulse lên Màn hình chính',
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  onTap: () => _showIosInstallSheet(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  void _showIosInstallSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grabber handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),

              // Header with App Icon & Title
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.bgPage,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/mascot.png',
                      fit: BoxFit.contain,
                      // Decode ở đúng kích thước hiển thị thay vì 1033x1880 gốc.
                      cacheWidth: 156,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.school_rounded,
                        color: AppColors.green,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cài đặt EduPulse trên iOS',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Dùng toàn màn hình như ứng dụng App Store',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Feature chips
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFeatureBadge(
                      Icons.bolt_rounded, 'Mở tức thì', AppColors.yellow),
                  _buildFeatureBadge(
                      Icons.wifi_off_rounded, 'Dùng offline', AppColors.blue),
                  _buildFeatureBadge(Icons.fullscreen_rounded, 'Toàn màn hình',
                      AppColors.green),
                ],
              ),
              const SizedBox(height: 18),

              // Steps container
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  children: [
                    _buildStepRow(
                      stepNum: '1',
                      icon: Icons.ios_share,
                      iconColor: AppColors.blue,
                      title: 'Nhấn nút Chia sẻ',
                      subtitle:
                          'Biểu tượng hình vuông có mũi tên lên ở thanh công cụ Safari.',
                    ),
                    Divider(color: AppColors.border, height: 16),
                    _buildStepRow(
                      stepNum: '2',
                      icon: Icons.add_box_outlined,
                      iconColor: AppColors.green,
                      title: 'Chọn "Thêm vào MH chính"',
                      subtitle:
                          'Cuộn xuống danh sách tùy chọn và nhấn "Add to Home Screen".',
                    ),
                    Divider(color: AppColors.border, height: 16),
                    _buildStepRow(
                      stepNum: '3',
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: AppColors.orange,
                      title: 'Nhấn "Thêm" ở góc phải',
                      subtitle:
                          'EduPulse sẽ xuất hiện trên màn hình chính như ứng dụng gốc!',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Đã hiểu',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required String stepNum,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Banner trạng thái offline/online:
/// - Khi mất mạng: hiển thị thông báo nhẹ nhàng dữ liệu được lưu an toàn trên máy
/// - Khi có mạng lại: hiển thị thông báo đã khôi phục và tự động đồng bộ
class _OfflineBanner extends StatefulWidget {
  const _OfflineBanner();

  @override
  State<_OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<_OfflineBanner> {
  bool _wasOffline = false;
  bool _showReconnected = false;
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    PwaService.onlineNotifier.addListener(_handleStatusChange);
    _wasOffline = !PwaService.isOnline;
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    PwaService.onlineNotifier.removeListener(_handleStatusChange);
    super.dispose();
  }

  void _handleStatusChange() {
    final isOnline = PwaService.onlineNotifier.value;
    if (!isOnline) {
      _reconnectTimer?.cancel();
      setState(() {
        _wasOffline = true;
        _showReconnected = false;
      });
    } else if (_wasOffline) {
      setState(() {
        _wasOffline = false;
        _showReconnected = true;
      });
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() => _showReconnected = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PwaService.onlineNotifier,
      builder: (context, isOnline, _) {
        if (isOnline && !_showReconnected) {
          return const SizedBox.shrink();
        }

        final isOffline = !isOnline;
        final bg = isOffline ? const Color(0xFFFFF7ED) : AppColors.greenLight;
        final border = isOffline ? const Color(0xFFFED7AA) : AppColors.green;
        final iconColor =
            isOffline ? const Color(0xFFEA580C) : AppColors.greenDark;
        final textColor =
            isOffline ? const Color(0xFF9A3412) : AppColors.greenDark;
        final icon =
            isOffline ? Icons.wifi_off_rounded : Icons.cloud_done_rounded;
        final text = isOffline
            ? 'Chế độ ngoại tuyến • Dữ liệu đang được lưu an toàn trên máy'
            : 'Đã kết nối lại • Đang tự động đồng bộ dữ liệu...';

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
