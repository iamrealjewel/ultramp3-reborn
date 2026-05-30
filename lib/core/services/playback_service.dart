import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:path/path.dart' as p;

import 'audio_handler.dart';
import 'storage_service.dart';

// Expose the global audio handler. This will be overridden in main.dart on startup.
final audioHandlerProvider = Provider<UltraAudioHandler>((ref) {
  throw UnimplementedError(
      'audioHandlerProvider must be overridden in ProviderScope');
});

final playbackServiceProvider = Provider<PlaybackService>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  final storage = ref.watch(storageServiceProvider);
  return PlaybackService(handler, storage);
});

class PlaybackService {
  final UltraAudioHandler _handler;
  final StorageService _storage;

  PlaybackService(this._handler, this._storage);

  UltraAudioHandler get handler => _handler;

  // Stream of active MediaItems from the background service
  Stream<MediaItem?> get currentMediaItemStream => _handler.mediaItem;

  // Stream combining playback status, positions and loading states
  Stream<PlaybackState> get playbackStateStream => _handler.playbackState;

  // Stream combining current progress and duration cleanly
  Stream<PositionState> get positionStateStream =>
      Rx.combineLatest2<Duration, MediaItem?, PositionState>(
        _handler.positionStream,
        _handler.mediaItem,
        (position, mediaItem) {
          final duration = mediaItem?.duration ?? Duration.zero;
          return PositionState(
            position: position,
            duration: duration,
          );
        },
      );

  // Play a local file with complete OS-level metadata tagging
  Future<void> playTrack({
    required String filePath,
    required String title,
    required String artist,
    required String album,
    Duration duration = Duration.zero,
    List<String>? queue,
  }) async {
    final mediaItem = MediaItem(
      id: filePath,
      album: album,
      title: title,
      artist: artist,
      duration: duration,
    );

    List<MediaItem>? fullQueueItems;
    if (queue != null && queue.isNotEmpty) {
      // In a real app, you'd fetch all metadata for these IDs.
      // For now, let's just create placeholder MediaItems if not the active one.
      fullQueueItems = queue.map((id) {
        if (id == filePath) return mediaItem;
        return MediaItem(
            id: id,
            title: p.basenameWithoutExtension(id),
            artist: 'Unknown Artist');
      }).toList();
    }

    // Load queue item and play immediately
    await _handler.loadQueueItem(mediaItem, fullQueue: fullQueueItems);
    await _handler.play();

    // Persist recently played track ID
    await _storage.addRecentlyPlayed(filePath);

    final finalQueue = queue ?? [filePath];
    await _storage.saveQueueState(
      songIds: finalQueue,
      activeSongId: filePath,
      playbackPositionMs: 0,
    );
  }

  Future<void> play() => _handler.play();

  Future<void> pause() => _handler.pause();

  Future<void> seek(Duration position) => _handler.seek(position);

  Future<void> stop() => _handler.stop();

  Future<void> setEqualizerBands(List<double> gains) =>
      _handler.setEqualizerBands(gains);

  Future<void> setStereoStrength(double value01) =>
      _handler.setStereoStrength(value01);

  Stream<double> get volumeStream => _handler.volumeStream;
  double get volume => _handler.userVolume;

  Future<void> setSystemVolume(double volume) async {
    await _handler.setSystemVolume(volume);
    await _storage.setVolumeLevel(volume);
  }

  Future<void> setVolume(double volume) async {
    // Redirect to system volume
    await setSystemVolume(volume);
  }

  Future<void> skipToNext() => _handler.skipToNext();

  Future<void> skipToPrevious() => _handler.skipToPrevious();
}

class PositionState {
  final Duration position;
  final Duration duration;

  PositionState({required this.position, required this.duration});
}
