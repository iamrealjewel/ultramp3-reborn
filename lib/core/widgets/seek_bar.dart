import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SeekBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final Duration totalDuration;
  final ValueChanged<double> onSeek;

  const SeekBar({
    super.key,
    required this.progress,
    required this.totalDuration,
    required this.onSeek,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final currentDuration = Duration(
      milliseconds: (totalDuration.inMilliseconds * progress).round(),
    );

    return Column(
      children: [
        // Digital Clock Timestamps Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(currentDuration),
              style: const TextStyle(
                color: AppColors.electricCyan,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Orbitron',
              ),
            ),
            Text(
              _formatDuration(totalDuration),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontFamily: 'Orbitron',
              ),
            ),
          ],
        ),

        // Interactive Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.electricCyan,
            inactiveTrackColor: AppColors.surfaceCard,
            thumbColor: AppColors.electricCyan,
            overlayColor: AppColors.electricCyan.withOpacity(0.12),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: onSeek,
          ),
        ),
      ],
    );
  }
}
