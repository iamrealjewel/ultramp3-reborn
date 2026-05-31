package com.ultramp3.ultramp3

import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * AudioEffectHandler
 *
 * Exposes Android's hardware Equalizer and BassBoost AudioEffects to Dart via a
 * MethodChannel. The native Equalizer provides true parametric frequency-band
 * shaping (typically 5–10 bands depending on the device), unlike SoLoud's FFT
 * amplitude-bucket filter which cannot isolate individual frequency ranges.
 *
 * Channel: "com.ultramp3/audio_effects"
 *
 * Methods:
 *   setupEqualizer(sessionId: Int)        — attach Equalizer + BassBoost to JustAudio session
 *   getEqProperties()                     — returns numBands, minLevel, maxLevel, centerFreqsHz
 *   setEqBandLevel(band: Int, level: Int) — set a band level in millibels
 *   setBassBoost(strength: Int)           — set BassBoost strength (0–1000)
 *   releaseEqualizer()                    — release both AudioEffects
 */
class AudioEffectHandler(private val flutterEngine: FlutterEngine) {

    companion object {
        const val CHANNEL = "com.ultramp3/audio_effects"
        private const val TAG = "AudioEffectHandler"
    }

    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null

    fun register() {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setupEqualizer" -> {
                    val sessionId = call.argument<Int>("sessionId") ?: 0
                    setupEqualizer(sessionId, result)
                }
                "getEqProperties" -> getEqProperties(result)
                "setEqBandLevel" -> {
                    val band  = call.argument<Int>("band")  ?: 0
                    val level = call.argument<Int>("level") ?: 0
                    setEqBandLevel(band, level, result)
                }
                "setBassBoost" -> {
                    val strength = call.argument<Int>("strength") ?: 0
                    setBassBoostStrength(strength, result)
                }
                "releaseEqualizer" -> releaseEqualizer(result)
                else -> result.notImplemented()
            }
        }
    }

    // ── Private handlers ──────────────────────────────────────────────────────

    private fun setupEqualizer(sessionId: Int, result: MethodChannel.Result) {
        try {
            // Release any previous instances
            equalizer?.release()
            bassBoost?.release()

            equalizer = Equalizer(0, sessionId).apply { enabled = true }
            bassBoost = BassBoost(0, sessionId).apply { enabled = true }

            Log.d(TAG, "Equalizer & BassBoost attached to session $sessionId")
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "setupEqualizer failed: ${e.message}")
            result.error("EQ_SETUP_FAILED", e.message, null)
        }
    }

    private fun getEqProperties(result: MethodChannel.Result) {
        val eq = equalizer
        if (eq == null) {
            result.success(null)
            return
        }
        try {
            val numBands  = eq.numberOfBands.toInt()
            val levelRange = eq.bandLevelRange          // [minMb, maxMb] in millibels
            val centers   = (0 until numBands).map { band ->
                // getCenterFreq returns millihertz — kept as-is, Dart divides by 1000
                eq.getCenterFreq(band.toShort()).toInt()
            }
            result.success(mapOf(
                "numBands"       to numBands,
                "minLevel"       to levelRange[0].toInt(),
                "maxLevel"       to levelRange[1].toInt(),
                "centerFreqsHz"  to centers
            ))
        } catch (e: Exception) {
            Log.e(TAG, "getEqProperties failed: ${e.message}")
            result.error("GET_PROPS_FAILED", e.message, null)
        }
    }

    private fun setEqBandLevel(band: Int, levelMillibels: Int, result: MethodChannel.Result) {
        val eq = equalizer
        if (eq == null) {
            result.success(null)  // graceful no-op if not set up yet
            return
        }
        try {
            val numBands   = eq.numberOfBands.toInt()
            if (band < 0 || band >= numBands) {
                result.error("INVALID_BAND", "Band $band is out of range 0–${numBands - 1}", null)
                return
            }
            val range   = eq.bandLevelRange
            val clamped = levelMillibels.coerceIn(range[0].toInt(), range[1].toInt()).toShort()
            eq.setBandLevel(band.toShort(), clamped)
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "setEqBandLevel($band, $levelMillibels) failed: ${e.message}")
            result.error("SET_BAND_FAILED", e.message, null)
        }
    }

    private fun setBassBoostStrength(strength: Int, result: MethodChannel.Result) {
        val bb = bassBoost
        if (bb == null) {
            result.success(null)
            return
        }
        try {
            val clamped = strength.coerceIn(0, 1000).toShort()
            bb.setStrength(clamped)
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "setBassBoost($strength) failed: ${e.message}")
            result.error("BASSBOOST_FAILED", e.message, null)
        }
    }

    private fun releaseEqualizer(result: MethodChannel.Result) {
        try {
            equalizer?.release()
            equalizer = null
            bassBoost?.release()
            bassBoost = null
            Log.d(TAG, "Equalizer & BassBoost released")
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "releaseEqualizer failed: ${e.message}")
            result.error("RELEASE_FAILED", e.message, null)
        }
    }
}
