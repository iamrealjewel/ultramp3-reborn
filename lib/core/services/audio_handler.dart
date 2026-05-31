
import 'package:audio_service/audio_service.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:ultramp3/core/services/storage_service.dart';
import 'package:ultramp3/core/services/native_eq_service.dart';

class UltraAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  
  AudioSource? _currentSound;
  SoundHandle? _activeHandle;
  int _queueIndex = 0;
  
  Timer? _positionTimer;
  StreamSubscription? _volumeSub;
  AudioData? _audioData;

  String _activeEngine = 'just_audio';
  String get activeEngine => _activeEngine;
  ja.AudioPlayer? _jaPlayer;
  StreamSubscription? _jaSessionSub;
  StreamSubscription? _jaPositionSub;
  StreamSubscription? _jaDurationSub;
  StreamSubscription? _jaPlayerStateSub;
  DateTime _lastSeekTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Last EQ gains (in dB) sent to setEqualizerBands().
  /// Stored so we can re-apply immediately after a new JustAudio session ID arrives.
  List<double>? _pendingEqGains;
  double _pendingBassValue = 0.5;

  final _visualizerBandsController = BehaviorSubject<List<double>>.seeded(List.filled(10, 0.0));
  List<double>? _latestVisualizerBands;
  Stream<List<double>> get visualizerBandsStream => _visualizerBandsController.stream;
  List<double>? get latestVisualizerBands => _latestVisualizerBands;

  final _positionStreamController = BehaviorSubject<Duration>.seeded(Duration.zero);
  Stream<Duration> get positionStream => _positionStreamController.stream;

  /// Reads the current playback position directly from the native engine —
  /// bypasses the stream and the seek-mute gate so FF/RW always have a
  /// fresh reference point even immediately after a seek.
  Duration get livePosition {
    if (_activeEngine == 'soloud') {
      final handle = _activeHandle;
      if (handle != null) {
        try {
          return SoLoud.instance.getPosition(handle);
        } catch (_) {}
      }
    } else {
      return _jaPlayer?.position ?? _positionStreamController.value;
    }
    return _positionStreamController.value;
  }

  final _volumeController = BehaviorSubject<double>.seeded(1.0);
  Stream<double> get volumeStream => _volumeController.stream;
  double _userVolume = 1.0;
  double get userVolume => _userVolume;
  bool _isEqFlat = true;

  double _lowEnergyEma = 0.0;
  double _beatPulse = 0.0;
  DateTime _lastBeatAt = DateTime.fromMillisecondsSinceEpoch(0);
  double get latestBeatPulse => _beatPulse;

  // Compiler-safe Mock Audio Player Adapter for existing screens (Loop/Shuffle/Seek mappings)
  late final MockAudioPlayer _mockPlayer;
  MockAudioPlayer get playerInstance => _mockPlayer;

  // Graceful degradation for player screen
  Future<dynamic> get equalizerParameters async => null;

  UltraAudioHandler() {
    _mockPlayer = MockAudioPlayer(this);
    _initAudioSession();
    _updatePlaybackState(playing: false);
    
    try {
      final storage = StorageService();
      _activeEngine = storage.getAudioEngine();
    } catch (_) {
      _activeEngine = 'just_audio';
    }

    try {
      _audioData = AudioData(GetSamplesKind.linear);
      SoLoud.instance.setVisualizationEnabled(true);
    } catch (e) {
      debugPrint('SoLoud visualization init failed: $e');
    }
  }

  void _initJustAudioPlayer() {
    if (_jaPlayer != null) return;
    _jaPlayer = ja.AudioPlayer();

    // Track completion and player state updates
    _jaPlayerStateSub?.cancel();
    _jaPlayerStateSub = _jaPlayer!.playerStateStream.listen((state) {
      if (state.processingState == ja.ProcessingState.completed) {
        skipToNext();
      } else if (_activeEngine == 'just_audio') {
        _updatePlaybackState(playing: state.playing);
      }
    });

    // Wire the Android audio session ID to NativeEqService.
    // The session ID is only available after a source is loaded and playback
    // begins. We subscribe here so we catch it as soon as it's ready and
    // can immediately apply any pending EQ gains.
    _jaSessionSub?.cancel();
    // androidAudioSessionIdStream is the correct just_audio API (Stream<int?>).
    // We subscribe here and apply pending EQ gains as soon as the session is ready.
    _jaSessionSub = _jaPlayer!.androidAudioSessionIdStream.listen((sessionId) async {
      if (sessionId != null && sessionId != 0) {
        await nativeEqService.setupEqualizer(sessionId);
        final gains = _pendingEqGains;
        if (gains != null) {
          await nativeEqService.setEqualizerBands(gains);
        }
        await nativeEqService.setBassBoost(_pendingBassValue);
        debugPrint('[AudioHandler] NativeEq wired to JustAudio session $sessionId');
      }
    });

    // Subscribe to position updates for the UI seeker and lock screen
    _jaPositionSub?.cancel();
    _jaPositionSub = _jaPlayer!.positionStream.listen((pos) {
      if (_activeEngine == 'just_audio') {
        _positionStreamController.add(pos);
      }
    });

    // Subscribe to duration updates to auto-correct media item duration
    _jaDurationSub?.cancel();
    _jaDurationSub = _jaPlayer!.durationStream.listen((duration) {
      if (_activeEngine == 'just_audio' && duration != null) {
        final currentItem = mediaItem.valueOrNull;
        if (currentItem != null && currentItem.duration != duration) {
          mediaItem.add(currentItem.copyWith(duration: duration));
          // Refresh playback state to update the total duration in system metadata
          _updatePlaybackState(playing: _jaPlayer!.playing);
        }
      }
    });
  }

  void updateEngineSelection(String engine) {
    if (_activeEngine == engine) return;
    stop();
    _activeEngine = engine;
    debugPrint('Audio engine switched to: $_activeEngine');
  }

  // --- PLAYBACK CONTROL MODULE ---

  Future<void> loadQueueItem(MediaItem item, {List<MediaItem>? fullQueue, bool autoplay = true}) async {
    mediaItem.add(item);
    
    if (fullQueue != null) {
      queue.add(fullQueue);
      _queueIndex = fullQueue.indexWhere((element) => element.id == item.id);
      if (_queueIndex < 0) _queueIndex = 0;
    } else {
      queue.add([item]);
      _queueIndex = 0;
    }

    _mockPlayer.updateIndex(_queueIndex);
    await _loadAndPlayFile(item.id, autoplay: autoplay);
  }

  Future<void> _loadAndPlayFile(String path, {bool autoplay = true}) async {
    // 1. Stop current playback if active
    if (_activeHandle != null) {
      final handleToStop = _activeHandle!;
      _activeHandle = null; // Instantly set to null to cancel the active visualizer timer and prevent race skips!
      try {
        await SoLoud.instance.stop(handleToStop);
      } catch (_) {}
    }

    // 2. Dispose current audio source (prevent native memory leaks)
    if (_currentSound != null) {
      try {
        await SoLoud.instance.disposeSource(_currentSound!);
      } catch (_) {}
      _currentSound = null;
    }

    if (_jaPlayer != null) {
      try {
        await _jaPlayer!.stop();
      } catch (_) {}
    }

    _positionStreamController.add(Duration.zero);

    // 3. Load the new file path in the selected engine (resolving Scoped Storage path if Android)
    final resolvedPath = await _resolvePlayablePath(path);
    
    if (_activeEngine == 'soloud') {
      try {
        final sound = await SoLoud.instance.loadFile(resolvedPath);
        _currentSound = sound;
      } catch (e) {
        debugPrint('SoLoud loader error for $path (resolved: $resolvedPath): $e');
        _updatePlaybackState(playing: false);
        return;
      }
    } else {
      try {
        _initJustAudioPlayer();
        await _jaPlayer!.setAudioSource(ja.AudioSource.file(resolvedPath));
      } catch (e) {
        debugPrint('just_audio loader error for $path (resolved: $resolvedPath): $e');
        _updatePlaybackState(playing: false);
        return;
      }
    }

    // 4. Autostart playback if requested
    if (autoplay) {
      await play();
    } else {
      // Setup initial player configuration but do not start playback
      if (_activeEngine == 'soloud') {
        final sound = _currentSound;
        if (sound != null) {
          try {
            final newHandle = await SoLoud.instance.play(sound);
            _activeHandle = newHandle;
            SoLoud.instance.setVolume(newHandle, _userVolume);
            SoLoud.instance.pauseSwitch(newHandle); // Pause immediately
            if (!_isEqFlat) {
              final filter = SoLoud.instance.filters.equalizerFilter;
              if (!filter.isActive) filter.activate();
            }
          } catch (_) {}
        }
      } else {
        _initJustAudioPlayer();
        _jaPlayer!.setVolume(1.0);
      }
      _updatePlaybackState(playing: false);
    }
  }

  Future<String> _resolvePlayablePath(String path) async {
    if (Platform.isAndroid) {
      try {
        final file = File(path);
        if (await file.exists()) {
          // If it is already in our app's private data storage, return directly
          if (path.contains('/data/user/0/') || path.contains('/data/data/')) {
            return path;
          }
          final tempDir = await getTemporaryDirectory();
          // Generate a microsecond unique path to fully avoid key collision and Future already completed exception in loadedFileCompleters!
          final tempFile = File(p.join(tempDir.path, 'temp_playback_${DateTime.now().microsecondsSinceEpoch}_${p.basename(path)}'));
          
          // Clean up old temporary files in the directory to prevent storage growth
          try {
            await for (final entity in tempDir.list(recursive: false)) {
              if (entity is File && p.basename(entity.path).startsWith('temp_playback_')) {
                await entity.delete().catchError((_) => entity);
              }
            }
          } catch (_) {}

          await file.copy(tempFile.path);
          debugPrint('Successfully resolved Android content path to temp cache: ${tempFile.path}');
          return tempFile.path;
        }
      } catch (e) {
        debugPrint('Failed to resolve playable path for Android: $e');
      }
    }
    return path;
  }

  @override
  Future<void> play() async {
    if (_activeEngine == 'soloud') {
      final sound = _currentSound;
      if (sound == null) return;

      final handle = _activeHandle;
      if (handle != null) {
        // Resume if paused
        final isPaused = SoLoud.instance.getPause(handle);
        if (isPaused) {
          SoLoud.instance.pauseSwitch(handle);
        }
      } else {
        // Start play
        try {
          final newHandle = await SoLoud.instance.play(sound);
          _activeHandle = newHandle;

          // Apply hardware volume instantly
          SoLoud.instance.setVolume(newHandle, _userVolume);
          
          // Activate native 8-band equalizer filter ONLY if EQ is not Flat (Transparent Bypass Mode)
          if (!_isEqFlat) {
            final filter = SoLoud.instance.filters.equalizerFilter;
            if (!filter.isActive) {
              filter.activate();
            }
          }

          _startPeriodicTimer();
        } catch (e) {
          debugPrint('SoLoud play handle error: $e');
          return;
        }
      }
    } else {
      _initJustAudioPlayer();
      _jaPlayer!.setVolume(1.0); // Unity gain (1.0) since OS controls system music volume stream natively
      _jaPlayer!.play();
      _startPeriodicTimer();
    }

    _updatePlaybackState(playing: true);
  }

  @override
  Future<void> pause() async {
    if (_activeEngine == 'soloud') {
      final handle = _activeHandle;
      if (handle != null) {
        final isPaused = SoLoud.instance.getPause(handle);
        if (!isPaused) {
          SoLoud.instance.pauseSwitch(handle);
        }
      }
    } else {
      await _jaPlayer?.pause();
    }
    _updatePlaybackState(playing: false);
  }

  @override
  Future<void> seek(Duration position) async {
    _lastSeekTime = DateTime.now();
    _positionStreamController.add(position);
    
    if (_activeEngine == 'soloud') {
      final handle = _activeHandle;
      if (handle != null) {
        SoLoud.instance.seek(handle, position);
      }
    } else {
      await _jaPlayer?.seek(position);
    }
  }

  @override
  Future<void> stop() async {
    _positionTimer?.cancel();
    if (_activeHandle != null) {
      await SoLoud.instance.stop(_activeHandle!);
      _activeHandle = null;
    }
    if (_currentSound != null) {
      await SoLoud.instance.disposeSource(_currentSound!);
      _currentSound = null;
    }
    if (_jaPlayer != null) {
      await _jaPlayer!.stop();
    }
    // Release the Android AudioEffect instances tied to the JustAudio session
    await nativeEqService.releaseEqualizer();
    _updatePlaybackState(playing: false);
  }

  @override
  Future<void> skipToNext() async {
    final currentQueue = queue.valueOrNull ?? [];
    if (currentQueue.isEmpty) return;

    if (_mockPlayer.shuffleModeEnabled) {
      _queueIndex = math.Random().nextInt(currentQueue.length);
    } else {
      _queueIndex = (_queueIndex + 1) % currentQueue.length;
    }
    
    _mockPlayer.updateIndex(_queueIndex);
    final nextTrack = currentQueue[_queueIndex];
    mediaItem.add(nextTrack);
    await _loadAndPlayFile(nextTrack.id);
  }

  @override
  Future<void> skipToPrevious() async {
    final currentQueue = queue.valueOrNull ?? [];
    if (currentQueue.isEmpty) return;

    _queueIndex = (_queueIndex - 1 + currentQueue.length) % currentQueue.length;
    _mockPlayer.updateIndex(_queueIndex);
    final prevTrack = currentQueue[_queueIndex];
    mediaItem.add(prevTrack);
    await _loadAndPlayFile(prevTrack.id);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    final currentQueue = queue.valueOrNull ?? [];
    if (currentQueue.isEmpty || index < 0 || index >= currentQueue.length) return;

    _queueIndex = index;
    _mockPlayer.updateIndex(_queueIndex);
    final track = currentQueue[_queueIndex];
    mediaItem.add(track);
    await _loadAndPlayFile(track.id);
  }

  // --- HARDWARE EQ & VOLUME DSP ---

  Future<void> setEqualizerBands(List<double> gains) async {
    _pendingEqGains = List.from(gains);

    if (_activeEngine == 'just_audio') {
      // ── JustAudio path: delegate to Android native Equalizer ──────────────
      // Check for flat (all gains ≈ 0 dB) → bypass hardware EQ entirely
      final isFlat = gains.every((g) => g.abs() < 0.01);
      if (isFlat) {
        await nativeEqService.setFlat();
        debugPrint('[AudioHandler] NativeEq: FLAT bypass applied.');
      } else {
        await nativeEqService.setEqualizerBands(gains);
        debugPrint('[AudioHandler] NativeEq: bands applied.');
      }
      return;
    }

    // ── SoLoud path: FFT filter (kept for users who want real FFT visualizers) ─
    try {
      final filter = SoLoud.instance.filters.equalizerFilter;

      final bool isFlat = gains.every((g) => g.abs() < 0.01);
      if (isFlat) {
        _isEqFlat = true;
        if (filter.isActive) filter.deactivate();
        final handle = _activeHandle;
        if (handle != null) SoLoud.instance.setVolume(handle, _userVolume);
        debugPrint('[AudioHandler] SoLoud EQ: FLAT bypass.');
        return;
      }

      _isEqFlat = false;
      if (!filter.isActive) filter.activate();

      // Full dB gains → linear multipliers (no compression — SoLoud's FFT filter
      // covers wide linear bins so even ±12 dB changes are perceptually moderate).
      final handle = _activeHandle;
      if (handle != null) SoLoud.instance.setVolume(handle, _userVolume);

      if (gains.length >= 8) {
        filter.band1.value = math.pow(10, gains[0] / 20.0).toDouble().clamp(0.0, 4.0);
        filter.band2.value = math.pow(10, gains[1] / 20.0).toDouble().clamp(0.0, 4.0);
        filter.band3.value = math.pow(10, gains[2] / 20.0).toDouble().clamp(0.0, 4.0);
        filter.band4.value = math.pow(10, gains[3] / 20.0).toDouble().clamp(0.0, 4.0);
        filter.band5.value = math.pow(10, gains[4] / 20.0).toDouble().clamp(0.0, 4.0);
        filter.band6.value = math.pow(10, gains[5] / 20.0).toDouble().clamp(0.0, 4.0);
        filter.band7.value = math.pow(10, gains[6] / 20.0).toDouble().clamp(0.0, 4.0);
        filter.band8.value = math.pow(10, gains[7] / 20.0).toDouble().clamp(0.0, 4.0);
      } else if (gains.length >= 5) {
        // Interpolate 5 → 8 bands
        final b1Db = gains[0];
        final b2Db = gains[0] * 0.5 + gains[1] * 0.5;
        final b3Db = gains[1];
        final b4Db = gains[1] * 0.3 + gains[2] * 0.7;
        final b5Db = gains[2];
        final b6Db = gains[2] * 0.3 + gains[3] * 0.7;
        final b7Db = gains[3];
        final b8Db = gains[4];
        filter.band1.value = math.pow(10, b1Db / 20.0).toDouble().clamp(0.0, 4.0);
        filter.band2.value = math.pow(10, b2Db / 20.0).toDouble().clamp(0.0, 4.0);
        filter.band3.value = math.pow(10, b3Db / 20.0).toDouble().clamp(0.0, 4.0);
        filter.band4.value = math.pow(10, b4Db / 20.0).toDouble().clamp(0.0, 4.0);
        filter.band5.value = math.pow(10, b5Db / 20.0).toDouble().clamp(0.0, 4.0);
        filter.band6.value = math.pow(10, b6Db / 20.0).toDouble().clamp(0.0, 4.0);
        filter.band7.value = math.pow(10, b7Db / 20.0).toDouble().clamp(0.0, 4.0);
        filter.band8.value = math.pow(10, b8Db / 20.0).toDouble().clamp(0.0, 4.0);
      }
      debugPrint('[AudioHandler] SoLoud EQ bands updated.');
    } catch (e) {
      debugPrint('[AudioHandler] SoLoud EQ failed: $e');
    }
  }

  /// Sets the bass boost strength.
  /// JustAudio: routes to Android BassBoost AudioEffect.
  /// SoLoud: no-op (bass boost is baked into bands by the UI layer).
  Future<void> setBassBoost(double bassKnobValue) async {
    _pendingBassValue = bassKnobValue;
    if (_activeEngine == 'just_audio') {
      await nativeEqService.setBassBoost(bassKnobValue);
    }
  }

  Future<void> setStereoStrength(double value01) async {
    // Stereo strength is a native effect; degraded gracefully in SoLoud C++
  }

  // --- AUDIO SINK & PERSISTENCE SYNCS ---

  Future<void> _initAudioSession() async {
    try {
      _volumeSub = FlutterVolumeController.addListener((volume) {
        _userVolume = volume;
        _volumeController.add(volume);
        
        final handle = _activeHandle;
        if (handle != null) {
          SoLoud.instance.setVolume(handle, volume);
        }
      });

      final initialVolume = await FlutterVolumeController.getVolume();
      _userVolume = initialVolume ?? 0.8;
      _volumeController.add(_userVolume);
    } catch (e) {
      debugPrint('Volume controller init failed: $e');
    }
  }

  Future<void> setSystemVolume(double volume) async {
    try {
      await FlutterVolumeController.setVolume(volume.clamp(0.0, 1.0));
      _userVolume = volume.clamp(0.0, 1.0);
      _volumeController.add(_userVolume);
      
      final handle = _activeHandle;
      if (handle != null) {
        SoLoud.instance.setVolume(handle, _userVolume);
      }
    } catch (e) {
      debugPrint('Failed to update system volume: $e');
    }
  }

  // --- PERIODIC REAL FFT TIMER & PROGRESS SCANNER ---

  void _startPeriodicTimer() {
    _positionTimer?.cancel();
    // High-fidelity 50Hz update loop (20ms polling) for absolute real-time visualizer bounciness!
    _positionTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (_activeEngine == 'soloud') {
        final handle = _activeHandle;
        if (handle == null) {
          timer.cancel();
          return;
        }

        // 1. Natural end-of-track detection (throttled to once every 500ms -> 25 ticks)
        if (timer.tick % 25 == 0) {
          final isHandleActive = SoLoud.instance.activeSounds.any((sound) => sound.handles.contains(handle));
          if (!isHandleActive) {
            timer.cancel();
            _activeHandle = null;
            skipToNext();
            return;
          }
        }

        // 2. Read exact playback position (throttled to once every 200ms -> 10 ticks).
        // Skip for 300ms after a seek so the position can't snap back before the
        // native audio thread finishes scrubbing to the new point.
        if (timer.tick % 10 == 0) {
          final msSinceSeek = DateTime.now().difference(_lastSeekTime).inMilliseconds;
          if (msSinceSeek >= 300) {
            try {
              final posDuration = SoLoud.instance.getPosition(handle);
              _positionStreamController.add(posDuration);
            } catch (_) {}
          }
        }

        // 3. Query C++ real-time FFT frequency spectrum using AudioData linear buffer (runs at full 50Hz)
        try {
          final ad = _audioData;
          if (ad != null && SoLoud.instance.isInitialized) {
            ad.updateSamples();
            final fftData = Float32List.fromList(
              List.generate(256, (i) => ad.getLinearFft(SampleLinear(i))),
            );
            final bands = _processFftToBands(fftData);
            _latestVisualizerBands = bands;
            _visualizerBandsController.add(bands);
          }
        } catch (e) {
          debugPrint('Visualizer FFT calculation error: $e');
        }
      } else {
        // ── JustAudio mode: Simulated Visualizer Bands ────────────────────────
        final isPlaying = _jaPlayer?.playing ?? false;
        if (!isPlaying) {
          // If not playing, decay bands to zero smoothly
          final bands = _latestVisualizerBands ?? List.filled(10, 0.0);
          final decayed = List<double>.generate(10, (i) => (bands[i] * 0.85).clamp(0.0, 1.0));
          _latestVisualizerBands = decayed;
          _visualizerBandsController.add(decayed);
          _beatPulse = 0.0;
          return;
        }

        // Generate simulated bouncing bands driven by sine waves + standard transients
        final now = DateTime.now().millisecondsSinceEpoch;
        final seconds = now / 1000.0;

        // Simulate standard kick beat every 460ms (~130 BPM)
        final beatTimeMs = now % 460;
        final double beatFactor = math.exp(-beatTimeMs / 120.0); // sharp rise, exponential decay

        // Sync beat pulse for lock screen or UI elements
        if (beatTimeMs < 40) {
          _beatPulse = 1.0;
        } else {
          _beatPulse = (_beatPulse * 0.9).clamp(0.0, 1.0);
        }

        final bands = List<double>.filled(10, 0.0);
        final baseList = _latestVisualizerBands ?? List.filled(10, 0.0);

        for (int i = 0; i < 10; i++) {
          final osc1 = math.sin(seconds * 3.5 + i * 0.7);
          final osc2 = math.cos(seconds * 7.0 - i * 1.2);
          
          double level = 0.1;
          if (i < 3) {
            level = 0.2 + beatFactor * 0.6 + osc1 * 0.15;
          } else if (i < 7) {
            level = 0.15 + osc1 * 0.25 + osc2 * 0.15 + beatFactor * 0.15;
          } else {
            final jitter = math.sin(seconds * 25.0 + i) * 0.1;
            level = 0.1 + osc2 * 0.2 + jitter + beatFactor * 0.05;
          }

          if (math.Random().nextDouble() < 0.04) {
            level += 0.3;
          }

          final target = level.clamp(0.0, 1.0);
          bands[i] = baseList[i] * 0.4 + target * 0.6;
        }

        _latestVisualizerBands = bands;
        _visualizerBandsController.add(bands);
      }
    });
  }

  List<double> _processFftToBands(Float32List fft) {
    final bands = List<double>.filled(10, 0.0);
    final n = fft.length;
    if (n < 10) return bands;

    final maxK = n - 1;
    // Skip index 0 (DC offset) to prevent visualizer bands from pinning to full.
    for (int b = 0; b < 10; b++) {
      final start = (math.pow(maxK.toDouble(), b / 10.0)).round().clamp(1, maxK);
      final end = (math.pow(maxK.toDouble(), (b + 1) / 10.0)).round().clamp(start, maxK);

      double sum = 0.0;
      int count = 0;
      for (int k = start; k <= end; k++) {
        sum += fft[k].abs();
        count++;
      }
      final avg = count > 0 ? sum / count : 0.0;

      // ── MUD GATING ──────────────────────────────────────────────────────────
      // Sub-bass / DC floor gate: low bands receive a hard noise floor.
      // Signals below the gate collapse via non-linear expansion (squaring),
      // preventing the first 2-5 bars from staying pinned at max when there
      // is only low-level rumble or DC offset in the spectrum.
      //
      // Gate floor scale: band 0 uses the highest gate (0.12) and it
      // reduces linearly to 0.02 for band 9 (highs have natural headroom).
      final gateFloor = 0.12 - b * 0.011; // b=0 → 0.120, b=9 → 0.021
      final gated = avg < gateFloor
          ? avg * (avg / gateFloor) // sub-floor: square-law collapse
          : avg; // above gate: pass through unchanged

      // Dynamic expansion exponent: high values crush noise harder on low bands.
      // b=0: exponent = 1.50 (aggressive expansion, kills rumble)
      // b=9: exponent = 0.82 (gentle compression, reveals high detail)
      final exponent = 1.50 - b * 0.076;
      final expanded = math.pow(gated, exponent).toDouble();

      // Band multipliers tuned for balanced headroom after expansion.
      // Bass (b=0): 1.6x — allows big jumps on true bass hits.
      // Highs (b=9): 3.0x — amplifies quiet high-frequency detail.
      final multiplier = 1.6 + b * 0.16;
      bands[b] = (expanded * multiplier).clamp(0.0, 1.0);
    }

    _updateBeatPulse(bands);
    return bands;
  }

  void _updateBeatPulse(List<double> bands01) {
    if (bands01.length < 3) return;
    
    final low = (bands01[0] + bands01[1] + bands01[2]) / 3.0;
    _lowEnergyEma = _lowEnergyEma * 0.92 + low * 0.08;

    final now = DateTime.now();
    final msSince = now.difference(_lastBeatAt).inMilliseconds;
    final transient = low - _lowEnergyEma;

    final canTrigger = msSince > 220;
    if (canTrigger && transient > 0.08) {
      _beatPulse = 1.0;
      _lastBeatAt = now;
    } else {
      _beatPulse *= 0.88;
      if (_beatPulse < 0.001) _beatPulse = 0.0;
    }
  }

  void _updatePlaybackState({required bool playing}) {
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: (_activeEngine == 'soloud' ? _currentSound != null : _jaPlayer != null)
          ? AudioProcessingState.ready
          : AudioProcessingState.idle,
      playing: playing,
      updatePosition: livePosition,
      bufferedPosition: livePosition,
      speed: 1.0,
      queueIndex: _queueIndex,
    ));
  }

  @override
  Future<void> onTaskRemoved() async {
    _positionTimer?.cancel();
    _volumeSub?.cancel();
    _jaSessionSub?.cancel();
    _jaPositionSub?.cancel();
    _jaDurationSub?.cancel();
    _jaPlayerStateSub?.cancel();
    _audioData?.dispose();
    await nativeEqService.releaseEqualizer();
    
    if (_activeHandle != null) {
      try {
        await SoLoud.instance.stop(_activeHandle!);
      } catch (_) {}
      _activeHandle = null;
    }
    
    if (_currentSound != null) {
      try {
        await SoLoud.instance.disposeSource(_currentSound!);
      } catch (_) {}
      _currentSound = null;
    }
    
    await super.onTaskRemoved();
  }
}

// Compiler-safe adapter wrapper for Loop/Shuffle control logic
class MockAudioPlayer {
  final UltraAudioHandler _handler;
  
  final _currentIndexController = BehaviorSubject<int?>.seeded(0);
  final _loopModeController = BehaviorSubject<ja.LoopMode>.seeded(ja.LoopMode.off);
  final _shuffleModeController = BehaviorSubject<bool>.seeded(false);

  MockAudioPlayer(this._handler);

  Stream<int?> get currentIndexStream => _currentIndexController.stream;
  Stream<ja.LoopMode> get loopModeStream => _loopModeController.stream;
  Stream<bool> get shuffleModeEnabledStream => _shuffleModeController.stream;

  int? get currentIndex => _currentIndexController.value;
  ja.LoopMode get loopMode => _loopModeController.value;
  bool get shuffleModeEnabled => _shuffleModeController.value;

  dynamic get sequenceState => null;
  Duration get position => _handler.livePosition;
  Duration? get duration => _handler.mediaItem.valueOrNull?.duration;
  Stream<Duration> get positionStream => _handler.positionStream;

  Future<void> seek(Duration position, {int? index}) async {
    if (index != null) {
      await _handler.skipToQueueItem(index);
    } else {
      await _handler.seek(position);
    }
  }

  Future<void> setShuffleModeEnabled(bool enabled) async {
    _shuffleModeController.add(enabled);
    if (_handler._activeHandle != null) {
      // Trigger update of playback state to notify UI
      _handler._updatePlaybackState(playing: true);
    }
  }

  Future<void> setLoopMode(ja.LoopMode mode) async {
    _loopModeController.add(mode);
    if (_handler._activeHandle != null) {
      _handler._updatePlaybackState(playing: true);
    }
  }
  
  void updateIndex(int index) {
    _currentIndexController.add(index);
  }
}
