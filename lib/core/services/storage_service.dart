import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  static const String _settingsBoxName = 'settings';
  static const String _favoritesBoxName = 'favorites';
  static const String _recentsBoxName = 'recently_played';
  static const String _playlistsBoxName = 'playlists';
  static const String _queueBoxName = 'active_queue';

  // Initialize Hive and open all required boxes in-memory for speed
  Future<void> init() async {
    await Hive.initFlutter();
    
    await Future.wait([
      Hive.openBox(_settingsBoxName),
      Hive.openBox<String>(_favoritesBoxName),
      Hive.openBox<String>(_recentsBoxName),
      Hive.openBox<List<String>>(_playlistsBoxName),
      Hive.openBox(_queueBoxName),
    ]);
  }

  // --- SETTINGS MODULE ---
  Box get _settingsBox => Hive.box(_settingsBoxName);
  
  bool getGlowEnabled() => _settingsBox.get('glow_enabled', defaultValue: true);
  Future<void> setGlowEnabled(bool value) => _settingsBox.put('glow_enabled', value);

  bool getGlassEnabled() => _settingsBox.get('glass_enabled', defaultValue: true);
  Future<void> setGlassEnabled(bool value) => _settingsBox.put('glass_enabled', value);

  // --- FAVORITES MODULE ---
  Box<String> get _favoritesBox => Hive.box<String>(_favoritesBoxName);

  List<String> getFavorites() => _favoritesBox.values.toList();
  
  Future<void> toggleFavorite(String songId) async {
    if (_favoritesBox.containsKey(songId)) {
      await _favoritesBox.delete(songId);
    } else {
      await _favoritesBox.put(songId, songId);
    }
  }

  bool isFavorite(String songId) => _favoritesBox.containsKey(songId);

  // --- RECENTLY PLAYED MODULE ---
  Box<String> get _recentsBox => Hive.box<String>(_recentsBoxName);

  List<String> getRecentlyPlayed() => _recentsBox.values.toList().reversed.toList();

  Future<void> addRecentlyPlayed(String songId) async {
    // Prevent duplicate entries in history
    if (_recentsBox.containsKey(songId)) {
      await _recentsBox.delete(songId);
    }
    
    // Cap recently played list at 50 tracks to keep index extremely compact
    if (_recentsBox.length >= 50) {
      final oldestKey = _recentsBox.keys.first;
      await _recentsBox.delete(oldestKey);
    }
    
    await _recentsBox.put(songId, songId);
  }

  // --- PLAYLISTS MODULE ---
  Box<List<String>> get _playlistsBox => Hive.box<List<String>>(_playlistsBoxName);

  Map<String, List<String>> getPlaylists() {
    final Map<String, List<String>> result = {};
    for (var key in _playlistsBox.keys) {
      final list = _playlistsBox.get(key);
      if (list != null) {
        result[key.toString()] = list;
      }
    }
    return result;
  }

  Future<void> createPlaylist(String playlistName) async {
    if (!_playlistsBox.containsKey(playlistName)) {
      await _playlistsBox.put(playlistName, []);
    }
  }

  Future<void> deletePlaylist(String playlistName) => _playlistsBox.delete(playlistName);

  Future<void> addSongToPlaylist(String playlistName, String songId) async {
    final list = _playlistsBox.get(playlistName) ?? [];
    if (!list.contains(songId)) {
      list.add(songId);
      await _playlistsBox.put(playlistName, list);
    }
  }

  Future<void> removeSongFromPlaylist(String playlistName, String songId) async {
    final list = _playlistsBox.get(playlistName);
    if (list != null && list.contains(songId)) {
      list.remove(songId);
      await _playlistsBox.put(playlistName, list);
    }
  }

  // --- QUEUE MODULE ---
  Box get _queueBox => Hive.box(_queueBoxName);

  Future<void> saveQueueState({
    required List<String> songIds,
    required String? activeSongId,
    required int playbackPositionMs,
  }) async {
    await _queueBox.putAll({
      'queue_list': songIds,
      'active_song_id': activeSongId,
      'position_ms': playbackPositionMs,
    });
  }

  List<String> getSavedQueueList() => 
      List<String>.from(_queueBox.get('queue_list', defaultValue: <String>[]));

  String? getSavedActiveSongId() => _queueBox.get('active_song_id');

  int getSavedPositionMs() => _queueBox.get('position_ms', defaultValue: 0);
}
