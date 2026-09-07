import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/storage_service.dart';
import '../../features/home/presentation/widgets/mascot_companion_modal.dart';
import '../services/audio_synth_service.dart';

/// Các trạng thái biểu cảm của linh vật Mascot Cú Sĩ tử
enum MascotMood {
  idle, // Trạng thái thở bồng bềnh bình thường
  focus, // Tập trung học tập Pomodoro
  excited, // Phấn khích khi hoàn thành bài tập / tap combo
  relax, // Thư giãn nghỉ ngơi giữa hiệp
  sleepy, // Buồn ngủ khi quá khuya
  celebrate, // Ăn mừng streak hoặc hoàn thành toàn bộ mục tiêu ngày
}

/// Dữ liệu một hạt hiệu ứng (particle) bay lên khi tương tác
class _MascotParticle {
  final Key id = UniqueKey();
  final String symbol;
  final double startX;
  final double driftX;
  final double speed;
  final double size;

  _MascotParticle({
    required this.symbol,
    required this.startX,
    required this.driftX,
    required this.speed,
    required this.size,
  });
}

/// Avatar linh vật Cú Sĩ tử tương tác cao cấp (Cấp 1, Cấp 2 & Cấp 3):
/// - Chuyển động vi mô: Idle breathing + Periodic ear twitching + Dynamic drag gaze tracking
/// - Tủ đồ phụ kiện đồng bộ với StorageService
/// - Context-aware speech quotes + Interactive Sound Synth (Duolingo-style)
/// - Tap to cheer / Multi-tap combo / Long-press to open "Góc Tâm Tình Sĩ Tử"
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

class _MascotAvatarState extends State<MascotAvatar>
    with TickerProviderStateMixin {
  // 1. Idle breathing float
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  // 2. Spring pop on tap
  late final AnimationController _tapCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _rotateAnim;

  // 3. Ear twitching animation (Cấp 3 sinh học)
  late final AnimationController _earTwitchCtrl;
  late final Animation<double> _earTwitchAnim;
  Timer? _earTwitchTimer;

  // 4. Interactive gaze tilt
  double _dragTilt = 0.0;

  // 5. Particles controller
  late final AnimationController _particleCtrl;
  final List<_MascotParticle> _activeParticles = [];
  final math.Random _random = math.Random();

  // 6. Quotes & Interaction state
  String? _currentQuote;
  Timer? _quoteTimer;
  int _quoteIndex = 0;
  int _tapCount = 0;
  Timer? _comboResetTimer;

  @override
  void initState() {
    super.initState();

    // 1. Idle breathing float animation (3.0s)
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _floatAnim = Tween<double>(begin: 0.0, end: -4.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOutSine),
    );
    _floatCtrl.repeat(reverse: true);

    // 2. Tap spring pop animation
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.22)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.22, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 55,
      ),
    ]).animate(_tapCtrl);

    _rotateAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.08, end: 0.07)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.07, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
    ]).animate(_tapCtrl);

    // 3. Ear twitching (giật tai mèo 4.8s một lần tạo sức sống sinh học)
    _earTwitchCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _earTwitchAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.09)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.09, end: 0.07)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.07, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
    ]).animate(_earTwitchCtrl);

    _earTwitchTimer = Timer.periodic(const Duration(milliseconds: 4800), (_) {
      if (!mounted) return;
      if (!_tapCtrl.isAnimating) {
        _earTwitchCtrl.forward(from: 0.0);
      }
    });

    // 4. Particles controller
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _particleCtrl.addListener(() {
      if (_particleCtrl.isCompleted) {
        setState(() => _activeParticles.clear());
      }
    });
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _comboResetTimer?.cancel();
    _earTwitchTimer?.cancel();
    _floatCtrl.dispose();
    _tapCtrl.dispose();
    _earTwitchCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  /// Phát sinh hạt lấp lánh hoặc tim khi tương tác
  void _spawnParticles({bool isHeart = false}) {
    final symbols = isHeart
        ? ['❤️', '💖', '✨', '🥰']
        : ['✨', '⭐', '🌟', '🎉'];
    _activeParticles.clear();
    for (int i = 0; i < 5; i++) {
      _activeParticles.add(
        _MascotParticle(
          symbol: symbols[_random.nextInt(symbols.length)],
          startX: (_random.nextDouble() - 0.5) * widget.size * 0.8,
          driftX: (_random.nextDouble() - 0.5) * 36,
          speed: 0.8 + _random.nextDouble() * 0.5,
          size: 13.0 + _random.nextDouble() * 6.0,
        ),
      );
    }
    _particleCtrl.forward(from: 0.0);
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

    final quote = contextualPool[_quoteIndex % contextualPool.length];
    _quoteIndex++;
    return quote;
  }

  void _onTap() {
    _tapCount++;
    _comboResetTimer?.cancel();
    _comboResetTimer = Timer(const Duration(milliseconds: 1200), () {
      _tapCount = 0;
    });

    if (_tapCount >= 3) {
      // Combo tap easter egg
      AudioSynthService.playPop();
      _spawnParticles(isHeart: true);
    } else {
      AudioSynthService.playChirp();
      _spawnParticles(isHeart: false);
    }

    _tapCtrl.forward(from: 0.0);

    setState(() {
      _currentQuote = _getContextualQuote();
    });

    _quoteTimer?.cancel();
    _quoteTimer = Timer(const Duration(milliseconds: 3600), () {
      if (mounted) {
        setState(() => _currentQuote = null);
      }
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
    _spawnParticles(isHeart: true);
    _tapCtrl.forward(from: 0.0);
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
        return AppColors.green;
      case MascotMood.sleepy:
        return const Color(0xFF6C5CE7); // Tím mộng mơ dịu nhẹ
      case MascotMood.celebrate:
        return const Color(0xFFFFB800); // Vàng kim rạng rỡ
      case MascotMood.idle:
        return AppColors.green;
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
        return AppColors.greenDark;
      case MascotMood.sleepy:
        return const Color(0xFF4834D4);
      case MascotMood.celebrate:
        return const Color(0xFFE58E26);
      case MascotMood.idle:
        return AppColors.greenDark;
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
    final reducedMotion = MediaQuery.of(context).disableAnimations;
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
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragTilt = (details.primaryDelta ?? 0.0) * 0.015;
            });
          },
          onHorizontalDragEnd: (_) {
            setState(() => _dragTilt = 0.0);
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: Listenable.merge([_floatCtrl, _tapCtrl, _earTwitchCtrl]),
            builder: (context, child) {
              final dy = reducedMotion ? 0.0 : _floatAnim.value;
              final scale = reducedMotion ? 1.0 : _scaleAnim.value;
              final rot = reducedMotion
                  ? 0.0
                  : (_rotateAnim.value + _earTwitchAnim.value + _dragTilt);

              return Transform.translate(
                offset: Offset(0, dy),
                child: Transform.rotate(
                  angle: rot,
                  child: Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                ),
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Vỏ avatar với màu sắc theo tâm trạng (mood)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
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

                // Hạt hiệu ứng bay lên khi tap (Particles)
                if (_activeParticles.isNotEmpty && !reducedMotion)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _particleCtrl,
                      builder: (context, _) {
                        final progress = _particleCtrl.value;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: _activeParticles.map((p) {
                            final dy = -progress * p.speed * 48.0;
                            final dx = p.startX + (progress * p.driftX);
                            final opacity = (1.0 - progress).clamp(0.0, 1.0);
                            final scale = (0.5 + progress * 0.6).clamp(0.0, 1.3);

                            return Positioned(
                              left: widget.size / 2 + dx,
                              top: widget.size / 2 + dy,
                              child: Opacity(
                                opacity: opacity,
                                child: Transform.scale(
                                  scale: scale,
                                  child: Text(
                                    p.symbol,
                                    style: TextStyle(fontSize: p.size),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 2. Motivational speech bubble
        if (_currentQuote != null)
          Positioned(
            left: widget.size + 14,
            top: -6,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              builder: (context, val, child) {
                return Transform.scale(
                  scale: val,
                  alignment: Alignment.centerLeft,
                  child: Opacity(
                    opacity: val.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
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
          ),
      ],
    );
  }
}
