import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class SoundWaveVisualizer extends StatefulWidget {
  final bool isPlaying;
  final String soundModeName;
  final String soundModeIcon;
  final VoidCallback onToggle;
  final VoidCallback onNextSound;

  const SoundWaveVisualizer({
    super.key,
    required this.isPlaying,
    required this.soundModeName,
    required this.soundModeIcon,
    required this.onToggle,
    required this.onNextSound,
  });

  @override
  State<SoundWaveVisualizer> createState() => _SoundWaveVisualizerState();
}

class _SoundWaveVisualizerState extends State<SoundWaveVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isPlaying ? AppColors.green : AppColors.border,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onToggle,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isPlaying ? AppColors.green : AppColors.bgPage,
                border: Border.all(color: widget.isPlaying ? AppColors.green : AppColors.border, width: 2),
              ),
              child: Center(
                child: Text(widget.soundModeIcon, style: const TextStyle(fontSize: 20)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      widget.soundModeName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: widget.isPlaying ? AppColors.green : AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: widget.onNextSound,
                      child: const Text(
                        'Đổi âm thanh',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedBuilder(
                  animation: _animCtrl,
                  builder: (context, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(18, (index) {
                        final factor = widget.isPlaying
                            ? (math.sin(_animCtrl.value * 2 * math.pi + index * 0.5).abs() * 18 + 4)
                            : 3.0;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 80),
                          width: 3,
                          height: factor,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: widget.isPlaying ? AppColors.green : AppColors.border,
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
