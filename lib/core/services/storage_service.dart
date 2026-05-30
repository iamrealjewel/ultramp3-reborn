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
  Future<void> setGlowEnabled(bool value) =>
      _settingsBox.put('glow_enabled', value);

  bool getGlassEnabled() =>
      _settingsBox.get('glass_enabled', defaultValue: true);
  Future<void> setGlassEnabled(bool value) =>
      _settingsBox.put('glass_enabled', value);

  bool getDialerTransparencyEnabled() =>
      _settingsBox.get('dialer_transparency_enabled', defaultValue: false);
  Future<void> setDialerTransparencyEnabled(bool value) =>
      _settingsBox.put('dialer_transparency_enabled', value);

  double getDialerOpacity() =>
      _settingsBox.get('dialer_opacity', defaultValue: 1.0);
  Future<void> setDialerOpacity(double value) =>
      _settingsBox.put('dialer_opacity', value);

  String getSkinType() =>
      _settingsBox.get('skin_type', defaultValue: 'classic');
  Future<void> setSkinType(String value) =>
      _settingsBox.put('skin_type', value);

  bool getVisualizerTransparencyEnabled() =>
      _settingsBox.get('visualizer_transparency_enabled', defaultValue: false);
  Future<void> setVisualizerTransparencyEnabled(bool value) =>
      _settingsBox.put('visualizer_transparency_enabled', value);

  double getVisualizerOpacity() =>
      _settingsBox.get('visualizer_opacity', defaultValue: 0.55);
  Future<void> setVisualizerOpacity(double value) =>
      _settingsBox.put('visualizer_opacity', value);

  bool getShowAlbumArt() =>
      _settingsBox.get('show_album_art', defaultValue: false);
  Future<void> setShowAlbumArt(bool value) =>
      _settingsBox.put('show_album_art', value);

  // --- PLAYBACK SESSION MODULE ---
  bool getShuffleEnabled() =>
      _settingsBox.get('shuffle_enabled', defaultValue: false);
  Future<void> setShuffleEnabled(bool value) =>
      _settingsBox.put('shuffle_enabled', value);

  String getLoopMode() => _settingsBox.get('loop_mode', defaultValue: 'off');
  Future<void> setLoopMode(String value) =>
      _settingsBox.put('loop_mode', value);

  String getEqualizerPreset() =>
      _settingsBox.get('equalizer_preset', defaultValue: 'Flat');
  Future<void> setEqualizerPreset(String value) =>
      _settingsBox.put('equalizer_preset', value);

  List<double> getEqualizerBands() {
    final bands = _settingsBox.get('equalizer_bands');
    if (bands is List) {
      return List<double>.from(bands.map((e) => (e as num).toDouble()));
    }
    return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  }

  Future<void> setEqualizerBands(List<double> values) =>
      _settingsBox.put('equalizer_bands', values);

  double getVolumeLevel() =>
      _settingsBox.get('volume_level', defaultValue: 1.0);
  Future<void> setVolumeLevel(double value) =>
      _settingsBox.put('volume_level', value);

  String getVisualizerStyle() =>
      _settingsBox.get('visualizer_style', defaultValue: 'spectrumBars');
  Future<void> setVisualizerStyle(String value) =>
      _settingsBox.put('visualizer_style', value);

  int getVisualizerVariation() =>
      _settingsBox.get('visualizer_variation', defaultValue: 0);
  Future<void> setVisualizerVariation(int value) =>
      _settingsBox.put('visualizer_variation', value);

  String getActiveSkin() =>
      _settingsBox.get('active_skin', defaultValue: 'Symbian Classic Blue');
  Future<void> setActiveSkin(String value) =>
      _settingsBox.put('active_skin', value);

  String getDialStyle() =>
      _settingsBox.get('dial_style', defaultValue: 'circular');
  Future<void> setDialStyle(String value) =>
      _settingsBox.put('dial_style', value);

  String getAudioEngine() =>
      _settingsBox.get('audio_engine', defaultValue: 'soloud');
  Future<void> setAudioEngine(String value) =>
      _settingsBox.put('audio_engine', value);


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

  List<String> getRecentlyPlayed() =>
      _recentsBox.values.toList().reversed.toList();

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
  Box<List<String>> get _playlistsBox =>
      Hive.box<List<String>>(_playlistsBoxName);

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

  Future<void> deletePlaylist(String playlistName) =>
      _playlistsBox.delete(playlistName);

  Future<void> addSongToPlaylist(String playlistName, String songId) async {
    final list = _playlistsBox.get(playlistName) ?? [];
    if (!list.contains(songId)) {
      list.add(songId);
      await _playlistsBox.put(playlistName, list);
    }
  }

  Future<void> removeSongFromPlaylist(
      String playlistName, String songId) async {
    final list = _playlistsBox.get(playlistName);
    if (list != null && list.contains(songId)) {
      list.remove(songId);
      await _playlistsBox.put(playlistName, list);
    }
  }

  // --- QUEUE MODULE ---
  Box get _queueBox => Hive.box(_queueBoxName);

  Future<void> savePlaybackPosition(int positionMs) =>
      _queueBox.put('position_ms', positionMs);

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
