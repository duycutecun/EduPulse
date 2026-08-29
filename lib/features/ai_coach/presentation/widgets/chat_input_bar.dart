import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final Uint8List? selectedImageBytes;
  final String? selectedImageName;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final ValueChanged<String> onSend;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.selectedImageBytes,
    required this.selectedImageName,
    required this.onPickImage,
    required this.onClearImage,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selectedImageBytes != null)
          GlassCard(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            borderColor: AppColors.green,
            shadows: const [],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(selectedImageBytes!, width: 36, height: 36, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selectedImageName ?? 'Ảnh',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onClearImage,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 14, color: AppColors.red),
                  ),
                ),
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 2),
            boxShadow: [
              BoxShadow(color: AppColors.borderDark, blurRadius: 0, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onPickImage,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: AppColors.blueDark, blurRadius: 0, offset: Offset(0, 3)),
                    ],
                  ),
                  child: const Icon(Icons.photo_camera_rounded, size: 20, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: !isLoading,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: selectedImageBytes != null ? 'Ghi chú cho ảnh...' : 'Hỏi AI bài tập...',
                    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  ),
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: onSend,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: isLoading ? null : () => onSend(controller.text),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isLoading ? AppColors.border : AppColors.green,
                    shape: BoxShape.circle,
                    boxShadow: isLoading ? null : const [
                      BoxShadow(color: AppColors.greenDark, blurRadius: 0, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Icon(
                    Icons.send,
                    color: isLoading ? AppColors.textMuted : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
