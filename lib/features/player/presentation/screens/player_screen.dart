import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'dart:math' as math;
import 'dart:async';

import 'package:ultramp3/core/theme/app_colors.dart';
import 'package:ultramp3/core/services/playback_service.dart';
import 'package:ultramp3/features/player/presentation/providers/player_skin_provider.dart';
import 'package:ultramp3/features/player/presentation/providers/player_settings_provider.dart';
import 'package:ultramp3/features/player/domain/models/player_skin.dart';
import 'package:ultramp3/features/player/presentation/screens/player_settings_screen.dart';
import 'package:ultramp3/features/player/presentation/screens/add_to_playlist_screen.dart';
import 'package:ultramp3/features/playlists/presentation/providers/playlist_providers.dart';

// Supported 12 Visualization Styles
enum VisualizerStyle {
  spectrumBars,     // Center-out, Rounded capsule, Retro Winamp, Floating
  waveform,         // Continuous, Oscilloscope, Bezier, Symmetrical
  circularSpectrum, // Rotating particles, Pulsing radius
  particleReactive, // Dust, Galaxy, Smoke, Energy field
  liquidFluid,      // Fluid simulation reacting to music
  breathingRings,   // Expanding concentric circles
  retroWinamp,      // Classical Winamp green/yellow grid
  albumArtReactive, // Glow, Blur pulse, Dynamic shadow heartbeat
  combinedUltra,    // Waveform+Spectrum, Circular+Album, Particles+Pulse, BackgroundBlur+Glow, Ultra Combo
  solarFlares,      // [NEW] Concentric laser rings & solar flares
  vortexOrbit,      // [NEW] Vocal double helix orbit dots
  rippleWaves,      // [NEW] Multi-layered translucent overlapping waves
}

// Supported Skeuomorphic Dial Styles
enum DialStyle {
  circular,
  rectangular,
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

class _PlayerScreenState extends ConsumerState<PlayerScreen> with TickerProviderStateMixin {
  late AnimationController _visualizerController;
  late AnimationController _vinylRotationController;
  
  final List<double> _visualizerHeights = List.filled(10, 4.0);
  final List<double> _peakHeights = List.filled(10, 4.0);
  final math.Random _random = math.Random();
  
  bool _isPlaying = false;
  bool _hasTrack = false; // Empty state safeguard: freeze visualizer when no track
  double _animationTime = 0.0;

  // Real-time stars list for Astro Starfield style
  late final List<_AstroStar> _stars;

  // Active configurations
  VisualizerStyle _visualizerStyle = VisualizerStyle.spectrumBars;
  int _visualizerVariation = 0; // Cycles from 0 to 4 depending on style!
  DialStyle _dialStyle = DialStyle.circular;
  bool _showEqualizer = false;

  String? _statusMessage;
  Timer? _statusTimer;

  // Equalizer 5-Band presets
  String _activePreset = 'Flat';

  final Map<String, List<double>> _presets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Rock': [4.0, 2.5, -1.5, 2.0, 5.0],
    'Pop': [-1.5, 1.5, 3.0, 1.0, -1.0],
    'Jazz': [3.0, 1.5, -1.5, 1.5, 3.0],
    'Bass & Treble': [7.0, 4.0, 0.0, 4.0, 7.0],
    'Mids': [-3.0, -1.0, 6.0, 4.0, -2.0],
    'Classic': [4.5, 3.0, 0.0, 2.5, 4.0],
    'Live': [-1.0, 2.0, 3.0, 3.0, 2.0],
    'Dance': [5.5, 7.0, 3.5, 0.0, 5.0],
    'Soft': [2.5, 1.0, 0.0, 1.5, 3.0],
    'No Bass': [-12.0, -12.0, 0.0, 0.0, 0.0],
    'No Mids': [0.0, 0.0, -12.0, -12.0, 0.0],
    'No Treble': [0.0, 0.0, 0.0, -12.0, -12.0],
    'Custom': [0.0, 0.0, 0.0, 0.0, 0.0],
  };

  // Equalizer 5-Band values (in dB, -12.0 to +12.0)
  final List<double> _eqBands = [0.0, 0.0, 0.0, 0.0, 0.0];

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
  }

  @override
  void dispose() {
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
          _visualizerHeights[i] = _visualizerHeights[i] * 0.7 + targetHeight.clamp(4.0, 18.0) * 0.3;

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

      final double beatPulse = math.sin(_animationTime * 2 * math.pi * 2.13).abs();

      for (int i = 0; i < 10; i++) {
        double targetHeight = 4.0;

        if (i < 3) {
          targetHeight = 4.0 + (beatPulse * 28.0) + (math.sin(_animationTime * 14.0 + i) * 6.0);
        } else if (i < 7) {
          targetHeight = 4.0 + (math.sin(_animationTime * 8.0 + i) * 20.0) + (math.cos(_animationTime * 12.0 - i) * 8.0);
        } else {
          targetHeight = 4.0 + (math.sin(_animationTime * 32.0 + i).abs() * 14.0) + (_random.nextDouble() * 8.0);
        }

        // Apply software-level 5-band EQ modulation to real-time visualizer heights
        final int bandIndex = (i / 2).floor().clamp(0, 4);
        final double gain = _eqBands[bandIndex];
        final double eqFactor = 1.0 + (gain / 12.0) * 0.8;
        targetHeight = targetHeight * eqFactor;

        targetHeight = targetHeight.clamp(4.0, 38.0);
        _visualizerHeights[i] = _visualizerHeights[i] * 0.45 + targetHeight * 0.55;

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
        return 1;
    }
  }

  void _volumeUp(PlaybackService service, PlayerSkin skin) async {
    final player = service.handler.playerInstance;
    final currentVol = player.volume;
    final targetVol = (currentVol + 0.1).clamp(0.0, 1.0);
    await player.setVolume(targetVol);
    if (mounted) {
      _showFeedbackGlow(context, 'VOLUME: ${(targetVol * 100).toInt()}%', skin.textColor);
    }
  }

  void _volumeDown(PlaybackService service, PlayerSkin skin) async {
    final player = service.handler.playerInstance;
    final currentVol = player.volume;
    final targetVol = (currentVol - 0.1).clamp(0.0, 1.0);
    await player.setVolume(targetVol);
    if (mounted) {
      _showFeedbackGlow(context, 'VOLUME: ${(targetVol * 100).toInt()}%', skin.textColor);
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

  void _applyEqPreset(PlaybackService service, String name, List<double> bands, Color color) {
    setState(() {
      _activePreset = name;
      for (int i = 0; i < 5; i++) {
        _eqBands[i] = bands[i];
      }
    });
    service.setEqualizerBands(bands);
    _showFeedbackGlow(context, 'EQ PRESET: ${name.toUpperCase()}', color);
  }

  void _showFeedbackGlow(BuildContext context, String message, Color glowColor) {
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
                        valueColor: AlwaysStoppedAnimation<Color>(activeSkin.textColor),
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
              boxShadow: isActive ? [
                BoxShadow(
                  color: activeColor.withOpacity(0.3),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                )
              ] : [],
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

  Widget _buildSkeuomorphicVolumeBar(double volume, ja.AudioPlayer player, PlayerSkin skin) {
    final activeColor = skin.textColor;
    final numSegments = 10;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        const double barWidth = 90.0;
        final double x = details.localPosition.dx.clamp(0.0, barWidth);
        final double volumePercent = x / barWidth;
        player.setVolume(volumePercent);
      },
      onHorizontalDragUpdate: (details) {
        const double barWidth = 90.0;
        final double x = details.localPosition.dx.clamp(0.0, barWidth);
        final double volumePercent = x / barWidth;
        player.setVolume(volumePercent);
      },
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(numSegments, (i) {
                final segmentThreshold = (i + 1) / numSegments;
                final isActive = volume >= (segmentThreshold - 0.05);
                final segmentHeight = 4.0 + (i * 2.2);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 4.5,
                  height: segmentHeight,
                  decoration: BoxDecoration(
                    color: isActive ? activeColor : activeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(1),
                    boxShadow: isActive ? [
                      BoxShadow(
                        color: activeColor.withOpacity(0.4),
                        blurRadius: 4,
                        spreadRadius: 0.2,
                      )
                    ] : [],
                  ),
                );
              }),
            ),
            const SizedBox(height: 3),
            Text(
              'VOLUME',
              style: TextStyle(
                color: activeColor.withOpacity(0.7),
                fontFamily: 'Orbitron',
                fontSize: 7.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatPlayControlPanel({
    required PlayerSkin activeSkin,
    required ja.AudioPlayer player,
    required PlaybackService playbackService,
    required bool isShuffle,
    required ja.LoopMode loopMode,
    required double bgOpacity,
    required bool hasTrack,
  }) {
    final accentColor = activeSkin.textColor;
    final disabledColor = accentColor.withOpacity(0.25);

    return Container(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 8),
      decoration: BoxDecoration(
        color: activeSkin.panelBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: activeSkin.outerBorderColor.withOpacity(0.3), width: 1.5),
          left: BorderSide(color: activeSkin.outerBorderColor.withOpacity(0.3), width: 1.5),
          right: BorderSide(color: activeSkin.outerBorderColor.withOpacity(0.3), width: 1.5),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, -3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Skip Prev | Fast Rewind | Play/Pause FAB | Fast Forward | Skip Next
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Skip Prev
              IconButton(
                icon: Icon(Icons.skip_previous_rounded, color: hasTrack ? accentColor : disabledColor, size: 36),
                onPressed: hasTrack ? () => playbackService.skipToPrevious() : null,
                tooltip: 'Previous',
                padding: EdgeInsets.zero,
              ),
              // Fast Rewind
              IconButton(
                icon: Icon(Icons.fast_rewind_rounded, color: hasTrack ? accentColor : disabledColor, size: 28),
                onPressed: hasTrack ? () => _fastRewind(playbackService, activeSkin) : null,
                tooltip: 'Rewind',
                padding: EdgeInsets.zero,
              ),
              // Play/Pause circular FAB – 64px
              GestureDetector(
                onTap: hasTrack ? () {
                  if (_isPlaying) {
                    playbackService.pause();
                  } else {
                    playbackService.play();
                  }
                } : null,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasTrack ? activeSkin.buttonFaceColor : activeSkin.buttonFaceColor.withOpacity(0.4),
                    border: Border.all(
                      color: hasTrack ? accentColor.withOpacity(0.9) : disabledColor,
                      width: 1.5,
                    ),
                    boxShadow: hasTrack ? [
                      BoxShadow(color: accentColor.withOpacity(0.25), blurRadius: 8, spreadRadius: 1)
                    ] : [],
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: hasTrack ? accentColor : disabledColor,
                    size: 38,
                  ),
                ),
              ),
              // Fast Forward
              IconButton(
                icon: Icon(Icons.fast_forward_rounded, color: hasTrack ? accentColor : disabledColor, size: 28),
                onPressed: hasTrack ? () => _fastForward(playbackService, activeSkin) : null,
                tooltip: 'Fast Forward',
                padding: EdgeInsets.zero,
              ),
              // Skip Next
              IconButton(
                icon: Icon(Icons.skip_next_rounded, color: hasTrack ? accentColor : disabledColor, size: 36),
                onPressed: hasTrack ? () => playbackService.skipToNext() : null,
                tooltip: 'Next',
                padding: EdgeInsets.zero,
              ),
            ],
          ),

          const SizedBox(height: 2),

          // Row 2: Shuffle & Repeat (left) | Volume Down & Up (right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Shuffle & Repeat
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: isShuffle ? accentColor : accentColor.withOpacity(0.35),
                      size: 26,
                    ),
                    onPressed: hasTrack ? () => _toggleShuffle(playbackService, accentColor) : null,
                    tooltip: 'Shuffle',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  IconButton(
                    icon: Icon(
                      loopMode == ja.LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                      color: loopMode != ja.LoopMode.off ? accentColor : accentColor.withOpacity(0.35),
                      size: 26,
                    ),
                    onPressed: hasTrack ? () => _toggleRepeat(playbackService, accentColor) : null,
                    tooltip: 'Repeat',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
              // Right: Volume Down & Up
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.volume_down_rounded, color: accentColor.withOpacity(0.85), size: 26),
                    onPressed: () => _volumeDown(playbackService, activeSkin),
                    tooltip: 'Volume Down',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  IconButton(
                    icon: Icon(Icons.volume_up_rounded, color: accentColor.withOpacity(0.85), size: 26),
                    onPressed: () => _volumeUp(playbackService, activeSkin),
                    tooltip: 'Volume Up',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizerControls(PlaybackService service, PlayerSkin skin, ja.AudioPlayer player) {
    return StreamBuilder<double>(
      stream: player.volumeStream,
      initialData: player.volume,
      builder: (context, volumeSnapshot) {
        final volume = volumeSnapshot.data ?? 1.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side: Selected Equalizer preset name as a backlit interactive badge
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showEqualizer = !_showEqualizer;
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: skin.textColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: skin.textColor.withOpacity(0.35), width: 1.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.equalizer_rounded, color: skin.textColor, size: 12),
                          const SizedBox(width: 5),
                          Text(
                            'EQ: ${_activePreset.toUpperCase()}',
                            style: TextStyle(
                              color: skin.textColor,
                              fontFamily: 'monospace',
                              fontSize: 10.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Right side: Persistent gradual heights Volume Bar
              _buildSkeuomorphicVolumeBar(volume, player, skin),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeSkin = ref.watch(playerSkinProvider);
    final playbackService = ref.watch(playbackServiceProvider);
    final player = playbackService.handler.playerInstance;
    final settings = ref.watch(playerSettingsProvider);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Dynamic landscape backgrounds
          Positioned.fill(
            child: Container(
              decoration: _buildBackgroundDecoration(activeSkin),
            ),
          ),

          Column(
            children: [
              // 2. Tucked Top Bar (full-width flat container at the very top edge with dynamic notch padding)
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 4,
                  left: 16,
                  right: 16,
                  bottom: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.9),
                  border: Border(
                    bottom: BorderSide(
                      color: activeSkin.textColor.withOpacity(0.15),
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
                    Text(
                      'ULTRAMP3',
                      style: TextStyle(
                        color: activeSkin.textColor,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(color: activeSkin.textColor.withOpacity(0.6), blurRadius: 8),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!activeSkin.isFlat)
                          IconButton(
                            tooltip: 'Dial Style',
                            icon: Icon(Icons.track_changes_rounded, color: activeSkin.textColor.withOpacity(0.9), size: 20),
                            onPressed: () {
                              setState(() {
                                final styles = DialStyle.values;
                                final nextIndex = (_dialStyle.index + 1) % styles.length;
                                _dialStyle = styles[nextIndex];
                              });
                              _showFeedbackGlow(
                                context,
                                'DIAL: ${_dialStyle.name.toUpperCase()}',
                                activeSkin.textColor,
                              );
                            },
                          ),
                        IconButton(
                          tooltip: 'Skin',
                          icon: Icon(Icons.palette_rounded, color: activeSkin.textColor.withOpacity(0.9), size: 20),
                          onPressed: () {
                            ref.read(playerSkinProvider.notifier).cycleSkin(ref.read(playerSettingsProvider).skinType);
                            final nextSkin = ref.read(playerSkinProvider);
                            _showFeedbackGlow(
                              context,
                              'SKIN: ${nextSkin.name.toUpperCase()}',
                              activeSkin.textColor,
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Visualizer Style',
                          icon: Icon(Icons.waves_rounded, color: activeSkin.textColor.withOpacity(0.9), size: 20),
                          onPressed: () {
                            setState(() {
                              final int maxVars = _getMaxVariations(_visualizerStyle);

                              if (_visualizerVariation < maxVars - 1) {
                                _visualizerVariation++;
                              } else {
                                final styles = VisualizerStyle.values;
                                final nextIndex = (_visualizerStyle.index + 1) % styles.length;
                                _visualizerStyle = styles[nextIndex];
                                _visualizerVariation = 0;
                              }
                            });
                            _showFeedbackGlow(
                              context,
                              'VISUALIZER: ${_visualizerStyle.name.toUpperCase()} (V${_visualizerVariation + 1})',
                              activeSkin.textColor,
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Equalizer',
                          icon: Icon(
                            _showEqualizer ? Icons.equalizer_rounded : Icons.equalizer_outlined,
                            color: _showEqualizer ? activeSkin.textColor : activeSkin.textColor.withOpacity(0.6),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _showEqualizer = !_showEqualizer;
                            });
                          },
                        ),
                        IconButton(
                          tooltip: 'Library',
                          icon: Icon(Icons.library_music_rounded, color: activeSkin.textColor.withOpacity(0.9), size: 20),
                          onPressed: () {
                            context.go('/library');
                          },
                        ),
                        IconButton(
                          tooltip: 'Settings',
                          icon: Icon(Icons.settings_rounded, color: activeSkin.textColor.withOpacity(0.9), size: 20),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const PlayerSettingsScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. Padded scroll-free cockpit area to prevent overflow
              Expanded(
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0), // Reduced from 16 to 10 for bleed bezel look
                    child: Column(
                      children: [
                         const SizedBox(height: 8), // Reduced spacing to avoid bottom overflow completely

                        // Sleek, unified visualizer with rounded corners & glass opacity
                        StreamBuilder<MediaItem?>(
                          stream: playbackService.currentMediaItemStream,
                          builder: (context, mediaSnapshot) {
                            return StreamBuilder<PlaybackState>(
                              stream: playbackService.playbackStateStream,
                              builder: (context, stateSnapshot) {
                                final state = stateSnapshot.data;
                                _isPlaying = state?.playing ?? false;
                                _hasTrack = mediaSnapshot.data != null;

                                final double visOpacity = activeSkin.isFlat
                                    ? 1.0
                                    : (settings.visualizerTransparencyEnabled
                                        ? settings.visualizerOpacity
                                        : 0.55);

                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8), // Reduced rounded corners from 16 to 8
                                  child: SizedBox(
                                    height: activeSkin.isFlat ? 300 : 230, // Premium visualizer viewport (230 height in skeuomorphic, 300 in flat)
                                    width: double.infinity,
                                    child: GestureDetector(
                                      onTap: () {
                                        if (!settings.showAlbumArt) {
                                          setState(() {
                                            final int maxVars = _getMaxVariations(_visualizerStyle);
                                            _visualizerVariation = (_visualizerVariation + 1) % maxVars;
                                          });
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
                                          return Stack(
                                            children: [
                                              // LCD Glass Background
                                              Positioned.fill(
                                                child: Container(
                                                  color: activeSkin.lcdBgColor.withOpacity(visOpacity),
                                                ),
                                              ),
                                              
                                              // CustomPaint or AlbumArt wrapped in Padding to keep distance from overlays
                                              if (settings.showAlbumArt)
                                                Positioned.fill(
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(top: 38, bottom: 44),
                                                    child: Container(
                                                      padding: const EdgeInsets.all(8),
                                                      alignment: Alignment.center,
                                                      child: _buildAlbumArtWidget(mediaItem, activeSkin),
                                                    ),
                                                  ),
                                                )
                                              else
                                                Positioned.fill(
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(top: 38, bottom: 60),
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
                                                        hasTrack: _isPlaying,
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                              // Top Status Overlay: Bitrate and Sample Rate badges
                                              Positioned(
                                                top: 10,
                                                left: 12,
                                                right: 12,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    _BacklitLCDBadge(
                                                      text: '320 KBPS',
                                                      color: activeSkin.textColor,
                                                    ),
                                                    const SizedBox(width: 16),
                                                    _BacklitLCDBadge(
                                                      text: '44.1 KHZ',
                                                      color: activeSkin.textColor,
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Bottom Controls Overlay: Equalizer selected badge & Volume level bar
                                              Positioned(
                                                bottom: 6,
                                                left: 8,
                                                right: 8,
                                                child: _buildVisualizerControls(playbackService, activeSkin, player),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 2),

                        // Floating background-less update feedback ticker
                        AnimatedOpacity(
                          opacity: _statusMessage != null ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
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
                                    color: activeSkin.textColor.withOpacity(0.8),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 4), 

                        // 4. Independent track name marquee + Quick Actions above progress bar
                        StreamBuilder<MediaItem?>(
                          stream: playbackService.currentMediaItemStream,
                          builder: (context, mediaSnapshot) {
                            final mediaItem = mediaSnapshot.data;
                            final String trackTitle = mediaItem?.title ?? 'No Track Loaded';
                            final String trackArtist = mediaItem?.artist ?? 'UltraMP3 Reborn';
                            final bool hasTrack = mediaItem != null;

                            return Consumer(
                              builder: (context, ref, _) {
                                final favorites = ref.watch(favoritesProvider);
                                final isFav = hasTrack && favorites.contains(mediaItem.id);

                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                  padding: const EdgeInsets.only(left: 12.0, right: 4.0, top: 2.0, bottom: 2.0),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: activeSkin.textColor.withOpacity(0.12), width: 0.8),
                                  ),
                                  height: 36,
                                  child: Row(
                                    children: [
                                      // Scrolling track title + artist
                                      Expanded(
                                        child: _ScrollingMarqueeText(
                                          title: trackTitle,
                                          artist: trackArtist,
                                          textColor: activeSkin.textColor,
                                        ),
                                      ),
                                      // Favorite toggle button
                                      SizedBox(
                                        width: 42,
                                        height: 42,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(21),
                                            onTap: hasTrack ? () => ref.read(favoritesProvider.notifier).toggle(mediaItem!.id) : null,
                                            child: Center(
                                              child: Icon(
                                                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                                color: isFav ? Colors.pinkAccent : activeSkin.textColor.withOpacity(0.55),
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Add to Playlist button
                                      SizedBox(
                                        width: 42,
                                        height: 42,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(21),
                                            onTap: hasTrack ? () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => AddToPlaylistScreen(
                                                    songId: mediaItem!.id,
                                                    songTitle: mediaItem.title,
                                                  ),
                                                ),
                                              );
                                            } : null,
                                            child: Center(
                                              child: Icon(
                                                Icons.playlist_add_rounded,
                                                color: activeSkin.textColor.withOpacity(0.55),
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

                        StreamBuilder<PositionState>(
                          stream: playbackService.positionStateStream,
                          builder: (context, posSnapshot) {
                            final posData = posSnapshot.data;
                            final position = posData?.position ?? Duration.zero;
                            final duration = posData?.duration ?? Duration.zero;
                            double currentProgress = 0.0;

                            if (duration.inMilliseconds > 0) {
                              currentProgress = position.inMilliseconds / duration.inMilliseconds;
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 3.0,
                                      activeTrackColor: activeSkin.textColor,
                                      inactiveTrackColor: activeSkin.textColor.withOpacity(0.15),
                                      thumbColor: activeSkin.textColor,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                    ),
                                    child: Slider(
                                      value: currentProgress.clamp(0.0, 1.0),
                                      onChanged: (val) {
                                        final targetMs = (val * duration.inMilliseconds).toInt();
                                        playbackService.seek(Duration(milliseconds: targetMs));
                                      },
                                    ),
                                  ),
                                  // Display progress time and total duration below the progress bar
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.4),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _formatDuration(position),
                                            style: TextStyle(
                                              color: activeSkin.textColor,
                                              fontFamily: 'Orbitron',
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.4),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _formatDuration(duration),
                                            style: TextStyle(
                                              color: activeSkin.textColor.withOpacity(0.8),
                                              fontFamily: 'Orbitron',
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
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

                        // Upcoming Queue Display
                        StreamBuilder<List<MediaItem>>(
                          stream: playbackService.handler.queue,
                          builder: (context, queueSnap) {
                            return StreamBuilder<int?>(
                              stream: playbackService.handler.playerInstance.currentIndexStream,
                              builder: (context, indexSnap) {
                                final queue = queueSnap.data ?? [];
                                final currentIndex = indexSnap.data ?? 0;

                                if (activeSkin.isFlat) {
                                  final upcoming = <MapEntry<int, MediaItem>>[];
                                  for (int i = currentIndex + 1; i < queue.length && upcoming.length < 5; i++) {
                                    upcoming.add(MapEntry(i, queue[i]));
                                  }
                                  if (upcoming.isEmpty) return const SizedBox.shrink();

                                  return Container(
                                    margin: const EdgeInsets.only(top: 6, left: 6, right: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.28),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: activeSkin.textColor.withOpacity(0.1), width: 0.8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Text(
                                            'UP NEXT',
                                            style: TextStyle(
                                              color: activeSkin.textColor.withOpacity(0.5),
                                              fontFamily: 'Orbitron',
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                        ...upcoming.map((entry) {
                                          final idx = entry.key;
                                          final item = entry.value;
                                          return GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => playbackService.handler.playerInstance.seek(Duration.zero, index: idx),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 4),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 22,
                                                    height: 22,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: activeSkin.textColor.withOpacity(0.1),
                                                    ),
                                                    child: Text(
                                                      '${idx + 1}',
                                                      style: TextStyle(
                                                        color: activeSkin.textColor.withOpacity(0.6),
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          item.title,
                                                          style: TextStyle(
                                                            color: activeSkin.textColor.withOpacity(0.9),
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        Text(
                                                          item.artist ?? '',
                                                          style: TextStyle(
                                                            color: activeSkin.textColor.withOpacity(0.45),
                                                            fontSize: 10,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Icon(Icons.chevron_right_rounded, color: activeSkin.textColor.withOpacity(0.3), size: 16),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ),
                                  );
                                } else {
                                  final nextIndex = currentIndex + 1;
                                  if (nextIndex >= queue.length) return const SizedBox.shrink();
                                  final nextItem = queue[nextIndex];

                                  return Container(
                                    margin: const EdgeInsets.only(top: 4, left: 6, right: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: activeSkin.lcdBgColor.withOpacity(0.55),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: activeSkin.lcdBorderColor.withOpacity(0.5), width: 0.8),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          'NEXT  ',
                                          style: TextStyle(
                                            color: activeSkin.textColor.withOpacity(0.55),
                                            fontFamily: 'Orbitron',
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            '${nextItem.title} – ${nextItem.artist ?? ""}',
                                            style: TextStyle(
                                              color: activeSkin.textColor.withOpacity(0.85),
                                              fontFamily: 'monospace',
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),

                        const Spacer(flex: 1),

                        if (activeSkin.isFlat)
                          const SizedBox(height: 125) // Reserved height for the tucked modern sticky footer dialer
                        else ...[
                          // 5. Dial cockpit console with real-time stream bindings for Shuffle & Repeat (Skeuomorphic Only)
                          StreamBuilder<ja.LoopMode>(
                            stream: player.loopModeStream,
                            initialData: player.loopMode,
                            builder: (context, loopSnapshot) {
                              final loopMode = loopSnapshot.data ?? ja.LoopMode.off;
                              return StreamBuilder<bool>(
                                stream: player.shuffleModeEnabledStream,
                                initialData: player.shuffleModeEnabled,
                                builder: (context, shuffleSnapshot) {
                                  final isShuffle = shuffleSnapshot.data ?? false;
                                  final bgOpacity = settings.dialerTransparencyEnabled ? settings.dialerOpacity : 1.0;
                                  return SizedBox(
                                    width: _dialStyle == DialStyle.rectangular ? 320 : 260,
                                    height: _dialStyle == DialStyle.rectangular ? 180 : 260,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: _S60DpadCockpitConsole(
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
                                            onToggleShuffle: () => _toggleShuffle(playbackService, activeSkin.textColor),
                                            onToggleRepeat: () => _toggleRepeat(playbackService, activeSkin.textColor),
                                            onCycleDialStyle: () {
                                              setState(() {
                                                final styles = DialStyle.values;
                                                final nextIndex = (_dialStyle.index + 1) % styles.length;
                                                _dialStyle = styles[nextIndex];
                                              });
                                              _showFeedbackGlow(
                                                context,
                                                'DIAL: ${_dialStyle.name.toUpperCase()}',
                                                activeSkin.textColor,
                                              );
                                            },
                                            onCycleSkin: () {
                                              ref.read(playerSkinProvider.notifier).cycleSkin(ref.read(playerSettingsProvider).skinType);
                                              _showFeedbackGlow(context, 'SKIN: ${ref.read(playerSkinProvider).name.toUpperCase()}', activeSkin.textColor);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                       ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (activeSkin.isFlat)
            Positioned(
              left: 0,
              right: 0,
              bottom: kBottomNavigationBarHeight,
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
                  color: Colors.black.withOpacity(0.72),
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: () {}, // Prevent tap-through
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 40.0),
                      child: _SkeuomorphicEqualizerPanel(
                        skin: activeSkin,
                        bands: _eqBands,
                        activePreset: _activePreset,
                        presets: _presets,
                        onBandChanged: (index, val) {
                          setState(() {
                            _eqBands[index] = val;
                            _activePreset = 'Custom';
                            _presets['Custom'] = List.from(_eqBands);
                          });
                          playbackService.setEqualizerBands(_eqBands);
                        },
                        onPresetSelected: (name, values) => _applyEqPreset(playbackService, name, values, activeSkin.textColor),
                        onClose: () => setState(() => _showEqualizer = false),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
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
      final double avgAmp = amplitudes.fold(0.0, (sum, val) => sum + val) / amplitudes.length;
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

    final double avgAmp = amplitudes.fold(0.0, (sum, val) => sum + val) / amplitudes.length;
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
                [barColor.withOpacity(0.4), barColor, barColor.withOpacity(0.4)],
                [0.0, 0.5, 1.0],
              )
              ..style = PaintingStyle.fill;
            
            canvas.drawRect(
              Rect.fromLTWH(left, midY - halfH, barWidth, activeHeight.clamp(2.0, h)),
              barPaint,
            );
          } else if (mode == 1) {
            // Rounded capsule bars
            final Paint barPaint = Paint()
              ..color = barColor
              ..style = PaintingStyle.fill;
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(left, h - activeHeight, barWidth, activeHeight.clamp(2.0, h)),
                Radius.circular(barWidth / 2),
              ),
              barPaint,
            );
          } else if (mode == 2) {
            // Retro Winamp style grid blocks
            final double blockSize = 3.2;
            final double blockGap = 1.0;
            final int activeBlocks = (activeHeight / (blockSize + blockGap)).floor();
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
              Rect.fromLTWH(left, h - activeHeight, barWidth, activeHeight.clamp(2.0, h)),
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
        final int waveType = variation % 4; // 0=Continuous, 1=Oscilloscope, 2=Bezier, 3=Symmetrical
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
            final double waveVal = math.sin(pct * 6 * math.pi + time * 10) * ampIdx * (h * 0.4);
            
            canvas.drawRect(
              Rect.fromLTWH(i * barW, midY - waveVal, barW - 0.8, waveVal * 2.0),
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
            final double dy = midY + math.sin(pct * 4 * math.pi - time * 14.0) * ampIdx * (h * 0.45);
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
            final double y1 = midY + math.sin(pct1 * 4 * math.pi + time * 8) * ampVal1 * (h * 0.4);
            
            final double x2 = pct2 * w;
            final double y2 = midY + math.sin(pct2 * 4 * math.pi + time * 8) * ampVal2 * (h * 0.4);

            final double x3 = pct3 * w;
            final double y3 = midY + math.sin(pct3 * 4 * math.pi + time * 8) * ampVal2 * (h * 0.4);

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
            final double waveVal = math.sin(pct * 3 * math.pi + time * 6).abs() * ampIdx * (h * 0.42);

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
        final int circType = variation % 4; // 0=Rotating particles, 1=Pulsing radius, 2=TrapNation Inward, 3=Monstercat Bars
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
            
          canvas.drawCircle(Offset(cx, cy), baseRadius - 5 + normalizedAmp * 10, fillPaint);

          for (int i = 0; i < numBars; i++) {
            final double angle = (i / numBars) * 2 * math.pi;
            final double bandAmp = amplitudes[i % 10] / 38.0;
            final double innerRad = baseRadius - bandAmp * maxRadius; // Subtracted to go inward

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

          for (int i = 0; i < numBars / 2; i++) { // Half bars for thickness
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
        final int effectType = variation % 4; // 0=Dust, 1=Galaxy, 2=Smoke, 3=Energy field

        if (effectType == 0) {
          // Dust (rising floaty embers)
          final Paint dustPaint = Paint()..style = PaintingStyle.fill;
          for (int i = 0; i < 25; i++) {
            final double speed = 0.5 + (i % 3) * 0.3;
            final double dx = ((i * 12.0 + time * 15 * speed) % w);
            final double wave = math.sin(time * 2.0 + i) * 6.0;
            final double dy = h - ((i * 6.0 + time * 8 * speed) % h);
            
            dustPaint.color = barColor.withOpacity((1.0 - (dy / h)).clamp(0.0, 1.0) * 0.7);
            canvas.drawCircle(Offset(dx, dy + wave), 1.0 + normalizedAmp * 1.5, dustPaint);
          }
        } else if (effectType == 1) {
          // Galaxy (twisting vortex)
          final int starsCount = 35;
          final Paint starPaint = Paint()..style = PaintingStyle.fill;

          for (int i = 0; i < starsCount; i++) {
            final double angle = (i * 2.4) + (time * 0.5 * (1.0 + normalizedAmp));
            final double distance = ((i * 1.8 + time * 12.0) % (w * 0.42));
            final double dx = cx + math.cos(angle) * distance * 1.6;
            final double dy = cy + math.sin(angle) * distance * 0.95;

            final double opacity = (1.0 - (distance / (w * 0.42))).clamp(0.0, 1.0);
            starPaint.color = HSLColor.fromAHSL(
              opacity,
              (angle * 180 / math.pi) % 360.0,
              0.8,
              0.6,
            ).toColor();

            canvas.drawCircle(Offset(dx, dy), 1.0 + normalizedAmp * 2.0, starPaint);
          }
        } else if (effectType == 2) {
          // Smoke (expanding soft clouds)
          final Paint smokePaint = Paint()..style = PaintingStyle.fill;
          for (int i = 0; i < 6; i++) {
            final double angle = (i * 2 * math.pi / 6) + time * 0.2;
            final double dist = 12.0 + normalizedAmp * 20.0;
            final double dx = cx + math.cos(angle) * dist * 1.4;
            final double dy = cy + math.sin(angle) * dist * 0.9;
            final double sizeRadius = 14.0 + math.sin(time * 3 + i).abs() * 6.0 * (1 + normalizedAmp);

            smokePaint.color = barColor.withOpacity(0.08 * (1.0 - normalizedAmp * 0.3));
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

            if (i == 0) path.moveTo(dx1, dy1);
            else path.lineTo(dx1, dy1);

            // Cross draw
            final double angle2 = ((i + 3) % nodes / nodes) * 2 * math.pi + time * 0.4;
            final double r2 = 12.0 + (amplitudes[(i + 3) % 10] / 38.0) * 25.0;
            final double dx2 = cx + math.cos(angle2) * r2 * 1.6;
            final double dy2 = cy + math.sin(angle2) * r2 * 0.95;
            canvas.drawLine(Offset(dx1, dy1), Offset(dx2, dy2), vectorPaint);
          }
          path.close();
          canvas.drawPath(path, vectorPaint);
        }
        break;

      // 5. LIQUID / FLUID VISUALIZER
      case VisualizerStyle.liquidFluid:
        final int fluidMode = 0; // Force 0 to bypass V2 & V3 (Bezier Swirl, Hot Lava Flow)
        final double midY = h / 2;

        if (fluidMode == 0) {
          // Wave plasma fluid
          final Path fluidPath = Path();
          fluidPath.moveTo(0, h);
          fluidPath.lineTo(0, midY);

          for (int x = 0; x <= w; x += 5) {
            final double pct = x / w;
            final double wave1 = math.sin(pct * 3 * math.pi + time * 4.5) * 8.0 * (1 + normalizedAmp);
            final double wave2 = math.cos(pct * 6 * math.pi - time * 3.0) * 4.0 * normalizedAmp;
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
        } else if (fluidMode == 1) {
          // Bezier Swirl
          final Paint swirlPaint = Paint()
            ..color = barColor.withOpacity(0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;

          final double cx = w / 2;
          final double cy = h / 2;
          final Path path = Path();
          final int segments = 45;

          for (int i = 0; i <= segments; i++) {
            final double pct = i / segments;
            final double angle = pct * 4 * math.pi + time * 3.0;
            final double radius = (4.0 + normalizedAmp * 24.0) * (1.0 + pct * 0.5);
            final double dx = cx + math.cos(angle) * radius * 1.5;
            final double dy = cy + math.sin(angle) * radius * 0.95;

            if (i == 0) path.moveTo(dx, dy);
            else path.lineTo(dx, dy);
          }
          canvas.drawPath(path, swirlPaint);
        } else {
          // Hot Lava Flow
          final Paint lavaPaint = Paint()..style = PaintingStyle.fill;
          for (int i = 0; i < 12; i++) {
            final double scale = 0.4 + (i % 3) * 0.3;
            final double dx = (i * (w / 11));
            final double lavaH = 6.0 + (amplitudes[i % 10] / 38.0) * h * 0.7;
            final double dy = h - lavaH;
            
            lavaPaint.color = HSLColor.fromAHSL(
              0.38,
              15.0 + normalizedAmp * 35.0, // Hot orange/red spectrum
              0.95,
              0.55,
            ).toColor();

            canvas.drawOval(
              Rect.fromLTWH(dx - 12, dy - 8, 24, lavaH * 2),
              lavaPaint,
            );
          }
        }
        break;

      // 6. CIRCULAR PULSE / BREATHING RINGS
      case VisualizerStyle.breathingRings:
        final double cx = w / 2;
        final double cy = h / 2;
        final int ringType = variation % 3; // 0=Single, 1=Concentric, 2=Star rings

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
            ringPaint.color = barColor.withOpacity((1.0 - (i * 0.25)).clamp(0.0, 1.0));
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

            if (i == 0) starPath.moveTo(dx, dy);
            else starPath.lineTo(dx, dy);
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
        final int retroMode = variation % 3; // 0=Winamp grid, 1=Glowing fire, 2=Falloff peaks

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
                  : (pct < 0.78 ? const Color(0xFFFFCC00) : const Color(0xFFFF0000));

              canvas.drawRect(
                Rect.fromLTWH(left, bottomY - blockH, barWidth, blockH),
                Paint()..color = col..style = PaintingStyle.fill,
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
              Rect.fromLTWH(left, h - activeHeight, barWidth, activeHeight.clamp(2.0, h)),
              firePaint,
            );
          } else {
            // Classical flat falling peak bar
            final Paint barPaint = Paint()
              ..color = const ui.Color(0xFF33FF55)
              ..style = PaintingStyle.fill;
            canvas.drawRect(
              Rect.fromLTWH(left, h - activeHeight, barWidth, activeHeight.clamp(1.0, h)),
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
        final int artMode = variation % 3; // 0=Glow around vinyl, 1=Blur pulse, 2=Dynamic shadow heartbeat

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
          canvas.drawCircle(Offset(cx, cy), baseRadius + 12 + normalizedAmp * 8.0, glowPaint);
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
        final int comboMode = variation % 4; // Force 4 options to bypass V5 (Ultra Combo)
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
          final double barWidth = (w - (barGap * (bandsCount - 1))) / bandsCount;

          for (int i = 0; i < bandsCount; i++) {
            final double left = i * (barWidth + barGap);
            final double activeHeight = (amplitudes[i] / 38.0) * h * 0.65;
            final Paint barPaint = Paint()
              ..color = barColor.withOpacity(0.48)
              ..style = PaintingStyle.fill;
            canvas.drawRect(Rect.fromLTWH(left, h - activeHeight, barWidth, activeHeight), barPaint);
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
            final double dy = h * 0.35 + math.sin(pct * 5 * math.pi + time * 12.0) * ampIdx * 15.0;
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
          final Paint cdPaint = Paint()..color = const Color(0xFF141414)..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(cx, cy), baseRadius, cdPaint);
          final Paint stickerPaint = Paint()..color = peakColor..style = PaintingStyle.fill;
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

            final double opacity = (1.0 - (distance / (w * 0.42 + r))).clamp(0.0, 1.0);
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
              final double dy = (h / 2) + math.sin(pct * 2 * math.pi + phase) * amp;
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
            canvas.drawCircle(Offset(dx, waveY), 1.0 + normalizedAmp * 1.0, pPaint);
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
          final Paint cdPaint = Paint()..color = const Color(0xFF0D0D0D)..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(cx, cy), baseRadius, cdPaint);
          final Paint stickerPaint = Paint()..color = peakColor..style = PaintingStyle.fill;
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
            final double dy = (h - 8) + math.cos(pct * 4 * math.pi + time * 8) * ampIdx * 6.0;
            bottomWave.lineTo(pct * w, dy);
          }
          canvas.drawPath(bottomWave, wavePaint);
        }
        break;

      case VisualizerStyle.solarFlares:
        {
          final double cx = w / 2;
          final double cy = h / 2;
          final double baseRadius = 32.0 + normalizedAmp * 12.0;

          // Paint outer glow
          final Paint glowPaint = Paint()
            ..color = peakColor.withOpacity(0.12 * normalizedAmp)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(cx, cy), baseRadius + 30, glowPaint);

          // Draw concentric rings
          final Paint ringPaint = Paint()
            ..color = barColor.withOpacity(0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;
          canvas.drawCircle(Offset(cx, cy), baseRadius, ringPaint);
          canvas.drawCircle(Offset(cx, cy), baseRadius - 8, ringPaint..color = peakColor.withOpacity(0.6));

          // Draw radial explosive solar flare spikes (like design 10)
          final int numSpikes = 64;
          final Paint flarePaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round;

          for (int i = 0; i < numSpikes; i++) {
            final double angle = (i / numSpikes) * 2 * math.pi + time * 0.2;
            final double amp = amplitudes[i % 10] / 38.0;
            // Flare spikes are highly reactive and explosive on beats
            final double flareLength = 8.0 + amp * 32.0 * (1.0 + normalizedAmp * 0.5);

            final double startX = cx + math.cos(angle) * baseRadius;
            final double startY = cy + math.sin(angle) * baseRadius;
            final double endX = cx + math.cos(angle) * (baseRadius + flareLength);
            final double endY = cy + math.sin(angle) * (baseRadius + flareLength);

            // Gradient effect: shift from cyan to neon pink or orange
            flarePaint.color = Color.lerp(barColor, peakColor, (i % 8) / 8.0)!.withOpacity(0.85);
            canvas.drawLine(Offset(startX, startY), Offset(endX, endY), flarePaint);
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
            final double orbitRadius = 40.0 + layer * 20.0 + normalizedAmp * 15.0;
            final Color layerColor = layer == 0 ? barColor : peakColor;

            for (int i = 0; i < dotsCount; i++) {
              final double progressPct = i / dotsCount;
              final double angle = (progressPct * 2 * math.pi) + (time * 0.8 * direction);
              
              // Modulate radius of the dot by amplitude
              final double amp = amplitudes[i % 10] / 38.0;
              final double dotSize = 2.0 + amp * 5.0;

              // Helix modulation (3D wave projection)
              final double xOffset = math.cos(angle) * orbitRadius * 1.5;
              final double yOffset = math.sin(angle) * orbitRadius * 0.85 + math.sin(time * 3 + i) * 6.0;

              dotPaint.color = layerColor.withOpacity(0.2 + 0.8 * (1.0 - progressPct));
              canvas.drawCircle(Offset(cx + xOffset, cy + yOffset), dotSize, dotPaint);
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
            final double ampFactor = (8.0 + layer * 6.0) * (0.2 + normalizedAmp * 1.5);
            
            path.lineTo(0, baseHeight);

            final int steps = 15;
            for (int i = 0; i <= steps; i++) {
              final double pct = i / steps;
              final double dx = pct * w;
              
              // Modulate wave height using amplitude spectrum bands
              final double amp = amplitudes[i % 10] / 38.0;
              final double dy = baseHeight - (amp * ampFactor) - (math.sin(pct * 3 * math.pi + phase) * 15.0);
              path.lineTo(dx, dy);
            }
            
            path.lineTo(w, h);
            path.close();

            final Paint wavePaint = Paint()
              ..style = PaintingStyle.fill
              ..color = Color.lerp(barColor, peakColor, layer / 2.0)!.withOpacity(0.18 + 0.12 * layer);

            canvas.drawPath(path, wavePaint);
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
    final bool isWide = dialStyle == DialStyle.rectangular;
    final double width = isWide ? 320.0 : 260.0;
    final double height = isWide ? 180.0 : 260.0;
    final Color iconCol = getDialIconColor();

    final double skipTop = (height - (isWide ? 38 : 50)) / 2;

    return Container(
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
              color: isShuffle ? getDialTextColor() : getDialTextColor().withOpacity(0.35),
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
              icon: loopMode == ja.LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
              color: loopMode != ja.LoopMode.off ? getDialTextColor() : getDialTextColor().withOpacity(0.35),
              buttonFaceColor: getDialButtonFaceColor(),
              onPressed: onToggleRepeat,
              label: loopMode == ja.LoopMode.one ? 'REP 1' : (loopMode == ja.LoopMode.all ? 'REP ALL' : 'REP OFF'),
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
              border: Border.all(color: Colors.black.withOpacity(0.65), width: 2),
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

// ---------------------------------------------------------
// Skeuomorphic Equalizer Panel Overlay Console
// ---------------------------------------------------------

class _SkeuomorphicEqualizerPanel extends StatelessWidget {
  final PlayerSkin skin;
  final List<double> bands;
  final String activePreset;
  final Map<String, List<double>> presets;
  final Function(int, double) onBandChanged;
  final Function(String, List<double>) onPresetSelected;
  final VoidCallback onClose;

  const _SkeuomorphicEqualizerPanel({
    required this.skin,
    required this.bands,
    required this.activePreset,
    required this.presets,
    required this.onBandChanged,
    required this.onPresetSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final frequencies = ['60Hz', '230Hz', '910Hz', '4kHz', '14kHz'];

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: skin.outerBorderColor, width: 2.5),
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
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'S60 GRAPHIC EQUALIZER',
                style: TextStyle(color: skin.textColor, fontFamily: 'Orbitron', fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.4)),
                  child: Icon(Icons.close_rounded, color: skin.textColor, size: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                return Column(
                  children: [
                    Text(
                      '${bands[index].toInt() > 0 ? "+" : ""}${bands[index].toInt()}dB',
                      style: TextStyle(color: skin.textColor, fontFamily: 'monospace', fontSize: 8, fontWeight: FontWeight.bold),
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
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                          ),
                          child: Slider(
                            value: bands[index].clamp(-12.0, 12.0),
                            min: -12.0,
                            max: 12.0,
                            onChanged: (val) => onBandChanged(index, val),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      frequencies[index],
                      style: TextStyle(color: skin.textMutedColor, fontFamily: 'monospace', fontSize: 8.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: presets.keys.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final presetName = presets.keys.elementAt(index);
                final presetValues = presets[presetName]!;
                final bool isSelected = presetName == activePreset;

                return GestureDetector(
                  onTap: () => onPresetSelected(presetName, presetValues),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: isSelected ? skin.textColor.withOpacity(0.2) : Colors.black.withOpacity(0.3),
                      border: Border.all(
                        color: isSelected ? skin.textColor : skin.textColor.withOpacity(0.15),
                        width: isSelected ? 1.2 : 0.8,
                      ),
                      boxShadow: isSelected ? [BoxShadow(color: skin.textColor.withOpacity(0.2), blurRadius: 4)] : [],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      presetName.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? skin.textColor : skin.textColor.withOpacity(0.7),
                        fontFamily: 'monospace',
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Sub-widgets

class _TactileButtonWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _TactileButtonWrapper({
    required this.child,
    this.onTap,
  });

  @override
  State<_TactileButtonWrapper> createState() => _TactileButtonWrapperState();
}

class _TactileButtonWrapperState extends State<_TactileButtonWrapper> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
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
            borderRadius: borderRadius != null ? BorderRadius.circular(10) : null,
            color: isPlaying ? activeTextColor.withOpacity(0.08) : Colors.transparent,
            border: Border.all(
              color: isPlaying ? activeTextColor : activeIconColor.withOpacity(0.35),
              width: 1.5,
            ),
            boxShadow: isPlaying ? [BoxShadow(color: activeTextColor.withOpacity(0.3), blurRadius: 6)] : [],
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
          color: Colors.transparent, // Completely flat/transparent style, removing heavy physical button borders and backgrounds
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color.withOpacity(0.95),
              size: dense ? 22 : 28,
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
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: dense ? 3.0 : 6.0),
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color.withOpacity(0.85), size: dense ? 19 : 23),
            const SizedBox(height: 0.5),
            Text(
              tooltip,
              style: TextStyle(color: color.withOpacity(0.55), fontSize: dense ? 6.5 : 7.5, fontWeight: FontWeight.bold),
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
          color: Colors.transparent, // Completely flat/transparent style, removing heavy physical button borders and backgrounds
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: dense ? 12 : 15,
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
            style: TextStyle(color: color.withOpacity(0.7), fontFamily: 'monospace', fontSize: 8.5, fontWeight: FontWeight.bold),
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
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0), // Expanded padding
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4), // Modern soft cornering
        border: Border.all(color: color.withOpacity(0.35), width: 1.0), // Premium backlit border
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
              color: active ? color.withOpacity(0.2) : Colors.black.withOpacity(0.35),
              border: Border.all(
                color: active ? color : color.withOpacity(0.2),
                width: 1.2,
              ),
              boxShadow: active ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)] : [],
            ),
            child: Icon(Icons.equalizer_rounded, color: active ? color : color.withOpacity(0.55), size: 13),
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
        border: Border.all(color: skin.outerBorderColor.withOpacity(0.2), width: 0.8),
        gradient: LinearGradient(
          colors: skin.metallicGradients.map((c) => c.withOpacity(0.25)).toList(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3)),
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
              border: Border.all(color: Colors.black.withOpacity(0.3), width: 0.8),
              color: skin.lcdBgColor.withOpacity(0.55),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
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
            shadows: [Shadow(color: widget.textColor.withOpacity(0.35), blurRadius: 4)],
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
              border: Border.all(color: Colors.black.withOpacity(0.5), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2))],
              gradient: RadialGradient(colors: [faceColor, faceColor.withOpacity(0.7)]),
            ),
            child: Center(child: Icon(icon, color: textColor.withOpacity(0.85), size: dense ? 13 : 16)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: textColor.withOpacity(0.85), fontFamily: 'monospace', fontSize: dense ? 7.5 : 9, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
