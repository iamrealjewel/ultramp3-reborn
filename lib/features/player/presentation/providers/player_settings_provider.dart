import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ultramp3/core/services/storage_service.dart';

class PlayerSettings {
  final bool dialerTransparencyEnabled;
  final double dialerOpacity;
  final String skinType; // 'classic' or 'flat'
  final bool visualizerTransparencyEnabled;
  final double visualizerOpacity;
  final bool showAlbumArt; // true = Album Art, false = Visualizer
  final bool glowEnabled;
  final bool glassEnabled;
  final String audioEngine; // 'soloud' or 'just_audio'

  const PlayerSettings({
    required this.dialerTransparencyEnabled,
    required this.dialerOpacity,
    required this.skinType,
    required this.visualizerTransparencyEnabled,
    required this.visualizerOpacity,
    required this.showAlbumArt,
    required this.glowEnabled,
    required this.glassEnabled,
    required this.audioEngine,
  });

  PlayerSettings copyWith({
    bool? dialerTransparencyEnabled,
    double? dialerOpacity,
    String? skinType,
    bool? visualizerTransparencyEnabled,
    double? visualizerOpacity,
    bool? showAlbumArt,
    bool? glowEnabled,
    bool? glassEnabled,
    String? audioEngine,
  }) {
    return PlayerSettings(
      dialerTransparencyEnabled:
          dialerTransparencyEnabled ?? this.dialerTransparencyEnabled,
      dialerOpacity: dialerOpacity ?? this.dialerOpacity,
      skinType: skinType ?? this.skinType,
      visualizerTransparencyEnabled:
          visualizerTransparencyEnabled ?? this.visualizerTransparencyEnabled,
      visualizerOpacity: visualizerOpacity ?? this.visualizerOpacity,
      showAlbumArt: showAlbumArt ?? this.showAlbumArt,
      glowEnabled: glowEnabled ?? this.glowEnabled,
      glassEnabled: glassEnabled ?? this.glassEnabled,
      audioEngine: audioEngine ?? this.audioEngine,
    );
  }

  static const defaultSettings = PlayerSettings(
    dialerTransparencyEnabled: true,
    dialerOpacity: 0.5,
    skinType: 'classic',
    visualizerTransparencyEnabled: true,
    visualizerOpacity: 0.5,
    showAlbumArt: false,
    glowEnabled: true,
    glassEnabled: true,
    audioEngine: 'soloud',
  );
}

class PlayerSettingsNotifier extends StateNotifier<PlayerSettings> {
  final StorageService _storageService;

  PlayerSettingsNotifier(this._storageService)
      : super(PlayerSettings.defaultSettings) {
    _loadSettings();
  }

  void _loadSettings() {
    state = PlayerSettings(
      dialerTransparencyEnabled: _storageService.getDialerTransparencyEnabled(),
      dialerOpacity: _storageService.getDialerOpacity(),
      skinType: _storageService.getSkinType(),
      visualizerTransparencyEnabled:
          _storageService.getVisualizerTransparencyEnabled(),
      visualizerOpacity: _storageService.getVisualizerOpacity(),
      showAlbumArt: _storageService.getShowAlbumArt(),
      glowEnabled: _storageService.getGlowEnabled(),
      glassEnabled: _storageService.getGlassEnabled(),
      audioEngine: _storageService.getAudioEngine(),
    );
  }

  void toggleDialerTransparency(bool enabled) {
    state = state.copyWith(dialerTransparencyEnabled: enabled);
    _storageService.setDialerTransparencyEnabled(enabled);
  }

  void setDialerOpacity(double opacity) {
    state = state.copyWith(dialerOpacity: opacity);
    _storageService.setDialerOpacity(opacity);
  }

  void setSkinType(String type) {
    state = state.copyWith(skinType: type);
    _storageService.setSkinType(type);
  }

  void toggleVisualizerTransparency(bool enabled) {
    state = state.copyWith(visualizerTransparencyEnabled: enabled);
    _storageService.setVisualizerTransparencyEnabled(enabled);
  }

  void setVisualizerOpacity(double opacity) {
    state = state.copyWith(visualizerOpacity: opacity);
    _storageService.setVisualizerOpacity(opacity);
  }

  void toggleShowAlbumArt(bool show) {
    state = state.copyWith(showAlbumArt: show);
    _storageService.setShowAlbumArt(show);
  }

  void toggleGlowEnabled(bool enabled) {
    state = state.copyWith(glowEnabled: enabled);
    _storageService.setGlowEnabled(enabled);
  }

  void toggleGlassEnabled(bool enabled) {
    state = state.copyWith(glassEnabled: enabled);
    _storageService.setGlassEnabled(enabled);
  }

  void setAudioEngine(String engine) {
    state = state.copyWith(audioEngine: engine);
    _storageService.setAudioEngine(engine);
  }
}

final playerSettingsProvider =
    StateNotifierProvider<PlayerSettingsNotifier, PlayerSettings>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return PlayerSettingsNotifier(storageService);
});
