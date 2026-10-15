import 'package:flutter/material.dart';

import '../widgets/state_views.dart';

/// Mô hình trạng thái async THỐNG NHẤT cho feature mới (đặc tả §6.3).
///
/// VÌ SAO: app trước đây biểu diễn tải/rỗng/lỗi bằng các biến rời rạc
/// (`_loading`, `_error`, `_data == null`) rải khắp màn hình — khó tái sử dụng
/// và dễ quên một nhánh. Kiểu này gom về bốn trạng thái chuẩn, đi kèm
/// [AsyncStateView] render sẵn bằng bộ widget chung ở `state_views.dart`.
///
/// QUY ƯỚC ÁP DỤNG (không cần chuyển toàn bộ app một lần — §6.3 cho phép làm
/// dần): feature/khu vực MỚI hoặc ĐƯỢC CẢI TỔ dùng [AsyncStateController] thay
/// cho cờ bool rời. Phần cũ giữ nguyên cho tới khi có đợt di chuyển riêng.
enum AsyncStatus { loading, data, empty, error }

/// Ảnh chụp bất biến của một lần tải dữ liệu.
@immutable
class AsyncState<T> {
  const AsyncState.loading()
      : status = AsyncStatus.loading,
        data = null,
        error = null;

  const AsyncState.data(this.data)
      : status = AsyncStatus.data,
        error = null;

  const AsyncState.empty()
      : status = AsyncStatus.empty,
        data = null,
        error = null;

  const AsyncState.error(this.error)
      : status = AsyncStatus.error,
        data = null;

  final AsyncStatus status;
  final T? data;
  final String? error;

  bool get isLoading => status == AsyncStatus.loading;
  bool get hasData => status == AsyncStatus.data;
  bool get isEmpty => status == AsyncStatus.empty;
  bool get hasError => status == AsyncStatus.error;
}

/// Bộ điều khiển nhẹ, không phụ thuộc thư viện ngoài: giữ một [AsyncState] và
/// cung cấp [load] để chạy một tác vụ bất đồng bộ rồi tự chuyển trạng thái.
///
/// Dễ fake trong test (chỉ cần thay hàm tác vụ), không tự gọi mạng lúc `build`,
/// và an toàn khi màn hình đã bị hủy (`dispose` chặn ghi đè state).
class AsyncStateController<T> extends ValueNotifier<AsyncState<T>> {
  AsyncStateController({
    bool Function(T value)? isEmpty,
    String Function(Object error)? describeError,
  })  : _isEmpty = isEmpty,
        _describeError = describeError,
        super(AsyncState<T>.loading());

  final bool Function(T value)? _isEmpty;
  final String Function(Object error)? _describeError;
  bool _disposed = false;

  /// Chạy [task] và cập nhật trạng thái: loading → data/empty/error.
  ///
  /// `isEmpty` (nếu có) quyết định khi nào một kết quả được coi là "rỗng";
  /// mặc định coi [Iterable] rỗng là trạng thái empty.
  Future<void> load(Future<T> Function() task) async {
    value = AsyncState<T>.loading();
    try {
      final result = await task();
      if (_disposed) return;
      value = _isResultEmpty(result)
          ? AsyncState<T>.empty()
          : AsyncState<T>.data(result);
    } catch (e) {
      if (_disposed) return;
      value =
          AsyncState<T>.error(_describeError?.call(e) ?? _defaultMessage(e));
    }
  }

  bool _isResultEmpty(T result) {
    if (_isEmpty != null) return _isEmpty(result);
    if (result is Iterable) return result.isEmpty;
    return false;
  }

  String _defaultMessage(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.isEmpty ? 'Đã có lỗi xảy ra.' : text;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Render một [AsyncState] bằng bộ widget chung (`state_views.dart`).
///
/// - loading → [LoadingStateView] (hoặc `loadingBuilder`)
/// - data    → [builder]
/// - empty   → [EmptyStatePanel] (hoặc `emptyBuilder`)
/// - error   → [ErrorStatePanel] kèm `onRetry`
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.state,
    required this.builder,
    this.onRetry,
    this.loadingMessage,
    this.emptyIcon = Icons.inbox_rounded,
    this.emptyTitle = 'Chưa có dữ liệu',
    this.emptyDescription = '',
    this.emptyActionLabel,
    this.onEmptyAction,
    this.padding,
  });

  final AsyncState<T> state;
  final Widget Function(BuildContext context, T data) builder;

  /// Gọi khi người dùng bấm "Thử lại" ở nhánh lỗi. Bỏ trống = ẩn nút thử lại.
  final VoidCallback? onRetry;

  final String? loadingMessage;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyDescription;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case AsyncStatus.loading:
        return LoadingStateView(message: loadingMessage);
      case AsyncStatus.data:
        return builder(context, state.data as T);
      case AsyncStatus.empty:
        return EmptyStatePanel(
          icon: emptyIcon,
          title: emptyTitle,
          description: emptyDescription,
          actionLabel: emptyActionLabel,
          onAction: onEmptyAction,
        );
      case AsyncStatus.error:
        return ErrorStatePanel(
          message: state.error ?? 'Đã có lỗi xảy ra.',
          onRetry: onRetry,
        );
    }
  }
}
