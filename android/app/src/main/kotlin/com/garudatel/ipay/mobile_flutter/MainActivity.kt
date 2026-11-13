package com.garudatel.ipay.mobile_flutter

import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Bundle
import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var toneGenerator: ToneGenerator? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            window.decorView.importantForAutofill = View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS
        }
        try {
            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.garudatel.ipay/scanner_feedback")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playBeep" -> {
                        try {
                            if (toneGenerator == null) {
                                toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                            }
                            // Nada bip standar scanner kasir minimarket / retail
                            toneGenerator?.startTone(ToneGenerator.TONE_PROP_BEEP, 120)
                            result.success(true)
                        } catch (e: Exception) {
                            e.printStackTrace()
                            result.success(false)
                        }
                    }
                    "playErrorBeep" -> {
                        try {
                            if (toneGenerator == null) {
                                toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                            }
                            toneGenerator?.startTone(ToneGenerator.TONE_PROP_BEEP2, 180)
                            result.success(true)
                        } catch (e: Exception) {
                            e.printStackTrace()
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        toneGenerator?.release()
        toneGenerator = null
        super.onDestroy()
    }
}
