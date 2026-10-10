import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/ai/weekly_report.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/family/family_models.dart';
import '../../../../core/family/family_service.dart';
import '../../../../shared/widgets/glass_card.dart';

/// Phụ huynh xem tiến độ học tập của con — CẬP NHẬT LIÊN TỤC.
///
/// Hai nguồn, một màn:
/// - **Trực tiếp**: bản mới nhất con đang chia sẻ (xem [LiveProgressService] ở
///   phía con). Có tín hiệu Realtime là màn này kéo lại ngay; hỏi định kỳ 30
///   giây chỉ là lưới an toàn khi tín hiệu không tới.
/// - **Báo cáo tuần**: từng mốc con tự tay bấm gửi, giữ lại làm lịch sử.
///
/// Vẫn đúng "Cửa sổ tin cậy": cả hai đều là nội dung con chọn chia sẻ. Màn này
/// không đọc dữ liệu thô, không suy diễn thêm, và nói thật khi con chưa bật
/// cập nhật trực tiếp.
class ChildReportScreen extends StatefulWidget {
  const ChildReportScreen({super.key, required this.child});

  final FamilyMember child;

  static Future<void> open(BuildContext context, FamilyMember child) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChildReportScreen(child: child),
    ));
  }

  @override
  State<ChildReportScreen> createState() => _ChildReportScreenState();
}

class _ChildReportScreenState extends State<ChildReportScreen>
    with WidgetsBindingObserver {
  /// Nhịp hỏi lại khi ba mẹ đang mở màn. Realtime mới là đường tắt cho độ trễ;
  /// nhịp này đảm bảo dữ liệu vẫn đúng khi tín hiệu rơi mất.
  static const Duration pollInterval = Duration(seconds: 30);

  List<SharedReport> _reports = const [];
  SharedReport? _live;
  bool _loading = true;
  bool _fetching = false;
  String? _error;
  DateTime? _updatedAt;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FamilyService.liveSignal.addListener(_onSignal);
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    FamilyService.liveSignal.removeListener(_onSignal);
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  /// App xuống nền thì ngừng hỏi (không đốt pin/mạng vô ích); quay lại là hỏi
  /// ngay một nhịp, không bắt ba mẹ chờ hết chu kỳ.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      unawaited(_poll());
    } else {
      _stopPolling();
    }
  }

  void _onSignal() {
    if (mounted) unawaited(_poll());
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) => unawaited(_poll()));
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Lần đầu mở màn / kéo làm mới: lấy đủ trang báo cáo + trạng thái trực tiếp.
  Future<void> _load() async {
    if (!mounted || _fetching) return;
    setState(() {
      _loading = true;
      _fetching = true;
    });
    final progress =
        await FamilyService.fetchChildProgress(widget.child.userId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _fetching = false;
      if (progress == null) {
        _error = 'Chưa kết nối được máy chủ — kéo xuống để thử lại.';
        return;
      }
      _error = null;
      _updatedAt = progress.serverTime ?? DateTime.now();
      _reports = progress.reports;
      _live = progress.live;
    });
  }

  /// Hỏi phần MỚI hơn cái đang có: nhẹ mạng và không nháy màn.
  ///
  /// `live` luôn được đọc kèm trong mọi phản hồi, nên `live == null` là sự
  /// thật "con chưa bật / vừa tắt" — phải xoá thẻ trực tiếp, không giữ bản cũ.
  Future<void> _poll() async {
    if (!mounted || _fetching) return;
    _fetching = true;
    final since = _reports.isEmpty
        ? 0
        : _reports.first.createdAt.millisecondsSinceEpoch;
    final progress = await FamilyService.fetchChildProgress(
      widget.child.userId,
      since: since,
    );
    if (!mounted) {
      _fetching = false;
      return;
    }
    setState(() {
      _fetching = false;
      _loading = false;
      if (progress == null) {
        if (_updatedAt == null) {
          _error = 'Chưa kết nối được máy chủ — kéo xuống để thử lại.';
        }
        return;
      }
      _error = null;
      _updatedAt = progress.serverTime ?? DateTime.now();
      _live = progress.live;
      if (progress.reports.isNotEmpty) {
        final known = _reports.map((r) => r.id).toSet();
        final fresh =
            progress.reports.where((r) => !known.contains(r.id)).toList();
        if (fresh.isNotEmpty) _reports = [...fresh, ..._reports];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.child.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            Text(
              _loading && _updatedAt == null
                  ? 'Tiến độ học tập con chia sẻ'
                  : 'Tiến độ học tập con chia sẻ · ${_clock(_updatedAt)}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          if (_live != null) ...[
            const _LiveDot(),
            const SizedBox(width: 2),
          ],
          IconButton(
            tooltip: 'Làm mới / tải lại',
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
            if (_loading && _updatedAt == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_error != null) ...[
                Text(_error!,
                    style:
                        const TextStyle(fontSize: 12.5, color: AppColors.red)),
                const SizedBox(height: 10),
              ],
              if (_live != null)
                _liveCard(_live!)
              else
                _noLiveCard(),
              const SizedBox(height: 16),
              const Text('Báo cáo tuần con đã gửi',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              if (_reports.isEmpty)
                _messageCard(
                  emoji: '💚',
                  title: 'Chưa có báo cáo tuần nào',
                  body:
                      'Khi con vào Cửa sổ tin cậy và bấm “Gửi cho gia đình”, báo cáo tuần sẽ hiện ở đây. '
                      'Con có thể chỉ chọn vài mục — đó là quyền của con.',
                )
              else
                for (var i = 0; i < _reports.length; i++) ...[
                  _reportCard(_reports[i], isLatest: i == 0),
                  const SizedBox(height: 12),
                ],
            ],
          ],
        ),
      ),
    );
  }

  /// Thẻ "trực tiếp": tiến độ mới nhất, tự cập nhật trong lúc ba mẹ mở màn.
  Widget _liveCard(SharedReport live) {
    final report = live.report;
    final stale = DateTime.now().difference(live.createdAt).inHours >= 24;

    return GlassCard(
      key: const Key('child-live-card'),
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.primary,
      borderWidth: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('CẬP NHẬT TRỰC TIẾP',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppColors.primaryDark)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cập nhật lúc ${_clock(live.createdAt)}',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (report == null)
            const Text(
              'Bản cập nhật này không đọc được (dữ liệu thiếu). Nhờ con mở lại '
              'Cửa sổ tin cậy nhé.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            )
          else ...[
            Text(
              _weekLabel(report.from, report.to),
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              report.headline,
              style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            for (final item in report.items) _itemRow(item),
          ],
          if (stale) ...[
            const SizedBox(height: 4),
            const Text(
              'Con chưa cập nhật hôm nay — con có thể đang nghỉ, hoặc đã tắt '
              'cập nhật trực tiếp.',
              style: TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  /// Con chưa bật cập nhật trực tiếp — nói thật, kèm cách bật, không doạ.
  Widget _noLiveCard() {
    return GlassCard(
      key: const Key('child-no-live-card'),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.podcasts_outlined,
              size: 20, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Con chưa bật cập nhật trực tiếp',
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'Báo cáo tuần con gửi vẫn hiện ngay bên dưới. Muốn thấy tiến độ '
                  'cập nhật liên tục, nhờ ${widget.child.name} mở Cửa sổ tin cậy và '
                  'bật “Cập nhật trực tiếp cho ba mẹ” — con chọn chia sẻ mục nào thì '
                  'chỉ mục đó được cập nhật.',
                  style: const TextStyle(
                      fontSize: 12, height: 1.45, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageCard({
    required String emoji,
    required String title,
    required String body,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 34)),
          const SizedBox(height: 8),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.45, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _reportCard(SharedReport shared, {required bool isLatest}) {
    final report = shared.report;

    return GlassCard(
      key: Key('child-report-${shared.id}'),
      padding: const EdgeInsets.all(16),
      borderColor: isLatest ? AppColors.primary : AppColors.border,
      borderWidth: isLatest ? 2 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isLatest) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('MỚI NHẤT',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark)),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  _sentLabel(shared.createdAt),
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (report == null)
            const Text(
              'Báo cáo này không đọc được (dữ liệu cũ hoặc thiếu). '
              'Nhờ con gửi lại báo cáo tuần này nhé.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            )
          else ...[
            Text(
              _weekLabel(report.from, report.to),
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              report.headline,
              style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            for (final item in report.items) _itemRow(item),
          ],
        ],
      ),
    );
  }

  Widget _itemRow(ReportItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.primary)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted)),
                Text(
                  '${item.value}${item.detail == null ? '' : ' — ${item.detail}'}',
                  style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _weekLabel(DateTime from, DateTime to) =>
      'Tuần ${from.day}/${from.month} – ${to.day}/${to.month}';

  static String _sentLabel(DateTime at) =>
      'Con gửi lúc ${_clock(at)} · ${_date(at)}';

  static String _clock(DateTime? at) {
    if (at == null) return '--:--';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }

  static String _date(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)}/${at.year}';
  }
}

/// Chấm "đang trực tiếp" ở góc phải AppBar — ba mẹ biết màn đang tự cập nhật.
class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Đang cập nhật trực tiếp từ con',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.greenSoft,
          borderRadius: BorderRadius.circular(10),
        ),
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
            const Text('Trực tiếp',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark)),
          ],
        ),
      ),
    );
  }
}
