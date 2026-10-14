import 'package:flutter/material.dart';

import '../../../../shared/widgets/state_views.dart';

/// Trạng thái rỗng của màn Ghi chú.
class NotesEmpty extends StatelessWidget {
  final VoidCallback? onCreate;
  const NotesEmpty({super.key, this.onCreate});

  @override
  Widget build(BuildContext context) => EmptyStateView(
        icon: Icons.sticky_note_2_outlined,
        title: 'Chưa có ghi chú',
        description: 'Lưu công thức, lỗi sai và ý tưởng để ôn lại sau.',
        actionLabel: 'Tạo ghi chú',
        onAction: onCreate,
      );
}
