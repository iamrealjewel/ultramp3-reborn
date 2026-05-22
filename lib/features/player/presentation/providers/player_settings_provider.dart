import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ultramp3/core/services/storage_service.dart';

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
  final StorageService _storageService;

  PlayerSettingsNotifier(this._storageService) : super(PlayerSettings.defaultSettings) {
    _loadSettings();
  }

  void _loadSettings() {
    state = PlayerSettings(
      dialerTransparencyEnabled: _storageService.getDialerTransparencyEnabled(),
      dialerOpacity: _storageService.getDialerOpacity(),
      skinType: _storageService.getSkinType(),
      visualizerTransparencyEnabled: _storageService.getVisualizerTransparencyEnabled(),
      visualizerOpacity: _storageService.getVisualizerOpacity(),
      showAlbumArt: _storageService.getShowAlbumArt(),
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
}

final playerSettingsProvider = StateNotifierProvider<PlayerSettingsNotifier, PlayerSettings>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return PlayerSettingsNotifier(storageService);
});
