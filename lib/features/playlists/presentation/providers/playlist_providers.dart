import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/storage_service.dart';

// --- FAVORITES STATE ---
class FavoritesNotifier extends StateNotifier<List<String>> {
  final StorageService _storage;
  FavoritesNotifier(this._storage) : super([]) {
    load();
  }

  void load() {
    state = _storage.getFavorites();
  }

  Future<void> toggle(String songId) async {
    await _storage.toggleFavorite(songId);
    load();
  }

  bool isFav(String songId) {
    return _storage.isFavorite(songId);
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<String>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return FavoritesNotifier(storage);
});

// --- RECENTLY PLAYED STATE ---
class RecentlyPlayedNotifier extends StateNotifier<List<String>> {
  final StorageService _storage;
  RecentlyPlayedNotifier(this._storage) : super([]) {
    load();
  }

  void load() {
    state = _storage.getRecentlyPlayed();
  }

  Future<void> add(String songId) async {
    await _storage.addRecentlyPlayed(songId);
    load();
  }
}

final recentlyPlayedProvider =
    StateNotifierProvider<RecentlyPlayedNotifier, List<String>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return RecentlyPlayedNotifier(storage);
});

// --- PLAYLISTS STATE ---
class PlaylistsNotifier extends StateNotifier<Map<String, List<String>>> {
  final StorageService _storage;
  PlaylistsNotifier(this._storage) : super({}) {
    load();
  }

  void load() {
    state = _storage.getPlaylists();
  }

  Future<void> createPlaylist(String name) async {
    await _storage.createPlaylist(name);
    load();
  }

  Future<void> deletePlaylist(String name) async {
    await _storage.deletePlaylist(name);
    load();
  }

  Future<void> addSongToPlaylist(String name, String songId) async {
    await _storage.addSongToPlaylist(name, songId);
    load();
  }

  Future<void> removeSongFromPlaylist(String name, String songId) async {
    await _storage.removeSongFromPlaylist(name, songId);
    load();
  }
}

final playlistsProvider =
    StateNotifierProvider<PlaylistsNotifier, Map<String, List<String>>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return PlaylistsNotifier(storage);
});
