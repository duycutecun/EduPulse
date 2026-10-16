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
  final VoidCallback onCreateQuiz;
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
    required this.onCreateQuiz,
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
            borderColor: AppColors.iosPrimary,
            shadows: const [],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(selectedImageBytes!,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      // Ảnh chụp từ điện thoại có thể 12MP — decode nhỏ để không giật.
                      cacheWidth: 108),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selectedImageName ?? 'Ảnh',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.iosTextPrimary),
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
                      color: AppColors.iosError.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        size: 14, color: AppColors.iosError),
                  ),
                ),
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.iosCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.iosSeparator, width: 2),
            boxShadow: [
              BoxShadow(
                  color: AppColors.iosSeparator,
                  blurRadius: 0,
                  offset: const Offset(0, 3)),
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
                    color: AppColors.iosInfo,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_camera_rounded,
                      size: 20, color: Colors.white),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onCreateQuiz,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.iosSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.quiz_rounded,
                      size: 20, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: !isLoading,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.iosTextPrimary),
                  decoration: InputDecoration(
                    hintText: selectedImageBytes != null
                        ? 'Ghi chú cho ảnh...'
                        : 'Hỏi AI bài tập...',
                    hintStyle:
                        TextStyle(color: AppColors.iosTextMuted, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
                    color: isLoading
                        ? AppColors.iosSeparator
                        : AppColors.iosPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.send,
                          color: Colors.white,
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
