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
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isPlaying
              ? AppColors.neonCyan.withValues(alpha: 0.4)
              : (isDark ? Colors.white12 : Colors.black12),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          // Sound icon with pulse
          GestureDetector(
            onTap: widget.onToggle,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: widget.isPlaying
                    ? const LinearGradient(
                        colors: [AppColors.neonCyan, AppColors.neonPurple],
                      )
                    : null,
                color: widget.isPlaying
                    ? null
                    : (isDark ? Colors.white10 : Colors.black12),
                boxShadow: widget.isPlaying
                    ? [
                        BoxShadow(
                          color: AppColors.neonCyan.withValues(alpha: 0.4),
                          blurRadius: 10,
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  widget.soundModeIcon,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info & wave
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Lo-Fi Focus: ${widget.soundModeName}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.isPlaying
                            ? AppColors.neonCyan
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: widget.onNextSound,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Đổi âm thanh ↻',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black45,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Animated sound bars
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
                            gradient: widget.isPlaying
                                ? const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      AppColors.neonCyan,
                                      AppColors.neonPurple,
                                    ],
                                  )
                                : null,
                            color: widget.isPlaying
                                ? null
                                : (isDark ? Colors.white12 : Colors.black12),
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
