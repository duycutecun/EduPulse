import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/storage_service.dart';
import '../../features/home/presentation/widgets/mascot_companion_modal.dart';
import '../services/audio_synth_service.dart';

/// Các trạng thái biểu cảm của linh vật Mascot Cú Sĩ tử
enum MascotMood {
  idle,
  focus,
  excited,
  relax,
  sleepy,
  celebrate,
}

/// Avatar linh vật Cú Sĩ tử phiên bản tinh giản (không animation):
/// - Màu nền/bóng/emote thay đổi theo mood.
/// - Tap để nghe câu thoại động viên (theo ngữ cảnh), long-press để mở
///   "Góc Tâm Tình Sĩ Tử".
class MascotAvatar extends StatefulWidget {
  final double size;
  final MascotMood mood;
  final String? userName;
  final int? streak;
  final int? daysLeft;
  final int? remainingTasks;
  final bool? isAllTasksCompleted;
  final bool enableCompanionModal;
  final VoidCallback? onTap;

  const MascotAvatar({
    super.key,
    this.size = 56,
    this.mood = MascotMood.idle,
    this.userName,
    this.streak,
    this.daysLeft,
    this.remainingTasks,
    this.isAllTasksCompleted,
    this.enableCompanionModal = true,
    this.onTap,
  });

  @override
  State<MascotAvatar> createState() => _MascotAvatarState();
}

class _MascotAvatarState extends State<MascotAvatar> {
  String? _currentQuote;
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Tạo câu thoại thông minh theo ngữ cảnh thực tế của học sinh
  String _getContextualQuote() {
    final now = DateTime.now();
    final hour = now.hour;
    final List<String> contextualPool = [];

    // 1. Phản hồi theo trạng thái mood
    switch (widget.mood) {
      case MascotMood.focus:
        contextualPool.addAll([
          'Đang trong phiên tập trung, hít thở sâu nào! 🎯',
          'Tập trung cao độ, 1 phút này quý giá lắm nhé! ⏱️',
          'Đừng vội mở mạng xã hội, sắp hoàn thành phiên rồi! 🤫',
        ]);
        break;
      case MascotMood.relax:
        contextualPool.addAll([
          'Nghỉ ngơi đôi mắt và uống chút nước nhé! ☕',
          'Vươn vai thả lỏng nào, hồi phục năng lượng nhé! 🌿',
        ]);
        break;
      case MascotMood.sleepy:
        contextualPool.addAll([
          'Khuya rồi, sĩ tử đừng thức muộn quá hại sức khỏe nhé! 💤',
          'Ngủ ngon để não bộ củng cố kiến thức đã học hôm nay! 🌙',
        ]);
        break;
      case MascotMood.celebrate:
        contextualPool.addAll([
          'Bạn xuất sắc lắm! Hôm nay đã hoàn thành mọi mục tiêu! 👑',
          'Thần thái thủ khoa là đây! Cứ thế mà phát huy nhé! 🌟',
        ]);
        break;
      case MascotMood.excited:
      case MascotMood.idle:
        break;
    }

    // 2. Phản hồi theo thời gian trong ngày
    if (hour >= 5 && hour < 8) {
      contextualPool.add('Chào buổi sáng sớm! Khởi động ngày mới thật tỉnh táo nhé! 🌅');
    } else if (hour >= 22 || hour < 5) {
      contextualPool.add('Khuya rồi, nhớ ngủ đủ giấc để ngày mai minh mẫn nhé! 💤');
    }

    // 3. Phản hồi theo kỳ thi & ngày đếm ngược
    if (widget.daysLeft != null && widget.daysLeft! > 0) {
      if (widget.daysLeft! <= 30) {
        contextualPool.add('Chỉ còn ${widget.daysLeft} ngày! Giai đoạn nước rút then chốt, cố lên! ⚡');
      } else if (widget.daysLeft! <= 100) {
        contextualPool.add('Còn ${widget.daysLeft} ngày nữa, từng ngày kiên trì sẽ tạo nên kỳ tích! 🎯');
      } else {
        contextualPool.add('Còn ${widget.daysLeft} ngày để chuẩn bị, đi từng bước thật chắc nhé! 🚀');
      }
    }

    // 4. Phản hồi theo Streak
    if (widget.streak != null && widget.streak! >= 3) {
      contextualPool.add('Chuỗi ${widget.streak} ngày liên tiếp cực kỳ đáng nể! 🔥');
    }

    // 5. Phản hồi theo nhiệm vụ trong ngày
    if (widget.isAllTasksCompleted == true) {
      contextualPool.add('Toàn bộ nhiệm vụ hôm nay đã xong, tự thưởng cho mình một chút nhé! 🌟');
    } else if (widget.remainingTasks != null && widget.remainingTasks! > 0) {
      contextualPool.add('Còn ${widget.remainingTasks} nhiệm vụ hôm nay, cùng giải quyết nốt nào! 💪');
    }

    // 6. Những câu truyền cảm hứng kinh điển
    contextualPool.addAll([
      'Hôm nay tập trung 25 phút Pomodoro nhé sĩ tử! 🎯',
      'Từng mục tiêu nhỏ hôm nay tạo nên kết quả lớn ngày mai! ✨',
      'Cố lên, cánh cổng đại học mơ ước đang chờ đón bạn! 🎓',
      'Kiên trì mỗi ngày là chìa khóa đỗ đạt nguyện vọng 1! 🌟',
      'Bạn đang tiến gần hơn tới mục tiêu rồi đấy! 🚀',
    ]);

    final quote = contextualPool[DateTime.now().millisecond % contextualPool.length];
    return quote;
  }

  void _onTap() {
    AudioSynthService.playChirp();
    setState(() {
      _currentQuote = _getContextualQuote();
    });
    widget.onTap?.call();
  }

  void _openCompanionModal() {
    if (!widget.enableCompanionModal) return;
    MascotCompanionModal.show(
      context,
      streak: widget.streak ?? 0,
      isAllTasksCompleted: widget.isAllTasksCompleted ?? false,
      onAccessoryChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _onLongPress() {
    AudioSynthService.playChirp();
    _openCompanionModal();
  }

  /// Lấy màu nền theo mood
  Color _getMoodColor() {
    switch (widget.mood) {
      case MascotMood.focus:
        return AppColors.blue;
      case MascotMood.excited:
        return AppColors.orange;
      case MascotMood.relax:
      case MascotMood.idle:
        return AppColors.green;
      case MascotMood.sleepy:
        return const Color(0xFF6C5CE7); // Tím mộng mơ dịu nhẹ
      case MascotMood.celebrate:
        return const Color(0xFFFFB800); // Vàng kim rạng rỡ
    }
  }

  /// Lấy màu bóng đổ 3D theo mood
  Color _getMoodShadowColor() {
    switch (widget.mood) {
      case MascotMood.focus:
        return AppColors.blueDark;
      case MascotMood.excited:
        return AppColors.orangeDark;
      case MascotMood.relax:
      case MascotMood.idle:
        return AppColors.greenDark;
      case MascotMood.sleepy:
        return const Color(0xFF4834D4);
      case MascotMood.celebrate:
        return const Color(0xFFE58E26);
    }
  }

  /// Lấy biểu tượng emote nhỏ gắn trên góc avatar
  String? _getMoodEmote() {
    switch (widget.mood) {
      case MascotMood.focus:
        return '🎯';
      case MascotMood.excited:
        return '✨';
      case MascotMood.relax:
        return '☕';
      case MascotMood.sleepy:
        return '💤';
      case MascotMood.celebrate:
        return '👑';
      case MascotMood.idle:
        return null;
    }
  }

  /// Lấy phụ kiện đang đeo từ StorageService
  String _getEquippedAccessoryIcon() {
    final equippedId = StorageService.getMascotAccessory();
    final item = kMascotAccessories.firstWhere(
      (a) => a.id == equippedId,
      orElse: () => kMascotAccessories.first,
    );
    return item.icon;
  }

  @override
  Widget build(BuildContext context) {
    final moodColor = _getMoodColor();
    final moodShadow = _getMoodShadowColor();
    final moodEmote = _getMoodEmote();
    final accessoryIcon = _getEquippedAccessoryIcon();

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.centerLeft,
      children: [
        // 1. Mascot interactive button
        GestureDetector(
          onTap: _onTap,
          onLongPress: _onLongPress,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Vỏ avatar với màu sắc theo tâm trạng (mood)
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: moodColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: moodShadow,
                      blurRadius: 0,
                      offset: const Offset(0, 3.5),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: EdgeInsets.all(widget.size * 0.1),
                  child: Image.asset(
                    'assets/images/mascot.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Phụ kiện đang đeo hiển thị góc trên bên phải
              Positioned(
                right: -3,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    shape: BoxShape.circle,
                    border: Border.all(color: moodColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: Text(
                    accessoryIcon,
                    style: TextStyle(fontSize: widget.size * 0.23),
                  ),
                ),
              ),

              // Badge emote hiển thị mood ở góc dưới bên phải
              if (moodEmote != null)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      shape: BoxShape.circle,
                      border: Border.all(color: moodColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      moodEmote,
                      style: TextStyle(fontSize: widget.size * 0.24),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 2. Motivational speech bubble
        if (_currentQuote != null)
          Positioned(
            left: widget.size + 14,
            top: -6,
            child: GestureDetector(
              onTap: _openCompanionModal,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 220),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: moodColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: moodColor.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentQuote!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    if (widget.enableCompanionModal) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Chạm để mở góc tâm tình',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: moodColor,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.chevron_right_rounded,
                              size: 12, color: moodColor),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
