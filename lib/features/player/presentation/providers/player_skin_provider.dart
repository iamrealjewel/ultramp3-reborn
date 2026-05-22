import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/player_skin.dart';

class PlayerSkinNotifier extends StateNotifier<PlayerSkin> {
  PlayerSkinNotifier() : super(PlayerSkin.s60Grey); // Default to classic S60 Grey

  // Cycle through available skins based on selected skinType in round-robin fashion
  void cycleSkin(String skinType) {
    final isTargetFlat = skinType == 'flat';
    final filteredSkins = PlayerSkin.all.where((s) => s.isFlat == isTargetFlat).toList();
    if (filteredSkins.isEmpty) return;

    final currentIndex = filteredSkins.indexOf(state);
    if (currentIndex == -1) {
      state = filteredSkins.first;
    } else {
      final nextIndex = (currentIndex + 1) % filteredSkins.length;
      state = filteredSkins[nextIndex];
    }
  }

  // Ensure active skin matches the current category
  void enforceSkinType(String skinType) {
    final isTargetFlat = skinType == 'flat';
    if (state.isFlat != isTargetFlat) {
      final filteredSkins = PlayerSkin.all.where((s) => s.isFlat == isTargetFlat).toList();
      if (filteredSkins.isNotEmpty) {
        state = filteredSkins.first;
      }
    }
  }

  // Explicitly select a skin by name
  void setSkinByName(String name) {
    state = PlayerSkin.all.firstWhere(
      (skin) => skin.name.toLowerCase() == name.toLowerCase(),
      orElse: () => PlayerSkin.s60Grey,
    );
  }

  // Set skin directly
  void setSkin(PlayerSkin skin) {
    state = skin;
  }
}

// Global provider for referencing and listening to active skeuomorphic skin changes
final playerSkinProvider = StateNotifierProvider<PlayerSkinNotifier, PlayerSkin>((ref) {
  return PlayerSkinNotifier();
});
