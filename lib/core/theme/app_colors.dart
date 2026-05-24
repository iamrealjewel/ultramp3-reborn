import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Backgrounds
  static const Color voidBlack = Color(0xFF07070A);
  static const Color obsidianDark = Color(0xFF0F0F16);
  static const Color surfaceCard = Color(0xFF161622);

  // Neon Retro Accents
  static const Color neonGreen =
      Color(0xFF39FF14); // Playback active state, equalizers
  static const Color electricCyan =
      Color(0xFF00E5FF); // Seek bar, progress, timers
  static const Color cyberPink =
      Color(0xFFFF0055); // Heart/Favorites active status, warnings
  static const Color laserViolet = Color(0xFF9D00FF); // Ambient glow accents

  // Typography Colors
  static const Color textPrimary = Color(0xFFF5F5FA);
  static const Color textSecondary = Color(0xFF9898AB);
  static const Color textMuted = Color(0xFF5A5A6D);

  // Glassmorphic Overlays & Gradients
  static const Color glassBackground = Color(0x0AFFFFFF);
  static const Color glassBorder = Color(0x1AFFFFFF);

  // Sleek Neon Gradients
  static const LinearGradient cyberGreenGradient = LinearGradient(
    colors: [Color(0xFF39FF14), Color(0xFF00E5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pinkVioletGradient = LinearGradient(
    colors: [Color(0xFFFF0055), Color(0xFF9D00FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassBorderGradient = LinearGradient(
    colors: [
      Color(0x33FFFFFF),
      Color(0x05FFFFFF),
      Color(0x05FFFFFF),
      Color(0x22FFFFFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.4, 0.6, 1.0],
  );

  // Glow Shadow Helpers
  static List<BoxShadow> neonGlow(
      {required Color color, double blurRadius = 12}) {
    return [
      BoxShadow(
        color: color.withOpacity(0.4),
        blurRadius: blurRadius,
        spreadRadius: 1,
      ),
      BoxShadow(
        color: color.withOpacity(0.2),
        blurRadius: blurRadius * 2,
        spreadRadius: 2,
      ),
    ];
  }
}
