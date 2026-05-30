import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'dart:math' as math;
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:ultramp3/core/services/playback_service.dart';
import 'package:ultramp3/core/services/audio_handler.dart';
import 'package:ultramp3/core/services/storage_service.dart';
import 'package:ultramp3/core/theme/app_colors.dart';
import 'package:ultramp3/features/player/presentation/providers/player_skin_provider.dart';
import 'package:ultramp3/features/player/presentation/providers/player_settings_provider.dart';
import 'package:ultramp3/features/player/domain/models/player_skin.dart';
import 'package:ultramp3/features/player/presentation/screens/add_to_playlist_screen.dart';
import 'package:ultramp3/features/playlists/presentation/providers/playlist_providers.dart';

// Supported 14 Visualization Styles
enum VisualizerStyle {
  spectrumBars, // Center-out, Rounded capsule, Retro Winamp, Floating
  waveform, // Continuous, Oscilloscope, Bezier, Symmetrical
  circularSpectrum, // Rotating particles, Pulsing radius
  particleReactive, // Dust, Galaxy, Smoke, Energy field
  liquidFluid, // Fluid simulation reacting to music
  breathingRings, // Expanding concentric circles
  retroWinamp, // Classical Winamp green/yellow grid
  albumArtReactive, // Glow, Blur pulse, Dynamic shadow heartbeat
  combinedUltra, // Waveform+Spectrum, Circular+Album, Particles+Pulse, BackgroundBlur+Glow, Ultra Combo
  solarFlares, // [NEW] Concentric laser rings & solar flares
  vortexOrbit, // [NEW] Vocal double helix orbit dots
  rippleWaves, // [NEW] Multi-layered translucent overlapping waves
  particleWaveFlow, // [NEW] Beautiful flowing particles on dynamic spectrum wave
  cosmicTunnel, // [NEW] 3D radial warp starfield vortex tunnel
  orbitalGlow,
  frequencyLaser,
  dnaHelix,
  audioMatrixGrid,
  blackHoleStars, // [NEW] 3D gravitational starfall vortex swallowing stars into a central singing singularity

  // GPU shader visualizers (Android-only for now)
  shaderAppsRing,
  shaderSteamBars,
}

// Supported Skeuomorphic Dial Styles
enum DialStyle {
  circular,
  rectangular,
  digitalToggles,
}

// 3D coordinate star for Astro Starfield visualizer
class _AstroStar {
  double x; // Horizontal offset (-1.0 to 1.0)
  double y; // Vertical offset (-1.0 to 1.0)
  double z; // Depth / distance (0.0 to 1.0)
  double speed;

  _AstroStar()
      : x = (math.Random().nextDouble() * 2 - 1),
        y = (math.Random().nextDouble() * 2 - 1),
        z = math.Random().nextDouble(),
        speed = 0.004 + math.Random().nextDouble() * 0.012;

  void update(double audioBoost) {
    z -= speed * (1.0 + audioBoost * 14.0);
    if (z <= 0) {
      x = (math.Random().nextDouble() * 2 - 1);
      y = (math.Random().nextDouble() * 2 - 1);
      z = 1.0;
    }
  }
}

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with TickerProviderStateMixin {
  bool _sessionRestored = false;

  late AnimationController _visualizerController;
  late AnimationController _vinylRotationController;

  final List<double> _visualizerHeights = List.filled(10, 4.0);
  final List<double> _peakHeights = List.filled(10, 4.0);
  final math.Random _random = math.Random();

  bool _isPlaying = false;
  bool _hasTrack =
      false; // Empty state safeguard: freeze visualizer when no track
  double _animationTime = 0.0;
  double _lastBeatTime = 0.0;
  double _beatEnergy = 0.0;
  double _snareEnergy = 0.0;

  // Real-time stars list for Astro Starfield style
  late final List<_AstroStar> _stars;

  // Background particles list for Obsidian Void & Glacier Crystalline Ice celestial background
  final List<_AstroStar> _bgCelestialStars =
      List.generate(40, (_) => _AstroStar());

  // Active configurations
  VisualizerStyle _visualizerStyle = VisualizerStyle.spectrumBars;
  int _visualizerVariation = 0; // Cycles from 0 to 4 depending on style!
  DialStyle _dialStyle = DialStyle.circular;
  bool _showEqualizer = false;

  bool _isShaderStyle(VisualizerStyle style) {
    switch (style) {
      case VisualizerStyle.shaderAppsRing:
      case VisualizerStyle.shaderSteamBars:
        return true;
      default:
        return false;
    }
  }

  // EQ Hardware Knobs (0.0 = min/neutral, 1.0 = max)
  double _bassValue = 0.5; // Boosts 60Hz + 230Hz bands via native EQ
  double _stereoValue = 0.5; // Simulates stereo widening in visualizer

  String? _statusMessage;
  Timer? _statusTimer;

  // Equalizer presets (mapped onto actual Android EQ band layout when supported)
  String _activePreset = 'Flat';

  static const List<String> _presetNames = [
    'Bose Signature',
    'Beats Audio',
    'Harman Kardon',
    'Sony ClearBass',
    'Sennheiser Club',
    'Flat',
    'Rock',
    'Pop',
    'Jazz',
    'Bass & Treble',
    'Mids',
    'Classic',
    'Live',
    'Dance',
    'Soft',
    'No Bass',
    'No Mids',
    'No Treble',
    'Custom',
  ];

  // Default EQ UI is a recognizable 5-band layout (per equalizer.md).
  // These are the UI bands we persist and edit.
  static const List<double> _eqUiCentersHz = <double>[
    60,
    150,
    400,
    1000,
    2400,
    6000,
    15000,
    20000,
  ];
  static const List<String> _eqUiLabels = <String>[
    '60Hz',
    '150Hz',
    '400Hz',
    '1kHz',
    '2.4kHz',
    '6kHz',
    '15kHz',
    '20kHz',
  ];

  // UI gains (8-band) in dB.
  final List<double> _eqBands = List.filled(8, 0.0);

  // Android device EQ parameters (used for mapping/clamping).
  double _eqMinDb = -12.0;
  double _eqMaxDb = 12.0;
  List<double> _deviceEqCentersHz = const [];

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<List<double>>? _visualizerBandsSub;
  List<double>? _latestRealBands01;
  double _latestBeatPulse = 0.0;

  /// Non-null only while the user is actively dragging the seek slider.
  /// Isolates local UI drag position from the stream-driven position so the
  /// thumb does not jump back to the old position during scrubbing.
  double? _dragValue;

  // Cache technical metadata (best-effort) per file path.
  final Map<String, _AudioTechInfo> _techInfoCache = {};
  final Map<String, Future<_AudioTechInfo?>> _techInfoInflight = {};

  ui.FragmentProgram? _appsRingProgram;
  ui.FragmentProgram? _steamBarsProgram;
  ui.FragmentProgram? _cosmicTunnelProgram;
  ui.FragmentProgram? _liquidFluidProgram;
  ui.FragmentProgram? _solarFlaresProgram;

  Future<ui.FragmentProgram?> _tryLoadProgram(String asset) async {
    try {
      return await ui.FragmentProgram.fromAsset(asset);
    } catch (e, st) {
      // Don't let one shader failure break all shader loading.
      // Keep this as debug-only signal.
      assert(() {
        debugPrint('Shader load failed ($asset): $e');
        debugPrint('$st');
        return true;
      }());
      return null;
    }
  }

  Future<void> _loadShaderPrograms() async {
    final apps = await _tryLoadProgram('shaders/apps_ring.frag');
    final steam = await _tryLoadProgram('shaders/steam_bars.frag');
    final tunnel = await _tryLoadProgram('shaders/cosmic_tunnel.frag');
    final fluid = await _tryLoadProgram('shaders/liquid_fluid.frag');
    final solar = await _tryLoadProgram('shaders/solar_flares.frag');

    if (!mounted) return;
    setState(() {
      _appsRingProgram = apps;
      _steamBarsProgram = steam;
      _cosmicTunnelProgram = tunnel;
      _liquidFluidProgram = fluid;
      _solarFlaresProgram = solar;
    });
  }

  @override
  void initState() {
    super.initState();

    _stars = List.generate(45, (index) => _AstroStar());

    _visualizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 33),
    )..addListener(_tickVisualizer);
    _visualizerController.repeat();

    _vinylRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _loadShaderPrograms();

    // Real audio-driven visualizer (Android): subscribe once and let _tickVisualizer
    // use the latest bands when available.
    _visualizerBandsSub =
        ref.read(playbackServiceProvider).handler.visualizerBandsStream.listen(
      (bands) {
        _latestRealBands01 = bands;
        _latestBeatPulse =
            ref.read(playbackServiceProvider).handler.latestBeatPulse;
      },
    );

    // 1. Load initial visualizer & dial & equalizer settings synchronously from storage
    final storage = ref.read(storageServiceProvider);

    final styleStr = storage.getVisualizerStyle();
    _visualizerStyle = VisualizerStyle.values.firstWhere(
      (e) => e.name == styleStr,
      orElse: () => VisualizerStyle.spectrumBars,
    );

    _visualizerVariation = storage.getVisualizerVariation();

    final dialStyleStr = storage.getDialStyle();
    _dialStyle = DialStyle.values.firstWhere(
      (e) => e.name == dialStyleStr,
      orElse: () => DialStyle.circular,
    );

    _activePreset = storage.getEqualizerPreset();

    // 2. Restore active playback session in a post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restorePlaybackSession();
    });
  }

  Future<void> _restorePlaybackSession() async {
    if (!mounted) return;
    try {
      final storage = ref.read(storageServiceProvider);
      final playbackService = ref.read(playbackServiceProvider);
      final player = playbackService.handler.playerInstance;

      // A. Restore Queue & Active Song & Position (ONLY if nothing is playing and not yet restored)
      if (!_sessionRestored) {
        _sessionRestored = true;
        if (player.sequenceState == null) {
          final queueList = storage.getSavedQueueList();
          final activeSongId = storage.getSavedActiveSongId();
          final positionMs = storage.getSavedPositionMs();

          if (queueList.isNotEmpty && activeSongId != null) {
            final activeSongItem = MediaItem(
              id: activeSongId,
              title: p.basenameWithoutExtension(activeSongId),
              artist: 'Unknown Artist',
            );

            final fullQueueItems = queueList.map((id) {
              if (id == activeSongId) return activeSongItem;
              return MediaItem(
                id: id,
                title: p.basenameWithoutExtension(id),
                artist: 'Unknown Artist',
              );
            }).toList();

            await playbackService.handler
                .loadQueueItem(activeSongItem, fullQueue: fullQueueItems);

            if (positionMs > 0) {
              await player.seek(Duration(milliseconds: positionMs));
            }
          }
        }
      }

      // Always keep a 10-band UI model. On Android, map to device EQ bands.
      final eqParams = await playbackService.handler.equalizerParameters;
      final savedBands = storage.getEqualizerBands();

      if (eqParams != null) {
        _eqMinDb = eqParams.minDecibels;
        _eqMaxDb = eqParams.maxDecibels;
        _deviceEqCentersHz = eqParams.bands
            .map((b) => b.centerFrequency / 1000.0)
            .toList(growable: false);
      } else {
        _eqMinDb = -12.0;
        _eqMaxDb = 12.0;
        _deviceEqCentersHz = const [];
      }

      // Restore persisted gains into the 5-band UI model.
      // If the active preset is a known predefined preset (not 'Custom' and not 'Flat'),
      // we load the fresh code-defined bands to ensure any preset tuning updates (like the 60Hz Pop fix) are immediately applied and saved.
      final List<double> bandsToRestore;
      if (_activePreset != 'Custom' && _activePreset != 'Flat') {
        bandsToRestore = _computePresetForEightBands(_activePreset);
        storage.setEqualizerBands(bandsToRestore);
      } else {
        bandsToRestore = savedBands;
      }

      // Migration rules:
      // - if saved/restore is 8: direct restore
      // - if saved/restore is 5: migrate from 5 to 8 by frequency interpolation
      // - if saved/restore is 10: migrate from 10 to 8 by frequency interpolation
      // - otherwise: best-effort copy/truncate
      if (bandsToRestore.length == 8) {
        for (int i = 0; i < 8; i++) {
          _eqBands[i] = bandsToRestore[i];
        }
      } else if (bandsToRestore.length == 5) {
        const legacyHz = <double>[60, 230, 910, 3600, 14000];
        for (int i = 0; i < 8; i++) {
          _eqBands[i] = _interpDb(
            x: _eqUiCentersHz[i],
            xs: legacyHz,
            ys: bandsToRestore,
          );
        }
      } else if (bandsToRestore.length == 10) {
        const legacyHz = <double>[
          31,
          62,
          125,
          250,
          500,
          1000,
          2000,
          4000,
          8000,
          16000
        ];
        for (int i = 0; i < 8; i++) {
          _eqBands[i] = _interpDb(
            x: _eqUiCentersHz[i],
            xs: legacyHz,
            ys: bandsToRestore,
          );
        }
      } else {
        for (int i = 0; i < 8; i++) {
          _eqBands[i] = i < bandsToRestore.length ? bandsToRestore[i] : 0.0;
        }
      }

      // B. Restore Shuffle & Loop (best-effort; only valid after a source exists)
      final shuffleOn = storage.getShuffleEnabled();
      try {
        await player.setShuffleModeEnabled(shuffleOn);
      } catch (_) {}

      final loopModeStr = storage.getLoopMode();
      final loopMode = ja.LoopMode.values.firstWhere(
        (e) => e.name == loopModeStr,
        orElse: () => ja.LoopMode.off,
      );
      try {
        await player.setLoopMode(loopMode);
      } catch (_) {}

      // C. Restore Volume & Equalizer Bands in the service
      final vol = storage.getVolumeLevel();
      try {
        await playbackService.setSystemVolume(vol);
      } catch (_) {}
      // Apply mapped EQ to the underlying engine.
      await _applyEqualizerNow(playbackService);

      // D. Register position subscription for real-time throttled persistence
      int lastSavedMs = 0;
      _positionSubscription = player.positionStream.listen((pos) {
        if (!mounted) return;
        final ms = pos.inMilliseconds;
        if ((ms - lastSavedMs).abs() >= 1000) {
          ref.read(storageServiceProvider).savePlaybackPosition(ms);
          lastSavedMs = ms;
        }
      });
    } catch (e) {
      debugPrint('Error restoring playback session: $e');
      if (mounted) {
        final skin = ref.read(playerSkinProvider);
        _showFeedbackGlow(context, 'RESTORE FAILED', skin.textColor);
      }
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    _positionSubscription?.cancel();
    _visualizerBandsSub?.cancel();
    _visualizerController.dispose();
    _vinylRotationController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  void _tickVisualizer() {
    if (!mounted) return;

    setState(() {
      _animationTime += 0.033;

      // Freeze everything flat when no track is loaded
      if (!_hasTrack) {
        for (int i = 0; i < 10; i++) {
          _visualizerHeights[i] = 4.0;
          _peakHeights[i] = 4.0;
        }
        if (_vinylRotationController.isAnimating) {
          _vinylRotationController.stop();
        }
        return;
      }

      if (!_isPlaying) {
        // Drifting stars and elegant breathing waves when idle/paused
        for (var star in _stars) {
          star.update(0.08);
        }
        if (_vinylRotationController.isAnimating) {
          _vinylRotationController.stop();
        }
        final double pulse = math.sin(_animationTime * 1.5).abs();
        for (int i = 0; i < 10; i++) {
          final double waveOffset = math.sin(_animationTime * 2.0 + i) * 3.0;
          final double targetHeight = 4.0 + (pulse * 8.0) + waveOffset;
          _visualizerHeights[i] =
              _visualizerHeights[i] * 0.7 + targetHeight.clamp(4.0, 18.0) * 0.3;

          if (_visualizerHeights[i] >= _peakHeights[i]) {
            _peakHeights[i] = _visualizerHeights[i];
          } else {
            _peakHeights[i] = math.max(4.0, _peakHeights[i] - 0.25);
          }
        }
        return;
      }

      for (var star in _stars) {
        star.update(_visualizerHeights[0] / 38.0);
      }

      if (!_vinylRotationController.isAnimating) {
        _vinylRotationController.repeat();
      }

      // Prefer real audio-reactive visualizer bands when available (Android).
      final realBands01 = _latestRealBands01;
      if (realBands01 != null && realBands01.length == 10) {
        final beat = _latestBeatPulse.clamp(0.0, 1.0);
        _beatEnergy = beat;
        for (int i = 0; i < 10; i++) {
          // Scale 0..1 roughly into 4..38.
          var targetHeight = 4.0 + (realBands01[i].clamp(0.0, 1.0) * 34.0);

          // Beat pulse: emphasize lower bands, subtle on higher bands.
          final beatBoost = i < 4 ? (1.0 + beat * 0.35) : (1.0 + beat * 0.10);
          targetHeight *= beatBoost;

          // Optional: keep the UI EQ influencing visuals (not audio) for style cohesion.
          if (_eqBands.isNotEmpty) {
            final int bandIndex = (i / 2).floor().clamp(0, _eqBands.length - 1);
            final double gain = _eqBands[bandIndex];
            final double eqFactor = 1.0 + (gain / 12.0) * 0.8;
            targetHeight *= eqFactor;
          }

          targetHeight = targetHeight.clamp(4.0, 38.0);
          // Snappier, bouncy responsive smoothing — 0.40 smoothing / 0.60 target
          // for instant visualizer decay so bars drop quickly between beats.
          _visualizerHeights[i] =
              _visualizerHeights[i] * 0.40 + targetHeight * 0.60;

          if (_visualizerHeights[i] >= _peakHeights[i]) {
            _peakHeights[i] = _visualizerHeights[i];
          } else {
            _peakHeights[i] = math.max(4.0, _peakHeights[i] - 0.6);
          }
        }
        return;
      }

      // ━━━━━ REAL-TIME TRANSIENT BEAT ENERGY SIMULATOR (fallback) ━━━━━
      // Exponential decay of beat transient energies
      _beatEnergy = _beatEnergy * 0.85;
      _snareEnergy = _snareEnergy * 0.82;

      // Kick drum beat (occurs every ~460ms -> ~130 BPM, standard punchy track)
      if (_animationTime - _lastBeatTime >= 0.46) {
        _beatEnergy = 1.0 +
            _random.nextDouble() *
                0.3; // Randomize velocity slightly for natural feel
        _lastBeatTime = _animationTime;
      }

      // Snare drum beat (hi-hat/snare hits shifted 230ms off the kick drum)
      if ((_animationTime - _lastBeatTime - 0.23).abs() <= 0.02 &&
          _snareEnergy < 0.2) {
        _snareEnergy = 0.8 + _random.nextDouble() * 0.25;
      }

      for (int i = 0; i < 10; i++) {
        double targetHeight = 4.0;

        if (i < 3) {
          // Low Bass bands kick heavily with beat energy transients
          targetHeight =
              4.0 + (_beatEnergy * 28.0) + (_random.nextDouble() * 4.0);
        } else if (i < 7) {
          // Mid vocal/snare bands react to hi-hat/snare hits
          targetHeight = 4.0 +
              (_snareEnergy * 22.0) +
              (math.sin(_animationTime * 14.0 + i).abs() * 8.0);
        } else {
          // Treble bands have high frequency sharp sparks and noise spikes
          if (_random.nextDouble() > 0.82) {
            targetHeight =
                4.0 + (_random.nextDouble() * 24.0); // crisp high-hat tick!
          } else {
            targetHeight =
                4.0 + (math.sin(_animationTime * 36.0 + i).abs() * 8.0);
          }
        }

        // Apply software-level 5-band EQ modulation to real-time visualizer heights
        final int bandIndex = (i / 2).floor().clamp(0, 4);
        final double gain = _eqBands[bandIndex];
        final double eqFactor = 1.0 + (gain / 12.0) * 0.8;
        targetHeight = targetHeight * eqFactor;

        targetHeight = targetHeight.clamp(4.0, 38.0);
        _visualizerHeights[i] =
            _visualizerHeights[i] * 0.45 + targetHeight * 0.55;

        if (_visualizerHeights[i] >= _peakHeights[i]) {
          _peakHeights[i] = _visualizerHeights[i];
        } else {
          _peakHeights[i] = math.max(4.0, _peakHeights[i] - 0.6);
        }
      }
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  int _getMaxVariations(VisualizerStyle style) {
    switch (style) {
      case VisualizerStyle.spectrumBars:
      case VisualizerStyle.waveform:
      case VisualizerStyle.circularSpectrum:
      case VisualizerStyle.particleReactive:
        return 4;
      case VisualizerStyle.breathingRings:
      case VisualizerStyle.retroWinamp:
      case VisualizerStyle.albumArtReactive:
        return 3;
      case VisualizerStyle.combinedUltra:
        return 4; // V5 removed (index 4)
      case VisualizerStyle.liquidFluid:
      case VisualizerStyle.solarFlares:
      case VisualizerStyle.vortexOrbit:
      case VisualizerStyle.rippleWaves:
      case VisualizerStyle.particleWaveFlow:
      case VisualizerStyle.cosmicTunnel:
      case VisualizerStyle.orbitalGlow:
      case VisualizerStyle.frequencyLaser:
      case VisualizerStyle.dnaHelix:
      case VisualizerStyle.audioMatrixGrid:
      case VisualizerStyle.blackHoleStars:
      case VisualizerStyle.shaderAppsRing:
      case VisualizerStyle.shaderSteamBars:
        return 4; // All newer styles support 4 variations
    }
  }

  void _volumeUp(PlaybackService service, PlayerSkin skin) async {
    final currentVol = service.volume;
    final targetVol = (currentVol + 0.1).clamp(0.0, 1.0);
    await service.setSystemVolume(targetVol);
    if (mounted) {
      _showFeedbackGlow(
          context, 'VOLUME: ${(targetVol * 100).toInt()}%', skin.textColor);
    }
  }

  void _volumeDown(PlaybackService service, PlayerSkin skin) async {
    final currentVol = service.volume;
    final targetVol = (currentVol - 0.1).clamp(0.0, 1.0);
    await service.setSystemVolume(targetVol);
    if (mounted) {
      _showFeedbackGlow(
          context, 'VOLUME: ${(targetVol * 100).toInt()}%', skin.textColor);
    }
  }

  void _fastRewind(PlaybackService service, PlayerSkin skin) async {
    final player = service.handler.playerInstance;
    final currentPos = player.position;
    final target = currentPos - const Duration(seconds: 10);
    await service.seek(target < Duration.zero ? Duration.zero : target);
    if (mounted) {
      _showFeedbackGlow(context, '<< REWIND -10S', skin.textColor);
    }
  }

  void _fastForward(PlaybackService service, PlayerSkin skin) async {
    final player = service.handler.playerInstance;
    final currentPos = player.position;
    final duration = player.duration ?? Duration.zero;
    final target = currentPos + const Duration(seconds: 10);
    await service.seek(target > duration ? duration : target);
    if (mounted) {
      _showFeedbackGlow(context, 'FAST FORWARD +10S >>', skin.textColor);
    }
  }

  void _toggleRepeat(PlaybackService service, Color glowColor) async {
    final player = service.handler.playerInstance;
    final ja.LoopMode targetMode;
    final String modeLabel;

    if (player.loopMode == ja.LoopMode.off) {
      targetMode = ja.LoopMode.one;
      modeLabel = 'REPEAT: ONE';
    } else if (player.loopMode == ja.LoopMode.one) {
      targetMode = ja.LoopMode.all;
      modeLabel = 'REPEAT: ALL';
    } else {
      targetMode = ja.LoopMode.off;
      modeLabel = 'REPEAT: OFF';
    }

    await player.setLoopMode(targetMode);
    if (mounted) {
      _showFeedbackGlow(context, modeLabel, glowColor);
    }
  }

  void _toggleShuffle(PlaybackService service, Color glowColor) async {
    final player = service.handler.playerInstance;
    final targetShuffle = !player.shuffleModeEnabled;
    await player.setShuffleModeEnabled(targetShuffle);

    if (mounted) {
      _showFeedbackGlow(
        context,
        targetShuffle ? 'SHUFFLE: ON' : 'SHUFFLE: OFF',
        glowColor,
      );
    }
  }

  void _applyEqPreset(PlaybackService service, String name, Color color) async {
    // Always apply presets to the 8-band UI model.
    final target = _computePresetForEightBands(name);

    setState(() {
      _activePreset = name;
      for (int i = 0; i < _eqBands.length && i < target.length; i++) {
        _eqBands[i] = target[i];
      }
    });

    // Persist immediately so relaunch restores the same sound.
    ref.read(storageServiceProvider).setEqualizerPreset(name);
    ref.read(storageServiceProvider).setEqualizerBands(List.from(_eqBands));

    _applyEqualizerWithKnobs(service);
    _showFeedbackGlow(context, 'EQ PRESET: ${name.toUpperCase()}', color);
  }

  /// Applies EQ bands to native engine, adding Bass knob boost on top of preset values.
  void _applyEqualizerWithKnobs(PlaybackService service) {
    // Compute bass boost from knob: 0.5 = neutral (0dB), 1.0 = +12dB boost, 0.0 = -12dB cut
    final double bassBoostDb = (_bassValue - 0.5) * 24.0; // ±12dB range
    final uiBands = List<double>.from(_eqBands);
    // Apply bass knob into the low-end UI bands (60Hz and 150Hz).
    uiBands[0] = (uiBands[0] + bassBoostDb * 1.0).clamp(_eqMinDb, _eqMaxDb);
    uiBands[1] = (uiBands[1] + bassBoostDb * 0.8).clamp(_eqMinDb, _eqMaxDb);

    // Persist UI state.
    ref.read(storageServiceProvider).setEqualizerBands(List.from(_eqBands));

    // Map UI -> device and apply.
    final deviceBands = _mapUiToDeviceBands(uiBands);
    service.setEqualizerBands(deviceBands);
  }

  Future<void> _applyEqualizerNow(PlaybackService service) async {
    final uiBands = List<double>.from(_eqBands);
    final deviceBands = _mapUiToDeviceBands(uiBands);
    await service.setEqualizerBands(deviceBands);
  }

  List<double> _mapUiToDeviceBands(List<double> uiBands) {
    // If we don't have device band centers, just pass UI bands through.
    // (Non-Android platforms will ignore anyway.)
    if (_deviceEqCentersHz.isEmpty) return uiBands;

    return _deviceEqCentersHz
        .map((hz) => _interpDb(x: hz, xs: _eqUiCentersHz, ys: uiBands))
        .map((v) => v.clamp(_eqMinDb, _eqMaxDb))
        .toList(growable: false);
  }

  double _interpDb({
    required double x,
    required List<double> xs,
    required List<double> ys,
  }) {
    if (xs.isEmpty || ys.isEmpty) return 0.0;
    if (xs.length != ys.length) return 0.0;
    if (x <= xs.first) return ys.first.toDouble();
    if (x >= xs.last) return ys.last.toDouble();

    // Interpolate in log-frequency space.
    final lx = math.log(x);
    for (int i = 0; i < xs.length - 1; i++) {
      final x0 = xs[i];
      final x1 = xs[i + 1];
      if (x >= x0 && x <= x1) {
        final t = (lx - math.log(x0)) / (math.log(x1) - math.log(x0));
        final y0 = ys[i];
        final y1 = ys[i + 1];
        return y0 + (y1 - y0) * t;
      }
    }
    return ys.last.toDouble();
  }

  String _formatHzLabel(double hz) {
    if (hz >= 1000) {
      final khz = hz / 1000.0;
      final s = khz >= 10 ? khz.toStringAsFixed(0) : khz.toStringAsFixed(1);
      return '${s}kHz';
    }
    return '${hz.round()}Hz';
  }

  List<double> _computePresetForAndroid(
      String name, ja.AndroidEqualizerParameters params) {
    // Build an 8-band UI preset first, then map it onto the device EQ layout.
    final ui = _computePresetForEightBands(name);
    final mapped = _deviceEqCentersHz.isNotEmpty
        ? _mapUiToDeviceBands(ui)
        : params.bands
            .map((b) => _interpDb(
                x: b.centerFrequency / 1000.0, xs: _eqUiCentersHz, ys: ui))
            .toList(growable: false);
    return mapped
        .map((v) => v.clamp(_eqMinDb, _eqMaxDb))
        .toList(growable: false);
  }

  List<double> _computePresetForEightBands(String name) {
    // Recognizable curves across 8 bands.
    // Order: 60Hz, 150Hz, 400Hz, 1kHz, 2.4kHz, 6kHz, 15kHz, 20kHz
    switch (name) {
      case 'Rock':
        return [4.0, 3.0, 1.0, -1.0, 1.0, 3.0, 4.0, 4.0];
      case 'Pop':
        return [2.0, 1.5, 1.0, -1.0, 0.5, 1.0, 1.0, 1.0];
      case 'Jazz':
        return [3.0, 2.0, 1.0, -1.5, 1.0, 2.0, 3.0, 3.0];
      case 'Bass & Treble':
        return [7.0, 5.0, 3.0, 0.0, 3.0, 5.0, 7.0, 7.0];
      case 'Mids':
        return [-2.0, -1.0, 3.0, 6.0, 5.0, 2.0, -1.0, -2.0];
      case 'Classic':
        return [4.5, 3.5, 2.0, 0.0, 1.5, 2.5, 4.0, 4.0];
      case 'Live':
        return [1.5, 2.0, 2.5, 3.0, 3.0, 2.5, 2.0, 2.0];
      case 'Dance':
        return [5.5, 6.5, 5.5, 3.5, 1.5, 0.0, 4.0, 5.0];
      case 'Soft':
        return [2.5, 2.0, 1.0, 0.0, 1.0, 1.5, 2.5, 3.0];
      case 'Beats Audio':
        return [5.5, 4.5, 2.5, -2.0, 1.5, 3.0, 4.5, 4.5];
      case 'Harman Kardon':
        return [3.0, 2.0, 1.0, -1.0, 1.0, 2.0, 3.5, 3.5];
      case 'Sony ClearBass':
        return [4.5, 3.5, 1.5, 0.0, 1.0, 1.5, 2.5, 2.5];
      case 'Bose Signature':
        return [3.5, 3.0, 2.0, 1.0, 1.5, 2.0, 2.0, 2.0];
      case 'Sennheiser Club':
        return [2.0, 1.5, 0.5, 0.0, 0.5, 1.0, 2.5, 3.0];
      case 'No Bass':
        return [-12.0, -12.0, -12.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      case 'No Mids':
        return [2.0, 2.0, -12.0, -12.0, -12.0, 0.0, 2.0, 2.0];
      case 'No Treble':
        return [2.0, 2.0, 2.0, 0.0, -12.0, -12.0, -12.0, -12.0];
      case 'Flat':
      case 'Custom':
      default:
        return List.filled(8, 0.0);
    }
  }

  void _showFeedbackGlow(
      BuildContext context, String message, Color glowColor) {
    _statusTimer?.cancel();
    setState(() {
      _statusMessage = message.toUpperCase();
    });
    _statusTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _statusMessage = null;
        });
      }
    });
  }

  Widget _buildAlbumArtWidget(MediaItem? mediaItem, PlayerSkin activeSkin) {
    final artUri = mediaItem?.artUri;

    return Center(
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: activeSkin.textColor.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: artUri != null
              ? Image.network(
                  artUri.toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildDefaultAlbumArt(activeSkin),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(activeSkin.textColor),
                      ),
                    );
                  },
                )
              : _buildDefaultAlbumArt(activeSkin),
        ),
      ),
    );
  }

  Widget _buildDefaultAlbumArt(PlayerSkin activeSkin) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note_rounded,
            size: 48,
            color: activeSkin.textColor.withOpacity(0.8),
          ),
          const SizedBox(height: 8),
          Text(
            'NO ALBUM ART',
            style: TextStyle(
              color: activeSkin.textColor.withOpacity(0.6),
              fontFamily: 'Orbitron',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          )
        ],
      ),
    );
  }

  BoxDecoration _buildBackgroundDecoration(PlayerSkin skin) {
    if (skin.isFlat) {
      if (skin.name.contains('Cyberpunk')) {
        return const BoxDecoration(
          color: Color(0xFF090A0F),
        );
      } else if (skin.name.contains('Mint')) {
        return const BoxDecoration(
          color: Color(0xFF0A120D),
        );
      } else if (skin.name.contains('Peach')) {
        return const BoxDecoration(
          color: Color(0xFF120C0A),
        );
      } else if (skin.name.contains('Amethyst')) {
        return const BoxDecoration(
          color: Color(0xFF0F0A18),
        );
      } else if (skin.name.contains('Amber')) {
        return const BoxDecoration(
          color: Color(0xFF140C05),
        );
      } else if (skin.name.contains('Polar')) {
        return const BoxDecoration(
          color: Color(0xFF040C14),
        );
      } else {
        // Flat Dark Monochrome
        return const BoxDecoration(
          color: Color(0xFF09090B),
        );
      }
    }

    return BoxDecoration(
      image: DecorationImage(
        image: AssetImage(skin.bgAssetPath),
        fit: BoxFit.cover,
        colorFilter: ColorFilter.mode(
          Colors.black.withOpacity(0.42),
          BlendMode.srcOver,
        ),
      ),
    );
  }

  Widget _buildTactileControl({
    required IconData icon,
    required bool isActive,
    required String label,
    required PlayerSkin skin,
    required VoidCallback onTap,
  }) {
    final activeColor = skin.textColor;
    final inactiveColor = skin.textColor.withOpacity(0.25);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? activeColor : activeColor.withOpacity(0.15),
                width: isActive ? 1.5 : 1.0,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: activeColor.withOpacity(0.3),
                        blurRadius: 6,
                        spreadRadius: 0.5,
                      )
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              color: isActive ? activeColor : inactiveColor,
              size: 16,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : inactiveColor,
              fontFamily: 'Orbitron',
              fontSize: 7.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeuomorphicVolumeBar(
      double volume, PlaybackService service, PlayerSkin skin) {
    final activeColor = skin.textColor;
    final numSegments = 10;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        const double barWidth = 80.0;
        final double x = details.localPosition.dx.clamp(0.0, barWidth);
        final double volumePercent = x / barWidth;
        service.setSystemVolume(volumePercent);
      },
      onHorizontalDragUpdate: (details) {
        const double barWidth = 80.0;
        final double x = details.localPosition.dx.clamp(0.0, barWidth);
        final double volumePercent = x / barWidth;
        service.setSystemVolume(volumePercent);
      },
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(numSegments, (i) {
                final segmentThreshold = (i + 1) / numSegments;
                final isActive = volume >= (segmentThreshold - 0.05);
                final segmentHeight = 4.0 + (i * 2.0);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      height: segmentHeight,
                      decoration: BoxDecoration(
                        color:
                            isActive ? activeColor : activeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(1),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: activeColor.withOpacity(0.4),
                                  blurRadius: 3,
                                  spreadRadius: 0.1,
                                )
                              ]
                            : [],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 2),
            Text(
              'VOL',
              style: TextStyle(
                color: activeColor.withOpacity(0.7),
                fontFamily: 'Orbitron',
                fontSize: 7,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Visualizer viewport layout - shared between portrait top section and landscape left section
  Widget _buildVisualizerSection({
    required BuildContext context,
    required PlayerSkin activeSkin,
    required PlaybackService playbackService,
    required PlayerSettings settings,
    required MockAudioPlayer player,
    required bool isLandscape,
  }) {
    final double visOpacity = activeSkin.isFlat
        ? 1.0
        : (settings.visualizerTransparencyEnabled
            ? settings.visualizerOpacity
            : 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: SizedBox(
        height: isLandscape ? double.infinity : (activeSkin.isFlat ? 280 : 240),
        width: double.infinity,
        child: GestureDetector(
          onTap: () {
            // When album art is enabled, we still allow shader visualizers to
            // cycle variations (since shaders can render behind the art).
            if (!settings.showAlbumArt || _isShaderStyle(_visualizerStyle)) {
              setState(() {
                final int maxVars = _getMaxVariations(_visualizerStyle);
                _visualizerVariation = (_visualizerVariation + 1) % maxVars;
              });
              // Persist the new variation value
              ref.read(storageServiceProvider).setVisualizerVariation(_visualizerVariation);
              _showFeedbackGlow(
                context,
                'VIS VARIATION: ${_visualizerVariation + 1}',
                activeSkin.textColor,
              );
            }
          },
          child: StreamBuilder<MediaItem?>(
            stream: playbackService.currentMediaItemStream,
            builder: (context, mediaSnapshot) {
              final mediaItem = mediaSnapshot.data;
              return StreamBuilder<PlaybackState>(
                stream: playbackService.playbackStateStream,
                builder: (context, stateSnapshot) {
                  final state = stateSnapshot.data;
                  _isPlaying = state?.playing ?? false;
                  _hasTrack = mediaItem != null;

                  return Stack(
                    children: [
                      // LCD Glass Background
                      Positioned.fill(
                        child: Container(
                          color: activeSkin.lcdBgColor.withOpacity(visOpacity),
                        ),
                      ),

                      // Visualizer (always rendered for shader styles).
                      if (!settings.showAlbumArt ||
                          _isShaderStyle(_visualizerStyle))
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 46),
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: _VisualizerPainter(
                                style: _visualizerStyle,
                                variation: _visualizerVariation,
                                amplitudes: _visualizerHeights,
                                peaks: _peakHeights,
                                time: _animationTime,
                                stars: _stars,
                                barColor: activeSkin.visualizerColor,
                                peakColor: activeSkin.visualizerPeakColor,
                                hasTrack: _hasTrack,
                                appsRingProgram: _appsRingProgram,
                                steamBarsProgram: _steamBarsProgram,
                                cosmicTunnelProgram: _cosmicTunnelProgram,
                                liquidFluidProgram: _liquidFluidProgram,
                                solarFlaresProgram: _solarFlaresProgram,
                                beat: _latestBeatPulse,
                              ),
                            ),
                          ),
                        ),

                      // Album art overlay.
                      if (settings.showAlbumArt)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 46),
                            child: Opacity(
                              // Let shader visualizers show through.
                              opacity:
                                  _isShaderStyle(_visualizerStyle) ? 0.82 : 1.0,
                              child: Container(
                                padding: isLandscape
                                    ? EdgeInsets.zero
                                    : const EdgeInsets.all(8),
                                alignment: Alignment.center,
                                child:
                                    _buildAlbumArtWidget(mediaItem, activeSkin),
                              ),
                            ),
                          ),
                        ),

                      // Bottom Controls Overlay: Bitrate/Sample badges, Equalizer preset & Volume level bar
                      Positioned(
                        bottom: isLandscape ? 4 : 2,
                        left: 8,
                        right: 8,
                        child: _buildVisualizerControls(
                            playbackService, activeSkin, player),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// Dialer panel selector layout - shared between portrait overlay and landscape right column
  Widget _buildConfiguredDialer({
    required BuildContext context,
    required PlayerSkin activeSkin,
    required PlaybackService playbackService,
    required MockAudioPlayer player,
    required PlayerSettings settings,
    required bool isShuffle,
    required ja.LoopMode loopMode,
  }) {
    if (activeSkin.isFlat) {
      return StreamBuilder<MediaItem?>(
        stream: playbackService.currentMediaItemStream,
        builder: (context, trackSnap) {
          final hasTrack = trackSnap.data != null;
          return _buildFlatPlayControlPanel(
            activeSkin: activeSkin,
            player: player,
            playbackService: playbackService,
            isShuffle: isShuffle,
            loopMode: loopMode,
            bgOpacity: 1.0,
            hasTrack: hasTrack,
          );
        },
      );
    } else {
      final bgOpacity =
          settings.dialerTransparencyEnabled ? settings.dialerOpacity : 1.0;
      return _S60DpadCockpitConsole(
        skin: activeSkin,
        isPlaying: _isPlaying,
        dialStyle: _dialStyle,
        animationTime: _animationTime,
        isShuffle: isShuffle,
        loopMode: loopMode,
        bgOpacity: bgOpacity,
        onPlayPause: () {
          if (_isPlaying) {
            playbackService.pause();
          } else {
            playbackService.play();
          }
        },
        onVolumeUp: () => _volumeUp(playbackService, activeSkin),
        onVolumeDown: () => _volumeDown(playbackService, activeSkin),
        onSkipPrevious: () => playbackService.skipToPrevious(),
        onSkipNext: () => playbackService.skipToNext(),
        onFastRewind: () => _fastRewind(playbackService, activeSkin),
        onFastForward: () => _fastForward(playbackService, activeSkin),
        onToggleShuffle: () =>
            _toggleShuffle(playbackService, activeSkin.textColor),
        onToggleRepeat: () =>
            _toggleRepeat(playbackService, activeSkin.textColor),
        onCycleDialStyle: () => _showDialerSwitcherSheet(context),
        onCycleSkin: () => _showSkinSwitcherSheet(context),
      );
    }
  }

  /// Landscape mode: 2-column cockpit layout
  /// Left: Visualizer | Right: Track controls + inline dialer
  Widget _buildLandscapeCockpit(
    BuildContext context,
    PlayerSkin activeSkin,
    PlaybackService playbackService,
    PlayerSettings settings,
    MockAudioPlayer player,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ══ Left column: Visualizer (flex 11) ══
        Expanded(
          flex: 11,
          child: _buildVisualizerSection(
            context: context,
            activeSkin: activeSkin,
            playbackService: playbackService,
            settings: settings,
            player: player,
            isLandscape: true,
          ),
        ),

        // ══ Right column: Controls (flex 10) ══
        Expanded(
          flex: 10,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 4,
              right: 8,
              top: 4,
              bottom:
                  16, // All dialers sit exactly 16px above bottom screen edge
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(
                    height:
                        50), // Move trackname & progressbar down by at least 50px

                // Track name
                StreamBuilder<MediaItem?>(
                  stream: playbackService.currentMediaItemStream,
                  builder: (context, mediaSnap) {
                    final mediaItem = mediaSnap.data;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: activeSkin.isFlat
                            ? Colors.black.withOpacity(0.3)
                            : activeSkin.lcdBgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: activeSkin.isFlat
                                ? activeSkin.textColor.withOpacity(0.15)
                                : activeSkin.lcdBorderColor,
                            width: 1.0),
                      ),
                      child: _ScrollingMarqueeText(
                        title: mediaItem?.title ?? 'No Track Loaded',
                        artist: mediaItem?.artist ?? 'UltraMP3 Reborn',
                        textColor: activeSkin.textColor,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 6), // Spacer

                // Progress bar
                StreamBuilder<PositionState>(
                  stream: playbackService.positionStateStream,
                  builder: (context, posSnapshot) {
                    final posData = posSnapshot.data;
                    final position = posData?.position ?? Duration.zero;
                    final duration = posData?.duration ?? Duration.zero;
                    final double progress = duration.inMilliseconds > 0
                        ? (position.inMilliseconds / duration.inMilliseconds)
                            .clamp(0.0, 1.0)
                        : 0.0;
                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 2.5,
                            activeTrackColor: activeSkin.textColor,
                            inactiveTrackColor:
                                activeSkin.textColor.withOpacity(0.15),
                            thumbColor: activeSkin.textColor,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 4.0),
                            overlayShape:
                                const RoundSliderOverlayShape(overlayRadius: 8),
                          ),
                          child: Slider(
                            // Use _dragValue while scrubbing so the thumb tracks
                            // the finger exactly; fall back to stream progress.
                            value: (_dragValue ?? progress).clamp(0.0, 1.0),
                            onChanged: (val) {
                              setState(() => _dragValue = val);
                            },
                            onChangeEnd: (val) {
                              final ms =
                                  (val * duration.inMilliseconds).toInt();
                              playbackService.seek(Duration(milliseconds: ms));
                              setState(() => _dragValue = null);
                            },
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(position),
                                style: TextStyle(
                                    color: activeSkin.textColor,
                                    fontFamily: 'Orbitron',
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                            Text(_formatDuration(duration),
                                style: TextStyle(
                                    color:
                                        activeSkin.textColor.withOpacity(0.6),
                                    fontFamily: 'Orbitron',
                                    fontSize: 9)),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const Spacer(),

                // Configured dialer console
                StreamBuilder<ja.LoopMode>(
                  stream: player.loopModeStream,
                  initialData: player.loopMode,
                  builder: (context, loopSnap) {
                    final loopMode = loopSnap.data ?? ja.LoopMode.off;
                    return StreamBuilder<bool>(
                      stream: player.shuffleModeEnabledStream,
                      initialData: player.shuffleModeEnabled,
                      builder: (context, shuffleSnap) {
                        final isShuffle = shuffleSnap.data ?? false;
                        final double designWidth =
                            360.0; // Uniform 360px design width so all match perfectly
                        final double designHeight = activeSkin.isFlat
                            ? 145.0
                            : (_dialStyle == DialStyle.rectangular
                                ? 180.0
                                : (_dialStyle == DialStyle.circular
                                    ? 220.0
                                    : 180.0));

                        return Center(
                          child: SizedBox(
                            height: designHeight,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: designWidth,
                                height: designHeight,
                                child: _buildConfiguredDialer(
                                  context: context,
                                  activeSkin: activeSkin,
                                  playbackService: playbackService,
                                  player: player,
                                  settings: settings,
                                  isShuffle: isShuffle,
                                  loopMode: loopMode,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlatPlayControlPanel({
    required PlayerSkin activeSkin,
    required MockAudioPlayer player,
    required PlaybackService playbackService,
    required bool isShuffle,
    required ja.LoopMode loopMode,
    required double bgOpacity,
    required bool hasTrack,
  }) {
    final accentColor = activeSkin.textColor;
    final disabledColor = accentColor.withOpacity(0.25);

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Padding(
      padding: isLandscape
          ? const EdgeInsets.symmetric(horizontal: 5, vertical: 0)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: isLandscape
                ? const EdgeInsets.symmetric(horizontal: 5, vertical: 4)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: activeSkin.panelBgColor.withOpacity(0.65),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: activeSkin.textColor.withOpacity(0.22), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: activeSkin.textColor.withOpacity(0.12),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Media Control Layout (Shuffle, Skip Prev, Neon Centerpiece Play, Skip Next, Repeat)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Shuffle
                    IconButton(
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: isShuffle
                            ? accentColor
                            : accentColor.withOpacity(0.35),
                        size: 24,
                      ),
                      onPressed: hasTrack
                          ? () => _toggleShuffle(playbackService, accentColor)
                          : null,
                      tooltip: 'Shuffle',
                      padding: EdgeInsets.zero,
                    ),
                    // Skip Prev
                    IconButton(
                      icon: Icon(Icons.skip_previous_rounded,
                          color: hasTrack ? accentColor : disabledColor,
                          size: 32),
                      onPressed: hasTrack
                          ? () => playbackService.skipToPrevious()
                          : null,
                      tooltip: 'Previous',
                      padding: EdgeInsets.zero,
                    ),
                    // Central floating neon play button
                    GestureDetector(
                      onTap: hasTrack
                          ? () {
                              if (_isPlaying) {
                                playbackService.pause();
                              } else {
                                playbackService.play();
                              }
                            }
                          : null,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              accentColor,
                              accentColor.withOpacity(0.85),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                              offset: const Offset(0, 0),
                            )
                          ],
                        ),
                        child: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: accentColor.computeLuminance() > 0.5
                              ? Colors.black87
                              : Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                    // Skip Next
                    IconButton(
                      icon: Icon(Icons.skip_next_rounded,
                          color: hasTrack ? accentColor : disabledColor,
                          size: 32),
                      onPressed:
                          hasTrack ? () => playbackService.skipToNext() : null,
                      tooltip: 'Next',
                      padding: EdgeInsets.zero,
                    ),
                    // Repeat
                    IconButton(
                      icon: Icon(
                        loopMode == ja.LoopMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: loopMode != ja.LoopMode.off
                            ? accentColor
                            : accentColor.withOpacity(0.35),
                        size: 24,
                      ),
                      onPressed: hasTrack
                          ? () => _toggleRepeat(playbackService, accentColor)
                          : null,
                      tooltip: 'Repeat',
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Divider(color: Colors.transparent, height: 4),
                ),

                // Bottom Row: Helper controls (Volume down, Fast Rewind, Fast Forward, Volume up)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Volume Down
                    IconButton(
                      icon: Icon(Icons.volume_down_rounded,
                          color: accentColor.withOpacity(0.65), size: 20),
                      onPressed: () => _volumeDown(playbackService, activeSkin),
                      tooltip: 'Volume Down',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    // Fast Rewind
                    IconButton(
                      icon: Icon(Icons.fast_rewind_rounded,
                          color: hasTrack
                              ? accentColor.withOpacity(0.8)
                              : disabledColor,
                          size: 22),
                      onPressed: hasTrack
                          ? () => _fastRewind(playbackService, activeSkin)
                          : null,
                      tooltip: 'Rewind',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    // Fast Forward
                    IconButton(
                      icon: Icon(Icons.fast_forward_rounded,
                          color: hasTrack
                              ? accentColor.withOpacity(0.8)
                              : disabledColor,
                          size: 22),
                      onPressed: hasTrack
                          ? () => _fastForward(playbackService, activeSkin)
                          : null,
                      tooltip: 'Fast Forward',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    // Volume Up
                    IconButton(
                      icon: Icon(Icons.volume_up_rounded,
                          color: accentColor.withOpacity(0.65), size: 20),
                      onPressed: () => _volumeUp(playbackService, activeSkin),
                      tooltip: 'Volume Up',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisualizerControls(
      PlaybackService service, PlayerSkin skin, MockAudioPlayer player) {
    return StreamBuilder<double>(
      stream: service.volumeStream,
      initialData: service.volume,
      builder: (context, volumeSnapshot) {
        final volume = volumeSnapshot.data ?? 1.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side: Bitrate/Sample badges + Selected Equalizer preset
              Expanded(
                child: StreamBuilder<MediaItem?>(
                  stream: service.currentMediaItemStream,
                  builder: (context, mediaSnap) {
                    final mediaItem = mediaSnap.data;
                    final sourceId = mediaItem?.id;
  
                    Future<_AudioTechInfo?>? techFuture;
                    if (sourceId != null && !sourceId.startsWith('http')) {
                      techFuture = _getTechInfo(sourceId);
                    }
  
                    return FutureBuilder<_AudioTechInfo?>(
                      future: techFuture,
                      builder: (context, techSnap) {
                        final info = techSnap.data;
                        final bitrateText = info?.bitrateKbps != null
                            ? '${info!.bitrateKbps}KBPS'
                            : '--KBPS';
                        final sampleText = info?.sampleRateHz != null
                            ? '${(info!.sampleRateHz! / 1000).toStringAsFixed(1)}KHZ'
                            : '--KHZ';
  
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _BacklitLCDBadge(
                                text: bitrateText, color: skin.textColor),
                            const SizedBox(width: 6),
                            _BacklitLCDBadge(
                                text: sampleText, color: skin.textColor),
                            const SizedBox(width: 6),
                            Flexible(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showEqualizer = !_showEqualizer;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0, vertical: 4.0),
                                  decoration: BoxDecoration(
                                    color: skin.textColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: skin.textColor.withOpacity(0.35),
                                        width: 1.0),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.equalizer_rounded,
                                          color: skin.textColor, size: 12),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          _activePreset.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: skin.textColor,
                                            fontFamily: 'monospace',
                                            fontSize: 10.0,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              // Right side: Persistent gradual heights Volume Bar
              _buildSkeuomorphicVolumeBar(volume, service, skin),
            ],
          ),
        );
      },
    );
  }

  void _showSkinSwitcherSheet(BuildContext context) {
    final activeSkin = ref.read(playerSkinProvider);
    final displayedSkins =
        PlayerSkin.all.where((s) => s.isFlat == activeSkin.isFlat).toList();
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: BorderRadius.zero,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: MediaQuery.of(context).size.height,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: activeSkin.panelBgColor.withOpacity(0.85),
                borderRadius: BorderRadius.zero,
                border: Border(
                  top: BorderSide(
                      color: activeSkin.textColor.withOpacity(0.25),
                      width: 1.5),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 48),
                        Expanded(
                          child: Text(
                            'COCKPIT SKINS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: activeSkin.textColor,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: activeSkin.textColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: displayedSkins.length,
                      itemBuilder: (context, idx) {
                        final skin = displayedSkins[idx];
                        final isSelected = skin.name == activeSkin.name;

                        return GestureDetector(
                          onTap: () {
                            ref
                                .read(playerSkinProvider.notifier)
                                .setSkinByName(skin.name);
                            Navigator.pop(context);
                            _showFeedbackGlow(
                                context,
                                'SKIN: ${skin.name.toUpperCase()}',
                                skin.textColor);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? skin.textColor.withOpacity(0.15)
                                  : Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? skin.textColor
                                    : skin.textColor.withOpacity(0.2),
                                width: isSelected ? 2.0 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: skin.textColor.withOpacity(0.25),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : [],
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: skin.textColor,
                                      ),
                                    ),
                                    Container(
                                      width: 18,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        color: skin.lcdBgColor,
                                        border: Border.all(
                                            color: skin.lcdBorderColor,
                                            width: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      skin.name,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isSelected
                                            ? skin.textColor
                                            : Colors.white.withOpacity(0.85),
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 10.5,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: Colors.black.withOpacity(0.4),
                                  ),
                                  child: Text(
                                    skin.isFlat ? 'FLAT' : 'S60',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.bold,
                                      color: skin.textColor.withOpacity(0.7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showVisualizerSwitcherSheet(BuildContext context) {
    final activeSkin = ref.read(playerSkinProvider);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: BorderRadius.zero,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: MediaQuery.of(context).size.height,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: activeSkin.panelBgColor.withOpacity(0.85),
                borderRadius: BorderRadius.zero,
                border: Border(
                  top: BorderSide(
                      color: activeSkin.textColor.withOpacity(0.25),
                      width: 1.5),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 48),
                        Expanded(
                          child: Text(
                            'VISUALIZATION ENGINES',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: activeSkin.textColor,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: activeSkin.textColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: VisualizerStyle.values.length,
                      itemBuilder: (context, idx) {
                        final style = VisualizerStyle.values[idx];
                        final isSelected = style == _visualizerStyle;

                        IconData styleIcon = Icons.analytics_rounded;
                        if (style == VisualizerStyle.spectrumBars)
                          styleIcon = Icons.bar_chart_rounded;
                        if (style == VisualizerStyle.waveform)
                          styleIcon = Icons.insights_rounded;
                        if (style == VisualizerStyle.circularSpectrum)
                          styleIcon = Icons.track_changes_rounded;
                        if (style == VisualizerStyle.particleReactive)
                          styleIcon = Icons.grain_rounded;
                        if (style == VisualizerStyle.liquidFluid)
                          styleIcon = Icons.opacity_rounded;
                        if (style == VisualizerStyle.breathingRings)
                          styleIcon = Icons.blur_circular_rounded;
                        if (style == VisualizerStyle.retroWinamp)
                          styleIcon = Icons.grid_view_rounded;
                        if (style == VisualizerStyle.albumArtReactive)
                          styleIcon = Icons.album_rounded;
                        if (style == VisualizerStyle.combinedUltra)
                          styleIcon = Icons.auto_awesome_rounded;
                        if (style == VisualizerStyle.solarFlares)
                          styleIcon = Icons.flare_rounded;
                        if (style == VisualizerStyle.vortexOrbit)
                          styleIcon = Icons.all_out_rounded;
                        if (style == VisualizerStyle.rippleWaves)
                          styleIcon = Icons.waves_rounded;
                        if (style == VisualizerStyle.particleWaveFlow)
                          styleIcon = Icons.bubble_chart_rounded;
                        if (style == VisualizerStyle.cosmicTunnel)
                          styleIcon = Icons.center_focus_strong_rounded;
                        if (style == VisualizerStyle.orbitalGlow)
                          styleIcon = Icons.star_purple500_rounded;
                        if (style == VisualizerStyle.frequencyLaser)
                          styleIcon = Icons.flash_on_rounded;
                        if (style == VisualizerStyle.dnaHelix)
                          styleIcon = Icons.sync_rounded;
                        if (style == VisualizerStyle.audioMatrixGrid)
                          styleIcon = Icons.apps_rounded;
                        if (style == VisualizerStyle.blackHoleStars)
                          styleIcon = Icons.blur_on_rounded;
                        if (style == VisualizerStyle.shaderAppsRing)
                          styleIcon = Icons.auto_awesome_motion_rounded;
                        if (style == VisualizerStyle.shaderSteamBars)
                          styleIcon = Icons.equalizer_rounded;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _visualizerStyle = style;
                              _visualizerVariation = 0;
                            });
                            // Persist the visualizer style selection
                            ref.read(storageServiceProvider).setVisualizerStyle(style.name);
                            // Persist the variation reset to 0
                            ref.read(storageServiceProvider).setVisualizerVariation(0);
                            Navigator.pop(context);
                            _showFeedbackGlow(
                                context,
                                'VISUALIZER: ${style.name.toUpperCase()}',
                                activeSkin.textColor);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? activeSkin.textColor.withOpacity(0.15)
                                  : Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? activeSkin.textColor
                                    : activeSkin.textColor.withOpacity(0.2),
                                width: isSelected ? 2.0 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: activeSkin.textColor
                                            .withOpacity(0.25),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : [],
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  styleIcon,
                                  color: isSelected
                                      ? activeSkin.textColor
                                      : Colors.white.withOpacity(0.7),
                                  size: 24,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  style.name
                                      .replaceAllMapped(
                                          RegExp(r'(^|[a-z])([A-Z])'),
                                          (m) => '${m.group(1)} ${m.group(2)}')
                                      .toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: isSelected
                                        ? activeSkin.textColor
                                        : Colors.white.withOpacity(0.85),
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 8,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDialerSwitcherSheet(BuildContext context) {
    final activeSkin = ref.read(playerSkinProvider);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: isLandscape
              ? BorderRadius.zero
              : const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: isLandscape
                  ? MediaQuery.of(context).size.height
                  : MediaQuery.of(context).size.height * 0.45,
              padding: EdgeInsets.only(
                top: isLandscape ? (MediaQuery.of(context).padding.top + 8) : 0,
                bottom: isLandscape
                    ? 12
                    : (kBottomNavigationBarHeight +
                        MediaQuery.of(context).padding.bottom),
              ),
              decoration: BoxDecoration(
                color: activeSkin.panelBgColor.withOpacity(0.85),
                borderRadius: isLandscape
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(top: Radius.circular(24)),
                border: isLandscape
                    ? null
                    : Border.all(
                        color: activeSkin.textColor.withOpacity(0.25),
                        width: 1.5),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: activeSkin.textColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: isLandscape
                          ? MainAxisAlignment.spaceBetween
                          : MainAxisAlignment.center,
                      children: [
                        if (isLandscape) const SizedBox(width: 48),
                        Text(
                          'TACTILE COCKPIT CONTROLLERS',
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: activeSkin.textColor,
                            letterSpacing: 1.5,
                          ),
                        ),
                        if (isLandscape)
                          IconButton(
                            icon: Icon(Icons.close_rounded,
                                color: activeSkin.textColor),
                            onPressed: () => Navigator.pop(context),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: DialStyle.values.length,
                      itemBuilder: (context, idx) {
                        final style = DialStyle.values[idx];
                        final isSelected = style == _dialStyle;

                        IconData dIcon = Icons.radio_button_checked_rounded;
                        String label = '';
                        if (style == DialStyle.circular) {
                          dIcon = Icons.motion_photos_on_rounded;
                          label = 'IPOD WHEEL';
                        }
                        if (style == DialStyle.rectangular) {
                          dIcon = Icons.crop_landscape_rounded;
                          label = 'RECT CONSOLE';
                        }
                        if (style == DialStyle.digitalToggles) {
                          dIcon = Icons.developer_board_rounded;
                          label = 'SYNTH RACK';
                        }

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _dialStyle = style;
                            });
                            ref
                                .read(storageServiceProvider)
                                .setDialStyle(style.name);
                            Navigator.pop(context);
                            _showFeedbackGlow(
                                context,
                                'DIAL: ${style.name.toUpperCase()}',
                                activeSkin.textColor);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? activeSkin.textColor.withOpacity(0.15)
                                  : Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? activeSkin.textColor
                                    : activeSkin.textColor.withOpacity(0.2),
                                width: isSelected ? 2.0 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: activeSkin.textColor
                                            .withOpacity(0.25),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : [],
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  dIcon,
                                  color: isSelected
                                      ? activeSkin.textColor
                                      : Colors.white.withOpacity(0.7),
                                  size: 32,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Orbitron',
                                    color: isSelected
                                        ? activeSkin.textColor
                                        : Colors.white.withOpacity(0.85),
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 8.5,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeSkin = ref.watch(playerSkinProvider);
    final topNavColor = activeSkin.name == 'S60 Classic Grey'
        ? const Color(0xFF2ECC71)
        : activeSkin.textColor;
    final playbackService = ref.watch(playbackServiceProvider);
    final player = playbackService.handler.playerInstance;
    final settings = ref.watch(playerSettingsProvider);

    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;
          if (isLandscape) {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          } else {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
                overlays: SystemUiOverlay.values);
          }

          return Stack(
            children: [
              // 1. Dynamic landscape backgrounds
              Positioned.fill(
                child: Container(
                  decoration: _buildBackgroundDecoration(activeSkin),
                ),
              ),

              Column(
                children: [
                  // 2. Tucked Top Bar (full-width flat container at the very top edge with dynamic notch padding, compact in landscape)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(
                      top: isLandscape
                          ? 4
                          : (MediaQuery.of(context).padding.top + 4),
                      left: 16,
                      right: 16,
                      bottom: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.9),
                      border: Border(
                        bottom: BorderSide(
                          color: topNavColor.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ULTRAMP3',
                              style: TextStyle(
                                color: topNavColor,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.5,
                                shadows: [
                                  Shadow(
                                      color: topNavColor.withOpacity(0.6),
                                      blurRadius: 8),
                                ],
                              ),
                            ),
                            if (isLandscape) ...[
                              const SizedBox(width: 24),
                              IconButton(
                                tooltip: 'Home',
                                icon: Icon(Icons.home_rounded,
                                    color: topNavColor, size: 20),
                                onPressed: () => context.go('/home'),
                              ),
                              IconButton(
                                tooltip: 'Library',
                                icon: Icon(Icons.music_note_rounded,
                                    color: topNavColor.withOpacity(0.9),
                                    size: 20),
                                onPressed: () => context.go('/library'),
                              ),
                              IconButton(
                                tooltip: 'Folders',
                                icon: Icon(Icons.folder_rounded,
                                    color: topNavColor.withOpacity(0.9),
                                    size: 20),
                                onPressed: () => context.go('/folders'),
                              ),
                              IconButton(
                                tooltip: 'Playlists',
                                icon: Icon(Icons.queue_music_rounded,
                                    color: topNavColor.withOpacity(0.9),
                                    size: 20),
                                onPressed: () => context.go('/playlists'),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 1,
                                height: 16,
                                color: topNavColor.withOpacity(0.2),
                              ),
                            ],
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!activeSkin.isFlat)
                              IconButton(
                                tooltip: 'Dial Style',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 32, minHeight: 32),
                                icon: Icon(Icons.track_changes_rounded,
                                    color: topNavColor.withOpacity(0.9),
                                    size: 20),
                                onPressed: () =>
                                    _showDialerSwitcherSheet(context),
                              ),
                            IconButton(
                              tooltip: 'Skin',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              icon: Icon(Icons.palette_rounded,
                                  color: topNavColor.withOpacity(0.9),
                                  size: 20),
                              onPressed: () => _showSkinSwitcherSheet(context),
                            ),
                            IconButton(
                              tooltip: 'Visualizer Style',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              icon: Icon(Icons.waves_rounded,
                                  color: topNavColor.withOpacity(0.9),
                                  size: 20),
                              onPressed: () =>
                                  _showVisualizerSwitcherSheet(context),
                            ),
                            IconButton(
                              tooltip: 'Equalizer',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              icon: Icon(
                                _showEqualizer
                                    ? Icons.equalizer_rounded
                                    : Icons.equalizer_outlined,
                                color: _showEqualizer
                                    ? topNavColor
                                    : topNavColor.withOpacity(0.6),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showEqualizer = !_showEqualizer;
                                });
                              },
                            ),
                            if (!isLandscape)
                              IconButton(
                                tooltip: 'Library',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 32, minHeight: 32),
                                icon: Icon(Icons.library_music_rounded,
                                    color: topNavColor.withOpacity(0.9),
                                    size: 20),
                                onPressed: () {
                                  context.go('/library');
                                },
                              ),
                            IconButton(
                              tooltip: 'Settings',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              icon: Icon(Icons.settings_rounded,
                                  color: topNavColor.withOpacity(0.9),
                                  size: 20),
                              onPressed: () {
                                context.push('/player-settings');
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 3. Cockpit area - responsive to both portrait and landscape orientation
                  Expanded(
                    child: SafeArea(
                      top: false,
                      left: !isLandscape,
                      right: !isLandscape,
                      bottom: !isLandscape,
                      child: () {
                        if (isLandscape) {
                          // ━━━━━ LANDSCAPE: Two-column cockpit ━━━━━
                          return _buildLandscapeCockpit(context, activeSkin,
                              playbackService, settings, player);
                        }

                        // ━━━━━ PORTRAIT: Standard vertical layout ━━━━━
                        return SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildVisualizerSection(
                                context: context,
                                activeSkin: activeSkin,
                                playbackService: playbackService,
                                settings: settings,
                                player: player,
                                isLandscape: false,
                              ),
                              // The flat visualizer is taller; pulling this section up causes
                              // the transient status message to overlap the visualizer.
                              Transform.translate(
                                offset: Offset(0, activeSkin.isFlat ? 0 : -10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const SizedBox(height: 2),

                                      // Floating background-less update feedback ticker
                                      AnimatedOpacity(
                                        opacity:
                                            _statusMessage != null ? 1.0 : 0.0,
                                        duration:
                                            const Duration(milliseconds: 200),
                                        child: Container(
                                          height: 16, // Reduced from 20
                                          alignment: Alignment.center,
                                          child: Text(
                                            _statusMessage ?? '',
                                            style: TextStyle(
                                              color: activeSkin.textColor,
                                              fontFamily: 'Orbitron',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              letterSpacing: 1.5,
                                              shadows: [
                                                Shadow(
                                                  color: activeSkin.textColor
                                                      .withOpacity(0.8),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Extra breathing room so the transient status message
                                      // doesn't crowd the track marquee.
                                      const SizedBox(height: 10),
                                      // 4. Track name marquee + Quick Actions above progress bar
                                      StreamBuilder<MediaItem?>(
                                        stream: playbackService
                                            .currentMediaItemStream,
                                        builder: (context, mediaSnapshot) {
                                          final mediaItem = mediaSnapshot.data;
                                          final String trackTitle =
                                              mediaItem?.title ??
                                                  'No Track Loaded';
                                          final String trackArtist =
                                              mediaItem?.artist ??
                                                  'UltraMP3 Reborn';
                                          final bool hasTrack =
                                              mediaItem != null;

                                          return Consumer(
                                            builder: (context, ref, _) {
                                              final favorites =
                                                  ref.watch(favoritesProvider);
                                              final isFav = hasTrack &&
                                                  favorites
                                                      .contains(mediaItem.id);

                                              return Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6.0,
                                                        vertical: 2.0),
                                                padding: const EdgeInsets.only(
                                                    left: 12.0,
                                                    right: 4.0,
                                                    top: 2.0,
                                                    bottom: 2.0),
                                                decoration: BoxDecoration(
                                                  color: activeSkin.isFlat
                                                      ? Colors.black
                                                          .withOpacity(0.35)
                                                      : activeSkin
                                                          .lcdBgColor, // Solid opaque for S60 legibility
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: activeSkin.isFlat
                                                        ? activeSkin.textColor
                                                            .withOpacity(0.15)
                                                        : activeSkin
                                                            .lcdBorderColor,
                                                    width: activeSkin.isFlat
                                                        ? 0.8
                                                        : 1.2,
                                                  ),
                                                ),
                                                height: 36,
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child:
                                                          _ScrollingMarqueeText(
                                                        title: trackTitle,
                                                        artist: trackArtist,
                                                        textColor: activeSkin
                                                            .textColor,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: 42,
                                                      height: 42,
                                                      child: Material(
                                                        color:
                                                            Colors.transparent,
                                                        child: InkWell(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(21),
                                                          onTap: hasTrack
                                                              ? () => ref
                                                                  .read(favoritesProvider
                                                                      .notifier)
                                                                  .toggle(
                                                                      mediaItem!
                                                                          .id)
                                                              : null,
                                                          child: Center(
                                                            child: Icon(
                                                              isFav
                                                                  ? Icons
                                                                      .favorite_rounded
                                                                  : Icons
                                                                      .favorite_border_rounded,
                                                              color: isFav
                                                                  ? Colors
                                                                      .pinkAccent
                                                                  : activeSkin
                                                                      .textColor
                                                                      .withOpacity(
                                                                          0.55),
                                                              size: 18,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: 42,
                                                      height: 42,
                                                      child: Material(
                                                        color:
                                                            Colors.transparent,
                                                        child: InkWell(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(21),
                                                          onTap: hasTrack
                                                              ? () {
                                                                  Navigator
                                                                      .push(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                      builder:
                                                                          (_) =>
                                                                              AddToPlaylistScreen(
                                                                        songId:
                                                                            mediaItem!.id,
                                                                        songTitle:
                                                                            mediaItem.title,
                                                                      ),
                                                                    ),
                                                                  );
                                                                }
                                                              : null,
                                                          child: Center(
                                                            child: Icon(
                                                              Icons
                                                                  .playlist_add_rounded,
                                                              color: activeSkin
                                                                  .textColor
                                                                  .withOpacity(
                                                                      0.55),
                                                              size: 18,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),

                                      // 5. Progress / seek bar + time badges
                                      StreamBuilder<PositionState>(
                                        stream:
                                            playbackService.positionStateStream,
                                        builder: (context, posSnapshot) {
                                          final posData = posSnapshot.data;
                                          final position = posData?.position ??
                                              Duration.zero;
                                          final duration = posData?.duration ??
                                              Duration.zero;
                                          double currentProgress = 0.0;

                                          if (duration.inMilliseconds > 0) {
                                            currentProgress =
                                                position.inMilliseconds /
                                                    duration.inMilliseconds;
                                          }

                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SliderTheme(
                                                  data: SliderThemeData(
                                                    trackHeight: 3.0,
                                                    activeTrackColor:
                                                        activeSkin.textColor,
                                                    inactiveTrackColor:
                                                        activeSkin.textColor
                                                            .withOpacity(0.15),
                                                    thumbColor:
                                                        activeSkin.textColor,
                                                    thumbShape:
                                                        const RoundSliderThumbShape(
                                                            enabledThumbRadius:
                                                                5.0),
                                                    overlayShape:
                                                        const RoundSliderOverlayShape(
                                                            overlayRadius: 10),
                                                  ),
                                                  child: Slider(
                                                    value: (_dragValue ?? currentProgress)
                                                        .clamp(0.0, 1.0),
                                                    onChanged: (val) {
                                                      setState(() => _dragValue = val);
                                                    },
                                                    onChangeEnd: (val) {
                                                      final targetMs = (val *
                                                              duration
                                                                  .inMilliseconds)
                                                          .toInt();
                                                      playbackService.seek(
                                                          Duration(
                                                              milliseconds:
                                                                  targetMs));
                                                      setState(() => _dragValue = null);
                                                    },
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12.0),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: activeSkin
                                                                  .isFlat
                                                              ? Colors.black
                                                                  .withOpacity(
                                                                      0.28)
                                                              : activeSkin
                                                                  .lcdBgColor, // Solid for S60
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                          border: activeSkin
                                                                  .isFlat
                                                              ? null
                                                              : Border.all(
                                                                  color: activeSkin
                                                                      .lcdBorderColor,
                                                                  width: 0.8),
                                                        ),
                                                        child: Text(
                                                          _formatDuration(
                                                              position),
                                                          style: TextStyle(
                                                            color: activeSkin
                                                                .textColor,
                                                            fontFamily:
                                                                'Orbitron',
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: activeSkin
                                                                  .isFlat
                                                              ? Colors.black
                                                                  .withOpacity(
                                                                      0.28)
                                                              : activeSkin
                                                                  .lcdBgColor, // Solid for S60
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                          border: activeSkin
                                                                  .isFlat
                                                              ? null
                                                              : Border.all(
                                                                  color: activeSkin
                                                                      .lcdBorderColor,
                                                                  width: 0.8),
                                                        ),
                                                        child: Text(
                                                          _formatDuration(
                                                              duration),
                                                          style: TextStyle(
                                                            color: activeSkin
                                                                .textColor,
                                                            fontFamily:
                                                                'Orbitron',
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),

                                      // 6. Upcoming Queue Display
                                      StreamBuilder<List<MediaItem>>(
                                        stream: playbackService.handler.queue,
                                        builder: (context, queueSnap) {
                                          return StreamBuilder<int?>(
                                            stream: playbackService
                                                .handler
                                                .playerInstance
                                                .currentIndexStream,
                                            builder: (context, indexSnap) {
                                              final queue =
                                                  queueSnap.data ?? [];
                                              final currentIndex =
                                                  indexSnap.data ?? 0;

                                              if (activeSkin.isFlat) {
                                                final upcoming = <MapEntry<int,
                                                    MediaItem>>[];
                                                for (int i = currentIndex + 1;
                                                    i < queue.length &&
                                                        upcoming.length < 5;
                                                    i++) {
                                                  upcoming.add(
                                                      MapEntry(i, queue[i]));
                                                }
                                                if (upcoming.isEmpty)
                                                  return const SizedBox
                                                      .shrink();

                                                return Container(
                                                  margin: const EdgeInsets.only(
                                                      top: 6,
                                                      left: 6,
                                                      right: 6),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.28),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    border: Border.all(
                                                        color: activeSkin
                                                            .textColor
                                                            .withOpacity(0.1),
                                                        width: 0.8),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                bottom: 6),
                                                        child: Text(
                                                          'UP NEXT',
                                                          style: TextStyle(
                                                            color: activeSkin
                                                                .textColor
                                                                .withOpacity(
                                                                    0.5),
                                                            fontFamily:
                                                                'Orbitron',
                                                            fontSize: 9,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            letterSpacing: 1.2,
                                                          ),
                                                        ),
                                                      ),
                                                      ...upcoming.map((entry) {
                                                        final idx = entry.key;
                                                        final item =
                                                            entry.value;
                                                        return GestureDetector(
                                                          behavior:
                                                              HitTestBehavior
                                                                  .opaque,
                                                          onTap: () =>
                                                              playbackService
                                                                  .handler
                                                                  .playerInstance
                                                                  .seek(
                                                                      Duration
                                                                          .zero,
                                                                      index:
                                                                          idx),
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        4),
                                                            child: Row(
                                                              children: [
                                                                Container(
                                                                  width: 22,
                                                                  height: 22,
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    color: activeSkin
                                                                        .textColor
                                                                        .withOpacity(
                                                                            0.1),
                                                                  ),
                                                                  child: Text(
                                                                    '${idx + 1}',
                                                                    style:
                                                                        TextStyle(
                                                                      color: activeSkin
                                                                          .textColor
                                                                          .withOpacity(
                                                                              0.6),
                                                                      fontSize:
                                                                          9,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    width: 10),
                                                                Expanded(
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Text(
                                                                        item.title,
                                                                        style:
                                                                            TextStyle(
                                                                          color: activeSkin
                                                                              .textColor
                                                                              .withOpacity(0.9),
                                                                          fontSize:
                                                                              12,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                        maxLines:
                                                                            1,
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                      ),
                                                                      // Flat mode: keep the queue compact and single-line.
                                                                    ],
                                                                  ),
                                                                ),
                                                                Icon(
                                                                    Icons
                                                                        .chevron_right_rounded,
                                                                    color: activeSkin
                                                                        .textColor
                                                                        .withOpacity(
                                                                            0.3),
                                                                    size: 16),
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ],
                                                  ),
                                                );
                                              } else {
                                                final upcoming = <MapEntry<int,
                                                    MediaItem>>[];
                                                for (int i = currentIndex + 1;
                                                    i < queue.length &&
                                                        upcoming.length < 5;
                                                    i++) {
                                                  upcoming.add(
                                                      MapEntry(i, queue[i]));
                                                }
                                                if (upcoming.isEmpty)
                                                  return const SizedBox
                                                      .shrink();

                                                return Container(
                                                  margin: const EdgeInsets.only(
                                                      top: 6,
                                                      left: 6,
                                                      right: 6),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 10,
                                                      vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: activeSkin.lcdBgColor
                                                        .withOpacity(0.85),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    border: Border.all(
                                                        color: activeSkin
                                                            .lcdBorderColor,
                                                        width: 1.0),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                bottom: 4),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'UPCOMING QUEUE',
                                                              style: TextStyle(
                                                                color: activeSkin
                                                                    .textColor
                                                                    .withOpacity(
                                                                        0.6),
                                                                fontFamily:
                                                                    'Orbitron',
                                                                fontSize: 8,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                letterSpacing:
                                                                    1.1,
                                                              ),
                                                            ),
                                                            Text(
                                                              '${upcoming.length} TRACKS',
                                                              style: TextStyle(
                                                                color: activeSkin
                                                                    .textColor
                                                                    .withOpacity(
                                                                        0.6),
                                                                fontFamily:
                                                                    'monospace',
                                                                fontSize: 8,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Divider(
                                                          color: activeSkin
                                                              .lcdBorderColor
                                                              .withOpacity(
                                                                  0.35),
                                                          height: 6,
                                                          thickness: 0.5),
                                                      ...upcoming.map((entry) {
                                                        final idx = entry.key;
                                                        final item =
                                                            entry.value;
                                                        return GestureDetector(
                                                          behavior:
                                                              HitTestBehavior
                                                                  .opaque,
                                                          onTap: () =>
                                                              playbackService
                                                                  .handler
                                                                  .playerInstance
                                                                  .seek(
                                                                      Duration
                                                                          .zero,
                                                                      index:
                                                                          idx),
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        3),
                                                            child: Row(
                                                              children: [
                                                                Text(
                                                                  '${(idx + 1).toString().padLeft(2, '0')}. ',
                                                                  style:
                                                                      TextStyle(
                                                                    color: activeSkin
                                                                        .textColor
                                                                        .withOpacity(
                                                                            0.8),
                                                                    fontFamily:
                                                                        'monospace',
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                                Expanded(
                                                                  child: Text(
                                                                    '${item.title} – ${item.artist ?? ""}',
                                                                    style:
                                                                        TextStyle(
                                                                      color: activeSkin
                                                                          .textColor,
                                                                      fontFamily:
                                                                          'monospace',
                                                                      fontSize:
                                                                          10,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                                Icon(
                                                                    Icons
                                                                        .play_arrow_rounded,
                                                                    color: activeSkin
                                                                        .textColor
                                                                        .withOpacity(
                                                                            0.5),
                                                                    size: 12),
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ],
                                                  ),
                                                );
                                              }
                                            },
                                          );
                                        },
                                      ),

                                      const SizedBox(height: 12),
                                      () {
                                        final navHeight =
                                            kBottomNavigationBarHeight +
                                                MediaQuery.of(context)
                                                    .padding
                                                    .bottom;
                                        if (activeSkin.isFlat) {
                                          return SizedBox(
                                              height: 100 + navHeight);
                                        } else {
                                          if (_dialStyle ==
                                              DialStyle.circular) {
                                            return SizedBox(
                                                height: 260 + navHeight);
                                          } else {
                                            return SizedBox(
                                                height: 180 + navHeight - 10);
                                          }
                                        }
                                      }(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }(),
                    ),
                  ),
                ],
              ),

              // Dialer panel — docked or floating cleanly above bottom navigation, hidden in landscape
              if (!isLandscape)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: () {
                    final navHeight = kBottomNavigationBarHeight +
                        MediaQuery.of(context).padding.bottom;
                    if (activeSkin.isFlat || _dialStyle == DialStyle.circular) {
                      return _dialStyle == DialStyle.circular
                          ? navHeight - 57
                          : navHeight - 60; // Flat dialer: shifted down by 20px
                    } else {
                      return navHeight -
                          10; // Skeuomorphic rectangular/synth: shifted down from navHeight + 20 by 30px
                    }
                  }(),
                  child: StreamBuilder<ja.LoopMode>(
                    stream: player.loopModeStream,
                    initialData: player.loopMode,
                    builder: (context, loopSnapshot) {
                      final loopMode = loopSnapshot.data ?? ja.LoopMode.off;
                      return StreamBuilder<bool>(
                        stream: player.shuffleModeEnabledStream,
                        initialData: player.shuffleModeEnabled,
                        builder: (context, shuffleSnapshot) {
                          final isShuffle = shuffleSnapshot.data ?? false;
                          return _buildConfiguredDialer(
                            context: context,
                            activeSkin: activeSkin,
                            playbackService: playbackService,
                            player: player,
                            settings: settings,
                            isShuffle: isShuffle,
                            loopMode: loopMode,
                          );
                        },
                      );
                    },
                  ),
                ),

              // 3. Full-screen EQ modal overlay (covers entire player screen)
              if (_showEqualizer)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _showEqualizer = false),
                    child: Container(
                      color: Colors.black.withOpacity(0.85),
                      child: GestureDetector(
                        onTap: () {}, // Prevent tap-through
                        child: _SkeuomorphicEqualizerPanel(
                          skin: activeSkin,
                          bands: _eqBands,
                          activePreset: _activePreset,
                          bassValue: _bassValue,
                          stereoValue: _stereoValue,
                          onBassChanged: (val) {
                            setState(() => _bassValue = val);
                            _applyEqualizerWithKnobs(playbackService);
                          },
                          onStereoChanged: (val) {
                            setState(() => _stereoValue = val);
                            // Real Android stereo widening via native Virtualizer.
                            playbackService.setStereoStrength(_stereoValue);
                          },
                          onBandChanged: (index, val) {
                            setState(() {
                              _eqBands[index] = val;
                              _activePreset = 'Custom';
                            });
                            ref
                                .read(storageServiceProvider)
                                .setEqualizerPreset('Custom');
                            ref
                                .read(storageServiceProvider)
                                .setEqualizerBands(List.from(_eqBands));
                            _applyEqualizerWithKnobs(playbackService);
                          },
                          onPresetSelected: (name) => _applyEqPreset(
                              playbackService, name, activeSkin.textColor),
                          onClose: () =>
                              setState(() => _showEqualizer = false),
                          minDb: _eqMinDb,
                          maxDb: _eqMaxDb,
                          frequencyLabels: _eqUiLabels,
                          presetNames: _presetNames,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<_AudioTechInfo?> _getTechInfo(String filePath) {
    final cached = _techInfoCache[filePath];
    if (cached != null) return Future.value(cached);

    final inflight = _techInfoInflight[filePath];
    if (inflight != null) return inflight;

    final future = _readAudioTechInfo(filePath).then((info) {
      if (info != null) {
        _techInfoCache[filePath] = info;
      }
      _techInfoInflight.remove(filePath);
      return info;
    });

    _techInfoInflight[filePath] = future;
    return future;
  }

  Future<_AudioTechInfo?> _readAudioTechInfo(String filePath) async {
    // Best-effort: currently only parses MP3 frame header.
    if (!filePath.toLowerCase().endsWith('.mp3')) return null;
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final raf = await file.open();
      try {
        int offset = 0;

        // Skip ID3v2 tag if present.
        final header = await raf.read(10);
        if (header.length == 10 &&
            header[0] == 0x49 &&
            header[1] == 0x44 &&
            header[2] == 0x33) {
          final tagSize = ((header[6] & 0x7F) << 21) |
              ((header[7] & 0x7F) << 14) |
              ((header[8] & 0x7F) << 7) |
              (header[9] & 0x7F);
          offset = 10 + tagSize;
          await raf.setPosition(offset);
        } else {
          // No ID3: rewind.
          await raf.setPosition(0);
        }

        // Scan forward for a frame sync (0xFFE).
        const maxScan = 64 * 1024;
        final start = await raf.position();
        while ((await raf.position()) - start < maxScan) {
          final b = await raf.read(2);
          if (b.length < 2) break;
          if (b[0] == 0xFF && (b[1] & 0xE0) == 0xE0) {
            // Candidate sync; read remaining 2 bytes of the header.
            final rest = await raf.read(2);
            if (rest.length < 2) break;
            final h0 = b[0];
            final h1 = b[1];
            final h2 = rest[0];
            final h3 = rest[1];
            final info = _parseMp3FrameHeader(h0, h1, h2, h3);
            if (info != null) return info;
            // Not valid, step back 3 bytes and keep scanning.
            final pos = await raf.position();
            await raf.setPosition(pos - 3);
          } else {
            // Step back 1 byte so we slide window by one.
            final pos = await raf.position();
            await raf.setPosition(pos - 1);
          }
        }
      } finally {
        await raf.close();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  _AudioTechInfo? _parseMp3FrameHeader(int h0, int h1, int h2, int h3) {
    // Validate sync (11 bits 1).
    if (h0 != 0xFF || (h1 & 0xE0) != 0xE0) return null;

    final versionId = (h1 >> 3) & 0x03;
    final layerId = (h1 >> 1) & 0x03;
    final bitrateIdx = (h2 >> 4) & 0x0F;
    final sampleIdx = (h2 >> 2) & 0x03;

    // Exclude reserved values.
    if (versionId == 0x01) return null;
    if (layerId == 0x00) return null;
    if (bitrateIdx == 0x00 || bitrateIdx == 0x0F) return null;
    if (sampleIdx == 0x03) return null;

    final isMpeg1 = versionId == 0x03;
    // Layer mapping: 01=Layer III, 10=Layer II, 11=Layer I
    final layer = switch (layerId) {
      0x03 => 1,
      0x02 => 2,
      0x01 => 3,
      _ => 0,
    };
    if (layer == 0) return null;

    final sampleRateHz = _mp3SampleRateHz(versionId, sampleIdx);
    if (sampleRateHz == null) return null;

    final bitrateKbps =
        _mp3BitrateKbps(isMpeg1: isMpeg1, layer: layer, idx: bitrateIdx);
    if (bitrateKbps == null) return null;

    return _AudioTechInfo(bitrateKbps: bitrateKbps, sampleRateHz: sampleRateHz);
  }

  int? _mp3SampleRateHz(int versionId, int sampleIdx) {
    // versionId: 00=MPEG2.5, 10=MPEG2, 11=MPEG1
    const mpeg1 = [44100, 48000, 32000];
    const mpeg2 = [22050, 24000, 16000];
    const mpeg25 = [11025, 12000, 8000];
    return switch (versionId) {
      0x03 => mpeg1[sampleIdx],
      0x02 => mpeg2[sampleIdx],
      0x00 => mpeg25[sampleIdx],
      _ => null,
    };
  }

  int? _mp3BitrateKbps(
      {required bool isMpeg1, required int layer, required int idx}) {
    // idx is 1..14 here.
    // Tables from MPEG audio spec; layer: 1=Layer I, 2=Layer II, 3=Layer III.
    const mpeg1L1 = [
      32,
      64,
      96,
      128,
      160,
      192,
      224,
      256,
      288,
      320,
      352,
      384,
      416,
      448
    ];
    const mpeg1L2 = [
      32,
      48,
      56,
      64,
      80,
      96,
      112,
      128,
      160,
      192,
      224,
      256,
      320,
      384
    ];
    const mpeg1L3 = [
      32,
      40,
      48,
      56,
      64,
      80,
      96,
      112,
      128,
      160,
      192,
      224,
      256,
      320
    ];
    const mpeg2L1 = [
      32,
      48,
      56,
      64,
      80,
      96,
      112,
      128,
      144,
      160,
      176,
      192,
      224,
      256
    ];
    const mpeg2L2L3 = [
      8,
      16,
      24,
      32,
      40,
      48,
      56,
      64,
      80,
      96,
      112,
      128,
      144,
      160
    ];

    final table = isMpeg1
        ? switch (layer) {
            1 => mpeg1L1,
            2 => mpeg1L2,
            3 => mpeg1L3,
            _ => null,
          }
        : switch (layer) {
            1 => mpeg2L1,
            2 || 3 => mpeg2L2L3,
            _ => null,
          };
    if (table == null) return null;
    return table[idx - 1];
  }
}

class _AudioTechInfo {
  final int? bitrateKbps;
  final int? sampleRateHz;

  const _AudioTechInfo({required this.bitrateKbps, required this.sampleRateHz});
}

// ---------------------------------------------------------
// Visualizer Custom Painter Engine (10 Styles * 3 Variations = 30 total variations!)
// ---------------------------------------------------------

class _VisualizerPainter extends CustomPainter {
  final VisualizerStyle style;
  final int variation;
  final List<double> amplitudes;
  final List<double> peaks;
  final double time;
  final List<_AstroStar> stars;
  final Color barColor;
  final Color peakColor;
  final bool hasTrack;
  final ui.FragmentProgram? appsRingProgram;
  final ui.FragmentProgram? steamBarsProgram;
  final ui.FragmentProgram? cosmicTunnelProgram;
  final ui.FragmentProgram? liquidFluidProgram;
  final ui.FragmentProgram? solarFlaresProgram;
  final double beat;

  _VisualizerPainter({
    required this.style,
    required this.variation,
    required this.amplitudes,
    required this.peaks,
    required this.time,
    required this.stars,
    required this.barColor,
    required this.peakColor,
    required this.hasTrack,
    this.appsRingProgram,
    this.steamBarsProgram,
    this.cosmicTunnelProgram,
    this.liquidFluidProgram,
    this.solarFlaresProgram,
    this.beat = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final double w = size.width;
    final double h = size.height;

    // Background blur / ambient glow for specific combined styles
    if (hasTrack &&
        ((style == VisualizerStyle.combinedUltra && (variation % 4 == 3)) ||
            style == VisualizerStyle.albumArtReactive)) {
      final double avgAmp =
          amplitudes.fold(0.0, (sum, val) => sum + val) / amplitudes.length;
      final double intensity = (avgAmp / 38.0).clamp(0.0, 1.0);

      final Paint glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(w / 2, h / 2),
          math.max(20.0, w * 0.45),
          [
            barColor.withOpacity(0.22 * intensity),
            barColor.withOpacity(0.04 * intensity),
            Colors.transparent
          ],
          [0.0, 0.5, 1.0],
        )
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), glowPaint);
    }

    if (!hasTrack) {
      final Paint flatPaint = Paint()
        ..color = barColor.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), flatPaint);

      // If no track is playing, draw an empty vinyl outline in the center for combined/album-art visualizer
      if (style == VisualizerStyle.albumArtReactive ||
          (style == VisualizerStyle.combinedUltra && (variation % 4 == 1))) {
        final Paint discPaint = Paint()
          ..color = barColor.withOpacity(0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(Offset(w / 2, h / 2), 24, discPaint);
      }
      canvas.restore();
      return;
    }

    final double avgAmp =
        amplitudes.fold(0.0, (sum, val) => sum + val) / amplitudes.length;
    final double normalizedAmp = (avgAmp / 38.0).clamp(0.0, 1.0);

    switch (style) {
      // 1. SPECTRUM BARS (EQUALIZER)
      case VisualizerStyle.spectrumBars:
        final int bandsCount = 10;
        final double barGap = 2.0;
        final double barWidth = (w - (barGap * (bandsCount - 1))) / bandsCount;

        // Determine variant: 0 = Center-out, 1 = Capsule, 2 = Retro Winamp, 3 = Floating bars
        final int mode = variation % 4;

        for (int i = 0; i < bandsCount; i++) {
          final double left = i * (barWidth + barGap);
          final double activeHeight = (amplitudes[i] / 38.0) * h * 0.88;
          final double floatingPeak = (peaks[i] / 38.0) * h * 0.88;

          if (mode == 0) {
            // Center-out bars (growing vertically from center)
            final double midY = h / 2;
            final double halfH = activeHeight / 2;
            final Paint barPaint = Paint()
              ..shader = ui.Gradient.linear(
                Offset(left, midY - halfH),
                Offset(left, midY + halfH),
                [
                  barColor.withOpacity(0.4),
                  barColor,
                  barColor.withOpacity(0.4)
                ],
                [0.0, 0.5, 1.0],
              )
              ..style = PaintingStyle.fill;

            canvas.drawRect(
              Rect.fromLTWH(
                  left, midY - halfH, barWidth, activeHeight.clamp(2.0, h)),
              barPaint,
            );
          } else if (mode == 1) {
            // Rounded capsule bars
            final Paint barPaint = Paint()
              ..color = barColor
              ..style = PaintingStyle.fill;
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(left, h - activeHeight, barWidth,
                    activeHeight.clamp(2.0, h)),
                Radius.circular(barWidth / 2),
              ),
              barPaint,
            );
          } else if (mode == 2) {
            // Retro Winamp style grid blocks
            final double blockSize = 3.2;
            final double blockGap = 1.0;
            final int activeBlocks =
                (activeHeight / (blockSize + blockGap)).floor();
            final int maxBlocks = (h / (blockSize + blockGap)).floor();

            for (int b = 0; b < activeBlocks; b++) {
              final double bottomY = h - (b * (blockSize + blockGap));
              // Green at bottom, yellow in mid, red at top
              final double pct = b / maxBlocks;
              final Color gridColor = pct < 0.5
                  ? Colors.greenAccent
                  : (pct < 0.82 ? Colors.yellowAccent : Colors.redAccent);

              final Paint blockPaint = Paint()
                ..color = gridColor.withOpacity(0.9)
                ..style = PaintingStyle.fill;

              canvas.drawRect(
                Rect.fromLTWH(left, bottomY - blockSize, barWidth, blockSize),
                blockPaint,
              );
            }
          } else {
            // Floating bars (hollow, outlined bars with peak)
            final Paint barPaint = Paint()
              ..color = barColor.withOpacity(0.4)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0;
            canvas.drawRect(
              Rect.fromLTWH(
                  left, h - activeHeight, barWidth, activeHeight.clamp(2.0, h)),
              barPaint,
            );
          }

          // Draw Peak dot (except in Winamp style which has its own peak falloff)
          if (mode != 2) {
            final Paint peakPaint = Paint()
              ..color = peakColor
              ..style = PaintingStyle.fill;
            canvas.drawRect(
              Rect.fromLTWH(left, h - floatingPeak - 2.0, barWidth, 1.8),
              peakPaint,
            );
          }
        }
        break;

      // 2. WAVEFORM VISUALIZATION
      case VisualizerStyle.waveform:
        final int samplePoints = 40;
        final int waveType = variation %
            4; // 0=Continuous, 1=Oscilloscope, 2=Bezier, 3=Symmetrical
        final double midY = h / 2;

        if (waveType == 0) {
          // Continuous waveform (filled bars)
          final double barW = w / samplePoints;
          final Paint fillPaint = Paint()
            ..color = barColor.withOpacity(0.65)
            ..style = PaintingStyle.fill;

          for (int i = 0; i < samplePoints; i++) {
            final double pct = i / samplePoints;
            final double ampIdx = amplitudes[i % 10] / 38.0;
            final double waveVal =
                math.sin(pct * 6 * math.pi + time * 10) * ampIdx * (h * 0.4);

            canvas.drawRect(
              Rect.fromLTWH(
                  i * barW, midY - waveVal, barW - 0.8, waveVal * 2.0),
              fillPaint,
            );
          }
        } else if (waveType == 1) {
          // Oscilloscope style
          final Paint linePaint = Paint()
            ..color = barColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round;

          final Path wavePath = Path();
          wavePath.moveTo(0, midY);
          for (int x = 0; x <= samplePoints; x++) {
            final double pct = x / samplePoints;
            final double ampIdx = amplitudes[x % 10] / 38.0;
            final double dx = pct * w;
            final double dy = midY +
                math.sin(pct * 4 * math.pi - time * 14.0) * ampIdx * (h * 0.45);
            wavePath.lineTo(dx, dy);
          }
          canvas.drawPath(wavePath, linePaint);
        } else if (waveType == 2) {
          // Smooth bezier waveform
          final Paint linePaint = Paint()
            ..color = barColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;

          final Path path = Path();
          path.moveTo(0, midY);

          for (int i = 0; i < samplePoints; i += 2) {
            final double pct1 = i / samplePoints;
            final double pct2 = (i + 1) / samplePoints;
            final double pct3 = (i + 2) / samplePoints;

            final double ampVal1 = amplitudes[i % 10] / 38.0;
            final double ampVal2 = amplitudes[(i + 1) % 10] / 38.0;

            final double x1 = pct1 * w;
            final double y1 = midY +
                math.sin(pct1 * 4 * math.pi + time * 8) * ampVal1 * (h * 0.4);

            final double x2 = pct2 * w;
            final double y2 = midY +
                math.sin(pct2 * 4 * math.pi + time * 8) * ampVal2 * (h * 0.4);

            final double x3 = pct3 * w;
            final double y3 = midY +
                math.sin(pct3 * 4 * math.pi + time * 8) * ampVal2 * (h * 0.4);

            path.quadraticBezierTo(x2, y2, x3, y3);
          }
          canvas.drawPath(path, linePaint);
        } else {
          // Symmetrical wave
          final Paint fillPaint = Paint()
            ..color = barColor.withOpacity(0.2)
            ..style = PaintingStyle.fill;
          final Paint borderPaint = Paint()
            ..color = barColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;

          final Path topPath = Path();
          final Path bottomPath = Path();
          topPath.moveTo(0, midY);
          bottomPath.moveTo(0, midY);

          for (int x = 0; x <= samplePoints; x++) {
            final double pct = x / samplePoints;
            final double ampIdx = amplitudes[x % 10] / 38.0;
            final double dx = pct * w;
            final double waveVal =
                math.sin(pct * 3 * math.pi + time * 6).abs() *
                    ampIdx *
                    (h * 0.42);

            topPath.lineTo(dx, midY - waveVal);
            bottomPath.lineTo(dx, midY + waveVal);
          }

          topPath.lineTo(w, midY);
          bottomPath.lineTo(w, midY);
          topPath.close();
          bottomPath.close();

          canvas.drawPath(topPath, fillPaint);
          canvas.drawPath(topPath, borderPaint);
          canvas.drawPath(bottomPath, fillPaint);
          canvas.drawPath(bottomPath, borderPaint);
        }
        break;

      // 3. CIRCULAR SPECTRUM
      case VisualizerStyle.circularSpectrum:
        final double cx = w / 2;
        final double cy = h / 2;
        final int circType = variation %
            4; // 0=Rotating particles, 1=Pulsing radius, 2=TrapNation Inward, 3=Monstercat Bars
        final int numBars = 64; // increased density

        if (circType == 0) {
          // Rotating particles in circular arrangement
          final double baseRadius = 45.0 + normalizedAmp * 15.0;
          final double angleOffset = time * 0.6;
          final Paint partPaint = Paint()..style = PaintingStyle.fill;

          for (int i = 0; i < numBars; i++) {
            final double angle = (i / numBars) * 2 * math.pi + angleOffset;
            final double bandAmp = amplitudes[i % 10] / 38.0;
            final double distance = baseRadius + bandAmp * 30.0;

            final double px = cx + math.cos(angle) * distance * 1.5;
            final double py = cy + math.sin(angle) * distance * 0.95;

            final double radius = 2.0 + (bandAmp * 4.0);
            partPaint.color = HSLColor.fromAHSL(
              1.0,
              (i * 360.0 / numBars + time * 40.0) % 360.0,
              0.8,
              0.6,
            ).toColor();

            canvas.drawCircle(Offset(px, py), radius, partPaint);
          }
        } else if (circType == 1) {
          // Pulsing radius spectrum rays
          final double baseRadius = 35.0 + normalizedAmp * 10.0;
          final double maxRadius = 80.0;
          final double angleOffset = -time * 0.3;

          final Paint rayPaint = Paint()
            ..color = barColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round;

          for (int i = 0; i < numBars; i++) {
            final double angle = (i / numBars) * 2 * math.pi + angleOffset;
            final double bandAmp = amplitudes[i % 10] / 38.0;
            final double extRad = baseRadius + bandAmp * maxRadius;

            final double sx = cx + math.cos(angle) * baseRadius * 1.5;
            final double sy = cy + math.sin(angle) * baseRadius * 0.95;

            final double ex = cx + math.cos(angle) * extRad * 1.5;
            final double ey = cy + math.sin(angle) * extRad * 0.95;

            canvas.drawLine(Offset(sx, sy), Offset(ex, ey), rayPaint);
          }
        } else if (circType == 2) {
          // TrapNation inward bouncing style
          final double baseRadius = 60.0;
          final double maxRadius = 45.0; // Grows inward!

          final Paint rayPaint = Paint()
            ..color = peakColor.withOpacity(0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0
            ..strokeCap = StrokeCap.round;

          final Paint fillPaint = Paint()
            ..color = peakColor.withOpacity(0.15)
            ..style = PaintingStyle.fill;

          canvas.drawCircle(
              Offset(cx, cy), baseRadius - 5 + normalizedAmp * 10, fillPaint);

          for (int i = 0; i < numBars; i++) {
            final double angle = (i / numBars) * 2 * math.pi;
            final double bandAmp = amplitudes[i % 10] / 38.0;
            final double innerRad =
                baseRadius - bandAmp * maxRadius; // Subtracted to go inward

            final double sx = cx + math.cos(angle) * baseRadius * 1.5;
            final double sy = cy + math.sin(angle) * baseRadius * 0.95;

            final double ex = cx + math.cos(angle) * innerRad * 1.5;
            final double ey = cy + math.sin(angle) * innerRad * 0.95;

            canvas.drawLine(Offset(sx, sy), Offset(ex, ey), rayPaint);
          }
        } else {
          // Monstercat-style dynamic thick bars
          final double baseRadius = 40.0;
          final double maxRadius = 65.0;

          final Paint barPaint = Paint()
            ..color = barColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.0 // Thick bars
            ..strokeCap = StrokeCap.square;

          for (int i = 0; i < numBars / 2; i++) {
            // Half bars for thickness
            final double angle = (i / (numBars / 2)) * 2 * math.pi;
            final double bandAmp = amplitudes[(i * 2) % 10] / 38.0;
            final double extRad = baseRadius + bandAmp * maxRadius;

            final double sx = cx + math.cos(angle) * baseRadius * 1.5;
            final double sy = cy + math.sin(angle) * baseRadius * 0.95;

            final double ex = cx + math.cos(angle) * extRad * 1.5;
            final double ey = cy + math.sin(angle) * extRad * 0.95;

            canvas.drawLine(Offset(sx, sy), Offset(ex, ey), barPaint);
          }
        }
        break;

      // 4. PARTICLE REACTIVE VISUALIZATION
      case VisualizerStyle.particleReactive:
        final double cx = w / 2;
        final double cy = h / 2;
        final int effectType =
            variation % 4; // 0=Dust, 1=Galaxy, 2=Smoke, 3=Energy field

        if (effectType == 0) {
          // Dust (rising floaty embers)
          final Paint dustPaint = Paint()..style = PaintingStyle.fill;
          for (int i = 0; i < 25; i++) {
            final double speed = 0.5 + (i % 3) * 0.3;
            final double dx = ((i * 12.0 + time * 15 * speed) % w);
            final double wave = math.sin(time * 2.0 + i) * 6.0;
            final double dy = h - ((i * 6.0 + time * 8 * speed) % h);

            dustPaint.color =
                barColor.withOpacity((1.0 - (dy / h)).clamp(0.0, 1.0) * 0.7);
            canvas.drawCircle(
                Offset(dx, dy + wave), 1.0 + normalizedAmp * 1.5, dustPaint);
          }
        } else if (effectType == 1) {
          // Galaxy (twisting vortex)
          final int starsCount = 35;
          final Paint starPaint = Paint()..style = PaintingStyle.fill;

          for (int i = 0; i < starsCount; i++) {
            final double angle =
                (i * 2.4) + (time * 0.5 * (1.0 + normalizedAmp));
            final double distance = ((i * 1.8 + time * 12.0) % (w * 0.42));
            final double dx = cx + math.cos(angle) * distance * 1.6;
            final double dy = cy + math.sin(angle) * distance * 0.95;

            final double opacity =
                (1.0 - (distance / (w * 0.42))).clamp(0.0, 1.0);
            starPaint.color = HSLColor.fromAHSL(
              opacity,
              (angle * 180 / math.pi) % 360.0,
              0.8,
              0.6,
            ).toColor();

            canvas.drawCircle(
                Offset(dx, dy), 1.0 + normalizedAmp * 2.0, starPaint);
          }
        } else if (effectType == 2) {
          // Smoke (expanding soft clouds)
          final Paint smokePaint = Paint()..style = PaintingStyle.fill;
          for (int i = 0; i < 6; i++) {
            final double angle = (i * 2 * math.pi / 6) + time * 0.2;
            final double dist = 12.0 + normalizedAmp * 20.0;
            final double dx = cx + math.cos(angle) * dist * 1.4;
            final double dy = cy + math.sin(angle) * dist * 0.9;
            final double sizeRadius =
                14.0 + math.sin(time * 3 + i).abs() * 6.0 * (1 + normalizedAmp);

            smokePaint.color =
                barColor.withOpacity(0.08 * (1.0 - normalizedAmp * 0.3));
            canvas.drawCircle(Offset(dx, dy), sizeRadius, smokePaint);
          }
        } else {
          // Energy Field (intersecting grid vectors)
          final Paint vectorPaint = Paint()
            ..color = barColor.withOpacity(0.15 + normalizedAmp * 0.3)
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke;

          final Path path = Path();
          final int nodes = 8;
          for (int i = 0; i < nodes; i++) {
            final double angle = (i / nodes) * 2 * math.pi + time * 0.4;
            final double r1 = 12.0 + (amplitudes[i % 10] / 38.0) * 25.0;
            final double dx1 = cx + math.cos(angle) * r1 * 1.6;
            final double dy1 = cy + math.sin(angle) * r1 * 0.95;

            if (i == 0)
              path.moveTo(dx1, dy1);
            else
              path.lineTo(dx1, dy1);

            // Cross draw
            final double angle2 =
                ((i + 3) % nodes / nodes) * 2 * math.pi + time * 0.4;
            final double r2 = 12.0 + (amplitudes[(i + 3) % 10] / 38.0) * 25.0;
            final double dx2 = cx + math.cos(angle2) * r2 * 1.6;
            final double dy2 = cy + math.sin(angle2) * r2 * 0.95;
            canvas.drawLine(Offset(dx1, dy1), Offset(dx2, dy2), vectorPaint);
          }
          path.close();
          canvas.drawPath(path, vectorPaint);
        }
        break;

      case VisualizerStyle.liquidFluid:
        {
          final program = liquidFluidProgram;
          if (program != null) {
            final shader = program.fragmentShader();
            shader.setFloat(0, w);
            shader.setFloat(1, h);
            shader.setFloat(2, time);
            shader.setFloat(3, beat.clamp(0.0, 1.0));
            for (int i = 0; i < 10; i++) {
              final v = (i < amplitudes.length)
                  ? (amplitudes[i] / 38.0).clamp(0.0, 1.0)
                  : 0.0;
              shader.setFloat(4 + i, v);
            }
            final paint = Paint()..shader = shader;
            canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
          } else {
            // Fallback: wave plasma fluid
            final double midY = h / 2;
            final Path fluidPath = Path();
            fluidPath.moveTo(0, h);
            fluidPath.lineTo(0, midY);

            for (int x = 0; x <= w; x += 5) {
              final double pct = x / w;
              final double wave1 = math.sin(pct * 3 * math.pi + time * 4.5) *
                  8.0 *
                  (1 + normalizedAmp);
              final double wave2 = math.cos(pct * 6 * math.pi - time * 3.0) *
                  4.0 *
                  normalizedAmp;
              fluidPath.lineTo(x.toDouble(), midY + wave1 + wave2);
            }
            fluidPath.lineTo(w, h);
            fluidPath.close();

            final Paint fluidPaint = Paint()
              ..shader = ui.Gradient.linear(
                Offset(w / 2, midY - 10),
                Offset(w / 2, h),
                [barColor.withOpacity(0.55), barColor.withOpacity(0.1)],
              )
              ..style = PaintingStyle.fill;
            canvas.drawPath(fluidPath, fluidPaint);
          }
        }
        break;

      // 6. CIRCULAR PULSE / BREATHING RINGS
      case VisualizerStyle.breathingRings:
        final double cx = w / 2;
        final double cy = h / 2;
        final int ringType =
            variation % 3; // 0=Single, 1=Concentric, 2=Star rings

        if (ringType == 0) {
          // Simple breathing ring expanding with bass
          final double r = 16.0 + normalizedAmp * 20.0;
          final Paint ringPaint = Paint()
            ..color = barColor.withOpacity(0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;

          canvas.drawCircle(Offset(cx, cy), r, ringPaint);

          // Outer halo
          ringPaint.color = barColor.withOpacity(0.2);
          ringPaint.strokeWidth = 1.0;
          canvas.drawCircle(Offset(cx, cy), r + 8.0, ringPaint);
        } else if (ringType == 1) {
          // Concentric multi-rings
          final Paint ringPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2;

          for (int i = 1; i <= 3; i++) {
            final double pulse = normalizedAmp * (8.0 * i);
            final double r = (12.0 * i) + pulse;
            ringPaint.color =
                barColor.withOpacity((1.0 - (i * 0.25)).clamp(0.0, 1.0));
            canvas.drawCircle(Offset(cx, cy), r, ringPaint);
          }
        } else {
          // Audio-reactive Star Rings
          final Paint starPaint = Paint()
            ..color = barColor.withOpacity(0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;

          final Path starPath = Path();
          final int spokes = 12;
          final double rInner = 14.0 + normalizedAmp * 5.0;
          final double rOuter = 22.0 + normalizedAmp * 18.0;

          for (int i = 0; i <= spokes * 2; i++) {
            final double angle = (i * math.pi / spokes) + time * 0.4;
            final double r = i % 2 == 0 ? rInner : rOuter;
            final double dx = cx + math.cos(angle) * r * 1.5;
            final double dy = cy + math.sin(angle) * r * 0.95;

            if (i == 0)
              starPath.moveTo(dx, dy);
            else
              starPath.lineTo(dx, dy);
          }
          starPath.close();
          canvas.drawPath(starPath, starPaint);
        }
        break;

      // 7. RETRO WINAMP-STYLE ANALYZER
      case VisualizerStyle.retroWinamp:
        final int bandsCount = 14;
        final double barGap = 1.5;
        final double barWidth = (w - (barGap * (bandsCount - 1))) / bandsCount;
        final int retroMode =
            variation % 3; // 0=Winamp grid, 1=Glowing fire, 2=Falloff peaks

        for (int i = 0; i < bandsCount; i++) {
          final double left = i * (barWidth + barGap);
          final double ampIdx = amplitudes[i % 10] / 38.0;
          final double peakIdx = peaks[i % 10] / 38.0;
          final double activeHeight = ampIdx * h * 0.85;
          final double floatingPeak = peakIdx * h * 0.85;

          if (retroMode == 0) {
            // Classical green/yellow Winamp grid blocks
            final double blockH = 2.5;
            final double gapH = 0.8;
            final int blocks = (activeHeight / (blockH + gapH)).floor();
            final int maxB = (h / (blockH + gapH)).floor();

            for (int b = 0; b < blocks; b++) {
              final double bottomY = h - (b * (blockH + gapH));
              final double pct = b / maxB;

              // Classic Winamp spectrum colors: green -> yellow -> red
              final Color col = pct < 0.4
                  ? const Color(0xFF00FF00)
                  : (pct < 0.78
                      ? const Color(0xFFFFCC00)
                      : const Color(0xFFFF0000));

              canvas.drawRect(
                Rect.fromLTWH(left, bottomY - blockH, barWidth, blockH),
                Paint()
                  ..color = col
                  ..style = PaintingStyle.fill,
              );
            }
          } else if (retroMode == 1) {
            // Glowing Fire spectrum
            final Paint firePaint = Paint()
              ..shader = ui.Gradient.linear(
                Offset(left, h),
                Offset(left, h - activeHeight),
                [Colors.red, Colors.orangeAccent, Colors.yellowAccent],
                [0.0, 0.5, 1.0],
              )
              ..style = PaintingStyle.fill;

            canvas.drawRect(
              Rect.fromLTWH(
                  left, h - activeHeight, barWidth, activeHeight.clamp(2.0, h)),
              firePaint,
            );
          } else {
            // Classical flat falling peak bar
            final Paint barPaint = Paint()
              ..color = const ui.Color(0xFF33FF55)
              ..style = PaintingStyle.fill;
            canvas.drawRect(
              Rect.fromLTWH(
                  left, h - activeHeight, barWidth, activeHeight.clamp(1.0, h)),
              barPaint,
            );
          }

          // Falloff peak dot
          final Paint peakPaint = Paint()
            ..color = peakColor
            ..style = PaintingStyle.fill;
          canvas.drawRect(
            Rect.fromLTWH(left, h - floatingPeak - 2.0, barWidth, 1.8),
            peakPaint,
          );
        }
        break;

      // 8. ALBUM-ART REACTIVE EFFECTS
      case VisualizerStyle.albumArtReactive:
        final double cx = w / 2;
        final double cy = h / 2;
        final int artMode = variation %
            3; // 0=Glow around vinyl, 1=Blur pulse, 2=Dynamic shadow heartbeat

        // 1. Draw central skeuomorphic Vinyl Record / CD disk
        final double vinylRotation = time * 1.5;
        final double baseRadius = 24.0 + (normalizedAmp * 4.0);

        // Render reactive pulsing outer ring
        if (artMode == 0) {
          // Glow halo
          final Paint glowPaint = Paint()
            ..color = barColor.withOpacity(0.4 + normalizedAmp * 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;
          canvas.drawCircle(Offset(cx, cy), baseRadius + 4, glowPaint);
        } else if (artMode == 1) {
          // Blur pulse
          final Paint glowPaint = Paint()
            ..color = barColor.withOpacity(0.18)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
              Offset(cx, cy), baseRadius + 12 + normalizedAmp * 8.0, glowPaint);
        } else {
          // Dynamic shadow ring
          final Paint shadowPaint = Paint()
            ..color = Colors.black.withOpacity(0.55 - normalizedAmp * 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5;
          canvas.drawCircle(Offset(cx + 2, cy + 3), baseRadius, shadowPaint);
        }

        // Draw Vinyl Disc Body
        final Paint discPaint = Paint()
          ..color = const Color(0xFF0F0F0F)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(cx, cy), baseRadius, discPaint);

        // Stylized Vinyl grooved lines
        final Paint groovePaint = Paint()
          ..color = Colors.white.withOpacity(0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;
        canvas.drawCircle(Offset(cx, cy), baseRadius * 0.72, groovePaint);
        canvas.drawCircle(Offset(cx, cy), baseRadius * 0.48, groovePaint);

        // Center Album Art sticker (Spinning)
        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(vinylRotation);

        final Paint stickerPaint = Paint()
          ..color = barColor.withOpacity(0.85)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset.zero, baseRadius * 0.32, stickerPaint);

        // Center spindle pinhole
        final Paint spindlePaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset.zero, 2.5, spindlePaint);

        canvas.restore();
        break;

      // 9. COMBINED ULTRA
      case VisualizerStyle.combinedUltra:
        final int comboMode =
            variation % 4; // Force 4 options to bypass V5 (Ultra Combo)
        // 0 = Waveform + spectrum bars
        // 1 = Circular spectrum + album art
        // 2 = Particles + pulse ring
        // 3 = Background blur + reactive glow
        // 4 = Ultra Combo! (Circular spectrum + album art vinyl + floating particles + tiny waveform)

        final double cx = w / 2;
        final double cy = h / 2;

        if (comboMode == 0) {
          // Waveform + spectrum bars
          // 1. Draw spectrum bars
          final int bandsCount = 10;
          final double barGap = 2.0;
          final double barWidth =
              (w - (barGap * (bandsCount - 1))) / bandsCount;

          for (int i = 0; i < bandsCount; i++) {
            final double left = i * (barWidth + barGap);
            final double activeHeight = (amplitudes[i] / 38.0) * h * 0.65;
            final Paint barPaint = Paint()
              ..color = barColor.withOpacity(0.48)
              ..style = PaintingStyle.fill;
            canvas.drawRect(
                Rect.fromLTWH(left, h - activeHeight, barWidth, activeHeight),
                barPaint);
          }

          // 2. Draw continuous waveform overlay
          final Paint linePaint = Paint()
            ..color = peakColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          final Path wavePath = Path();
          wavePath.moveTo(0, h * 0.35);

          for (int x = 0; x <= 30; x++) {
            final double pct = x / 30;
            final double ampIdx = amplitudes[x % 10] / 38.0;
            final double dx = pct * w;
            final double dy = h * 0.35 +
                math.sin(pct * 5 * math.pi + time * 12.0) * ampIdx * 15.0;
            wavePath.lineTo(dx, dy);
          }
          canvas.drawPath(wavePath, linePaint);
        } else if (comboMode == 1) {
          // Circular spectrum + album art
          // 1. Draw circular rays
          final int numBars = 24;
          final double baseRadius = 24.0;
          final Paint rayPaint = Paint()
            ..color = barColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round;

          for (int i = 0; i < numBars; i++) {
            final double angle = (i / numBars) * 2 * math.pi + time * 0.4;
            final double bandAmp = amplitudes[i % 10] / 38.0;
            final double extRad = baseRadius + bandAmp * 14.0;

            final double sx = cx + math.cos(angle) * baseRadius * 1.45;
            final double sy = cy + math.sin(angle) * baseRadius * 0.95;

            final double ex = cx + math.cos(angle) * extRad * 1.45;
            final double ey = cy + math.sin(angle) * extRad * 0.95;

            canvas.drawLine(Offset(sx, sy), Offset(ex, ey), rayPaint);
          }

          // 2. Draw Vinyl CD
          final Paint cdPaint = Paint()
            ..color = const Color(0xFF141414)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(cx, cy), baseRadius, cdPaint);
          final Paint stickerPaint = Paint()
            ..color = peakColor
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(cx, cy), baseRadius * 0.35, stickerPaint);
          canvas.drawCircle(Offset(cx, cy), 1.8, Paint()..color = Colors.black);
        } else if (comboMode == 2) {
          // Particles + pulse ring
          // 1. Drawing expanding bass ring
          final double r = 14.0 + normalizedAmp * 16.0;
          final Paint ringPaint = Paint()
            ..color = barColor.withOpacity(0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8;
          canvas.drawCircle(Offset(cx, cy), r, ringPaint);

          // 2. Drawing stardust floating embers
          final Paint pPaint = Paint()..style = PaintingStyle.fill;
          for (int i = 0; i < 15; i++) {
            final double angle = (i * 2.1) + time * 0.5;
            final double distance = ((i * 3.5 + time * 14.0) % (w * 0.42)) + r;
            final double dx = cx + math.cos(angle) * distance * 1.5;
            final double dy = cy + math.sin(angle) * distance * 0.95;

            final double opacity =
                (1.0 - (distance / (w * 0.42 + r))).clamp(0.0, 1.0);
            pPaint.color = barColor.withOpacity(opacity * 0.8);
            canvas.drawCircle(Offset(dx, dy), 1.2, pPaint);
          }
        } else if (comboMode == 3) {
          // Background blur + reactive glow
          // Soft glowing energy waves
          final Paint p = Paint()
            ..color = barColor.withOpacity(0.08 + normalizedAmp * 0.12)
            ..style = PaintingStyle.fill;

          for (int i = 0; i < 3; i++) {
            final Path path = Path();
            path.moveTo(0, h);
            final double phase = time * 2.0 + (i * 1.5);
            final double amp = 8.0 + normalizedAmp * 15.0;

            for (int x = 0; x <= 20; x++) {
              final double pct = x / 20;
              final double dy =
                  (h / 2) + math.sin(pct * 2 * math.pi + phase) * amp;
              path.lineTo(pct * w, dy);
            }
            path.lineTo(w, h);
            path.close();
            canvas.drawPath(path, p);
          }
        } else {
          // 4. THE ULTRA COMBO!
          // Combined: Circular spectrum + Album art vinyl + Floating particles + Tiny seekbar waveform at the bottom

          // A. Draw drifting stardust particles in the background
          final Paint pPaint = Paint()..style = PaintingStyle.fill;
          for (int i = 0; i < 12; i++) {
            final double dx = (i * 18.0 + time * 12.0) % w;
            final double waveY = cy + math.sin(time + i) * (h * 0.35);
            pPaint.color = barColor.withOpacity(0.24);
            canvas.drawCircle(
                Offset(dx, waveY), 1.0 + normalizedAmp * 1.0, pPaint);
          }

          // B. Draw circular spectrum expanding outward from the center vinyl
          final int numBars = 28;
          final double baseRadius = 24.0;
          final Paint rayPaint = Paint()
            ..color = barColor.withOpacity(0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round;

          for (int i = 0; i < numBars; i++) {
            final double angle = (i / numBars) * 2 * math.pi - time * 0.5;
            final double bandAmp = amplitudes[i % 10] / 38.0;
            final double extRad = baseRadius + bandAmp * 16.0;

            final double sx = cx + math.cos(angle) * baseRadius * 1.45;
            final double sy = cy + math.sin(angle) * baseRadius * 0.95;

            final double ex = cx + math.cos(angle) * extRad * 1.45;
            final double ey = cy + math.sin(angle) * extRad * 0.95;

            canvas.drawLine(Offset(sx, sy), Offset(ex, ey), rayPaint);
          }

          // C. Draw the Vinyl record CD disk in the center
          final Paint cdPaint = Paint()
            ..color = const Color(0xFF0D0D0D)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(cx, cy), baseRadius, cdPaint);
          final Paint stickerPaint = Paint()
            ..color = peakColor
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(cx, cy), baseRadius * 0.32, stickerPaint);
          canvas.drawCircle(Offset(cx, cy), 2.0, Paint()..color = Colors.black);

          // D. Draw tiny seekbar waveform at the bottom (bottom 10px)
          final Paint wavePaint = Paint()
            ..color = barColor.withOpacity(0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          final Path bottomWave = Path();
          bottomWave.moveTo(0, h - 8);

          for (int x = 0; x <= 30; x++) {
            final double pct = x / 30;
            final double ampIdx = amplitudes[x % 10] / 38.0;
            final double dy =
                (h - 8) + math.cos(pct * 4 * math.pi + time * 8) * ampIdx * 6.0;
            bottomWave.lineTo(pct * w, dy);
          }
          canvas.drawPath(bottomWave, wavePaint);
        }
        break;

      case VisualizerStyle.solarFlares:
        {
          final program = solarFlaresProgram;
          if (program != null) {
            final shader = program.fragmentShader();
            shader.setFloat(0, w);
            shader.setFloat(1, h);
            shader.setFloat(2, time);
            shader.setFloat(3, beat.clamp(0.0, 1.0));
            for (int i = 0; i < 10; i++) {
              final v = (i < amplitudes.length)
                  ? (amplitudes[i] / 38.0).clamp(0.0, 1.0)
                  : 0.0;
              shader.setFloat(4 + i, v);
            }
            final paint = Paint()..shader = shader;
            canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
          } else {
            // Fallback: concentric solar flares
            final double cx = w / 2;
            final double cy = h / 2;
            final double baseRadius = 32.0 + normalizedAmp * 12.0;

            final Paint glowPaint = Paint()
              ..color = peakColor.withOpacity(0.12 * normalizedAmp)
              ..style = PaintingStyle.fill;
            canvas.drawCircle(Offset(cx, cy), baseRadius + 30, glowPaint);

            final Paint ringPaint = Paint()
              ..color = barColor.withOpacity(0.85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0;
            canvas.drawCircle(Offset(cx, cy), baseRadius, ringPaint);
            canvas.drawCircle(Offset(cx, cy), baseRadius - 8,
                ringPaint..color = peakColor.withOpacity(0.6));

            final int numSpikes = 64;
            final Paint flarePaint = Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8
              ..strokeCap = StrokeCap.round;

            for (int i = 0; i < numSpikes; i++) {
              final double angle = (i / numSpikes) * 2 * math.pi + time * 0.2;
              final double amp = amplitudes[i % 10] / 38.0;
              final double flareLength =
                  8.0 + amp * 32.0 * (1.0 + normalizedAmp * 0.5);

              final double startX = cx + math.cos(angle) * baseRadius;
              final double startY = cy + math.sin(angle) * baseRadius;
              final double endX =
                  cx + math.cos(angle) * (baseRadius + flareLength);
              final double endY =
                  cy + math.sin(angle) * (baseRadius + flareLength);

              flarePaint.color = Color.lerp(barColor, peakColor, (i % 8) / 8.0)!
                  .withOpacity(0.85);
              canvas.drawLine(
                  Offset(startX, startY), Offset(endX, endY), flarePaint);
            }
          }
        }
        break;

      case VisualizerStyle.vortexOrbit:
        {
          final double cx = w / 2;
          final double cy = h / 2;
          final int dotsCount = 24;
          final Paint dotPaint = Paint()..style = PaintingStyle.fill;

          // Double helix orbit orbits
          for (int layer = 0; layer < 2; layer++) {
            final double direction = layer == 0 ? 1.0 : -1.0;
            final double orbitRadius =
                40.0 + layer * 20.0 + normalizedAmp * 15.0;
            final Color layerColor = layer == 0 ? barColor : peakColor;

            for (int i = 0; i < dotsCount; i++) {
              final double progressPct = i / dotsCount;
              final double angle =
                  (progressPct * 2 * math.pi) + (time * 0.8 * direction);

              // Modulate radius of the dot by amplitude
              final double amp = amplitudes[i % 10] / 38.0;
              final double dotSize = 2.0 + amp * 5.0;

              // Helix modulation (3D wave projection)
              final double xOffset = math.cos(angle) * orbitRadius * 1.5;
              final double yOffset = math.sin(angle) * orbitRadius * 0.85 +
                  math.sin(time * 3 + i) * 6.0;

              dotPaint.color =
                  layerColor.withOpacity(0.2 + 0.8 * (1.0 - progressPct));
              canvas.drawCircle(
                  Offset(cx + xOffset, cy + yOffset), dotSize, dotPaint);
            }
          }
        }
        break;

      case VisualizerStyle.rippleWaves:
        {
          // Draw 3 layers of translucent overlapping liquid bezier waves
          for (int layer = 0; layer < 3; layer++) {
            final Path path = Path();
            path.moveTo(0, h);

            final double baseHeight = h * 0.45 + (layer * 12.0);
            final double phase = time * 2.5 + (layer * 2.1);
            final double ampFactor =
                (8.0 + layer * 6.0) * (0.2 + normalizedAmp * 1.5);

            path.lineTo(0, baseHeight);

            final int steps = 15;
            for (int i = 0; i <= steps; i++) {
              final double pct = i / steps;
              final double dx = pct * w;

              // Modulate wave height using amplitude spectrum bands
              final double amp = amplitudes[i % 10] / 38.0;
              final double dy = baseHeight -
                  (amp * ampFactor) -
                  (math.sin(pct * 3 * math.pi + phase) * 15.0);
              path.lineTo(dx, dy);
            }

            path.lineTo(w, h);
            path.close();

            final Paint wavePaint = Paint()
              ..style = PaintingStyle.fill
              ..color = Color.lerp(barColor, peakColor, layer / 2.0)!
                  .withOpacity(0.18 + 0.12 * layer);

            canvas.drawPath(path, wavePaint);
          }
        }
        break;

      case VisualizerStyle.particleWaveFlow:
        {
          // Draw a gorgeous glowing bezier wave with colorful particles flowing on it
          final Paint wavePaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..color = barColor;

          final Path path = Path();
          final double baseHeight = h * 0.5;
          path.moveTo(0, baseHeight);

          final int steps = 20;
          final List<Offset> points = [];
          for (int i = 0; i <= steps; i++) {
            final double pct = i / steps;
            final double dx = pct * w;
            final double amp = amplitudes[i % 10] / 38.0;

            // Multiple sine overlays for high-complexity fluid physics look
            final double dy = baseHeight -
                (amp * 45.0 * (1.0 + normalizedAmp)) -
                (math.sin(pct * 4 * math.pi + time * 3.0) * 20.0);
            if (i == 0) {
              path.moveTo(dx, dy);
            } else {
              path.lineTo(dx, dy);
            }
            points.add(Offset(dx, dy));
          }
          canvas.drawPath(path, wavePaint);

          // Now paint floating energetic particles along the wave coordinates
          final Paint particlePaint = Paint()..style = PaintingStyle.fill;
          for (int i = 0; i < points.length; i++) {
            final pt = points[i];
            final double amp = amplitudes[i % 10] / 38.0;
            final double particleSize = 3.0 + amp * 9.0;

            // Neon glowing particles
            particlePaint.color =
                Color.lerp(barColor, peakColor, i / points.length)!
                    .withOpacity(0.4 + 0.6 * math.sin(time * 5 + i).abs());

            // Subtle floating offset
            final double yOffset = math.sin(time * 4 + i) * (5.0 + amp * 12.0);
            canvas.drawCircle(
                Offset(pt.dx, pt.dy + yOffset), particleSize, particlePaint);

            // Double outline glow
            canvas.drawCircle(
              Offset(pt.dx, pt.dy + yOffset),
              particleSize + 4.0,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.0
                ..color = peakColor.withOpacity(0.25 * (1.0 - (i % 3) * 0.2)),
            );
          }
        }
        break;

      case VisualizerStyle.cosmicTunnel:
        {
          final program = cosmicTunnelProgram;
          if (program != null) {
            final shader = program.fragmentShader();
            shader.setFloat(0, w);
            shader.setFloat(1, h);
            shader.setFloat(2, time);
            shader.setFloat(3, beat.clamp(0.0, 1.0));
            for (int i = 0; i < 10; i++) {
              final v = (i < amplitudes.length)
                  ? (amplitudes[i] / 38.0).clamp(0.0, 1.0)
                  : 0.0;
              shader.setFloat(4 + i, v);
            }
            final paint = Paint()..shader = shader;
            canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
          } else {
            // Fallback: 3D starfield tunnel
            final double cx = w / 2;
            final double cy = h / 2;
            final Paint starPaint = Paint()..style = PaintingStyle.fill;

            // Paint cosmic vortex lines (tunnel guidelines)
            final Paint linePaint = Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8
              ..color = barColor.withOpacity(0.12);
            for (int i = 0; i < 8; i++) {
              final double angle = (i / 8) * 2 * math.pi + time * 0.1;
              canvas.drawLine(
                Offset(cx, cy),
                Offset(cx + math.cos(angle) * w, cy + math.sin(angle) * h),
                linePaint,
              );
            }

            // Render active reactive 3D starfield tunnel
            for (final star in stars) {
              star.update(normalizedAmp * 0.2);
              if (star.z <= 0) continue;

              final double screenX = cx + (star.x * w) / star.z;
              final double screenY = cy + (star.y * h) / star.z;

              if (screenX < 0 || screenX > w || screenY < 0 || screenY > h)
                continue;

              final double size = (1.2 - star.z) * (3.5 + normalizedAmp * 8.0);
              final double opacity = (1.0 - star.z).clamp(0.0, 1.0);

              starPaint.color = Color.lerp(
                      barColor, peakColor, (star.z * 2.0).clamp(0.0, 1.0))!
                  .withOpacity(opacity * (0.35 + normalizedAmp * 0.65));

              canvas.drawCircle(Offset(screenX, screenY), size, starPaint);

              if (star.z < 0.4) {
                final double tailX = cx + (star.x * w) / (star.z + 0.05);
                final double tailY = cy + (star.y * h) / (star.z + 0.05);
                canvas.drawLine(
                  Offset(screenX, screenY),
                  Offset(tailX, tailY),
                  Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = size * 0.4
                    ..color = peakColor.withOpacity(opacity * 0.35),
                );
              }
            }
          }
        }
        break;

      case VisualizerStyle.orbitalGlow:
        {
          final double cx = w / 2;
          final double cy = h / 2;
          final int ringsCount = 4;
          final Paint ringPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;

          for (int i = 0; i < ringsCount; i++) {
            final double amp = amplitudes[i % 10] / 38.0;
            final double radius =
                30.0 + i * 28.0 + (amp * 20.0) * (1.0 + normalizedAmp);
            final double opacity = (0.8 - (i * 0.15)).clamp(0.1, 1.0);

            ringPaint.color =
                Color.lerp(barColor, peakColor, i / (ringsCount - 1))!
                    .withOpacity(opacity);
            canvas.drawCircle(Offset(cx, cy), radius, ringPaint);

            final int particlesOnRing = 3 + i * 2;
            final Paint pPaint = Paint()..style = PaintingStyle.fill;
            for (int j = 0; j < particlesOnRing; j++) {
              final double angle =
                  (j / particlesOnRing) * 2 * math.pi + time * (0.4 + i * 0.15);
              final double px = cx + math.cos(angle) * radius;
              final double py = cy + math.sin(angle) * radius;
              pPaint.color = peakColor.withOpacity(opacity);
              canvas.drawCircle(Offset(px, py), 3.5 + amp * 3.0, pPaint);

              canvas.drawCircle(
                Offset(px, py),
                6.0 + amp * 5.0,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.0
                  ..color = barColor.withOpacity(opacity * 0.4),
              );
            }
          }
        }
        break;

      case VisualizerStyle.frequencyLaser:
        {
          final int numLasers = 12;
          final double spacing = w / (numLasers + 1);

          for (int i = 0; i < numLasers; i++) {
            final double amp = amplitudes[i % 10] / 38.0;
            final double dx = spacing * (i + 1);
            final double laserHeight =
                h * 0.8 * amp * (0.5 + normalizedAmp * 0.5);

            final Rect rect = Rect.fromLTRB(dx - 3, h - laserHeight, dx + 3, h);
            final Paint beamPaint = Paint()
              ..shader = ui.Gradient.linear(
                Offset(dx, h - laserHeight),
                Offset(dx, h),
                [
                  peakColor.withOpacity(0.9),
                  barColor.withOpacity(0.4),
                  Colors.transparent,
                ],
                [0.0, 0.7, 1.0],
              );
            canvas.drawRRect(
                RRect.fromRectAndRadius(rect, const Radius.circular(3)),
                beamPaint);

            canvas.drawLine(
              Offset(dx, h - laserHeight),
              Offset(dx, h),
              Paint()
                ..color = Colors.white.withOpacity(0.9)
                ..strokeWidth = 1.0
                ..strokeCap = StrokeCap.round,
            );

            canvas.drawCircle(
              Offset(dx, h),
              8.0 + amp * 8.0,
              Paint()
                ..color = barColor.withOpacity(0.35 * (1.0 + normalizedAmp)),
            );
          }
        }
        break;

      case VisualizerStyle.dnaHelix:
        {
          final double cx = w / 2;
          final int nodes = 18;
          final double nodeSpacing = h / (nodes + 1);
          final Paint dotPaint = Paint()..style = PaintingStyle.fill;
          final Paint linkPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2;

          for (int i = 0; i < nodes; i++) {
            final double amp = amplitudes[i % 10] / 38.0;
            final double dy = nodeSpacing * (i + 1);
            final double angle = (i * 0.4) + time * 2.2;

            final double offsetDist = 35.0 + amp * 25.0;
            final double x1 = cx + math.cos(angle) * offsetDist;
            final double x2 = cx - math.cos(angle) * offsetDist;

            linkPaint.color =
                Color.lerp(barColor, peakColor, i / nodes)!.withOpacity(0.35);
            canvas.drawLine(Offset(x1, dy), Offset(x2, dy), linkPaint);

            dotPaint.color = barColor.withOpacity(0.85);
            canvas.drawCircle(Offset(x1, dy), 4.0 + amp * 4.0, dotPaint);
            canvas.drawCircle(
              Offset(x1, dy),
              8.0 + amp * 6.0,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.8
                ..color = barColor.withOpacity(0.3),
            );

            dotPaint.color = peakColor.withOpacity(0.85);
            canvas.drawCircle(Offset(x2, dy), 4.0 + amp * 4.0, dotPaint);
            canvas.drawCircle(
              Offset(x2, dy),
              8.0 + amp * 6.0,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.8
                ..color = peakColor.withOpacity(0.3),
            );
          }
        }
        break;

      case VisualizerStyle.audioMatrixGrid:
        {
          final int cols = 10;
          final int rows = 8;
          final double gridW = w - 16;
          final double cellW = gridW / cols;
          final double cellH = h / rows;
          final Paint cellPaint = Paint()..style = PaintingStyle.fill;

          for (int col = 0; col < cols; col++) {
            final double amp = amplitudes[col % 10] / 38.0;
            final int activeRows = (amp * rows * (0.8 + normalizedAmp * 0.2))
                .round()
                .clamp(1, rows);

            for (int row = 0; row < rows; row++) {
              final bool isActive = row < activeRows;
              final double dx = 8.0 + col * cellW;
              final double dy = h - (row + 1) * cellH;

              final Rect cellRect =
                  Rect.fromLTWH(dx + 2, dy + 2, cellW - 4, cellH - 4);
              final double rowPct = row / rows;
              final Color baseCellColor =
                  Color.lerp(barColor, peakColor, rowPct)!;

              if (isActive) {
                cellPaint.color = baseCellColor.withOpacity(0.85);
                canvas.drawRRect(
                    RRect.fromRectAndRadius(cellRect, const Radius.circular(2)),
                    cellPaint);

                canvas.drawRRect(
                  RRect.fromRectAndRadius(
                      cellRect.inflate(1.5), const Radius.circular(3)),
                  Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1.0
                    ..color = baseCellColor.withOpacity(0.4),
                );
              } else {
                cellPaint.color = baseCellColor.withOpacity(0.08);
                canvas.drawRRect(
                    RRect.fromRectAndRadius(cellRect, const Radius.circular(2)),
                    cellPaint);
              }
            }
          }
        }
        break;

      case VisualizerStyle.blackHoleStars:
        {
          final double cx = w / 2;
          final double cy = h / 2;
          final double maxRadius = math.max(cx, cy) * 1.2;

          final double avgAmp =
              amplitudes.fold(0.0, (sum, val) => sum + val) / amplitudes.length;
          final double amp = avgAmp / 38.0;
          final double bhRadius = 15.0 + amp * 22.0;

          // 1. Accretion Disk Glow (Layered concentric glowing pulses)
          final Paint glowPaint = Paint()..style = PaintingStyle.fill;
          glowPaint.color = barColor.withOpacity(0.12 + amp * 0.15);
          canvas.drawCircle(Offset(cx, cy), bhRadius * 2.8, glowPaint);

          glowPaint.color = peakColor.withOpacity(0.24 + amp * 0.2);
          canvas.drawCircle(Offset(cx, cy), bhRadius * 1.8, glowPaint);

          glowPaint.color = Colors.white.withOpacity(0.45);
          canvas.drawCircle(Offset(cx, cy), bhRadius * 1.2, glowPaint);

          // 2. Accretion Disk Swirling Gas Rings
          final Paint ringPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 + amp * 2.5
            ..color = barColor.withOpacity(0.35 + amp * 0.3);
          canvas.drawCircle(Offset(cx, cy), bhRadius + 4.0, ringPaint);

          // 3. Falling Spaghettified Stars
          final int starCount = 36;
          final Paint starPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;

          for (int i = 0; i < starCount; i++) {
            final double starAmp = amplitudes[i % 10] / 38.0;
            final double radius = (maxRadius -
                (time * (35.0 + starAmp * 85.0) + i * 22.0) % maxRadius);

            // Do not paint stars that are already consumed inside the event horizon
            if (radius <= bhRadius + 2.0) continue;

            final double angle =
                i * 0.8 + (maxRadius - radius) * 0.016 + time * 1.4;

            final double sx = cx + math.cos(angle) * radius;
            final double sy = cy + math.sin(angle) * radius;

            // Prev position for spaghettification tail stretching
            final double radiusPrev = radius + 6.0 + starAmp * 15.0;
            final double anglePrev =
                i * 0.8 + (maxRadius - radiusPrev) * 0.016 + time * 1.4;
            final double sxPrev = cx + math.cos(anglePrev) * radiusPrev;
            final double syPrev = cy + math.sin(anglePrev) * radiusPrev;

            final double proximityFactor =
                (radius - bhRadius) / (maxRadius - bhRadius);
            final double opacity =
                (proximityFactor * 0.8 + 0.2).clamp(0.0, 1.0);

            final Color starColor = Color.lerp(barColor, Colors.white, 0.45)!;
            starPaint.color = starColor.withOpacity(opacity);
            starPaint.strokeWidth = 1.0 + (1.0 - proximityFactor) * 2.5;

            canvas.drawLine(Offset(sx, sy), Offset(sxPrev, syPrev), starPaint);
          }

          // 4. Central Singularity (Pure Void Event Horizon)
          final Paint singularityPaint = Paint()
            ..color = Colors.black
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(cx, cy), bhRadius, singularityPaint);
        }
        break;

      case VisualizerStyle.shaderAppsRing:
        {
          final program = appsRingProgram;
          if (program != null) {
            final shader = program.fragmentShader();
            // Uniform order must match shaders/apps_ring.frag.
            shader.setFloat(0, w);
            shader.setFloat(1, h);
            shader.setFloat(2, time);
            shader.setFloat(3, beat.clamp(0.0, 1.0));
            for (int i = 0; i < 10; i++) {
              final v = (i < amplitudes.length)
                  ? (amplitudes[i] / 38.0).clamp(0.0, 1.0)
                  : 0.0;
              shader.setFloat(4 + i, v);
            }
            final paint = Paint()..shader = shader;
            canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
          } else {
            // Fallback: simple ring.
            final double cx = w / 2;
            final double cy = h / 2;
            final double baseRadius = 40.0 + normalizedAmp * 15.0;
            final Paint ringPaint = Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.0
              ..color = barColor.withOpacity(0.8);
            canvas.drawCircle(Offset(cx, cy), baseRadius, ringPaint);
          }
        }
        break;

      case VisualizerStyle.shaderSteamBars:
        {
          final program = steamBarsProgram;
          if (program != null) {
            final shader = program.fragmentShader();
            // Uniform order must match shaders/steam_bars.frag.
            shader.setFloat(0, w);
            shader.setFloat(1, h);
            shader.setFloat(2, time);
            shader.setFloat(3, beat.clamp(0.0, 1.0));
            for (int i = 0; i < 10; i++) {
              final v = (i < amplitudes.length)
                  ? (amplitudes[i] / 38.0).clamp(0.0, 1.0)
                  : 0.0;
              shader.setFloat(4 + i, v);
            }
            canvas.drawRect(
                Rect.fromLTWH(0, 0, w, h), Paint()..shader = shader);
          } else {
            // Fallback: classic mirrored bars.
            final Paint p = Paint()
              ..color = barColor.withOpacity(0.8)
              ..style = PaintingStyle.fill;
            final double midY = h * 0.52;
            final int bars = 32;
            final double bw = w / bars;
            for (int i = 0; i < bars; i++) {
              final double v =
                  (amplitudes[i % amplitudes.length] / 38.0).clamp(0.0, 1.0);
              final double bh = (h * 0.35) * v;
              final Rect top = Rect.fromLTWH(i * bw + 1, midY - bh, bw - 2, bh);
              final Rect bot = Rect.fromLTWH(i * bw + 1, midY, bw - 2, bh);
              canvas.drawRect(top, p);
              canvas.drawRect(bot, p..color = barColor.withOpacity(0.25));
            }
          }
        }
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VisualizerPainter oldDelegate) {
    return true;
  }
}

// ---------------------------------------------------------
// Upgraded 10 Dials S60 D-Pad Joystick Console
// ---------------------------------------------------------

class _S60DpadCockpitConsole extends StatelessWidget {
  final PlayerSkin skin;
  final bool isPlaying;
  final DialStyle dialStyle;
  final double animationTime;
  final bool isShuffle;
  final ja.LoopMode loopMode;
  final VoidCallback onPlayPause;
  final VoidCallback onVolumeUp;
  final VoidCallback onVolumeDown;
  final VoidCallback onSkipPrevious;
  final VoidCallback onSkipNext;
  final VoidCallback onFastRewind;
  final VoidCallback onFastForward;
  final VoidCallback onToggleShuffle;
  final VoidCallback onToggleRepeat;
  final VoidCallback onCycleDialStyle;
  final VoidCallback onCycleSkin;
  final double bgOpacity;

  const _S60DpadCockpitConsole({
    required this.skin,
    required this.isPlaying,
    required this.dialStyle,
    required this.animationTime,
    required this.isShuffle,
    required this.loopMode,
    required this.onPlayPause,
    required this.onVolumeUp,
    required this.onVolumeDown,
    required this.onSkipPrevious,
    required this.onSkipNext,
    required this.onFastRewind,
    required this.onFastForward,
    required this.onToggleShuffle,
    required this.onToggleRepeat,
    required this.onCycleDialStyle,
    required this.onCycleSkin,
    required this.bgOpacity,
  });

  Color getDialIconColor() => skin.buttonIconColor;
  Color getDialTextColor() => skin.textColor;
  Color getDialButtonFaceColor() => skin.buttonFaceColor;

  @override
  Widget build(BuildContext context) {
    if (dialStyle == DialStyle.digitalToggles) {
      return _buildDigitalTogglesConsole(context);
    }

    final bool isWide = dialStyle == DialStyle.rectangular;

    // If skeuomorphic (not flat) and circular, render the gorgeous iPod click-wheel console
    if (!isWide && !skin.isFlat) {
      return _buildSkeuomorphicClickWheel(context);
    }

    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final double width = isLandscape ? 350.0 : (isWide ? 360.0 : 260.0);
    final double height = isWide ? 180.0 : 260.0;
    final Color iconCol = getDialIconColor();

    final double skipTop = (height - (isWide ? 38 : 50)) / 2;

    return Center(
      child: Container(
        width: width,
        height: height,
        decoration: _buildOuterDialChassis(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // North: Vol Up
            Positioned(
              top: isWide ? 2 : 4,
              child: _DpadTactileButton(
                icon: Icons.add_rounded,
                color: iconCol,
                buttonFaceColor: getDialButtonFaceColor(),
                onTap: onVolumeUp,
                tooltip: 'VOL +',
                dense: isWide,
              ),
            ),

            // South: Vol Down
            Positioned(
              bottom: isWide ? 2 : 4,
              child: _DpadTactileButton(
                icon: Icons.remove_rounded,
                color: iconCol,
                buttonFaceColor: getDialButtonFaceColor(),
                onTap: onVolumeDown,
                tooltip: 'VOL -',
                dense: isWide,
              ),
            ),

            // West: Prev skip (Vertically Centered)
            Positioned(
              left: isWide ? 2 : 4,
              top: skipTop,
              child: _DpadTactileButton(
                icon: Icons.skip_previous_rounded,
                color: iconCol,
                buttonFaceColor: getDialButtonFaceColor(),
                onTap: onSkipPrevious,
                tooltip: 'PREV',
                dense: isWide,
              ),
            ),

            // East: Next skip (Vertically Centered)
            Positioned(
              right: isWide ? 2 : 4,
              top: skipTop,
              child: _DpadTactileButton(
                icon: Icons.skip_next_rounded,
                color: iconCol,
                buttonFaceColor: getDialButtonFaceColor(),
                onTap: onSkipNext,
                tooltip: 'NEXT',
                dense: isWide,
              ),
            ),

            // Diagonal top-left: Shuffle toggle (was EQ)
            Positioned(
              left: isWide ? 16 : 30,
              top: isWide ? 4 : 30,
              child: _DpadMicroToggle(
                icon: Icons.shuffle_rounded,
                color: isShuffle
                    ? getDialTextColor()
                    : getDialTextColor().withOpacity(0.35),
                buttonFaceColor: getDialButtonFaceColor(),
                onPressed: onToggleShuffle,
                label: 'SHUF',
                dense: isWide,
              ),
            ),

            // Diagonal top-right: Repeat toggle (was VIS)
            Positioned(
              right: isWide ? 16 : 30,
              top: isWide ? 4 : 30,
              child: _DpadMicroToggle(
                icon: loopMode == ja.LoopMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                color: loopMode != ja.LoopMode.off
                    ? getDialTextColor()
                    : getDialTextColor().withOpacity(0.35),
                buttonFaceColor: getDialButtonFaceColor(),
                onPressed: onToggleRepeat,
                label: loopMode == ja.LoopMode.one
                    ? 'REP 1'
                    : (loopMode == ja.LoopMode.all ? 'REP ALL' : 'REP OFF'),
                dense: isWide,
              ),
            ),

            // Diagonal bottom-left: Seek Rewind (Same size as EQ/VIS)
            Positioned(
              left: isWide ? 16 : 30,
              bottom: isWide ? 4 : 30,
              child: _DpadMicroToggle(
                icon: Icons.fast_rewind_rounded,
                color: getDialTextColor().withOpacity(0.85),
                buttonFaceColor: getDialButtonFaceColor(),
                onPressed: onFastRewind,
                label: 'REW',
                dense: isWide,
              ),
            ),

            // Diagonal bottom-right: Seek Forward (Same size as EQ/VIS)
            Positioned(
              right: isWide ? 16 : 30,
              bottom: isWide ? 4 : 30,
              child: _DpadMicroToggle(
                icon: Icons.fast_forward_rounded,
                color: getDialTextColor().withOpacity(0.85),
                buttonFaceColor: getDialButtonFaceColor(),
                onPressed: onFastForward,
                label: 'FF',
                dense: isWide,
              ),
            ),

            // Play/Pause center button
            Align(
              alignment: Alignment.center,
              child: _buildCenterPlayPad(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeuomorphicClickWheel(BuildContext context) {
    final Color iconCol = getDialIconColor();
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      width: isLandscape ? 350.0 : double.infinity,
      height: 220.0,
      decoration: BoxDecoration(
        borderRadius: isLandscape
            ? const BorderRadius.all(Radius.circular(20.0))
            : const BorderRadius.only(
                topLeft: Radius.circular(30.0),
                topRight: Radius.circular(30.0),
              ),
        border: isLandscape
            ? Border(
                top: BorderSide(
                    color: skin.outerBorderColor.withOpacity(0.5), width: 2),
                left: BorderSide(
                    color: skin.outerBorderColor.withOpacity(0.5), width: 2),
                right: BorderSide(
                    color: skin.outerBorderColor.withOpacity(0.5), width: 2),
              )
            : Border(
                top: BorderSide(
                  color: skin.outerBorderColor.withOpacity(0.5),
                  width: 2,
                ),
              ),
        color: skin.panelBgColor.withOpacity(bgOpacity),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Corner buttons outside the main wheel

          // Top-Left corner: Fast Backward
          Positioned(
            left: 20,
            top: 8,
            child: _buildCornerButton(
              icon: Icons.fast_rewind_rounded,
              onTap: onFastRewind,
              tooltip: 'FAST BACKWARD',
            ),
          ),

          // Top-Right corner: Fast Forward
          Positioned(
            right: 20,
            top: 8,
            child: _buildCornerButton(
              icon: Icons.fast_forward_rounded,
              onTap: onFastForward,
              tooltip: 'FAST FORWARD',
            ),
          ),

          // Bottom-Left corner: Repeat toggle
          Positioned(
            left: 20,
            bottom: 8,
            child: _buildCornerButton(
              icon: loopMode == ja.LoopMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              onTap: onToggleRepeat,
              isActive: loopMode != ja.LoopMode.off,
              tooltip: loopMode == ja.LoopMode.one
                  ? 'REPEAT: ONE'
                  : (loopMode == ja.LoopMode.all
                      ? 'REPEAT: ALL'
                      : 'REPEAT: OFF'),
            ),
          ),

          // Bottom-Right corner: Shuffle toggle
          Positioned(
            right: 20,
            bottom: 8,
            child: _buildCornerButton(
              icon: Icons.shuffle_rounded,
              onTap: onToggleShuffle,
              isActive: isShuffle,
              tooltip: isShuffle ? 'SHUFFLE: ON' : 'SHUFFLE: OFF',
            ),
          ),

          // Main central iPod click-wheel circle
          Container(
            width: 204,
            height: 204,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: skin.outerBorderColor.withOpacity(0.85), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
              gradient: SweepGradient(
                colors: [
                  skin.buttonFaceColor,
                  skin.buttonFaceColor.withOpacity(0.8),
                  skin.buttonFaceColor.withOpacity(0.55),
                  skin.buttonFaceColor.withOpacity(0.8),
                  skin.buttonFaceColor,
                ],
                stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Top: Vol Up
                Positioned(
                  top: 5,
                  child: _WheelCardinalButton(
                    icon: Icons.add_rounded,
                    onTap: onVolumeUp,
                    tooltip: 'VOL +',
                    iconColor: iconCol,
                  ),
                ),

                // Bottom: Vol Down
                Positioned(
                  bottom: 5,
                  child: _WheelCardinalButton(
                    icon: Icons.remove_rounded,
                    onTap: onVolumeDown,
                    tooltip: 'VOL -',
                    iconColor: iconCol,
                  ),
                ),

                // Left: Skip Previous (Long press: REW)
                Positioned(
                  left: 5,
                  child: _WheelCardinalButton(
                    icon: Icons.skip_previous_rounded,
                    onTap: onSkipPrevious,
                    onLongPress: onFastRewind,
                    tooltip: 'PREV (Hold: REW)',
                    iconColor: iconCol,
                  ),
                ),

                // Right: Skip Next (Long press: FF)
                Positioned(
                  right: 5,
                  child: _WheelCardinalButton(
                    icon: Icons.skip_next_rounded,
                    onTap: onSkipNext,
                    onLongPress: onFastForward,
                    tooltip: 'NEXT (Hold: FF)',
                    iconColor: iconCol,
                  ),
                ),

                // Center circular Play/Pause button
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.black.withOpacity(0.45), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        )
                      ],
                      gradient: LinearGradient(
                        colors: [
                          skin.buttonFaceColor.withOpacity(0.9),
                          skin.buttonFaceColor,
                          skin.buttonFaceColor.withOpacity(0.65),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onPlayPause,
                        child: Center(
                          child: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: iconCol,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
    required String tooltip,
  }) {
    return _TactileButtonWrapper(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border:
                Border.all(color: Colors.black.withOpacity(0.45), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
            gradient: LinearGradient(
              colors: [
                skin.buttonFaceColor,
                skin.buttonFaceColor.withOpacity(0.7),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              color: isActive
                  ? skin.textColor
                  : skin.buttonIconColor.withOpacity(0.7),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDigitalTogglesConsole(BuildContext context) {
    final Color activeCol = getDialTextColor();
    final Color iconCol = getDialIconColor();

    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Container(
      width: double.infinity,
      margin: isLandscape
          ? const EdgeInsets.symmetric(horizontal: 5.0)
          : const EdgeInsets.symmetric(horizontal: 16.0),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: skin.panelBgColor.withOpacity(bgOpacity),
        border: Border.all(color: skin.outerBorderColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isShuffle ? activeCol : Colors.grey[800],
                      boxShadow: isShuffle
                          ? [BoxShadow(color: activeCol, blurRadius: 4)]
                          : [],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'SHUF',
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 8,
                        color:
                            isShuffle ? activeCol : activeCol.withOpacity(0.4),
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: loopMode != ja.LoopMode.off
                          ? activeCol
                          : Colors.grey[800],
                      boxShadow: loopMode != ja.LoopMode.off
                          ? [BoxShadow(color: activeCol, blurRadius: 4)]
                          : [],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'REP',
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 8,
                        color: loopMode != ja.LoopMode.off
                            ? activeCol
                            : activeCol.withOpacity(0.4),
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onCycleDialStyle,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: activeCol.withOpacity(0.3), width: 0.8),
                    color: Colors.black.withOpacity(0.3),
                  ),
                  child: Text(
                    'SYNTH RACK',
                    style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 8,
                        color: activeCol,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDigitalRackButton(
                icon: Icons.remove_rounded,
                label: 'V-',
                onTap: onVolumeDown,
                color: activeCol,
              ),
              _buildDigitalRackButton(
                icon: Icons.skip_previous_rounded,
                label: 'PRV',
                onTap: onSkipPrevious,
                color: activeCol,
              ),
              GestureDetector(
                onTap: onPlayPause,
                child: Container(
                  width: 58,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: getDialButtonFaceColor(),
                    border: Border.all(color: activeCol, width: 2.0),
                    boxShadow: [
                      BoxShadow(
                        color: activeCol.withOpacity(0.18),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isPlaying ? activeCol : Colors.transparent,
                          border: Border.all(
                              color: activeCol.withOpacity(0.5), width: 1.0),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: activeCol,
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isPlaying ? 'RUN' : 'HALT',
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 8,
                            color: activeCol,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              _buildDigitalRackButton(
                icon: Icons.skip_next_rounded,
                label: 'NXT',
                onTap: onSkipNext,
                color: activeCol,
              ),
              _buildDigitalRackButton(
                icon: Icons.add_rounded,
                label: 'V+',
                onTap: onVolumeUp,
                color: activeCol,
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRackMiniToggle(
                  label: 'SHUF',
                  isActive: isShuffle,
                  onTap: onToggleShuffle,
                  color: activeCol),
              _buildRackMiniToggle(
                  label: 'REW',
                  isActive: false,
                  onTap: onFastRewind,
                  color: activeCol),
              _buildRackMiniToggle(
                  label: 'FF',
                  isActive: false,
                  onTap: onFastForward,
                  color: activeCol),
              _buildRackMiniToggle(
                  label: 'LOOP',
                  isActive: loopMode != ja.LoopMode.off,
                  onTap: onToggleRepeat,
                  color: activeCol),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalRackButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return _TactileButtonWrapper(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: getDialButtonFaceColor(),
          border: Border.all(color: color.withOpacity(0.5), width: 1.0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 8,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRackMiniToggle({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required Color color,
  }) {
    return _TactileButtonWrapper(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: isActive
              ? color.withOpacity(0.12)
              : Colors.black.withOpacity(0.25),
          border: Border.all(
              color: isActive ? color : color.withOpacity(0.35), width: 1.0),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 8,
            color: isActive ? color : color.withOpacity(0.7),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildOuterDialChassis() {
    if (skin.isFlat) {
      switch (dialStyle) {
        case DialStyle.circular:
          return BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: skin.outerBorderColor, width: 2),
            color: skin.panelBgColor.withOpacity(bgOpacity),
          );
        case DialStyle.rectangular:
        case DialStyle.digitalToggles:
          return BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: skin.outerBorderColor, width: 2),
            color: skin.panelBgColor.withOpacity(bgOpacity),
          );
      }
    }

    switch (dialStyle) {
      case DialStyle.circular:
        return BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: skin.outerBorderColor, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.65),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
          gradient: SweepGradient(
            colors: [
              skin.panelBgColor.withOpacity(bgOpacity),
              skin.outerBorderColor.withOpacity(bgOpacity),
              skin.panelBgColor.withOpacity(bgOpacity),
              skin.outerBorderColor.withOpacity(bgOpacity),
              skin.panelBgColor.withOpacity(bgOpacity),
            ],
            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        );

      case DialStyle.rectangular:
      case DialStyle.digitalToggles:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: skin.outerBorderColor, width: 3.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.7),
              blurRadius: 16,
              offset: const Offset(0, 8),
            )
          ],
          gradient: LinearGradient(
            colors: [
              skin.panelBgColor.withOpacity(bgOpacity),
              skin.buttonFaceColor.withOpacity(0.3 * bgOpacity),
              skin.outerBorderColor.withOpacity(bgOpacity),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        );
    }
  }

  Widget _buildCenterPlayPad() {
    return Container(
      width: 82,
      height: 82,
      decoration: skin.isFlat
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: skin.outerBorderColor, width: 2),
              color: getDialButtonFaceColor(),
            )
          : BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.black.withOpacity(0.65), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
              color: getDialButtonFaceColor(),
              gradient: LinearGradient(
                colors: [
                  getDialButtonFaceColor(),
                  getDialButtonFaceColor().withOpacity(0.7),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
      child: _CenterPlayInkwell(
        isPlaying: isPlaying,
        skin: skin,
        onPlayPause: onPlayPause,
        iconColor: getDialIconColor(),
        textColor: getDialTextColor(),
      ),
    );
  }
}

class _WheelCardinalButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String tooltip;
  final Color iconColor;
  final double size;
  final double iconSize;

  const _WheelCardinalButton({
    required this.icon,
    required this.onTap,
    this.onLongPress,
    required this.tooltip,
    required this.iconColor,
    this.size = 52,
    this.iconSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: _TactileButtonWrapper(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: iconColor,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Skeuomorphic Equalizer Panel Overlay Console
// ---------------------------------------------------------

class _SkeuomorphicEqualizerPanel extends StatelessWidget {
  final PlayerSkin skin;
  final List<double> bands;
  final String activePreset;
  final Function(int, double) onBandChanged;
  final ValueChanged<String> onPresetSelected;
  final VoidCallback onClose;
  final double bassValue; // 0.0-1.0 hardware knob
  final double stereoValue; // 0.0-1.0 hardware knob
  final ValueChanged<double> onBassChanged;
  final ValueChanged<double> onStereoChanged;
  final double minDb;
  final double maxDb;
  final List<String> frequencyLabels;
  final List<String> presetNames;

  const _SkeuomorphicEqualizerPanel({
    required this.skin,
    required this.bands,
    required this.activePreset,
    required this.onBandChanged,
    required this.onPresetSelected,
    required this.onClose,
    required this.bassValue,
    required this.stereoValue,
    required this.onBassChanged,
    required this.onStereoChanged,
    required this.minDb,
    required this.maxDb,
    required this.frequencyLabels,
    required this.presetNames,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    const double knobSize = 88;

    return SafeArea(
      child: Container(
        width: isLandscape ? MediaQuery.of(context).size.width : null,
        height: isLandscape ? MediaQuery.of(context).size.height : null,
        decoration: BoxDecoration(
          borderRadius:
              isLandscape ? BorderRadius.zero : BorderRadius.circular(20),
          border: isLandscape
              ? null
              : Border.all(color: skin.outerBorderColor, width: 2.5),
          color: skin.panelBgColor,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.85), blurRadius: 20),
          ],
          gradient: LinearGradient(
            colors: [skin.panelBgColor, skin.outerBorderColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.only(
          top: 12.0,
          bottom: 12.0,
          left: 14.0,
          right: 14.0,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      'S60 GRAPHIC EQUALIZER',
                      style: TextStyle(
                          color: skin.textColor,
                          fontFamily: 'Orbitron',
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8),
                    ),
                    Positioned(
                      right: 0,
                      child: GestureDetector(
                        onTap: onClose,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.4)),
                          child: Icon(Icons.close_rounded,
                              color: skin.textColor, size: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Bass & Stereo hardware knobs row
              // Active preset display - centered
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PRESET: ',
                      style: TextStyle(
                          color: skin.textMutedColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10),
                    ),
                    Text(
                      activePreset.toUpperCase(),
                      style: TextStyle(
                          color: skin.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Presets - equal width badges distributed evenly
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.41,
                children: presetNames.map((String name) {
                  final selected = name == activePreset;
                  final isPremium = ['Bose Signature', 'Beats Audio', 'Harman Kardon', 'Sony ClearBass', 'Sennheiser Club'].contains(name);
                  
                  return GestureDetector(
                    onTap: () => onPresetSelected(name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? skin.textColor.withOpacity(0.3)
                            : isPremium
                                ? Color(0xFF1a472a).withOpacity(0.6)
                                : Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? skin.textColor.withOpacity(0.7)
                              : isPremium
                                  ? Color(0xFF4ade80).withOpacity(0.5)
                                  : skin.textColor.withOpacity(0.2),
                          width: selected ? 1.2 : isPremium ? 1.0 : 0.9,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          name.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? skin.textColor
                                : isPremium
                                    ? Color(0xFF4ade80)
                                    : skin.textColor.withOpacity(0.75),
                            fontFamily: 'monospace',
                            fontSize: 10,
                            fontWeight: selected ? FontWeight.bold : isPremium ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Bass & Stereo hardware knobs - larger and centered
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: skin.textColor.withOpacity(0.15), width: 0.8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SkeuomorphicKnob(
                      value: bassValue,
                      label: 'BASS',
                      accentColor: skin.textColor,
                      size: 110,
                      onChanged: onBassChanged,
                    ),
                    const SizedBox(width: 24),
                    _SkeuomorphicKnob(
                      value: stereoValue,
                      label: 'STEREO',
                      accentColor: skin.textColor,
                      size: 110,
                      onChanged: onStereoChanged,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(bands.length, (index) {
                    return Column(
                      children: [
                        Text(
                          '${bands[index].toInt() > 0 ? "+" : ""}${bands[index].toInt()}dB',
                          style: TextStyle(
                              color: skin.textColor,
                              fontFamily: 'monospace',
                              fontSize: 8,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 2.5,
                                activeTrackColor: skin.textColor,
                                inactiveTrackColor: Colors.black26,
                                thumbColor: skin.textColor,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 5),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 10),
                              ),
                              child: Slider(
                                value: bands[index].clamp(minDb, maxDb),
                                min: minDb,
                                max: maxDb,
                                onChanged: (val) => onBandChanged(index, val),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          index < frequencyLabels.length
                              ? frequencyLabels[index]
                              : '',
                          style: TextStyle(
                              color: skin.textMutedColor,
                              fontFamily: 'monospace',
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Premium Rotating Hardware Knob (Bass & Stereo EQ controls)
// ---------------------------------------------------------

class _SkeuomorphicKnob extends StatefulWidget {
  final double value; // 0.0 to 1.0
  final String label;
  final Color accentColor;
  final ValueChanged<double> onChanged;
  final double size;

  const _SkeuomorphicKnob({
    required this.value,
    required this.label,
    required this.accentColor,
    required this.onChanged,
    this.size = 76,
  });

  @override
  State<_SkeuomorphicKnob> createState() => _SkeuomorphicKnobState();
}

class _SkeuomorphicKnobState extends State<_SkeuomorphicKnob> {
  double _dragStart = 0.0;
  double _valueStart = 0.0;

  // Convert 0.0-1.0 value to rotation angle (-135° to +135°)
  double get _rotationAngle {
    return (-135 + widget.value * 270) * (math.pi / 180);
  }

  void _onPanStart(DragStartDetails details) {
    _dragStart = details.localPosition.dy;
    _valueStart = widget.value;
    HapticFeedback.lightImpact();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final double delta = (_dragStart - details.localPosition.dy) / 120.0;
    final double newValue = (_valueStart + delta).clamp(0.0, 1.0);
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    final Color glowColor = widget.accentColor;
    final double percentDb = (widget.value - 0.5) * 24.0;
    final String dbLabel = percentDb >= 0
        ? '+${percentDb.toStringAsFixed(0)}dB'
        : '${percentDb.toStringAsFixed(0)}dB';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Knob label
        Text(
          widget.label,
          style: TextStyle(
            color: glowColor.withOpacity(0.7),
            fontFamily: 'Orbitron',
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        // Knob body with drag gesture
        GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _KnobPainter(
                rotation: _rotationAngle,
                value: widget.value,
                accentColor: glowColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // dB value below knob
        Text(
          dbLabel,
          style: TextStyle(
            color: glowColor.withOpacity(0.9),
            fontFamily: 'monospace',
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// CustomPainter that draws a premium skeuomorphic rotary knob
class _KnobPainter extends CustomPainter {
  final double rotation;
  final double value;
  final Color accentColor;

  _KnobPainter(
      {required this.rotation, required this.value, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius = math.min(cx, cy) - 2;

    // 1. Outer chrome ring with glow
    final Paint ringPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy),
        radius,
        [
          Colors.white.withOpacity(0.05),
          accentColor.withOpacity(0.25),
          Colors.black.withOpacity(0.6),
        ],
        [0.0, 0.6, 1.0],
      )
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), radius, ringPaint);

    // 2. Knob body (metallic dark with subtle sweep gradient)
    final Paint bodyPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx - radius * 0.2, cy - radius * 0.2),
        radius * 0.95,
        [
          const Color(0xFF555555),
          const Color(0xFF222222),
          const Color(0xFF111111),
        ],
        [0.0, 0.6, 1.0],
      )
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), radius * 0.85, bodyPaint);

    // 3. Active arc track (120 degree range indicator)
    final Paint trackPaint = Paint()
      ..color = accentColor.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    const double startAngle = 135 * (math.pi / 180);
    const double sweepAngle = 270 * (math.pi / 180);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius * 0.88),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // 4. Active fill arc (green/accent colored portion)
    final Paint activePaint = Paint()
      ..shader = ui.Gradient.sweep(
        Offset(cx, cy),
        [accentColor.withOpacity(0.8), accentColor.withOpacity(0.4)],
        [0.0, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius * 0.88),
      startAngle,
      sweepAngle * value,
      false,
      activePaint,
    );

    // 5. Glowing indicator needle (rotates with value)
    final double indicatorX =
        cx + (radius * 0.55) * math.cos(rotation - math.pi / 2);
    final double indicatorY =
        cy + (radius * 0.55) * math.sin(rotation - math.pi / 2);
    final Paint needlePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(cx, cy), Offset(indicatorX, indicatorY), needlePaint);

    // 6. Center dot
    final Paint dotPaint = Paint()
      ..color = accentColor.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(_KnobPainter oldDelegate) =>
      oldDelegate.rotation != rotation || oldDelegate.value != value;
}

// Sub-widgets

class _TactileButtonWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _TactileButtonWrapper({
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<_TactileButtonWrapper> createState() => _TactileButtonWrapperState();
}

class _TactileButtonWrapperState extends State<_TactileButtonWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  void _handleLongPress() {
    _controller.reverse();
    if (widget.onLongPress != null) {
      HapticFeedback.mediumImpact();
      widget.onLongPress!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: widget.onLongPress != null ? _handleLongPress : null,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

class _CenterPlayInkwell extends StatelessWidget {
  final bool isPlaying;
  final PlayerSkin skin;
  final VoidCallback onPlayPause;
  final BorderRadius? borderRadius;
  final Color? iconColor;
  final Color? textColor;

  const _CenterPlayInkwell({
    required this.isPlaying,
    required this.skin,
    required this.onPlayPause,
    this.borderRadius,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeIconColor = iconColor ?? skin.buttonIconColor;
    final activeTextColor = textColor ?? skin.textColor;

    return _TactileButtonWrapper(
      onTap: onPlayPause,
      child: Center(
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: borderRadius == null ? BoxShape.circle : BoxShape.rectangle,
            borderRadius:
                borderRadius != null ? BorderRadius.circular(10) : null,
            color: isPlaying
                ? activeTextColor.withOpacity(0.08)
                : Colors.transparent,
            border: Border.all(
              color: isPlaying
                  ? activeTextColor
                  : activeIconColor.withOpacity(0.35),
              width: 1.5,
            ),
            boxShadow: isPlaying
                ? [
                    BoxShadow(
                        color: activeTextColor.withOpacity(0.3), blurRadius: 6)
                  ]
                : [],
          ),
          child: Center(
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: isPlaying ? activeTextColor : activeIconColor,
              size: 34,
            ),
          ),
        ),
      ),
    );
  }
}

class _DpadTactileButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color buttonFaceColor;
  final VoidCallback onTap;
  final String tooltip;
  final bool dense;

  const _DpadTactileButton({
    required this.icon,
    required this.color,
    required this.buttonFaceColor,
    required this.onTap,
    required this.tooltip,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final double w = dense ? 56 : 66;
    final double h = dense ? 38 : 50;

    return _TactileButtonWrapper(
      onTap: onTap,
      child: Container(
        width: w,
        height: h,
        decoration: const BoxDecoration(
          color: Colors
              .transparent, // Completely flat/transparent style, removing heavy physical button borders and backgrounds
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color.withOpacity(0.95),
              size: dense ? 26 : 32,
            ),
            const SizedBox(height: 1),
            Text(
              tooltip,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: dense ? 7 : 8,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _DpadMicroSeekButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  final bool dense;

  const _DpadMicroSeekButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return _TactileButtonWrapper(
      onTap: onTap,
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: 10, vertical: dense ? 3.0 : 6.0),
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color.withOpacity(0.85), size: dense ? 19 : 23),
            const SizedBox(height: 0.5),
            Text(
              tooltip,
              style: TextStyle(
                  color: color.withOpacity(0.55),
                  fontSize: dense ? 6.5 : 7.5,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _DpadMicroToggle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color buttonFaceColor;
  final VoidCallback onPressed;
  final String label;
  final bool dense;

  const _DpadMicroToggle({
    required this.icon,
    required this.color,
    required this.buttonFaceColor,
    required this.onPressed,
    required this.label,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final double w = dense ? 38 : 46;
    final double h = dense ? 34 : 42;

    return _TactileButtonWrapper(
      onTap: onPressed,
      child: Container(
        width: w,
        height: h,
        decoration: const BoxDecoration(
          color: Colors
              .transparent, // Completely flat/transparent style, removing heavy physical button borders and backgrounds
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: dense ? 15 : 18,
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.9),
                fontFamily: 'monospace',
                fontSize: dense ? 6.5 : 7.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LCDBezelMiniButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _LCDBezelMiniButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return _TactileButtonWrapper(
      onTap: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.25),
              border: Border.all(color: color.withOpacity(0.12), width: 0.8),
            ),
            child: Icon(icon, color: color.withOpacity(0.75), size: 10),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                color: color.withOpacity(0.7),
                fontFamily: 'monospace',
                fontSize: 8.5,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _BacklitLCDBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _BacklitLCDBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4.0),
      padding: const EdgeInsets.symmetric(
          horizontal: 8.0, vertical: 3.0), // Expanded padding
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4), // Modern soft cornering
        border: Border.all(
            color: color.withOpacity(0.35),
            width: 1.0), // Premium backlit border
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontFamily: 'monospace',
          fontSize: 10.5, // Larger font size for premium visibility
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EqualizerIconButton extends StatelessWidget {
  final bool active;
  final Color color;
  final VoidCallback onPressed;

  const _EqualizerIconButton({
    required this.active,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return _TactileButtonWrapper(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? color.withOpacity(0.2)
                  : Colors.black.withOpacity(0.35),
              border: Border.all(
                color: active ? color : color.withOpacity(0.2),
                width: 1.2,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                          color: color.withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 1)
                    ]
                  : [],
            ),
            child: Icon(Icons.equalizer_rounded,
                color: active ? color : color.withOpacity(0.55), size: 13),
          ),
          const SizedBox(height: 2),
          Text(
            'EQ',
            style: TextStyle(
              color: active ? color : color.withOpacity(0.55),
              fontFamily: 'monospace',
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetallicLCDContainer extends StatelessWidget {
  final PlayerSkin skin;
  final Widget child;

  const _MetallicLCDContainer({required this.skin, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: skin.outerBorderColor.withOpacity(0.2), width: 0.8),
        gradient: LinearGradient(
          colors:
              skin.metallicGradients.map((c) => c.withOpacity(0.25)).toList(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(2.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5.5, sigmaY: 5.5),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Colors.black.withOpacity(0.3), width: 0.8),
              color: skin.lcdBgColor.withOpacity(0.55),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ScrollingMarqueeText extends StatefulWidget {
  final String title;
  final String artist;
  final Color textColor;

  const _ScrollingMarqueeText({
    required this.title,
    required this.artist,
    required this.textColor,
  });

  @override
  State<_ScrollingMarqueeText> createState() => _ScrollingMarqueeTextState();
}

class _ScrollingMarqueeTextState extends State<_ScrollingMarqueeText> {
  late ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  @override
  void didUpdateWidget(covariant _ScrollingMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      _scrollController.jumpTo(0);
      _startScrolling();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startScrolling() {
    _timer?.cancel();
    if (!_scrollController.hasClients) return;

    _timer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      timer.cancel();
      if (!mounted || !_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      await _scrollController.animateTo(
        maxScroll,
        duration: Duration(milliseconds: (maxScroll * 45).toInt() + 1500),
        curve: Curves.linear,
      );

      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0);

      _startScrolling();
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayText = '${widget.title} - ${widget.artist}'.toUpperCase();

    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Center(
        child: Text(
          displayText,
          style: TextStyle(
            color: widget.textColor,
            fontFamily: 'monospace',
            fontSize: 12.0,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            shadows: [
              Shadow(color: widget.textColor.withOpacity(0.35), blurRadius: 4)
            ],
          ),
        ),
      ),
    );
  }
}

class _TactileRoundToggle extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color faceColor;
  final IconData icon;
  final VoidCallback onPressed;
  final bool dense;

  const _TactileRoundToggle({
    required this.label,
    required this.textColor,
    required this.faceColor,
    required this.icon,
    required this.onPressed,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return _TactileButtonWrapper(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dense ? 30 : 38,
            height: dense ? 30 : 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: faceColor,
              border:
                  Border.all(color: Colors.black.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
              gradient: RadialGradient(
                  colors: [faceColor, faceColor.withOpacity(0.7)]),
            ),
            child: Center(
                child: Icon(icon,
                    color: textColor.withOpacity(0.85), size: dense ? 13 : 16)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
                color: textColor.withOpacity(0.85),
                fontFamily: 'monospace',
                fontSize: dense ? 7.5 : 9,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// DYNAMIC ANIMATED CELESTIAL BACKGROUNDS CUSTOM PAINTERS
// ---------------------------------------------------------

enum CelestialStyle {
  milkyWay,
  blackHole,
}

class _CelestialBackgroundPainter extends CustomPainter {
  final CelestialStyle style;
  final double time;
  final double bassEnergy;
  final List<_AstroStar> stars;
  final Color coreColor;
  final Color accentColor;

  _CelestialBackgroundPainter({
    required this.style,
    required this.time,
    required this.bassEnergy,
    required this.stars,
    required this.coreColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final isLandscape = w > h;

    // Dynamic Gravity Centers
    final Offset center = isLandscape
        ? Offset(w * 0.25, h * 0.5)
        : Offset(w * 0.5, h * 0.22); // Under the visualizer screen in portrait

    final double maxDim = math.max(w, h);

    if (style == CelestialStyle.milkyWay) {
      // 1. Twinkling Milky Way Spiral Galaxy
      final corePaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = ui.Gradient.radial(
          center,
          maxDim * 0.35,
          [
            coreColor.withOpacity(0.4 + bassEnergy * 0.2),
            accentColor.withOpacity(0.15 + bassEnergy * 0.1),
            Colors.transparent,
          ],
          [0.0, 0.55, 1.0],
        );
      canvas.drawCircle(center, maxDim * 0.35, corePaint);

      // Spiral arms particles
      final particlePaint = Paint()..style = PaintingStyle.fill;
      final int armCount = 2;
      final double rotAngle = time * 0.05;

      for (int arm = 0; arm < armCount; arm++) {
        final double baseAngle = arm * math.pi;
        for (int i = 0; i < 40; i++) {
          final double t = i / 40.0;
          final double distance = t * maxDim * 0.45;
          final double spiralAngle = baseAngle + t * 4.0 + rotAngle;

          final double dx = center.dx + math.cos(spiralAngle) * distance;
          final double dy = center.dy + math.sin(spiralAngle) * distance;

          // React to bass for twinkling size and opacity
          final double sparkle =
              math.sin(time * 3 + i).abs() * (0.3 + bassEnergy * 0.7);
          final double sizeVal = (1.5 + t * 2.0) * (0.8 + sparkle * 0.5);
          final double opacityVal =
              (0.2 + (1.0 - t) * 0.6) * (0.5 + sparkle * 0.5);

          particlePaint.color = (i % 2 == 0 ? coreColor : accentColor)
              .withOpacity(opacityVal.clamp(0.0, 1.0));
          canvas.drawCircle(Offset(dx, dy), sizeVal, particlePaint);
        }
      }
    } else {
      // 2. Black Hole Gravitational Vortex
      // Swirling accretion gas rings expanding/contracting with bass
      final gasPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..shader = ui.Gradient.radial(
          center,
          120.0 + bassEnergy * 40.0,
          [
            accentColor.withOpacity(0.35),
            coreColor.withOpacity(0.1),
            Colors.transparent,
          ],
          [0.0, 0.6, 1.0],
        );

      for (int r = 0; r < 3; r++) {
        final double radius = 40.0 +
            r * 25.0 +
            math.sin(time * 2.0 + r).abs() * 15.0 * (1.0 + bassEnergy);
        canvas.drawCircle(center, radius, gasPaint);
      }

      // Gravitational lens / accretion glow
      final lensPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = ui.Gradient.radial(
          center,
          52.0 + bassEnergy * 15.0,
          [
            accentColor.withOpacity(0.55),
            coreColor.withOpacity(0.2),
            Colors.transparent,
          ],
          [0.0, 0.55, 1.0],
        );
      canvas.drawCircle(center, 52.0 + bassEnergy * 15.0, lensPaint);

      // Singularity / Event Horizon (pure black void)
      final eventHorizonPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.black;
      canvas.drawCircle(center, 22.0, eventHorizonPaint);

      // Inward falling spaghettified stars
      final starPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < stars.length; i++) {
        final star = stars[i];

        // Convert star's 3D coordinates into spaghettified inward spiral
        final double starTime = (time * 0.8 + i * 0.25) % 1.0;
        final double currentRadius = (1.0 - starTime) * maxDim * 0.55;

        if (currentRadius <= 22.0) {
          // Swallow star when it crosses event horizon
          continue;
        }

        final double angle = star.x * 2 * math.pi + starTime * 3.5;

        // Draw stretching light tail (spaghettified trail)
        final double tailLength =
            10.0 + (1.0 - starTime) * 35.0 * (1.0 + bassEnergy * 2.0);
        final Path tailPath = Path();

        final double startX = center.dx + math.cos(angle) * currentRadius;
        final double startY = center.dy + math.sin(angle) * currentRadius;

        final double nextAngle = star.x * 2 * math.pi + (starTime - 0.05) * 3.5;
        final double nextRadius = currentRadius + tailLength;
        final double endX = center.dx + math.cos(nextAngle) * nextRadius;
        final double endY = center.dy + math.sin(nextAngle) * nextRadius;

        tailPath.moveTo(startX, startY);
        tailPath.lineTo(endX, endY);

        final double opacity =
            ((currentRadius - 22.0) / (maxDim * 0.55)).clamp(0.0, 1.0);
        starPaint
          ..color = coreColor.withOpacity(opacity * 0.65)
          ..strokeWidth =
              (1.2 + (1.0 - starTime) * 2.5) * (1.0 + bassEnergy * 0.5);

        canvas.drawPath(tailPath, starPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CelestialBackgroundPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.bassEnergy != bassEnergy ||
        oldDelegate.style != style;
  }
}
