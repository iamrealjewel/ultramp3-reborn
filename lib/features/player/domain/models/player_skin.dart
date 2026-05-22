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
  final bool isFlat; // True for modern flat skins, false for metallic/skeuomorphic

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
    outerBorderColor: Color(0xFF3E3E42),
    panelBgColor: Color(0xFFCCCCCC),
    metallicGradients: [
      Color(0xFFF0F0F2),
      Color(0xFFD4D4D9),
      Color(0xFFABABAF),
      Color(0xFFF0F0F2),
    ],
    lcdBgColor: Color(0xFF8FA38F), // Reflective Nokia Retro LCD olive
    lcdBorderColor: Color(0xFF4A5C4A),
    textColor: Color(0xFF142014), // Deep charcoal Nokia LCD active pixels
    textMutedColor: Color(0xFF405040),
    visualizerColor: Color(0xFF203020),
    visualizerPeakColor: Color(0xFF3A4A3A),
    buttonFaceColor: Color(0xFFD6D6DB), // Brushed metallic chrome button base
    buttonIconColor: Color(0xFF252528),
    statusLedColor: Color(0xFFFF5500),
    bgAssetPath: 'assets/images/bg_nature.png',
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

  static const List<PlayerSkin> all = [
    classicBlue,
    s60Grey,
    obsidianVoid,
    matrixAmber,
    ferrariRed,
    auroraGreen,
    desertGold,
    glacierIce,
    flatCyberpunk,
    flatMint,
    flatPeach,
    flatDark,
    flatAmethyst,
    flatAmber,
    flatPolar,
  ];
}
