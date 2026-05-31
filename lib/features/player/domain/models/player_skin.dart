import 'package:flutter/material.dart';

class PlayerSkin {
  final String name;
  final Color outerBorderColor;
  final Color panelBgColor; // Base background color
  final List<Color> metallicGradients; // Dashboard gradient / flat base colors
  final Color lcdBgColor; // Glowing glass background
  final Color lcdBorderColor;
  final Color textColor; // Digital clock and marquee text
  final Color textMutedColor; // Inactive LCD labels
  final Color visualizerColor; // Active frequency columns
  final Color visualizerPeakColor; // Peak decibel floating dots
  final Color buttonFaceColor; // Tactile button face
  final Color buttonIconColor; // Icon glyph active color
  final Color statusLedColor; // Glowing indicator LED
  final String bgAssetPath; // Swappable landscape background image path
  final bool
      isFlat; // True for modern flat skins, false for metallic/skeuomorphic

  const PlayerSkin({
    required this.name,
    required this.outerBorderColor,
    required this.panelBgColor,
    required this.metallicGradients,
    required this.lcdBgColor,
    required this.lcdBorderColor,
    required this.textColor,
    required this.textMutedColor,
    required this.visualizerColor,
    required this.visualizerPeakColor,
    required this.buttonFaceColor,
    required this.buttonIconColor,
    required this.statusLedColor,
    required this.bgAssetPath,
    this.isFlat = false,
  });

  // 1. Lonely Cat S60 Classic Grey
  static const PlayerSkin s60Grey = PlayerSkin(
    name: 'S60 Classic Grey',
    outerBorderColor: Color(0xFF1E1E22),
    panelBgColor: Color(0xFF28282C),
    metallicGradients: [
      Color(0xFF3A3A3F),
      Color(0xFF2A2A2E),
      Color(0xFF1C1C1F),
      Color(0xFF3A3A3F),
    ],
    lcdBgColor: Color(0xFF141518), // Reflective Dark Obsidian Glass
    lcdBorderColor: Color(0xFF2E3138),
    textColor: Color(0xFFECEFF4), // Glowing Ice White active pixels
    textMutedColor: Color(0xFF818693), // Muted Silver
    visualizerColor: Color(0xFFECEFF4),
    visualizerPeakColor: Color(0xFF00FFCC), // Ice Cyan Peak Markers
    buttonFaceColor: Color(0xFF36373C), // Brushed Dark Chrome button base
    buttonIconColor: Color(0xFFECEFF4),
    statusLedColor: Color(0xFF00FFBB), // Glowing Mint LED
    bgAssetPath: 'assets/images/bg_classic_gray.png',
    isFlat: false,
  );

  // 2. Symbian Classic Blue
  static const PlayerSkin classicBlue = PlayerSkin(
    name: 'Symbian Classic Blue',
    outerBorderColor: Color(0xFF1B2A4A),
    panelBgColor: Color(0xFF1E2B4B),
    metallicGradients: [
      Color(0xFF354875),
      Color(0xFF1D294E),
      Color(0xFF101933),
      Color(0xFF354875),
    ],
    lcdBgColor: Color(0xFF070E1A), // Midnight blue
    lcdBorderColor: Color(0xFF15223C),
    textColor: Color(0xFF00E5FF), // Electric cyan
    textMutedColor: Color(0xFF2E456B),
    visualizerColor: Color(0xFF00E5FF),
    visualizerPeakColor: Color(0xFFFF0055),
    buttonFaceColor: Color(0xFF233256),
    buttonIconColor: Color(0xFFF5F5FA),
    statusLedColor: Color(0xFF00FF00),
    bgAssetPath: 'assets/images/bg_starry.png',
  );

  // 3. Obsidian Void
  static const PlayerSkin obsidianVoid = PlayerSkin(
    name: 'Obsidian Void',
    outerBorderColor: Color(0xFF1E1E26),
    panelBgColor: Color(0xFF09090C),
    metallicGradients: [
      Color(0xFF1E1E27),
      Color(0xFF0F0F14),
      Color(0xFF070709),
      Color(0xFF1E1E27),
    ],
    lcdBgColor: Color(0xFF000000), // Black void
    lcdBorderColor: Color(0xFF1C1C26),
    textColor: Color(0xFF39FF14), // Neon toxic green
    textMutedColor: Color(0xFF3A3A4A),
    visualizerColor: Color(0xFF39FF14),
    visualizerPeakColor: Color(0xFFFF0055),
    buttonFaceColor: Color(0xFF13131A),
    buttonIconColor: Color(0xFF39FF14),
    statusLedColor: Color(0xFFFF0055),
    bgAssetPath: 'assets/images/bg_scifi.png',
  );

  // 4. Matrix Amber
  static const PlayerSkin matrixAmber = PlayerSkin(
    name: 'Matrix Amber',
    outerBorderColor: Color(0xFF3B2A15),
    panelBgColor: Color(0xFF1E160E),
    metallicGradients: [
      Color(0xFF2D2012),
      Color(0xFF1C1309),
      Color(0xFF0D0803),
      Color(0xFF2D2012),
    ],
    lcdBgColor: Color(0xFF1D0E02), // Amber orange
    lcdBorderColor: Color(0xFF3E2005),
    textColor: Color(0xFFFF9000), // Gas-plasma amber
    textMutedColor: Color(0xFF6E390A),
    visualizerColor: Color(0xFFFF9000),
    visualizerPeakColor: Color(0xFFFF0000),
    buttonFaceColor: Color(0xFF2B1D0E),
    buttonIconColor: Color(0xFFFFA500),
    statusLedColor: Color(0xFFFF0000),
    bgAssetPath: 'assets/images/bg_milkyway.png',
  );

  // 5. Ferrari Special Edition
  static const PlayerSkin ferrariRed = PlayerSkin(
    name: 'Ferrari Special Edition',
    outerBorderColor: Color(0xFF8B0000), // Dark racing red
    panelBgColor: Color(0xFFCC0000), // Racing red
    metallicGradients: [
      Color(0xFFFF3333),
      Color(0xFFCC0000),
      Color(0xFF8B0000),
      Color(0xFFFF3333),
    ],
    lcdBgColor: Color(0xFF100101), // Deep charcoal red
    lcdBorderColor: Color(0xFF550000),
    textColor: Color(0xFFFFCC00), // Ferrari yellow digits!
    textMutedColor: Color(0xFF882222),
    visualizerColor: Color(0xFFFF3333),
    visualizerPeakColor: Color(0xFFFFCC00),
    buttonFaceColor: Color(0xFF990000),
    buttonIconColor: Color(0xFFFFFFFF),
    statusLedColor: Color(0xFFFFCC00),
    bgAssetPath: 'assets/images/bg_ferrari.png',
  );

  // 6. Neon Aurora Green
  static const PlayerSkin auroraGreen = PlayerSkin(
    name: 'Neon Aurora Green',
    outerBorderColor: Color(0xFF0A2B18),
    panelBgColor: Color(0xFF0E3821),
    metallicGradients: [
      Color(0xFF1A5A35),
      Color(0xFF0E3821),
      Color(0xFF051D10),
      Color(0xFF1A5A35),
    ],
    lcdBgColor: Color(0xFF021207), // Dark forest green glow
    lcdBorderColor: Color(0xFF093517),
    textColor: Color(0xFF00FF88), // Glowing emerald green
    textMutedColor: Color(0xFF0F562E),
    visualizerColor: Color(0xFF00FF88),
    visualizerPeakColor: Color(0xFFFFFF00),
    buttonFaceColor: Color(0xFF114227),
    buttonIconColor: Color(0xFF00FF88),
    statusLedColor: Color(0xFF00FF88),
    bgAssetPath: 'assets/images/bg_aurora.png',
  );

  // 9. Desert Horizon Gold
  static const PlayerSkin desertGold = PlayerSkin(
    name: 'Desert Horizon Gold',
    outerBorderColor: Color(0xFF3D2505),
    panelBgColor: Color(0xFF5C3C0B),
    metallicGradients: [
      Color(0xFF8A5D19),
      Color(0xFF5C3C0B),
      Color(0xFF301E03),
      Color(0xFF8A5D19),
    ],
    lcdBgColor: Color(0xFF1A0F01), // Golden desert dusk
    lcdBorderColor: Color(0xFF4D3004),
    textColor: Color(0xFFFFCC00), // Sparkling solar gold
    textMutedColor: Color(0xFF7A500D),
    visualizerColor: Color(0xFFFFCC00),
    visualizerPeakColor: Color(0xFFFF4500), // Orange-red solar flare peaks
    buttonFaceColor: Color(0xFF4C3008),
    buttonIconColor: Color(0xFFFFCC00),
    statusLedColor: Color(0xFFFF4500),
    bgAssetPath: 'assets/images/bg_desert.png',
  );

  // 10. Glacier Crystalline Ice
  static const PlayerSkin glacierIce = PlayerSkin(
    name: 'Glacier Crystalline Ice',
    outerBorderColor: Color(0xFF0C2430),
    panelBgColor: Color(0xFF143B4E),
    metallicGradients: [
      Color(0xFF255D75),
      Color(0xFF143B4E),
      Color(0xFF0A222E),
      Color(0xFF255D75),
    ],
    lcdBgColor: Color(0xFF031016), // Deep blue glacier cave
    lcdBorderColor: Color(0xFF0E2E3E),
    textColor: Color(0xFF00F0FF), // Sparkling glacial crystalline cyan
    textMutedColor: Color(0xFF1B5570),
    visualizerColor: Color(0xFF00F0FF),
    visualizerPeakColor: Color(0xFFFFFFFF), // Pure white snow peaks
    buttonFaceColor: Color(0xFF113242),
    buttonIconColor: Color(0xFF00F0FF),
    statusLedColor: Color(0xFFFFFFFF),
    bgAssetPath: 'assets/images/bg_glacier.png',
  );

  // ==========================================
  // FLAT SKINS (Modern Minimalist Designs)
  // ==========================================

  // 11. Flat Cyberpunk Neon
  static const PlayerSkin flatCyberpunk = PlayerSkin(
    name: 'Flat Cyberpunk',
    outerBorderColor: Color(0xFF1A1B26),
    panelBgColor: Color(0xFF1F2335),
    metallicGradients: [
      Color(0xFF1F2335),
      Color(0xFF1F2335),
      Color(0xFF1F2335),
      Color(0xFF1F2335),
    ],
    lcdBgColor: Color(0xFF16161E),
    lcdBorderColor: Color(0xFFBB9AF7),
    textColor: Color(0xFFFF007F), // Neon Pink
    textMutedColor: Color(0xFF565F89),
    visualizerColor: Color(0xFF7AA2F7), // Neon Blue
    visualizerPeakColor: Color(0xFF00F0FF), // Cyan
    buttonFaceColor: Color(0xFF24283B),
    buttonIconColor: Color(0xFFBB9AF7),
    statusLedColor: Color(0xFFFF007F),
    bgAssetPath: 'assets/images/bg_scifi.png',
    isFlat: true,
  );

  // 12. Flat Mint Forest (Refitted for premium dark solid background)
  static const PlayerSkin flatMint = PlayerSkin(
    name: 'Flat Mint Forest',
    outerBorderColor: Color(0xFF2D4435),
    panelBgColor: Color(0xFF18221B),
    metallicGradients: [
      Color(0xFF18221B),
      Color(0xFF18221B),
      Color(0xFF18221B),
      Color(0xFF18221B),
    ],
    lcdBgColor: Color(0xFF0C140F),
    lcdBorderColor: Color(0xFF27AE60),
    textColor: Color(0xFF2ECC71), // Glowing neon mint emerald
    textMutedColor: Color(0xFF1E6C3E),
    visualizerColor: Color(0xFF2ECC71),
    visualizerPeakColor: Color(0xFFE74C3C),
    buttonFaceColor: Color(0xFF202C23),
    buttonIconColor: Color(0xFF2ECC71),
    statusLedColor: Color(0xFF2ECC71),
    bgAssetPath: 'assets/images/bg_nature.png',
    isFlat: true,
  );

  // 13. Flat Peach Blossom (Refitted for premium dark solid background)
  static const PlayerSkin flatPeach = PlayerSkin(
    name: 'Flat Peach Blossom',
    outerBorderColor: Color(0xFF442D28),
    panelBgColor: Color(0xFF221A18),
    metallicGradients: [
      Color(0xFF221A18),
      Color(0xFF221A18),
      Color(0xFF221A18),
      Color(0xFF221A18),
    ],
    lcdBgColor: Color(0xFF140C0A),
    lcdBorderColor: Color(0xFFE67E22),
    textColor: Color(0xFFFF7043), // Glowing neon coral peach
    textMutedColor: Color(0xFFD35400),
    visualizerColor: Color(0xFFFF7043),
    visualizerPeakColor: Color(0xFFF1C40F),
    buttonFaceColor: Color(0xFF2C211E),
    buttonIconColor: Color(0xFFFF7043),
    statusLedColor: Color(0xFFFF7043),
    bgAssetPath: 'assets/images/bg_desert.png',
    isFlat: true,
  );

  // 14. Flat Dark Monochrome
  static const PlayerSkin flatDark = PlayerSkin(
    name: 'Flat Dark Monochrome',
    outerBorderColor: Color(0xFF121212),
    panelBgColor: Color(0xFF1F1F1F),
    metallicGradients: [
      Color(0xFF1F1F1F),
      Color(0xFF1F1F1F),
      Color(0xFF1F1F1F),
      Color(0xFF1F1F1F),
    ],
    lcdBgColor: Color(0xFF121212),
    lcdBorderColor: Color(0xFF333333),
    textColor: Color(0xFFFFFFFF),
    textMutedColor: Color(0xFF757575),
    visualizerColor: Color(0xFFE0E0E0),
    visualizerPeakColor: Color(0xFF9E9E9E),
    buttonFaceColor: Color(0xFF2D2D2D),
    buttonIconColor: Color(0xFFFFFFFF),
    statusLedColor: Color(0xFFBDBDBD),
    bgAssetPath: 'assets/images/bg_starry.png',
    isFlat: true,
  );

  // 15. Flat Amethyst Violet
  static const PlayerSkin flatAmethyst = PlayerSkin(
    name: 'Flat Amethyst Violet',
    outerBorderColor: Color(0xFF2C1A3C),
    panelBgColor: Color(0xFF160E22),
    metallicGradients: [
      Color(0xFF160E22),
      Color(0xFF160E22),
      Color(0xFF160E22),
      Color(0xFF160E22),
    ],
    lcdBgColor: Color(0xFF0F0A18),
    lcdBorderColor: Color(0xFF9B59B6),
    textColor: Color(0xFFBF55EC), // Glowing neon purple
    textMutedColor: Color(0xFF7D3C98),
    visualizerColor: Color(0xFFBF55EC),
    visualizerPeakColor: Color(0xFFE26A6A),
    buttonFaceColor: Color(0xFF1E132D),
    buttonIconColor: Color(0xFFBF55EC),
    statusLedColor: Color(0xFFBF55EC),
    bgAssetPath: 'assets/images/bg_starry.png',
    isFlat: true,
  );

  // 16. Flat Amber Sunset
  static const PlayerSkin flatAmber = PlayerSkin(
    name: 'Flat Amber Sunset',
    outerBorderColor: Color(0xFF3B240E),
    panelBgColor: Color(0xFF1E1207),
    metallicGradients: [
      Color(0xFF1E1207),
      Color(0xFF1E1207),
      Color(0xFF1E1207),
      Color(0xFF1E1207),
    ],
    lcdBgColor: Color(0xFF140C05),
    lcdBorderColor: Color(0xFFE67E22),
    textColor: Color(0xFFF39C12), // Bright golden amber
    textMutedColor: Color(0xFFB9770E),
    visualizerColor: Color(0xFFF39C12),
    visualizerPeakColor: Color(0xFFE74C3C),
    buttonFaceColor: Color(0xFF27190A),
    buttonIconColor: Color(0xFFF39C12),
    statusLedColor: Color(0xFFF39C12),
    bgAssetPath: 'assets/images/bg_milkyway.png',
    isFlat: true,
  );

  // 17. Flat Polar Cyan
  static const PlayerSkin flatPolar = PlayerSkin(
    name: 'Flat Polar Cyan',
    outerBorderColor: Color(0xFF0D2535),
    panelBgColor: Color(0xFF07141E),
    metallicGradients: [
      Color(0xFF07141E),
      Color(0xFF07141E),
      Color(0xFF07141E),
      Color(0xFF07141E),
    ],
    lcdBgColor: Color(0xFF040C14),
    lcdBorderColor: Color(0xFF1ABC9C),
    textColor: Color(0xFF00E5FF), // Arctic cyan
    textMutedColor: Color(0xFF16A085),
    visualizerColor: Color(0xFF00E5FF),
    visualizerPeakColor: Color(0xFF3498DB),
    buttonFaceColor: Color(0xFF0A1D2B),
    buttonIconColor: Color(0xFF00E5FF),
    statusLedColor: Color(0xFF00E5FF),
    bgAssetPath: 'assets/images/bg_glacier.png',
    isFlat: true,
  );

  // 18. Flat Neon Sunset
  static const PlayerSkin flatNeonSunset = PlayerSkin(
    name: 'Flat Neon Sunset',
    outerBorderColor: Color(0xFF3D133D),
    panelBgColor: Color(0xFF1F0825),
    metallicGradients: [
      Color(0xFF1F0825),
      Color(0xFF1F0825),
      Color(0xFF1F0825),
      Color(0xFF1F0825),
    ],
    lcdBgColor: Color(0xFF100214),
    lcdBorderColor: Color(0xFFFF007F),
    textColor: Color(0xFFFF9000),
    textMutedColor: Color(0xFF9C1F8C),
    visualizerColor: Color(0xFFFF9000),
    visualizerPeakColor: Color(0xFFFF007F),
    buttonFaceColor: Color(0xFF2C0B35),
    buttonIconColor: Color(0xFFFF9000),
    statusLedColor: Color(0xFFFF9000),
    bgAssetPath: 'assets/images/bg_starry.png',
    isFlat: true,
  );

  // 19. Flat Sakura Pastel
  static const PlayerSkin flatSakuraPastel = PlayerSkin(
    name: 'Flat Sakura Pastel',
    outerBorderColor: Color(0xFF4C2A34),
    panelBgColor: Color(0xFF29151A),
    metallicGradients: [
      Color(0xFF29151A),
      Color(0xFF29151A),
      Color(0xFF29151A),
      Color(0xFF29151A),
    ],
    lcdBgColor: Color(0xFF180A0D),
    lcdBorderColor: Color(0xFFFF85A2),
    textColor: Color(0xFFFFB7B2),
    textMutedColor: Color(0xFFC05C7E),
    visualizerColor: Color(0xFFFFB7B2),
    visualizerPeakColor: Color(0xFFFF85A2),
    buttonFaceColor: Color(0xFF381C23),
    buttonIconColor: Color(0xFFFFB7B2),
    statusLedColor: Color(0xFFFFB7B2),
    bgAssetPath: 'assets/images/bg_nature.png',
    isFlat: true,
  );

  // 20. Flat Glassmorphic
  static const PlayerSkin flatGlassmorphic = PlayerSkin(
    name: 'Flat Glassmorphic',
    outerBorderColor: Color(0xFF0F2B48),
    panelBgColor: Color(0xFF091424),
    metallicGradients: [
      Color(0xFF091424),
      Color(0xFF091424),
      Color(0xFF091424),
      Color(0xFF091424),
    ],
    lcdBgColor: Color(0xFF040A12),
    lcdBorderColor: Color(0xFF00FFCC),
    textColor: Color(0xFF00E5FF),
    textMutedColor: Color(0xFF138A8A),
    visualizerColor: Color(0xFF00E5FF),
    visualizerPeakColor: Color(0xFFFF007F),
    buttonFaceColor: Color(0xFF0D1F36),
    buttonIconColor: Color(0xFF00E5FF),
    statusLedColor: Color(0xFF00FFCC),
    bgAssetPath: 'assets/images/bg_scifi.png',
    isFlat: true,
  );

  // 21. Flat Lo-Fi Rain
  static const PlayerSkin flatLofiRain = PlayerSkin(
    name: 'Flat Lo-Fi Rain',
    outerBorderColor: Color(0xFF1E293B),
    panelBgColor: Color(0xFF0F172A),
    metallicGradients: [
      Color(0xFF0F172A),
      Color(0xFF0F172A),
      Color(0xFF0F172A),
      Color(0xFF0F172A),
    ],
    lcdBgColor: Color(0xFF020617),
    lcdBorderColor: Color(0xFF818CF8),
    textColor: Color(0xFFC7D2FE),
    textMutedColor: Color(0xFF475569),
    visualizerColor: Color(0xFF818CF8),
    visualizerPeakColor: Color(0xFFC7D2FE),
    buttonFaceColor: Color(0xFF1E293B),
    buttonIconColor: Color(0xFFC7D2FE),
    statusLedColor: Color(0xFF818CF8),
    bgAssetPath: 'assets/images/bg_starry.png',
    isFlat: true,
  );

  // 22. Flat Minimal Techno
  static const PlayerSkin flatMinimalTechno = PlayerSkin(
    name: 'Flat Minimal Techno',
    outerBorderColor: Color(0xFF1F2937),
    panelBgColor: Color(0xFF111827),
    metallicGradients: [
      Color(0xFF111827),
      Color(0xFF111827),
      Color(0xFF111827),
      Color(0xFF111827),
    ],
    lcdBgColor: Color(0xFF030712),
    lcdBorderColor: Color(0xFF10B981),
    textColor: Color(0xFF34D399),
    textMutedColor: Color(0xFF4B5563),
    visualizerColor: Color(0xFF10B981),
    visualizerPeakColor: Color(0xFF6EE7B7),
    buttonFaceColor: Color(0xFF1F2937),
    buttonIconColor: Color(0xFF34D399),
    statusLedColor: Color(0xFF10B981),
    bgAssetPath: 'assets/images/bg_scifi.png',
    isFlat: true,
  );

  // 23. Flat Vinyl Noir
  static const PlayerSkin flatVinylNoir = PlayerSkin(
    name: 'Flat Vinyl Noir',
    outerBorderColor: Color(0xFF27272A),
    panelBgColor: Color(0xFF09090B),
    metallicGradients: [
      Color(0xFF09090B),
      Color(0xFF09090B),
      Color(0xFF09090B),
      Color(0xFF09090B),
    ],
    lcdBgColor: Color(0xFF000000),
    lcdBorderColor: Color(0xFFEAB308),
    textColor: Color(0xFFFACC15),
    textMutedColor: Color(0xFF52525B),
    visualizerColor: Color(0xFFEAB308),
    visualizerPeakColor: Color(0xFFFDE047),
    buttonFaceColor: Color(0xFF18181B),
    buttonIconColor: Color(0xFFFACC15),
    statusLedColor: Color(0xFFEAB308),
    bgAssetPath: 'assets/images/bg_ferrari.png',
    isFlat: true,
  );

  // 24. Flat Pastel Lavender
  static const PlayerSkin flatPastelLavender = PlayerSkin(
    name: 'Flat Pastel Lavender',
    outerBorderColor: Color(0xFFDDD6FE),
    panelBgColor: Color(0xFFF5F3FF),
    metallicGradients: [
      Color(0xFFF5F3FF),
      Color(0xFFF5F3FF),
      Color(0xFFF5F3FF),
      Color(0xFFF5F3FF),
    ],
    lcdBgColor: Color(0xFFFFFFFF),
    lcdBorderColor: Color(0xFF8B5CF6),
    textColor: Color(0xFF6D28D9),
    textMutedColor: Color(0xFFC084FC),
    visualizerColor: Color(0xFF8B5CF6),
    visualizerPeakColor: Color(0xFFEC4899),
    buttonFaceColor: Color(0xFFEDE9FE),
    buttonIconColor: Color(0xFF6D28D9),
    statusLedColor: Color(0xFF8B5CF6),
    bgAssetPath: 'assets/images/bg_nature.png',
    isFlat: true,
  );

  // 25. Flat Sakura Light
  static const PlayerSkin flatSakuraLight = PlayerSkin(
    name: 'Flat Sakura Light',
    outerBorderColor: Color(0xFFFCE7F3),
    panelBgColor: Color(0xFFFFF1F2),
    metallicGradients: [
      Color(0xFFFFF1F2),
      Color(0xFFFFF1F2),
      Color(0xFFFFF1F2),
      Color(0xFFFFF1F2),
    ],
    lcdBgColor: Color(0xFFFFFFFF),
    lcdBorderColor: Color(0xFFF43F5E),
    textColor: Color(0xFFBE123C),
    textMutedColor: Color(0xFFF472B6),
    visualizerColor: Color(0xFFF43F5E),
    visualizerPeakColor: Color(0xFFFB7185),
    buttonFaceColor: Color(0xFFFFE4E6),
    buttonIconColor: Color(0xFFBE123C),
    statusLedColor: Color(0xFFF43F5E),
    bgAssetPath: 'assets/images/bg_nature.png',
    isFlat: true,
  );

  // 26. Retro Cyber (Splash Screen Aesthetic)
  static const PlayerSkin retroCyber = PlayerSkin(
    name: 'Retro Cyber',
    outerBorderColor: Color(0xFF141224),
    panelBgColor: Color(0xFF0A0A0F),
    metallicGradients: [
      Color(0xFF141224),
      Color(0xFF0A0A0F),
      Color(0xFF07070A),
      Color(0xFF141224),
    ],
    lcdBgColor: Color(0xFF050508),
    lcdBorderColor: Color(0xFF39FF14),
    textColor: Color(0xFF39FF14),
    textMutedColor: Color(0xFF1B5E20),
    visualizerColor: Color(0xFF39FF14),
    visualizerPeakColor: Color(0xFF00E5FF),
    buttonFaceColor: Color(0xFF1A1A24),
    buttonIconColor: Color(0xFF39FF14),
    statusLedColor: Color(0xFF00E5FF),
    bgAssetPath: 'assets/images/bg_scifi.png',
    isFlat: false, // Semi-skeuomorphic with metallic gradients to match splash screen feel
  );

  static const List<PlayerSkin> all = [
    classicBlue,
    s60Grey,
    obsidianVoid,
    matrixAmber,
    ferrariRed,
    auroraGreen,
    desertGold,
    glacierIce,
    flatDark,
    flatCyberpunk,
    flatMint,
    flatPeach,
    flatAmethyst,
    flatAmber,
    flatPolar,
    flatNeonSunset,
    flatSakuraPastel,
    flatGlassmorphic,
    flatLofiRain,
    flatMinimalTechno,
    flatVinylNoir,
    flatPastelLavender,
    flatSakuraLight,
    retroCyber,
  ];
}
