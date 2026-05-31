package com.ultramp3.ultramp3

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register Android native AudioEffect (Equalizer + BassBoost) platform channel
        AudioEffectHandler(flutterEngine).register()
    }
}
