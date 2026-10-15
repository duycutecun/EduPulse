import 'package:flutter/material.dart';
import 'package:edupulse/features/tasks/domain/repositories/task_repository.dart';
import 'package:edupulse/features/tasks/presentation/widgets/task_detail_sheet.dart';
import 'app_navigator_key.dart';

/// Route deep-link: `task/<id>` → mở chi tiết task.
///
/// Sau khi xác định được ID, chúng tôi tìm task trong [TaskRepository.instance]
/// và mở [TaskDetailSheet] với các callback đi kèm. Nếu không tìm thấy task
/// nào, chúng tôi chỉ mở HomeScreen (hoặc giữ nguyên màn hình hiện tại) và
/// nhắn nhở bằng SnackBar nhẹ — không crash, không bắt user phải làm gì.
///
/// Lưu ý quản lý bộ nhớ:_deep-link_ handshake sẽ gửi yêu cầu mở modal, nhưng
/// nếu không có TaskDetailSheet nào trên màn hình thì chúng tôi sẽ mở từ
/// HomeScreen currently visible hoặc fallback về HomeScreen.
class DeepLinkHandler {
  /// Mở chi tiết task từ URI deep-link.
  ///
  /// [context] là BuildContext hiện tại (thường là từ MainShell or HomeScreen).
  /// [taskId] là ID của task cần mở (từ URI path segment).
  static Future<void> openTaskDetail(
    BuildContext context, {
    required String taskId,
  }) async {
    try {
      // Tìm task trong repository.
      final task = TaskRepository.instance.getTaskById(taskId);

      if (task == null) {
        // Task không tồn tại — thông báo nhẹ, không crash.
        ScaffoldMessenger.of(appNavigatorKey.currentContext ?? context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Không tìm thấy nhiệm vụ: $taskId',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      // Mở chi tiết task thông qua navigator key để đảm bảo context hợp lệ.
      final ctx = appNavigatorKey.currentContext ?? context;
      if (!ctx.mounted) return;

      await TaskDetailSheet.show(
        ctx,
        task: task,
        onTaskUpdated: (updatedTask) {
          // Cập nhật task vào repository.
          TaskRepository.instance.updateTask(updatedTask);
        },
        // KHÔNG truyền callback hành động: deep-link không có state của Home
        // (nút Sửa/Xóa/Dời lịch/Bắt đầu học ẩn đi — tránh nút bấm vô tác dụng).
        // Mở nhiệm vụ từ tab Hôm nay để thao tác đầy đủ.
      );
    } catch (e) {
      // Bất kỳ lỗi nào cũng không crash app — chỉ thông báo.
      ScaffoldMessenger.of(appNavigatorKey.currentContext ?? context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Không thể mở nhiệm vụ: ${e.toString()}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
