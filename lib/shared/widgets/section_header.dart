import 'package:flutter/material.dart';
import '../../core/constants/app_tokens.dart';

/// Tiêu đề phân nhóm cho các khối nội dung theo cấu trúc rõ ràng của v2.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppTokens.space16,
      vertical: AppTokens.space8,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTokens.heading2,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppTokens.space2),
                  Text(
                    subtitle!,
                    style: AppTokens.caption,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
