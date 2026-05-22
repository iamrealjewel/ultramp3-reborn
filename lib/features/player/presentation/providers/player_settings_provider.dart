import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerSettings {
  final bool dialerTransparencyEnabled;
  final double dialerOpacity;
  final String skinType; // 'classic' or 'flat'
  final bool visualizerTransparencyEnabled;
  final double visualizerOpacity;
  final bool showAlbumArt; // true = Album Art, false = Visualizer

  const PlayerSettings({
    required this.dialerTransparencyEnabled,
    required this.dialerOpacity,
    required this.skinType,
    required this.visualizerTransparencyEnabled,
    required this.visualizerOpacity,
    required this.showAlbumArt,
  });

  PlayerSettings copyWith({
    bool? dialerTransparencyEnabled,
    double? dialerOpacity,
    String? skinType,
    bool? visualizerTransparencyEnabled,
    double? visualizerOpacity,
    bool? showAlbumArt,
  }) {
    return PlayerSettings(
      dialerTransparencyEnabled: dialerTransparencyEnabled ?? this.dialerTransparencyEnabled,
      dialerOpacity: dialerOpacity ?? this.dialerOpacity,
      skinType: skinType ?? this.skinType,
      visualizerTransparencyEnabled: visualizerTransparencyEnabled ?? this.visualizerTransparencyEnabled,
      visualizerOpacity: visualizerOpacity ?? this.visualizerOpacity,
      showAlbumArt: showAlbumArt ?? this.showAlbumArt,
    );
  }

  static const defaultSettings = PlayerSettings(
    dialerTransparencyEnabled: false,
    dialerOpacity: 1.0,
    skinType: 'classic',
    visualizerTransparencyEnabled: false,
    visualizerOpacity: 0.55,
    showAlbumArt: false,
  );
}

class PlayerSettingsNotifier extends StateNotifier<PlayerSettings> {
  PlayerSettingsNotifier() : super(PlayerSettings.defaultSettings);

  void toggleDialerTransparency(bool enabled) {
    state = state.copyWith(dialerTransparencyEnabled: enabled);
  }

  void setDialerOpacity(double opacity) {
    state = state.copyWith(dialerOpacity: opacity);
  }

  void setSkinType(String type) {
    state = state.copyWith(skinType: type);
  }

  void toggleVisualizerTransparency(bool enabled) {
    state = state.copyWith(visualizerTransparencyEnabled: enabled);
  }

  void setVisualizerOpacity(double opacity) {
    state = state.copyWith(visualizerOpacity: opacity);
  }

  void toggleShowAlbumArt(bool show) {
    state = state.copyWith(showAlbumArt: show);
  }
}

final playerSettingsProvider = StateNotifierProvider<PlayerSettingsNotifier, PlayerSettings>((ref) {
  return PlayerSettingsNotifier();
});
