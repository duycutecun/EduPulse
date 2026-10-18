import 'package:flutter/material.dart';

import '../../../../core/notifications/adaptive_policy.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/analytics/product_analytics.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../study/domain/models/study_models.dart';
import '../../../study/domain/repositories/study_session_repository.dart';
import '../widgets/account_page_shared.dart';
import '../widgets/appearance_card.dart';

/// Trang con **Cài đặt** của tab "Tôi" — mở bằng cách bấm row "Cài đặt" trên
/// trang chính (drill-down kiểu iOS Settings).
///
/// v2.8: gọn cho user phổ thông — chỉ còn 2 mục user:
/// ① Nhắc học hằng ngày (cảnh báo & nhắc) và ② Cỡ chữ ([FontSizeCard]).
///
/// Toàn bộ phần nâng cao (giao diện & âm thanh, dữ liệu & riêng tư, AI...)
/// chuyển xuống nhóm CHỦ APP ở `about_screen.dart` — mở bằng unlock 7 bấm
/// vào hàng "Phiên bản" trong tab "Thông tin app".
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Nhắc học hằng ngày
  bool _reminderEnabled = false;
  int _reminderHour = 19;
  int _reminderMinute = 0;
  bool _digestEnabled = false;
  bool _advancedReminderEnabled = false;
  bool _analyticsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _reminderEnabled = StorageService.getBool('reminder_enabled') ?? false;
    _reminderHour = StorageService.getInt('reminder_hour') ?? 19;
    _reminderMinute = StorageService.getInt('reminder_minute') ?? 0;
    _digestEnabled = StorageService.getBool('notif_digest_enabled') ?? false;
    _advancedReminderEnabled =
        StorageService.getBool('notif_advanced_enabled') ?? false;
    _analyticsEnabled = ProductAnalytics.instance.enabled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.iosBackground,
      appBar: AppBar(
        title: const Text('Cài đặt',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ══════════════ Nhóm CẢNH BÁO & NHẮC ══════════════
            // Nhắc học + digest 20:30 + thông báo nâng cao — mục ① của user
            // phổ thông (logic giữ nguyên của ReminderCard).
            const AccountSectionHeader('CẢNH BÁO & NHẮC'),
            _buildReminderCard(),

            // ══════════════ Nhóm GIAO DIỆN ══════════════
            // Mục ②: card Cỡ chữ RIÊNG (tách khỏi AppearanceCard cũ — phần
            // còn lại của card chuyển xuống nhóm chủ app).
            const SizedBox(height: 28),
            const AccountSectionHeader('GIAO DIỆN'),
            const FontSizeCard(),
          ],
        ),
      ),
    );
  }

  /// Thẻ cài đặt nhắc học hằng ngày — chỉ trên mobile native.
  Widget _buildReminderCard() {
    if (!NotificationService.isSupported) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const AppIcon(
              Icons.notifications_active_rounded,
              tileSize: 36,
              iconSize: 18,
              color: AppColors.iosWarning,
              bg: AppColors.iosWarningSoft,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nhắc học hằng ngày chỉ khả dụng trên ứng dụng Android/iOS.',
                style: TextStyle(
                    fontSize: 12.5, color: AppColors.iosTextSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final timeLabel =
        '${_reminderHour.toString().padLeft(2, '0')}:${_reminderMinute.toString().padLeft(2, '0')}';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(
                Icons.notifications_active_rounded,
                tileSize: 36,
                iconSize: 18,
                color: AppColors.iosWarning,
                bg: AppColors.iosWarningSoft,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Nhắc học hằng ngày',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.iosTextPrimary)),
              ),
              Switch(
                value: _reminderEnabled,
                activeTrackColor: AppColors.iosPrimary,
                onChanged: (v) => _setReminderEnabled(v),
              ),
            ],
          ),
          if (_reminderEnabled) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickReminderTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.iosBackground,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.iosSeparator, width: 2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 18, color: AppColors.iosWarning),
                          const SizedBox(width: 10),
                          Text(
                            'Nhắc lúc: $timeLabel',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.iosTextPrimary),
                          ),
                          const Spacer(),
                          Icon(Icons.edit_calendar_rounded,
                              size: 18, color: AppColors.iosTextMuted),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () async {
                    await NotificationService.cancel();
                    _setReminderEnabled(false);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.iosError.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.iosError, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Giữ vững thói quen — nhắc nhẹ nhàng mỗi ngày, thưa dần nếu bạn ít mở app. Không dùng để tạo áp lực.',
              style: TextStyle(fontSize: 11.5, color: AppColors.iosTextMuted),
            ),
            const Divider(height: 18),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tóm tắt cuối ngày (Digest)',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              subtitle: const Text(
                  'Một thông báo duy nhất lúc 20:30: nhiệm vụ còn lại, phút focus và đếm ngược kỳ thi.',
                  style: TextStyle(fontSize: 11)),
              value: _digestEnabled,
              onChanged: (v) async {
                setState(() => _digestEnabled = v);
                StorageService.setBool('notif_digest_enabled', v);
                if (v) {
                  // Digest cũng là thông báo thật → phải có quyền trên iOS.
                  if (!await _ensureNotificationPermission()) return;
                  await AdaptivePolicy.scheduleDigest(
                    tasks: _digestTasks(),
                    sessions: const [],
                    primaryExam: null,
                  );
                } else {
                  await NotificationService.cancelId(
                      NotificationService.digestId);
                }
              },
            ),
            const Divider(height: 18),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Thông báo nâng cao (P2)',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              subtitle: const Text(
                  'Báo cáo tuần vào Chủ nhật + nhắc bảo vệ chuỗi (ngôn ngữ nhẹ nhàng).',
                  style: TextStyle(fontSize: 11)),
              value: _advancedReminderEnabled,
              onChanged: (v) async {
                setState(() => _advancedReminderEnabled = v);
                StorageService.setBool('notif_advanced_enabled', v);
                if (v && !await _ensureNotificationPermission()) {
                  setState(() => _advancedReminderEnabled = false);
                  StorageService.setBool('notif_advanced_enabled', false);
                  return;
                }
                // Tự đồng bộ lại nhắc khi bật/tắt — syncReminders xử lý toàn bộ.
                await AdaptivePolicy.syncReminders(
                  reminderEnabled: _reminderEnabled,
                  reminderHour: _reminderHour,
                  reminderMinute: _reminderMinute,
                  tasks: _digestTasks(),
                  sessions: StudySessionRepository.instance.getAll(),
                  primaryExam: null,
                  advancedEnabled: _advancedReminderEnabled,
                  weeklyReportEnabled: _advancedReminderEnabled,
                  streakGuardEnabled: _advancedReminderEnabled,
                );
              },
            ),
            const Divider(height: 18),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Số liệu cải thiện trải nghiệm',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              subtitle: const Text(
                  'Mặc định TẮT. Chỉ lưu tại máy số đếm thao tác (không gửi lên mạng, không chứa nội dung học tập).',
                  style: TextStyle(fontSize: 11)),
              value: _analyticsEnabled,
              onChanged: (v) async {
                setState(() => _analyticsEnabled = v);
                ProductAnalytics.instance.setEnabled(v);
              },
            ),
          ],
        ],
      ),
    );
  }

  List<TodayTask> _digestTasks() => StorageService.getTodayTaskIds()
      .map(StorageService.getTodayTaskJson)
      .whereType<String>()
      .map((json) {
        try {
          return TodayTask.fromJsonString(json);
        } catch (_) {
          return null;
        }
      })
      .whereType<TodayTask>()
      .toList();

  /// Xin quyền thông báo **đúng lúc người dùng bật tính năng**.
  ///
  /// iOS chỉ hỏi một lần duy nhất trong đời app: nếu hỏi sớm lúc mở app mà
  /// người dùng bấm "Không cho phép" thì nhắc học coi như chết vĩnh viễn.
  /// Trả về `false` chỉ khi máy chặn rõ ràng (`null` = Android cũ không cần
  /// quyền runtime → vẫn cho đặt lịch).
  Future<bool> _ensureNotificationPermission() async {
    final granted = await NotificationService.requestPermission();
    if (granted == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Máy đang chặn thông báo. Mở Cài đặt hệ thống → EduPulse → Thông báo để bật nhé.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
    return granted != false;
  }

  Future<void> _setReminderEnabled(bool v) async {
    setState(() => _reminderEnabled = v);
    StorageService.setBool('reminder_enabled', v);
    if (v) {
      if (!await _ensureNotificationPermission()) {
        // Máy chặn thông báo ⇒ không lịch nào được đặt; trả công tắc về OFF để
        // UI/prefs không "nói dối" (trước đây switch vẫn ON dù không có lịch).
        if (mounted) setState(() => _reminderEnabled = false);
        StorageService.setBool('reminder_enabled', false);
        return;
      }
      await NotificationService.scheduleDaily(
        hour: _reminderHour,
        minute: _reminderMinute,
      );
    } else {
      await NotificationService.cancel();
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: AppColors.iosWarning),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _reminderHour = picked.hour;
      _reminderMinute = picked.minute;
    });
    StorageService.setInt('reminder_hour', picked.hour);
    StorageService.setInt('reminder_minute', picked.minute);
    if (_reminderEnabled) {
      await NotificationService.scheduleDaily(
          hour: picked.hour, minute: picked.minute);
    }
  }
}
