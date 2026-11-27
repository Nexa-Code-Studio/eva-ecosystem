package com.example.eva_mobile

import android.os.Handler
import android.os.Looper
import com.example.eva_mobile.audio.AudioCaptureEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val methodChannelName = "com.eva.single_audio/methods"
    private val audioStreamChannelName = "com.eva.single_audio/audio_stream"
    private val audioEventsChannelName = "com.eva.single_audio/audio_events"

    private lateinit var audioCaptureEngine: AudioCaptureEngine
    private val mainHandler = Handler(Looper.getMainLooper())

    private var audioEventSink: EventChannel.EventSink? = null
    private var audioMetaEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        audioCaptureEngine = AudioCaptureEngine()

        // 1. Method Channel: uniform pure PCM capture control for Emulator & Physical USB
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startCapture", "startAudioCapture" -> {
                        val started = audioCaptureEngine.startCapture(
                            object : AudioCaptureEngine.AudioCaptureListener {
                                override fun onAudioChunk(bytes: ByteArray) {
                                    sendAudioChunk(bytes)
                                }

                                override fun onSoundLevel(level: Double) {
                                    sendAudioEvent(mapOf("type" to "sound_level", "level" to level))
                                }

                                override fun onError(message: String) {
                                    sendAudioEvent(mapOf("type" to "error", "error" to message))
                                }
                            }
                        )
                        result.success(started)
                    }
                    "stopCapture", "stopAudioCapture" -> {
                        audioCaptureEngine.stopCapture()
                        result.success(true)
                    }
                    "setMuted" -> {
                        val muted = call.argument<Boolean>("muted") ?: false
                        audioCaptureEngine.setMuted(muted)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // 2. Raw 16kHz 16-bit mono PCM binary stream channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, audioStreamChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    audioEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    audioEventSink = null
                }
            })

        // 3. Audio telemetry events channel (RMS sound_level & capture errors)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, audioEventsChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    audioMetaEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    audioMetaEventSink = null
                }
            })
    }

    private fun sendAudioChunk(bytes: ByteArray) {
        mainHandler.post {
            audioEventSink?.success(bytes)
        }
    }

    private fun sendAudioEvent(event: Map<String, Any>) {
        mainHandler.post {
            audioMetaEventSink?.success(event)
        }
    }

    override fun onDestroy() {
        if (::audioCaptureEngine.isInitialized) {
            audioCaptureEngine.stopCapture()
        }
        super.onDestroy()
    }
}
