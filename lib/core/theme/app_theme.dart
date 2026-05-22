import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color glassBgColor;
  final Color glassBorderColor;
  final List<BoxShadow> greenGlow;
  final List<BoxShadow> cyanGlow;
  final List<BoxShadow> pinkGlow;
  final TextStyle digitalClockStyle;
  final TextStyle trackTitleStyle;

  AppThemeExtension({
    required this.glassBgColor,
    required this.glassBorderColor,
    required this.greenGlow,
    required this.cyanGlow,
    required this.pinkGlow,
    required this.digitalClockStyle,
    required this.trackTitleStyle,
  });

  @override
  AppThemeExtension copyWith({
    Color? glassBgColor,
    Color? glassBorderColor,
    List<BoxShadow>? greenGlow,
    List<BoxShadow>? cyanGlow,
    List<BoxShadow>? pinkGlow,
    TextStyle? digitalClockStyle,
    TextStyle? trackTitleStyle,
  }) {
    return AppThemeExtension(
      glassBgColor: glassBgColor ?? this.glassBgColor,
      glassBorderColor: glassBorderColor ?? this.glassBorderColor,
      greenGlow: greenGlow ?? this.greenGlow,
      cyanGlow: cyanGlow ?? this.cyanGlow,
      pinkGlow: pinkGlow ?? this.pinkGlow,
      digitalClockStyle: digitalClockStyle ?? this.digitalClockStyle,
      trackTitleStyle: trackTitleStyle ?? this.trackTitleStyle,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      glassBgColor: Color.lerp(glassBgColor, other.glassBgColor, t)!,
      glassBorderColor: Color.lerp(glassBorderColor, other.glassBorderColor, t)!,
      greenGlow: other.greenGlow, // Complex structures lerp to other directly
      cyanGlow: other.cyanGlow,
      pinkGlow: other.pinkGlow,
      digitalClockStyle: TextStyle.lerp(digitalClockStyle, other.digitalClockStyle, t)!,
      trackTitleStyle: TextStyle.lerp(trackTitleStyle, other.trackTitleStyle, t)!,
    );
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.voidBlack,
      primaryColor: AppColors.neonGreen,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.neonGreen,
        secondary: AppColors.electricCyan,
        tertiary: AppColors.cyberPink,
        surface: AppColors.obsidianDark,
        onSurface: AppColors.textPrimary,
        error: AppColors.cyberPink,
      ),
      textTheme: GoogleFonts.outfitTextTheme().copyWith(
        displayLarge: GoogleFonts.orbitron(
          color: AppColors.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
        displayMedium: GoogleFonts.orbitron(
          color: AppColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        titleLarge: GoogleFonts.outfit(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.outfit(
          color: AppColors.textPrimary,
          fontSize: 16,
        ),
        bodyMedium: GoogleFonts.outfit(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        labelLarge: GoogleFonts.rajdhani(
          color: AppColors.textSecondary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.obsidianDark,
        selectedItemColor: AppColors.neonGreen,
        unselectedItemColor: AppColors.textMuted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.electricCyan,
        inactiveTrackColor: AppColors.surfaceCard,
        thumbColor: AppColors.electricCyan,
        overlayColor: Color(0x3300E5FF),
        trackHeight: 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      extensions: [
        AppThemeExtension(
          glassBgColor: AppColors.glassBackground,
          glassBorderColor: AppColors.glassBorder,
          greenGlow: AppColors.neonGlow(color: AppColors.neonGreen),
          cyanGlow: AppColors.neonGlow(color: AppColors.electricCyan),
          pinkGlow: AppColors.neonGlow(color: AppColors.cyberPink),
          digitalClockStyle: GoogleFonts.orbitron(
            color: AppColors.neonGreen,
            fontSize: 48,
            fontWeight: FontWeight.bold,
            shadows: [
              const Shadow(
                color: AppColors.neonGreen,
                blurRadius: 10,
              ),
            ],
          ),
          trackTitleStyle: GoogleFonts.rajdhani(
            color: AppColors.neonGreen,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
