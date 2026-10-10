import 'package:flutter/material.dart';

import '../core/utils/storage_service.dart';
import '../features/family/presentation/screens/parent_home_screen.dart';
import 'main_shell.dart';

/// Màn hình gốc theo VAI TRÒ tài khoản: phụ huynh vào thẳng bảng theo dõi của
/// con, học sinh vào app học tập như cũ.
///
/// Lắng nghe [StorageService.roleNotifier] thay vì chỉ đọc một lần lúc mở app:
/// đăng nhập bằng tài khoản phụ huynh ngay trong tab Tôi, hoặc bấm "Chế độ học
/// sinh" ở màn phụ huynh, đều phải đổi màn hình gốc tức thì.
class AccountRoleGate extends StatelessWidget {
  const AccountRoleGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: StorageService.roleNotifier,
      builder: (context, role, _) {
        if (role == StorageService.roleParent) {
          return const ParentHomeScreen();
        }
        return const MainShellScreen();
      },
    );
  }
}
