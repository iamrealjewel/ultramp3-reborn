import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class UltraAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  late final AndroidEqualizer? _equalizer;
  late final AudioPlayer _player;

  UltraAudioHandler() {
    AndroidEqualizer? eq;
    try {
      eq = AndroidEqualizer();
    } catch (e) {
      print('AndroidEqualizer not supported on this platform: $e');
    }
    _equalizer = eq;

    _player = AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: [
          if (eq != null) eq,
        ],
      ),
    );

    // Forward just_audio events to audio_service's notification state
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Keep mediaItem in sync with player's active source changes (such as skips)
    _player.sequenceStateStream.listen((sequenceState) {
      if (sequenceState == null) return;
      final currentSource = sequenceState.currentSource;
      if (currentSource != null && currentSource.tag is MediaItem) {
        mediaItem.add(currentSource.tag as MediaItem);
      }
    });

    // Fallback: Keep mediaItem in sync with player's currentIndex changes (such as skips)
    _player.currentIndexStream.listen((index) {
      if (index != null && queue.hasValue) {
        final currentQueue = queue.value;
        if (index >= 0 && index < currentQueue.length) {
          mediaItem.add(currentQueue[index]);
        }
      }
    });
  }

  Future<void> setEqualizerBands(List<double> gains) async {
    final eq = _equalizer;
    if (eq == null) return;
    try {
      final parameters = await eq.parameters;
      final bands = parameters.bands;
      for (int i = 0; i < bands.length && i < gains.length; i++) {
        final db = gains[i].clamp(-12.0, 12.0);
        await bands[i].setGain(db);
      }
      print('Native Equalizer applied gains: $gains');
    } catch (e) {
      print('Failed to apply native equalizer gains: $e');
    }
  }

  // Bridging: Load a song with full metadata details into the background notifications
  Future<void> loadQueueItem(MediaItem item, {List<MediaItem>? fullQueue}) async {
    mediaItem.add(item);

    if (fullQueue != null) {
      queue.add(fullQueue);
      final index = fullQueue.indexWhere((element) => element.id == item.id);
      
      final playlist = ConcatenatingAudioSource(
        children: fullQueue.map((m) {
          if (m.id.startsWith('http')) return AudioSource.uri(Uri.parse(m.id), tag: m);
          return AudioSource.file(m.id, tag: m);
        }).toList(),
      );
      
      await _player.setAudioSource(playlist, initialIndex: index >= 0 ? index : 0);
    } else {
      try {
        if (item.id.startsWith('http') || item.id.startsWith('asset')) {
          await _player.setAudioSource(AudioSource.uri(Uri.parse(item.id), tag: item));
        } else {
          await _player.setAudioSource(AudioSource.file(item.id, tag: item));
        }
      } catch (e) {
        print('Audio Engine loading error: $e');
      }
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await playbackState.firstWhere(
        (state) => state.processingState == AudioProcessingState.idle);
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  // Access stream to read raw player durations and states
  Stream<Duration?> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  AudioPlayer get playerInstance => _player;
  bool get isEqualizerSupported => _equalizer != null;

  // Transforming just_audio states to the OS level states
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}
