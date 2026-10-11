import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/family/family_models.dart';
import '../../../../core/family/family_service.dart';

/// Cửa sổ nhắn gọn giữa ba mẹ và con trong "Cửa sổ tin cậy".
///
/// Không phải chat thời gian thực: lời nhắn được giữ lại để đầu bên kia đọc
/// khi rảnh, kèm dấu "đã đọc". Dùng chung cho CẢ HAI phía — con nhắn ba mẹ,
/// ba mẹ nhắn con, trang trí chỉ khác ở chiều cục bộ.
class FamilyMessageSheet {
  FamilyMessageSheet._();

  /// [myRole] = vai của người đang mở ('parent' | 'child'), để bong bóng tin
  /// của MÌNH nằm bên phải. [onChanged] gọi sau khi đã-đọc để màn ngoài cập
  /// nhật lại badge unread.
  static Future<void> open(
    BuildContext context, {
    required String linkId,
    required String otherName,
    required String myRole,
    VoidCallback? onChanged,
  }) async {
    final result = await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) =>
          SizedBox(height: MediaQuery.sizeOf(ctx).height * 0.72, child: _Body(
            linkId: linkId,
            otherName: otherName,
            myRole: myRole,
          )),
    );
    onChanged?.call();
    // ignore: unnecessary_cast
    return result;
  }
}

class _Body extends StatefulWidget {
  const _Body({
    required this.linkId,
    required this.otherName,
    required this.myRole,
  });

  final String linkId;
  final String otherName;
  final String myRole;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<FamilyMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final messages = await FamilyService.fetchMessages(widget.linkId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = messages == null ? 'Không đọc được lời nhắn — thử lại.' : null;
      if (messages != null) _messages = messages;
    });
    // Đã-đọc được server cập nhật khi đọc — cuộn xuống tin mới nhất.
    _jumpToBottom();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final result = await FamilyService.sendMessage(widget.linkId, text);
    if (!mounted) return;
    if (result.ok && _messages.every((m) => m.body != text)) {
      // Phản hồi của server đủ để dựng tin mới tại chỗ (chưa cần gọi lại).
      _messages = [
        FamilyMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          fromRole: widget.myRole,
          body: text,
          createdAt: DateTime.now(),
        ),
        ..._messages,
      ];
      _ctrl.clear();
      _jumpToBottom();
    } else if (!result.ok) {
      _snack(result.message, error: true);
    }
    setState(() => _sending = false);
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.red : AppColors.primary,
    ));
  }

  bool _mine(FamilyMessage m) => m.fromRole != widget.myRole;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _header(),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _error != null
                  ? _errorView()
                  : ListView(
                      reverse: true,
                      controller: _scroll,
                      padding: const EdgeInsets.all(14),
                      children: [
                        ..._messages.map((m) => _bubble(m)),
                        if (_messages.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Center(
                              child: Text(
                                'Chưa có lời nhắn nào. Viết vài dòng động viên nhé 💚',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12.5, color: AppColors.textMuted),
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
        _inputBar(),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          const AppIconLocal(
            Icons.chat_bubble_outline_rounded,
            tileSize: 40,
            iconSize: 20,
            color: AppColors.purple,
            bg: AppColors.purpleSoft,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nhắn với ${widget.otherName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                const Text(
                  'Lời nhắn được giữ lại — đọc được lúc nào cũng được.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Đóng',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 28, color: AppColors.textMuted),
          const SizedBox(height: 8),
          Text(_error!,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          TextButton(onPressed: _load, child: const Text('Thử lại')),
        ],
      ),
    );
  }

  Widget _bubble(FamilyMessage m) {
    final mine = _mine(m);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.72),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : AppColors.bgPageSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(m.body,
                style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: mine ? Colors.white : AppColors.textPrimary)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_stamp(m.createdAt),
                    style: TextStyle(
                        fontSize: 9.5,
                        color: mine
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppColors.textMuted)),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    m.isRead
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Nhắn động viên…',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.bgPageSoft,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 46,
              width: 46,
              child: ElevatedButton(
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 19),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _stamp(DateTime at) {
    final now = DateTime.now();
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    if (sameDay) return 'Hôm nay $hh:$mm';
    return '${at.day}/${at.month} $hh:$mm';
  }
}

/// Tiện bản nhỏ để sheet không phụ thuộc AppIcon (ảnh minh hoạ không cần thiết).
class AppIconLocal extends StatelessWidget {
  const AppIconLocal(
    this.icon, {
    super.key,
    required this.tileSize,
    required this.iconSize,
    required this.color,
    required this.bg,
  });

  final IconData icon;
  final double tileSize;
  final double iconSize;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tileSize,
      height: tileSize,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}
