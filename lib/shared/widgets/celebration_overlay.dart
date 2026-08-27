import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class CelebrationOverlay extends StatefulWidget {
  final String title;
  final String subtitle;
  final VoidCallback onContinue;

  const CelebrationOverlay({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onContinue,
  });

  static Future<void> show(
    BuildContext context, {
    String title = 'HOÀN THÀNH!',
    String subtitle = '+10 XP',
    required VoidCallback onContinue,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => CelebrationOverlay(
        title: title,
        subtitle: subtitle,
        onContinue: onContinue,
      ),
    );
  }

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.green,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const ConfettiParticles(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.yellow,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onContinue();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: AppColors.greenDark, blurRadius: 0, offset: Offset(0, 4)),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'TIẾP TỤC',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppColors.green,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ConfettiParticles extends StatefulWidget {
  const ConfettiParticles({super.key});

  @override
  State<ConfettiParticles> createState() => _ConfettiParticlesState();
}

class _ConfettiParticlesState extends State<ConfettiParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, child) {
          return CustomPaint(
            size: const Size(280, 320),
            painter: _ConfettiPainter(_ctrl.value),
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  _ConfettiPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(42);
    final colors = [AppColors.yellow, AppColors.blue, AppColors.purple, Colors.white, AppColors.orange];
    const n = 12;
    for (int i = 0; i < n; i++) {
      final seedX = rand.nextInt(100);
      final seedY = rand.nextInt(100);
      final x = size.width * seedX / 100 + math.sin(t * 2 * math.pi * 2 + i) * 12;
      final y = size.height * (0.1 + t) + seedY * 0.3 - (t * size.height * 0.2);
      final color = colors[i % colors.length];
      final paint = Paint()..color = color;
      final sizeP = 6.0 + rand.nextInt(4);
      final rect = Rect.fromCenter(center: Offset(x, y), width: sizeP, height: sizeP * 1.6);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 2 * math.pi * 3 + i);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
