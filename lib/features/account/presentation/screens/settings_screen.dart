import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:convert';

import '../../../../core/ai/ai_models.dart';
import '../../../../core/notifications/adaptive_policy.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/analytics/product_analytics.dart';
import '../../../../core/privacy/share_audit_log.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/data_transfer.dart';
import '../../../../core/utils/feedback_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../study/domain/models/study_models.dart';
import '../../../study/domain/repositories/study_session_repository.dart';
import '../widgets/account_page_shared.dart';
import '../widgets/appearance_card.dart';
import 'privacy_data_screen.dart';

/// Trang con **Cài đặt** của tab "Tôi" — mở bằng cách bấm row "Cài đặt" trên
/// trang chính (drill-down kiểu iOS Settings).
///
/// Gom phần "tuỳ chỉnh hành vi app" của tab Cài đặt cũ: cảnh báo & nhắc,
/// giao diện & âm thanh, dữ liệu & riêng tư — người dùng chỉnh 1 lần rồi quên.
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
  bool _aiMayRead = true;
  bool _aiMayAnalyze = true;
  bool _mascotEnabled = true;
  bool _reduceMotion = false;

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
    _aiMayRead = StorageService.getBool('ai_permission_read') ?? true;
    _aiMayAnalyze = StorageService.getBool('ai_permission_analyze') ?? true;
    _mascotEnabled = StorageService.getBool('mascot_enabled') ?? true;
    _reduceMotion = StorageService.getBool('reduce_motion') ?? false;
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
            const AccountSectionHeader('CẢNH BÁO & NHẮC'),
            // Nhắc học + digest 20:30 + thông báo nâng cao (báo cáo tuần Chủ
            // nhật, streak guard) — giữ nguyên logic của ReminderCard.
            _buildReminderCard(),

            // ══════════════ Nhóm GIAO DIỆN & ÂM THANH ══════════════
            const SizedBox(height: 28),
            const AccountSectionHeader('GIAO DIỆN & ÂM THANH'),
            const AppearanceCard(),
            const SizedBox(height: 10),
            _buildDisplayPrefsCard(),

            // ══════════════ Nhóm DỮ LIỆU & RIÊNG TƯ ══════════════
            const SizedBox(height: 28),
            const AccountSectionHeader('DỮ LIỆU & RIÊNG TƯ',
                subtitle: 'AI chỉ sử dụng dữ liệu khi bạn cho phép.'),
            _buildDataPrefsCard(),
          ],
        ),
      ),
    );
  }

  /// Thẻ công tắc trải nghiệm hiển thị/âm thanh.
  ///
  /// Đặc tả 5.14 — hai mục rung/âm thanh phải tắt được thật, nên mọi rung /
  /// âm thanh đều đi qua FeedbackService thay vì gọi thẳng platform.
  Widget _buildDisplayPrefsCard() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: accountTilePadding,
            title: const Text('Hiện linh vật'),
            value: _mascotEnabled,
            onChanged: (value) => setState(() {
              _mascotEnabled = value;
              StorageService.setBool('mascot_enabled', value);
            }),
          ),
          const Divider(height: 1, indent: 16),
          SwitchListTile.adaptive(
            contentPadding: accountTilePadding,
            title: const Text('Giảm chuyển động'),
            value: _reduceMotion,
            onChanged: (value) => setState(() {
              _reduceMotion = value;
              StorageService.setBool('reduce_motion', value);
            }),
          ),
          const Divider(height: 1, indent: 16),
          SwitchListTile.adaptive(
            contentPadding: accountTilePadding,
            title: const Text('Rung'),
            subtitle: const Text('Rung nhẹ khi bấm nút, tick nhiệm vụ, hết giờ',
                style: TextStyle(fontSize: 11)),
            value: FeedbackService.hapticsEnabled,
            onChanged: (value) =>
                setState(() => FeedbackService.setHaptics(value)),
          ),
          const Divider(height: 1, indent: 16),
          SwitchListTile.adaptive(
            contentPadding: accountTilePadding,
            title: const Text('Âm thanh'),
            subtitle: const Text(
                'Âm báo hoàn thành phiên và tương tác linh vật',
                style: TextStyle(fontSize: 11)),
            value: FeedbackService.soundEnabled,
            onChanged: (value) =>
                setState(() => FeedbackService.setSound(value)),
          ),
        ],
      ),
    );
  }

  /// Thẻ nhóm DỮ LIỆU & RIÊNG TƯ: quyền AI, AI nâng cao, xuất nhập dữ liệu,
  /// quyền riêng tư và xóa dữ liệu AI. Thứ tự từ đọc-hiểu đến hành động phá
  /// hủy (xóa lịch sử AI) — mục phá hủy luôn nằm cùng.
  Widget _buildDataPrefsCard() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: accountTilePadding,
            title: const Text('AI đọc nhiệm vụ và phiên học'),
            subtitle: const Text('Dùng để trả lời theo ngữ cảnh',
                style: TextStyle(fontSize: 11)),
            value: _aiMayRead,
            onChanged: (value) => setState(() {
              _aiMayRead = value;
              StorageService.setBool('ai_permission_read', value);
              ShareAuditLog.log(ShareAuditKinds.aiRead, value ? 'bật' : 'tắt');
            }),
          ),
          const Divider(height: 1, indent: 16),
          SwitchListTile.adaptive(
            contentPadding: accountTilePadding,
            title: const Text('AI phân tích tiến độ'),
            subtitle: const Text(
                'Tạo insight và đề xuất, không tự sửa kế hoạch',
                style: TextStyle(fontSize: 11)),
            value: _aiMayAnalyze,
            onChanged: _aiMayRead
                ? (value) => setState(() {
                      _aiMayAnalyze = value;
                      StorageService.setBool('ai_permission_analyze', value);
                      ShareAuditLog.log(
                          ShareAuditKinds.aiAnalyze, value ? 'bật' : 'tắt');
                    })
                : null,
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            contentPadding: accountTilePadding,
            leading:
                const Icon(Icons.tune_rounded, color: AppColors.iosSecondary),
            title: const Text('AI nâng cao'),
            subtitle: const Text('Chọn model, quyền AI, lịch sử hội thoại',
                style: TextStyle(fontSize: 11)),
            onTap: _openAiAdvancedSheet,
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            contentPadding: accountTilePadding,
            leading:
                const Icon(Icons.ios_share_rounded, color: AppColors.iosInfo),
            title: const Text('Xuất / nhập dữ liệu'),
            subtitle: const Text('JSON đầy đủ, CSV nhật ký, Markdown ghi chú',
                style: TextStyle(fontSize: 11)),
            onTap: _openDataSheet,
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            contentPadding: accountTilePadding,
            leading: const Icon(Icons.privacy_tip_outlined,
                color: AppColors.iosSuccess),
            title: const Text('Quyền riêng tư & dữ liệu'),
            subtitle: const Text('Thời hạn lưu, xoá dữ liệu cá nhân',
                style: TextStyle(fontSize: 11)),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const PrivacyDataScreen(),
            )),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            contentPadding: accountTilePadding,
            leading: const Icon(Icons.delete_sweep_outlined,
                color: AppColors.iosError),
            title: const Text('Xóa lịch sử trò chuyện AI'),
            onTap: _clearAiHistory,
          ),
        ],
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

  /// Đặc tả UX 5.11 — "AI nâng cao": chọn model, hành vi AI, lịch sử hội thoại.
  ///
  /// Mặc định app tự chọn model phù hợp (Auto); chỉ khi học sinh chủ động ghim
  /// model ở đây thì màn AI mới dùng model đó. Không lộ tên nhà cung cấp /
  /// thông số kỹ thuật ra UI chính (UX 5.11 "Never show").
  void _openAiAdvancedSheet() {
    final runtime = AIModel.runtimeDefinitions;
    final models =
        (runtime != null && runtime.isNotEmpty) ? runtime : AIModel.definitions;

    Widget modelRow(AIModel? model, {required bool isAuto}) {
      final slug = isAuto ? '' : model!.slug;
      final selected = StorageService.getAiModel() == slug;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: Icon(
          isAuto ? Icons.auto_awesome_rounded : aiModelIcon(model!.slug),
          color: selected ? AppColors.iosPrimary : AppColors.iosTextMuted,
          size: 20,
        ),
        title: Text(
          isAuto ? 'Tự động (khuyên dùng)' : model!.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          isAuto
              ? 'Tự chuyển model theo độ khó câu hỏi.'
              : (model!.description.isEmpty ? model.slug : model.description),
          style: const TextStyle(fontSize: 11, color: AppColors.iosTextMuted),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded,
                color: AppColors.iosPrimary, size: 20)
            : null,
        onTap: () {
          StorageService.setAiModel(slug);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isAuto
                  ? 'Đã chuyển AI về chế độ tự động chọn model.'
                  : 'Đã ghim model ${model!.label}.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.iosCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) => ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                const Text('AI nâng cao',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'EduPulse tự chọn model phù hợp với từng câu hỏi. Bạn có thể '
                  'ghin một model nếu muốn.',
                  style: TextStyle(fontSize: 12, color: AppColors.iosTextMuted),
                ),
                const SizedBox(height: 10),
                modelRow(null, isAuto: true),
                const Divider(),
                for (final m in models) modelRow(m, isAuto: false),
                const Divider(),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tự phân tích ảnh kèm theo'),
                  subtitle: const Text(
                      'Gửi ảnh chụp bài/đề vào AI ngay khi chọn, không cần gõ prompt.',
                      style: TextStyle(fontSize: 11)),
                  value: StorageService.getAiAutoReadImage(),
                  onChanged: (v) {
                    StorageService.setAiAutoReadImage(v);
                    ShareAuditLog.log(
                        ShareAuditKinds.aiAutoImage, v ? 'bật' : 'tắt');
                    setSheetState(() {});
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_sweep_outlined,
                      color: AppColors.iosError),
                  title: const Text('Xóa lịch sử trò chuyện AI',
                      style: TextStyle(color: AppColors.iosError)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _clearAiHistory();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Sheet Xuất / nhập / xóa dữ liệu cục bộ (đặc tả mục 19).
  void _openDataSheet() {
    final c = DataTransfer.counts();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.iosCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dữ liệu của bạn',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                '${c.tasks} nhiệm vụ • ${c.notes} ghi chú • ${c.sessions} phiên focus • ${c.exams} kỳ thi • ${c.logs} nhật ký',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.iosTextMuted),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.data_object_rounded,
                    color: AppColors.iosInfo),
                title: const Text('Xuất JSON (đầy đủ — dùng để nhập lại)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Clipboard.setData(
                      ClipboardData(text: DataTransfer.exportJson()));
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Đã sao chép JSON đầy đủ vào clipboard.')));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.table_chart_rounded,
                    color: AppColors.iosPrimary),
                title: const Text('Xuất nhật ký học (CSV)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Clipboard.setData(
                      ClipboardData(text: DataTransfer.exportStudyLogCsv()));
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Đã sao chép CSV nhật ký vào clipboard.')));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_rounded,
                    color: AppColors.iosWarning),
                title: const Text('Xuất ghi chú (Markdown)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Clipboard.setData(
                      ClipboardData(text: DataTransfer.exportNotesMarkdown()));
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Đã sao chép Markdown ghi chú vào clipboard.')));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.download_rounded,
                    color: AppColors.iosSecondary),
                title: const Text('Nhập từ JSON'),
                subtitle: const Text(
                    'Chỉ thêm bản ghi mới, không ghi đè dữ liệu hiện có.',
                    style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final picked = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['json'],
                  );
                  if (picked.isEmpty) return;
                  final bytes = await picked.first.readAsBytes();
                  final text = utf8.decode(bytes, allowMalformed: true);
                  if (!mounted) return;
                  final result = DataTransfer.importJson(text);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result.error.isNotEmpty
                        ? result.error
                        : 'Đã nhập ${result.imported} bản ghi, bỏ qua ${result.skipped} bản trùng.'),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_forever_rounded,
                    color: AppColors.iosError),
                title: const Text('Xóa dữ liệu học cục bộ',
                    style: TextStyle(color: AppColors.iosError)),
                subtitle: const Text(
                    'Nhiệm vụ, ghi chú, phiên, kỳ thi, nhật ký. Cài đặt và lịch sử AI giữ nguyên.',
                    style: TextStyle(fontSize: 11)),
                onTap: () => _confirmDeleteStudyData(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteStudyData(BuildContext sheetContext) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa dữ liệu học?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Hành động này không thể hoàn tác. Xuất JSON trước nếu muốn giữ lại.'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Gõ XÓA để xác nhận',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(
                dialogContext, controller.text.trim().toUpperCase() == 'XÓA'),
            style: TextButton.styleFrom(foregroundColor: AppColors.iosError),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    DataTransfer.deleteAllStudyData();
    if (!sheetContext.mounted) return;
    Navigator.pop(sheetContext);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa dữ liệu học cục bộ.')));
  }

  /// Xóa AI memory (mục 19 — Delete): lịch sử chat + feedback + nháp
  /// note — toàn bộ thứ AI dùng để cá nhân hóa. Có backup trong phiên
  /// để Undo ngay (undo window).
  Future<void> _clearAiHistory() async {
    final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Xóa bộ nhớ AI?'),
              content: const Text(
                  'Lịch sử trò chuyện, phản hồi 👍/👎 và bản nháp ghi chú '
                  'trên thiết bị này sẽ bị xóa. AI sẽ quay về trạng thái như mới cài.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Hủy')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Xóa',
                        style: TextStyle(
                            color: AppColors.iosError,
                            fontWeight: FontWeight.w800)))
              ],
            ));
    if (accepted != true) return;

    // Backup để Undo trong phiên (undo window — mục 19).
    final chatBackup = StorageService.getAiChatHistory();
    final feedbackIds =
        StorageService.prefs.getStringList('ai_feedback_ids') ?? [];
    final feedbackBackup = <String, String?>{
      for (final id in feedbackIds)
        'ai_feedback_$id': StorageService.getString('ai_feedback_$id'),
      'ai_feedback_ids': feedbackIds.isNotEmpty ? feedbackIds.join(',') : null,
    };
    final draftBackup = StorageService.getString('note_draft_v1');

    // Xóa toàn bộ AI memory.
    StorageService.clearAiChatHistory();
    for (final id in feedbackIds) {
      StorageService.prefs.remove('ai_feedback_$id');
    }
    StorageService.prefs.remove('ai_feedback_ids');
    StorageService.prefs.remove('note_draft_v1');

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Đã xóa bộ nhớ AI.'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Hoàn tác',
          onPressed: () {
            // Undo: khôi phục nguyên trạng.
            if (chatBackup != null) {
              StorageService.setAiChatHistory(chatBackup);
            }
            feedbackBackup.forEach((key, value) {
              if (value != null && key != 'ai_feedback_ids') {
                StorageService.setString(key, value);
              }
            });
            final ids = feedbackBackup['ai_feedback_ids'];
            if (ids != null) {
              StorageService.prefs
                  .setStringList('ai_feedback_ids', ids.split(','));
            }
            if (draftBackup != null) {
              StorageService.setString('note_draft_v1', draftBackup);
            }
          },
        ),
      ));
  }
}
