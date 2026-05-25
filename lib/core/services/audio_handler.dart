import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'dart:async';
import 'dart:math' as math;

class UltraAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  late final AndroidEqualizer? _equalizer;
  late final AudioPlayer _player;

  static const MethodChannel _effectsChannel =
      MethodChannel('ultramp3/audio_effects');
  static const EventChannel _visualizerChannel =
      EventChannel('ultramp3/visualizer');
  int? _lastAndroidSessionId;

  StreamSubscription? _visualizerSub;
  final _visualizerBandsController = StreamController<List<double>>.broadcast();
  List<double>? _latestVisualizerBands;
  bool _equalizerEnabled = false;
  Timer? _eqRampTimer;
  double _userVolume = 1.0;
  final _volumeController = StreamController<double>.broadcast();
  Stream<double> get volumeStream => _volumeController.stream;
  double get userVolume => _userVolume;

  // Beat-ish envelope derived from low-frequency energy.
  double _lowEnergyEma = 0.0;
  double _beatPulse = 0.0;
  DateTime _lastBeatAt = DateTime.fromMillisecondsSinceEpoch(0);

  double get latestBeatPulse => _beatPulse;

  /// Real audio-driven visualizer bands (10 values, roughly 0..1).
  Stream<List<double>> get visualizerBandsStream =>
      _visualizerBandsController.stream;

  List<double>? get latestVisualizerBands => _latestVisualizerBands;

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

    // Initialize AudioSession for system volume control
    _initAudioSession();

    // Audio effects are disabled by default in just_audio.
    // Enable the Android equalizer when present.
    if (eq != null) {
      // Best-effort; will apply once the player becomes active.
      eq.setEnabled(true);
      _equalizerEnabled = true;
    }

    // Keep a handle on the Android audio session so we can attach native effects
    // (e.g. Virtualizer for real stereo widening).
    _player.androidAudioSessionIdStream.listen((sessionId) {
      _lastAndroidSessionId = sessionId;

      // Start/stop Android Visualizer based on session availability.
      if (sessionId != null) {
        _startAndroidVisualizer(sessionId);
      } else {
        _stopAndroidVisualizer();
      }
    });

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
      // Ensure the effect is enabled, otherwise gains will be bypassed.
      if (!_equalizerEnabled) {
        await eq.setEnabled(true);
        _equalizerEnabled = true;
      }
      final parameters = await eq.parameters;
      final bands = parameters.bands;
      final minDb = parameters.minDecibels;
      final maxDb = parameters.maxDecibels;

      final targetGains = gains.map((g) => g.clamp(minDb, maxDb)).toList();

      // Apply gains instantly without slow ramping to prevent audio artifacts
      // Cancel any ongoing transition
      _eqRampTimer?.cancel();
      _eqRampTimer = null;

      // Apply all band gains immediately
      final futures = <Future<void>>[];
      for (int i = 0; i < bands.length && i < targetGains.length; i++) {
        futures.add(bands[i].setGain(targetGains[i]));
      }
      await Future.wait(futures);
      print('Equalizer applied gains: $targetGains');
    } catch (e) {
      print('Failed to apply equalizer gains: $e');
    }
  }

  /// Best-effort access to platform EQ parameters.
  /// Returns null when the platform doesn't support AndroidEqualizer.
  Future<AndroidEqualizerParameters?> get equalizerParameters async {
    final eq = _equalizer;
    if (eq == null) return null;
    try {
      return await eq.parameters;
    } catch (_) {
      return null;
    }
  }

  // Bridging: Load a song with full metadata details into the background notifications
  Future<void> loadQueueItem(MediaItem item,
      {List<MediaItem>? fullQueue}) async {
    mediaItem.add(item);

    if (fullQueue != null) {
      queue.add(fullQueue);
      final index = fullQueue.indexWhere((element) => element.id == item.id);

      final playlist = ConcatenatingAudioSource(
        children: fullQueue.map((m) {
          if (m.id.startsWith('http'))
            return AudioSource.uri(Uri.parse(m.id), tag: m);
          return AudioSource.file(m.id, tag: m);
        }).toList(),
      );

      await _player.setAudioSource(playlist,
          initialIndex: index >= 0 ? index : 0);
    } else {
      try {
        if (item.id.startsWith('http') || item.id.startsWith('asset')) {
          await _player
              .setAudioSource(AudioSource.uri(Uri.parse(item.id), tag: item));
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
    _stopAndroidVisualizer();
    await playbackState.firstWhere(
        (state) => state.processingState == AudioProcessingState.idle);
  }

  @override
  Future<void> skipToNext() async {
    final nextIdx = _player.nextIndex;
    if (nextIdx != null) {
      await _player.seek(Duration.zero, index: nextIdx);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final prevIdx = _player.previousIndex;
    if (prevIdx != null) {
      await _player.seek(Duration.zero, index: prevIdx);
    }
  }

  // Access stream to read raw player durations and states
  Stream<Duration?> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  AudioPlayer get playerInstance => _player;
  bool get isEqualizerSupported => _equalizer != null;

  Future<void> setStereoStrength(double value01) async {
    // Android-only native effect; no-op elsewhere.
    final sessionId = _lastAndroidSessionId;
    if (sessionId == null) return;

    // Map 0.0..1.0 => 0..1000.
    final strength = (value01.clamp(0.0, 1.0) * 1000).round();
    try {
      await _effectsChannel.invokeMethod('setVirtualizer', {
        'sessionId': sessionId,
        'strength': strength,
        'enabled': strength > 0,
      });
    } catch (_) {
      // Best-effort; platform may not support this effect.
    }
  }

  Future<void> _initAudioSession() async {
    try {
      // Initialize flutter_volume_controller
      final subscription = FlutterVolumeController.addListener((volume) {
        _userVolume = volume;
        _volumeController.add(volume);
      });

      // Get initial volume
      final initialVolume = await FlutterVolumeController.getVolume();
      _userVolume = initialVolume ?? 0.5;
      _volumeController.add(_userVolume);

      print('FlutterVolumeController initialized. System volume: $_userVolume');
    } catch (e) {
      print('FlutterVolumeController not available: $e');
      // Fallback: keep using just_audio volume
    }
  }

  /// Set system volume (0.0 to 1.0)
  Future<void> setSystemVolume(double volume) async {
    try {
      await FlutterVolumeController.setVolume(volume.clamp(0.0, 1.0));
      _userVolume = volume.clamp(0.0, 1.0);
      _volumeController.add(_userVolume);
      print('System volume set to: $_userVolume');
    } catch (e) {
      print('Failed to set system volume: $e');
      // Fallback to app volume
      await setVolume(volume);
    }
  }

  /// Get current system volume
  double getSystemVolume() {
    try {
      return _userVolume;
    } catch (_) {
      return _userVolume;
    }
  }

  Future<void> setVolume(double volume) async {
    // Redirect to system volume control
    await setSystemVolume(volume);
  }

  void _startAndroidVisualizer(int sessionId) {
    // Ensure a single subscription.
    _visualizerSub ??= _visualizerChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Uint8List) {
          final bands = _fftToBands(event);
          _latestVisualizerBands = bands;
          _visualizerBandsController.add(bands);
        }
      },
      onError: (_) {
        // Best-effort.
      },
    );

    // Best-effort start.
    _effectsChannel.invokeMethod('startVisualizer', {'sessionId': sessionId});
  }

  void _stopAndroidVisualizer() {
    _effectsChannel.invokeMethod('stopVisualizer');
  }

  List<double> _fftToBands(Uint8List fftBytes) {
    // Android Visualizer FFT format: interleaved real/imag bytes.
    final n = fftBytes.length;
    if (n < 4) return List.filled(10, 0.0);

    final bins = (n ~/ 2).clamp(2, 512);
    final magnitudes = List<double>.filled(bins, 0.0);
    magnitudes[0] = 0.0;

    for (int k = 1; k < bins; k++) {
      final r = _signedByte(fftBytes[2 * k]);
      final i = _signedByte(fftBytes[2 * k + 1]);
      final mag = math.sqrt((r * r + i * i).toDouble());
      magnitudes[k] = mag;
    }

    final bands = List<double>.filled(10, 0.0);
    final maxK = bins - 1;
    for (int b = 0; b < 10; b++) {
      final start =
          (math.pow(maxK.toDouble(), b / 10.0)).round().clamp(1, maxK);
      final end = (math.pow(maxK.toDouble(), (b + 1) / 10.0))
          .round()
          .clamp(start, maxK);
      double sum = 0.0;
      int count = 0;
      for (int k = start; k <= end; k++) {
        sum += magnitudes[k];
        count++;
      }
      final avg = count > 0 ? sum / count : 0.0;
      final norm = (avg / 180.0).clamp(0.0, 1.0);
      bands[b] = norm;
    }

    _updateBeatPulse(bands);
    return bands;
  }

  void _updateBeatPulse(List<double> bands01) {
    if (bands01.length < 3) return;
    // Low-frequency energy proxy.
    final low = (bands01[0] + bands01[1] + bands01[2]) / 3.0;
    // Smooth baseline.
    _lowEnergyEma = _lowEnergyEma * 0.92 + low * 0.08;

    // Detect a transient above baseline.
    final now = DateTime.now();
    final msSince = now.difference(_lastBeatAt).inMilliseconds;
    final transient = low - _lowEnergyEma;

    // Refractory window avoids machine-gun triggers.
    final canTrigger = msSince > 220;
    if (canTrigger && transient > 0.10) {
      _beatPulse = 1.0;
      _lastBeatAt = now;
    } else {
      // Decay pulse.
      _beatPulse *= 0.88;
      if (_beatPulse < 0.001) _beatPulse = 0.0;
    }
  }

  int _signedByte(int v) => v > 127 ? v - 256 : v;

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
