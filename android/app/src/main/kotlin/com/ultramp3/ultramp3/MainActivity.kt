package com.ultramp3.ultramp3

import android.media.audiofx.Virtualizer
import android.media.audiofx.Visualizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val channelName = "ultramp3/audio_effects"
  private val visualizerEventName = "ultramp3/visualizer"
  private var virtualizer: Virtualizer? = null
  private var virtualizerSessionId: Int? = null

  private var visualizer: Visualizer? = null
  private var visualizerSessionId: Int? = null
  private var visualizerSink: EventChannel.EventSink? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    EventChannel(flutterEngine.dartExecutor.binaryMessenger, visualizerEventName)
      .setStreamHandler(object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
          visualizerSink = events
        }

        override fun onCancel(arguments: Any?) {
          visualizerSink = null
        }
      })

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "setVirtualizer" -> {
            val sessionId = call.argument<Int>("sessionId")
            val strength = call.argument<Int>("strength")
            val enabled = call.argument<Boolean>("enabled") ?: true

            if (sessionId == null || strength == null) {
              result.error("ARGUMENT_ERROR", "sessionId/strength required", null)
              return@setMethodCallHandler
            }

            try {
              // Recreate effect if session changes.
              if (virtualizer == null || virtualizerSessionId != sessionId) {
                virtualizer?.release()
                virtualizer = Virtualizer(0, sessionId)
                virtualizerSessionId = sessionId
              }

              // Virtualizer strength is 0..1000.
              val clamped = strength.coerceIn(0, 1000).toShort()
              virtualizer?.setStrength(clamped)
              virtualizer?.enabled = enabled
              result.success(true)
            } catch (e: Exception) {
              result.error("VIRTUALIZER_ERROR", e.message, null)
            }
          }

          "releaseVirtualizer" -> {
            try {
              virtualizer?.release()
              virtualizer = null
              virtualizerSessionId = null
              result.success(true)
            } catch (e: Exception) {
              result.error("VIRTUALIZER_ERROR", e.message, null)
            }
          }

          "startVisualizer" -> {
            val sessionId = call.argument<Int>("sessionId")
            if (sessionId == null) {
              result.error("ARGUMENT_ERROR", "sessionId required", null)
              return@setMethodCallHandler
            }

            try {
              // Recreate if session changes.
              if (visualizer == null || visualizerSessionId != sessionId) {
                visualizer?.release()
                visualizer = Visualizer(sessionId)
                visualizerSessionId = sessionId
              }

              val v = visualizer ?: run {
                result.error("VISUALIZER_ERROR", "Visualizer init failed", null)
                return@setMethodCallHandler
              }

              v.captureSize = Visualizer.getCaptureSizeRange()[1]
              v.setDataCaptureListener(
                object : Visualizer.OnDataCaptureListener {
                  override fun onWaveFormDataCapture(
                    visualizer: Visualizer?,
                    waveform: ByteArray?,
                    samplingRate: Int
                  ) {
                    // no-op
                  }

                  override fun onFftDataCapture(
                    visualizer: Visualizer?,
                    fft: ByteArray?,
                    samplingRate: Int
                  ) {
                    val data = fft ?: return
                    // Send raw FFT bytes to Dart; Dart will bucket into bands.
                    // Ensure sink calls happen on UI thread.
                    val sink = visualizerSink ?: return
                    runOnUiThread {
                      sink.success(data)
                    }
                  }
                },
                // Visualizer capture rate is in milliHertz. Using a high rate makes the
                // UI feel "too fast" vs musical tempo. Target ~30Hz for beat-synced feel.
                minOf(Visualizer.getMaxCaptureRate(), 30_000),
                false,
                true
              )

              v.enabled = true
              result.success(true)
            } catch (e: Exception) {
              result.error("VISUALIZER_ERROR", e.message, null)
            }
          }

          "stopVisualizer" -> {
            try {
              visualizer?.enabled = false
              visualizer?.release()
              visualizer = null
              visualizerSessionId = null
              result.success(true)
            } catch (e: Exception) {
              result.error("VISUALIZER_ERROR", e.message, null)
            }
          }

          else -> result.notImplemented()
        }
      }
  }

  override fun onDestroy() {
    virtualizer?.release()
    virtualizer = null
    virtualizerSessionId = null

    visualizer?.release()
    visualizer = null
    visualizerSessionId = null
    super.onDestroy()
  }
}
