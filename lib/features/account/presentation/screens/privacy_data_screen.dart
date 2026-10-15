import 'package:flutter/material.dart';

import '../../../../core/account/account_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/state/async_state.dart';

/// Màn "Quyền riêng tư & dữ liệu" (đặc tả mục 8, dòng 214).
///
/// Hai phần:
///  1. Chính sách lưu trữ/cache (tải từ `/api/account`) — dùng mô hình trạng
///     thái thống nhất [AsyncStateController] (đặc tả §6.3).
///  2. Nút xoá dữ liệu cá nhân đã lưu trên máy chủ, kèm xác nhận gõ "XÓA".
class PrivacyDataScreen extends StatefulWidget {
  const PrivacyDataScreen({super.key});

  @override
  State<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends State<PrivacyDataScreen> {
  late final AsyncStateController<List<RetentionItem>> _retention;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _retention = AsyncStateController<List<RetentionItem>>();
    _retention.load(AccountService.fetchRetention);
  }

  @override
  void dispose() {
    _retention.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá dữ liệu cá nhân trên máy chủ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Bản sao lưu, ảnh đề bài, liên kết và báo cáo gia đình của bạn '
                'sẽ bị xoá khỏi máy chủ. Dữ liệu học tập trên thiết bị này vẫn giữ.'),
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
            onPressed: () {
              if (controller.text.trim().toUpperCase() == 'XÓA') {
                Navigator.pop(dialogContext, true);
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Xoá vĩnh viễn'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final result = await AccountService.deleteMyData();
    if (!mounted) return;
    setState(() => _deleting = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.ok
          ? 'Đã xoá ${result.totalDeleted} mục dữ liệu cá nhân trên máy chủ.'
          : (result.message ?? 'Xoá dữ liệu không thành công.')),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Quyền riêng tư & dữ liệu'),
        backgroundColor: AppColors.bgPage,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Dữ liệu lưu trên máy chủ'),
          const SizedBox(height: 8),
          ValueListenableBuilder<AsyncState<List<RetentionItem>>>(
            valueListenable: _retention,
            builder: (context, state, _) => AsyncStateView<List<RetentionItem>>(
              state: state,
              onRetry: () => _retention.load(AccountService.fetchRetention),
              loadingMessage: 'Đang tải chính sách lưu trữ...',
              emptyIcon: Icons.cloud_off_rounded,
              emptyTitle: 'Không tải được chính sách lưu trữ',
              emptyDescription:
                  'Kiểm tra kết nối mạng rồi thử lại. Dữ liệu học tập của bạn vẫn an toàn trên thiết bị.',
              emptyActionLabel: 'Thử lại',
              onEmptyAction: () =>
                  _retention.load(AccountService.fetchRetention),
              builder: (context, items) => Column(
                children: [
                  for (final r in items) _RetentionTile(item: r),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Xoá dữ liệu cá nhân'),
          const SizedBox(height: 8),
          const Text(
            'Bạn có thể yêu cầu xoá toàn bộ dữ liệu cá nhân đã lưu trên máy chủ '
            'bất cứ lúc nào. Dữ liệu học tập cục bộ trên thiết bị không bị ảnh hưởng.',
            style: TextStyle(
                fontSize: 13, height: 1.4, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _deleting ? null : _confirmDelete,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: _deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.delete_forever_rounded),
            label: Text(
                _deleting ? 'Đang xoá...' : 'Xoá dữ liệu cá nhân trên máy chủ'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary),
      );
}

class _RetentionTile extends StatelessWidget {
  const _RetentionTile({required this.item});

  final RetentionItem item;

  @override
  Widget build(BuildContext context) {
    final ttl = item.ttlDays;
    final value = ttl == null
        ? 'Giữ tới khi bạn xoá'
        : (ttl >= 999 ? 'Không giới hạn' : 'Tối đa $ttl ngày');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule_rounded,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
