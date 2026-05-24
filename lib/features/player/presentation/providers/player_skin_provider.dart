import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ultramp3/core/services/storage_service.dart';
import '../../domain/models/player_skin.dart';

class PlayerSkinNotifier extends StateNotifier<PlayerSkin> {
  final StorageService _storageService;

  PlayerSkinNotifier(this._storageService) : super(PlayerSkin.classicBlue) {
    _loadSkin();
  }

  void _loadSkin() {
    final skinName = _storageService.getActiveSkin();
    state = PlayerSkin.all.firstWhere(
      (s) => s.name.toLowerCase() == skinName.toLowerCase(),
      orElse: () => PlayerSkin.classicBlue,
    );
  }

  void _saveSkin(PlayerSkin skin) {
    _storageService.setActiveSkin(skin.name);
  }

  // Cycle through available skins based on selected skinType in round-robin fashion
  void cycleSkin(String skinType) {
    final isTargetFlat = skinType == 'flat';
    final filteredSkins =
        PlayerSkin.all.where((s) => s.isFlat == isTargetFlat).toList();
    if (filteredSkins.isEmpty) return;

    final currentIndex = filteredSkins.indexOf(state);
    final PlayerSkin nextSkin;
    if (currentIndex == -1) {
      nextSkin = filteredSkins.first;
    } else {
      final nextIndex = (currentIndex + 1) % filteredSkins.length;
      nextSkin = filteredSkins[nextIndex];
    }
    state = nextSkin;
    _saveSkin(nextSkin);
  }

  // Ensure active skin matches the current category
  void enforceSkinType(String skinType) {
    final isTargetFlat = skinType == 'flat';
    if (state.isFlat != isTargetFlat) {
      final filteredSkins =
          PlayerSkin.all.where((s) => s.isFlat == isTargetFlat).toList();
      if (filteredSkins.isNotEmpty) {
        state = filteredSkins.first;
        _saveSkin(filteredSkins.first);
      }
    }
  }

  // Explicitly select a skin by name
  void setSkinByName(String name) {
    final newSkin = PlayerSkin.all.firstWhere(
      (skin) => skin.name.toLowerCase() == name.toLowerCase(),
      orElse: () => PlayerSkin.classicBlue,
    );
    state = newSkin;
    _saveSkin(newSkin);
  }

  // Set skin directly
  void setSkin(PlayerSkin skin) {
    state = skin;
    _saveSkin(skin);
  }
}

// Global provider for referencing and listening to active skeuomorphic skin changes
final playerSkinProvider =
    StateNotifierProvider<PlayerSkinNotifier, PlayerSkin>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return PlayerSkinNotifier(storageService);
});
