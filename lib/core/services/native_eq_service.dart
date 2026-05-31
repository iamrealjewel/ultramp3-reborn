import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// NativeEqService
///
/// Dart wrapper around the Android native Equalizer + BassBoost AudioEffects
/// exposed via the 'com.ultramp3/audio_effects' MethodChannel.
///
/// Usage:
///   1. Call [setupEqualizer] with the JustAudio androidAudioSessionId.
///   2. Call [setEqualizerBands] with 8 dB gain values (from UI).
///   3. Call [setBassBoost] with 0.0–1.0 from the bass knob.
///   4. Call [releaseEqualizer] on stop/dispose.
class NativeEqService {
  static const _channel = MethodChannel('com.ultramp3/audio_effects');

  // Device EQ properties (populated after setupEqualizer + getEqProperties)
  int _numBands = 0;
  int _minLevelMb = -1500; // millibels
  int _maxLevelMb = 1500;  // millibels
  List<double> _centerFreqsHz = []; // Hz (converted from millihertz)

  bool get isReady => _numBands > 0;
  int get numBands => _numBands;
  List<double> get centerFreqsHz => _centerFreqsHz;

  /// Our fixed 8-band UI center frequencies (Hz).
  /// Presets are defined against these frequencies.
  static const List<double> uiCentersHz = [
    60, 150, 400, 1000, 2400, 6000, 15000, 20000,
  ];

  // ── Setup / Teardown ───────────────────────────────────────────────────────

  /// Attaches Android Equalizer + BassBoost to [sessionId] (JustAudio session).
  /// Also reads device EQ properties (band count, range, center frequencies).
  Future<void> setupEqualizer(int sessionId) async {
    try {
      await _channel.invokeMethod<void>('setupEqualizer', {'sessionId': sessionId});

      final rawProps = await _channel.invokeMethod<Map<Object?, Object?>>('getEqProperties');
      if (rawProps != null) {
        _numBands    = (rawProps['numBands']  as int?) ?? 0;
        _minLevelMb  = (rawProps['minLevel']  as int?) ?? -1500;
        _maxLevelMb  = (rawProps['maxLevel']  as int?) ?? 1500;

        // Android returns center frequencies in millihertz; convert to Hz.
        final rawCenters = rawProps['centerFreqsHz'];
        if (rawCenters is List) {
          _centerFreqsHz = rawCenters
              .map((v) => (v as num).toDouble() / 1000.0)
              .toList();
        }
      }

      debugPrint(
        '[NativeEq] Ready: $_numBands bands | range: ${_minLevelMb}–${_maxLevelMb} mB | '
        'centers: ${_centerFreqsHz.map((f) => '${f.toInt()}Hz').join(', ')}',
      );
    } catch (e) {
      debugPrint('[NativeEq] setupEqualizer failed: $e');
    }
  }

  Future<void> releaseEqualizer() async {
    try {
      await _channel.invokeMethod<void>('releaseEqualizer');
    } catch (e) {
      debugPrint('[NativeEq] releaseEqualizer failed: $e');
    } finally {
      _numBands = 0;
      _centerFreqsHz = [];
    }
  }

  // ── EQ Band Control ────────────────────────────────────────────────────────

  /// Applies [gainsDb] (8 values, one per UI band) to the device's hardware EQ.
  ///
  /// Interpolates by frequency when the device has a different number of bands
  /// than the 8 UI bands. Each device band's center frequency is looked up in
  /// the UI curve to get the correct dB value.
  Future<void> setEqualizerBands(List<double> gainsDb) async {
    if (_numBands == 0 || _centerFreqsHz.isEmpty) return;

    for (int band = 0; band < _numBands; band++) {
      final targetHz = _centerFreqsHz[band];
      final gainDb   = _interpolateDb(targetHz, uiCentersHz, gainsDb);
      final levelMb  = (gainDb * 100).round().clamp(_minLevelMb, _maxLevelMb);

      try {
        await _channel.invokeMethod<void>(
          'setEqBandLevel',
          {'band': band, 'level': levelMb},
        );
      } catch (e) {
        debugPrint('[NativeEq] setEqBandLevel($band, $levelMb) failed: $e');
      }
    }
  }

  /// Resets all hardware EQ bands to 0 dB (true flat / bit-perfect bypass).
  Future<void> setFlat() async {
    if (_numBands == 0) return;
    for (int band = 0; band < _numBands; band++) {
      try {
        await _channel.invokeMethod<void>(
          'setEqBandLevel',
          {'band': band, 'level': 0},
        );
      } catch (_) {}
    }
  }

  // ── BassBoost Control ──────────────────────────────────────────────────────

  /// Maps the UI bass knob (0.0–1.0, where 0.5 = neutral) to Android's
  /// BassBoost strength (0–1000). Values below 0.5 = no boost (0 strength).
  Future<void> setBassBoost(double bassKnobValue) async {
    // Only boost (Android BassBoost cannot cut bass).
    // 0.5–1.0 maps linearly to 0–1000 strength.
    // 0.0–0.5 maps to 0 (no effect).
    final normalised = ((bassKnobValue - 0.5) * 2.0).clamp(0.0, 1.0);
    final strength   = (normalised * 1000).round();
    try {
      await _channel.invokeMethod<void>('setBassBoost', {'strength': strength});
    } catch (e) {
      debugPrint('[NativeEq] setBassBoost($strength) failed: $e');
    }
  }

  // ── Interpolation ──────────────────────────────────────────────────────────

  /// Linearly interpolates a dB gain at [targetHz] from the UI band curve
  /// defined by parallel [xs] (frequencies) and [ys] (dB gains).
  double _interpolateDb(double targetHz, List<double> xs, List<double> ys) {
    if (xs.isEmpty || ys.isEmpty) return 0.0;
    if (targetHz <= xs.first) return ys.first;
    if (targetHz >= xs.last) return ys.last;
    for (int i = 0; i < xs.length - 1; i++) {
      if (targetHz >= xs[i] && targetHz <= xs[i + 1]) {
        final t = (targetHz - xs[i]) / (xs[i + 1] - xs[i]);
        return ys[i] + t * (ys[i + 1] - ys[i]);
      }
    }
    return 0.0;
  }
}

/// Global singleton — one instance shared across the app.
final nativeEqService = NativeEqService();
