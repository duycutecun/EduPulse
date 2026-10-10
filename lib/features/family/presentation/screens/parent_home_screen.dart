import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/family/family_models.dart';
import '../../../../core/family/family_notify_service.dart';
import '../../../../core/family/family_service.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/utils/auth_service.dart';
import '../../../../core/utils/feedback_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
import 'child_report_screen.dart';

/// Màn hình của TÀI KHOẢN PHỤ HUYNH — nửa còn lại của "Cửa sổ tin cậy".
///
/// Nguyên tắc:
/// - Ba mẹ **chỉ** thấy báo cáo con đã chủ động gửi. Không có bảng đọc dữ liệu
///   thô, không có "theo dõi trực tiếp" — đúng giao kèo với học sinh.
/// - Liên kết bằng mã 8 chữ số con đọc cho ba mẹ; ba mẹ cũng ngắt được liên kết.
/// - Nói thật trạng thái: chưa đăng nhập, chưa liên kết, con chưa gửi báo cáo —
///   ba trạng thái khác nhau, không gộp thành một màn trống.
/// - **Theo dõi liên tục**: con bật "Cập nhật trực tiếp" thì màn này tự cập
///   nhật khi con đổi số liệu (tín hiệu Realtime, kèm nhịp hỏi định kỳ làm
///   lưới an toàn) — ba mẹ không phải kéo làm mới.
class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen>
    with WidgetsBindingObserver {
  final TextEditingController _codeCtrl = TextEditingController();

  /// Nhịp hỏi lại danh sách con. Realtime là đường tắt; đây là nguồn đúng khi
  /// tín hiệu không tới.
  static const Duration pollInterval = Duration(seconds: 30);

  FamilyState? _state;
  bool _loading = true;
  bool _linking = false;
  bool _authReady = false;
  String? _error;
  bool _authSubscribed = false;
  Timer? _pollTimer;

  /// Ba mẹ có bật thông báo "con vừa cập nhật" hay không.
  bool _notifyOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FamilyService.liveSignal.addListener(_onLiveSignal);
    _notifyOn = FamilyNotifyService.enabled;
    _bootstrap();
    _startPolling();
  }

  @override
  void dispose() {
    FamilyService.liveSignal.removeListener(_onLiveSignal);
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  /// Xuống nền thì ngừng hỏi cho đỡ tồn pin/mạng; quay lại là hỏi ngay.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      unawaited(_load());
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _onLiveSignal() {
    if (mounted) unawaited(_load());
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (AuthService.isLoggedIn) unawaited(_load());
    });
  }

  /// Firebase có thể chưa init xong ở frame đầu (main.dart khởi tạo sau frame
  /// đầu để app mở nhanh). Chờ tới khi Auth sẵn sàng rồi mới đọc trạng thái —
  /// nếu không, ba mẹ đã đăng nhập rồi vẫn bị hỏi đăng nhập.
  ///
  /// Có giới hạn thời gian chờ: chưa cấu hình Firebase (hoặc chạy trong test)
  /// thì `whenReady` không bao giờ hoàn tất, và màn phụ huynh phải hiện nút
  /// đăng nhập chứ không được treo spinner vô hạn.
  Future<void> _bootstrap() async {
    await AuthService.whenReady
        .timeout(const Duration(seconds: 4), onTimeout: () {});
    if (!mounted) return;
    _authReady = AuthService.isConfigured;
    if (!_authSubscribed) {
      _authSubscribed = true;
      AuthService.authStateChanges?.listen((_) {
        if (mounted) _load();
      });
    }
    await _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    if (!AuthService.isLoggedIn) {
      setState(() {
        _loading = false;
        _state = null;
        _error = null;
      });
      return;
    }
    setState(() => _error = null);
    final state = await FamilyService.fetchState();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (state != null) _state = state;
      _error = state == null
          ? 'Chưa kết nối được máy chủ — kéo xuống để thử lại.'
          : null;
    });
    // Đọc trạng thái xong là lúc biết con có gì mới: báo ngay (không chặn UI).
    if (state != null) unawaited(FamilyNotifyService.handleState(state));
  }

  Future<void> _toggleNotify(bool value) async {
    FeedbackService.selection();
    final ok = await FamilyNotifyService.setEnabled(value);
    if (!mounted) return;
    setState(() => _notifyOn = FamilyNotifyService.enabled);
    if (value && !ok) {
      _snack('Máy đang chặn thông báo — bật lại trong Cài đặt hệ thống nhé.',
          error: true);
    } else if (value) {
      _snack('Từ giờ con cập nhật là bạn được báo ngay.');
    }
  }

  Future<void> _link() async {
    if (_linking) return;
    final code = _codeCtrl.text.trim();
    if (code.length != 8) {
      _snack('Mã mời gồm 8 chữ số — nhập lại giúp mình nhé.', error: true);
      return;
    }
    setState(() => _linking = true);
    FeedbackService.selection();
    final result = await FamilyService.redeem(
      code,
      parentName: StorageService.getUserName(),
    );
    if (!mounted) return;
    setState(() => _linking = false);
    _snack(result.message, error: !result.ok);
    if (result.ok) {
      _codeCtrl.clear();
      await _load();
    }
  }

  Future<void> _unlink(FamilyMember child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border, width: 2)),
        title: const Text('Ngắt liên kết?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'Bạn sẽ không xem được báo cáo của ${child.name} nữa. '
          'Muốn theo dõi lại thì cần con tạo mã mời mới.',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ liên kết',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ngắt liên kết',
                style: TextStyle(
                    color: AppColors.red, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await FamilyService.unlink(child.linkId, asParent: true);
    if (!mounted) return;
    _snack(result.message, error: !result.ok);
    await _load();
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.red : AppColors.primary,
    ));
  }

  void _exitParentMode() {
    // Đổi vai trò là đủ: [AccountRoleGate] nghe notifier và trả về app học
    // sinh ngay, không cần điều hướng thủ công.
    StorageService.setAccountRole(StorageService.roleStudent);
  }

  Future<void> _openAuth() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => AuthScreen(
        initialRole: StorageService.roleParent,
        onAuthSuccess: () async {
          Navigator.pop(ctx);
          await _load();
        },
        onSkip: () => Navigator.pop(ctx),
      ),
    ));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Cửa sổ tin cậy',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            _roleBanner(),
            const SizedBox(height: 12),
            if (!AuthService.isLoggedIn) ...[
              _loginCard(),
              const SizedBox(height: 12),
            ],
            _linkCard(),
            if (AuthService.isLoggedIn &&
                NotificationService.isSupported) ...[
              const SizedBox(height: 12),
              _notifyCard(),
            ],
            const SizedBox(height: 14),
            _childrenSection(),
            const SizedBox(height: 14),
            _privacyNote(),
          ],
        ),
      ),
    );
  }

  /// Nói rõ đang ở vai nào + đường quay lại chế độ học sinh (không giấu).
  Widget _roleBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.purpleSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.family_restroom_rounded,
              color: AppColors.purple, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Bạn đang ở chế độ PHỤ HUYNH. Chỉ thấy những gì con chủ động gửi.',
              style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: AppColors.purpleDark),
            ),
          ),
          TextButton(
            onPressed: _exitParentMode,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Chế độ học sinh',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.purpleDark)),
          ),
        ],
      ),
    );
  }

  Widget _loginCard() {
    return GlassCard(
      key: const Key('parent-login-card'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              AppIcon(Icons.login_rounded,
                  tileSize: 36,
                  iconSize: 18,
                  color: AppColors.blue,
                  bg: AppColors.blueSoft),
              SizedBox(width: 10),
              Expanded(
                child: Text('Cần đăng nhập',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _authReady
                ? 'Đăng nhập tài khoản phụ huynh để liên kết và nhận báo cáo học tập của con.'
                : 'Đang chuẩn bị đăng nhập…',
            style:
                const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _authReady ? _openAuth : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Đăng nhập tài khoản phụ huynh',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              AppIcon(Icons.vpn_key_rounded,
                  tileSize: 36,
                  iconSize: 18,
                  color: AppColors.primary,
                  bg: AppColors.greenSoft),
              SizedBox(width: 10),
              Expanded(
                child: Text('Nhập mã mời của con',
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Nhờ con mở EduPulse → Cửa sổ tin cậy → “Tạo mã mời” rồi đọc 8 chữ số cho bạn.',
            style: TextStyle(
                fontSize: 12, height: 1.4, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('parent-invite-input'),
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (_) => _link(),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '12345678',
                    hintStyle: const TextStyle(
                        letterSpacing: 4, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.bgPageSoft,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  style: const TextStyle(
                      fontSize: 18,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  key: const Key('parent-link-button'),
                  onPressed: _linking ? null : _link,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _linking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Liên kết',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Công tắc thông báo. Ẩn trên web/desktop (nền tảng không có thông báo hệ
  /// thống) — không hiện một công tắc vô tác dụng.
  Widget _notifyCard() {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const AppIcon(Icons.notifications_active_rounded,
              tileSize: 36,
              iconSize: 18,
              color: AppColors.blue,
              bg: AppColors.blueSoft),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thông báo khi con cập nhật',
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w800)),
                SizedBox(height: 3),
                Text(
                  'Báo ngay khi con chia sẻ tiến độ mới. Chỉ hoạt động khi app '
                  'còn đang chạy.',
                  style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            key: const Key('parent-notify-switch'),
            value: _notifyOn,
            activeThumbColor: AppColors.primary,
            onChanged: _toggleNotify,
          ),
        ],
      ),
    );
  }

  Widget _childrenSection() {
    final children = _state?.children ?? const <FamilyMember>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Con của bạn',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            if (_loading)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 8),
        if (_error != null)
          Text(_error!,
              style: const TextStyle(fontSize: 12.5, color: AppColors.red)),
        if (_error == null && children.isEmpty)
          const Text(
            'Chưa liên kết với tài khoản nào. Nhập mã mời của con ở trên để bắt đầu.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        for (final child in children) ...[
          _childCard(child),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _childCard(FamilyMember child) {
    final reportText = child.hasReport
        ? 'Báo cáo mới nhất: ${_dayLabel(child.latestReportAt!)}'
        : 'Con chưa gửi báo cáo tuần nào';

    return GlassCard(
      key: Key('parent-child-${child.userId}'),
      padding: const EdgeInsets.all(16),
      onTap: () async {
        await ChildReportScreen.open(context, child);
        await _load();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(Icons.face_rounded,
                  tileSize: 40,
                  iconSize: 22,
                  color: AppColors.primary,
                  bg: AppColors.primaryLight),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    if (child.isLive) _liveChip(child.liveAt!),
                    const SizedBox(height: 2),
                    Text(reportText,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: child.hasReport
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: child.hasReport
                                ? AppColors.primary
                                : AppColors.textMuted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Ngắt liên kết',
                onPressed: () => _unlink(child),
                icon: const Icon(Icons.link_off_rounded,
                    size: 20, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await ChildReportScreen.open(context, child);
                      await _load();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.insights_rounded, size: 17),
                    label: const Text('Xem tiến độ học tập',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _privacyNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        '💚 Cửa sổ tin cậy: con chọn chia sẻ gì thì ba mẹ thấy nấy. '
        'App không đọc dữ liệu riêng tư của con và không nhắc con “phải” chia sẻ.',
        style: TextStyle(
            fontSize: 11.5, height: 1.4, color: AppColors.primaryDark),
      ),
    );
  }

  /// Nhãn "con đang chia sẻ liên tục" trên thẻ con — có chấm nhấp nháy theo
  /// ngữ cảnh (màu xanh, không animation để không đốt vẽ lại liên tục).
  Widget _liveChip(DateTime at) {
    return Padding(
      padding: const EdgeInsets.only(top: 3, bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text('Cập nhật trực tiếp · ${_agoLabel(at)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark)),
          ),
        ],
      ),
    );
  }

  /// "vừa xong / 12 phút trước / 3 giờ trước" — đủ để ba mẹ biết bản đang xem
  /// có thật sự mới hay không.
  static String _agoLabel(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return _dayLabel(at);
  }

  static String _dayLabel(DateTime at) {
    final now = DateTime.now();
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    if (sameDay) return 'hôm nay';
    final diff = now.difference(at).inDays;
    if (diff == 1) return 'hôm qua';
    if (diff < 7) return '$diff ngày trước';
    return '${at.day}/${at.month}/${at.year}';
  }
}
