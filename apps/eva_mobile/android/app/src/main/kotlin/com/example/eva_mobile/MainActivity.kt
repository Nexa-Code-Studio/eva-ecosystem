package com.example.eva_mobile

import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.example.eva_mobile.audio.AudioCaptureEngine
import com.example.eva_mobile.audio.SpeechRecognizerPipeManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val methodChannelName = "com.eva.single_audio/methods"
    private val audioStreamChannelName = "com.eva.single_audio/audio_stream"
    private val sttEventsChannelName = "com.eva.single_audio/stt_events"

    private lateinit var audioCaptureEngine: AudioCaptureEngine
    private lateinit var speechRecognizerPipeManager: SpeechRecognizerPipeManager
    private val mainHandler = Handler(Looper.getMainLooper())

    private var audioEventSink: EventChannel.EventSink? = null
    private var sttEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        audioCaptureEngine = AudioCaptureEngine()
        speechRecognizerPipeManager = SpeechRecognizerPipeManager(applicationContext)

        // 1. Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkCapability" -> {
                        val supported = speechRecognizerPipeManager.isInjectionSupported()
                        val isEmulator = (Build.HARDWARE.contains("goldfish")
                                || Build.HARDWARE.contains("ranchu")
                                || Build.MODEL.contains("google_sdk")
                                || Build.MODEL.contains("Emulator")
                                || Build.FINGERPRINT.startsWith("generic"))
                        result.success(
                            mapOf(
                                "supported" to supported,
                                "sdkInt" to Build.VERSION.SDK_INT,
                                "isEmulator" to isEmulator
                            )
                        )
                    }
                    "startAudioCapture" -> {
                        val isEmulator = (Build.HARDWARE.contains("goldfish")
                                || Build.HARDWARE.contains("ranchu")
                                || Build.MODEL.contains("google_sdk")
                                || Build.MODEL.contains("Emulator")
                                || Build.FINGERPRINT.startsWith("generic"))
                        if (isEmulator) {
                            Log.w("MainActivity", "🎙️ Android Emulator detected: Skipping concurrent AudioRecord to preserve exclusive mic access for SpeechRecognizer.")
                            result.success(false)
                        } else {
                            val captureStarted = audioCaptureEngine.startCapture(
                                null, // Parallel mode: No virtual pipe, direct mic capture
                                object : AudioCaptureEngine.AudioCaptureListener {
                                    override fun onAudioChunk(bytes: ByteArray) {
                                        sendAudioChunk(bytes)
                                    }

                                    override fun onSoundLevel(level: Double) {
                                        sendSttEvent(mapOf("type" to "sound_level", "level" to level))
                                    }

                                    override fun onError(message: String) {
                                        sendSttEvent(mapOf("type" to "error", "error" to message))
                                    }
                                }
                            )
                            result.success(captureStarted)
                        }
                    }
                    "stopAudioCapture" -> {
                        audioCaptureEngine.stopCapture()
                        result.success(true)
                    }
                    "startListening" -> {
                        val locale = call.argument<String>("locale") ?: "id-ID"
                        val pipeStarted = speechRecognizerPipeManager.startListening(
                            locale,
                            object : SpeechRecognizerPipeManager.SttEventListener {
                                override fun onStatus(status: String) {
                                    sendSttEvent(mapOf("type" to "status", "status" to status))
                                }

                                override fun onPartial(text: String) {
                                    sendSttEvent(mapOf("type" to "partial", "text" to text))
                                }

                                override fun onFinal(text: String) {
                                    sendSttEvent(mapOf("type" to "final", "text" to text))
                                }

                                override fun onSoundLevel(level: Double) {
                                    sendSttEvent(mapOf("type" to "sound_level", "level" to level))
                                }

                                override fun onError(error: String) {
                                    sendSttEvent(mapOf("type" to "error", "error" to error))
                                }
                            }
                        )

                        val pipeOutStream = speechRecognizerPipeManager.getPipeOutputStream()
                        val captureStarted = audioCaptureEngine.startCapture(
                            pipeOutStream,
                            object : AudioCaptureEngine.AudioCaptureListener {
                                override fun onAudioChunk(bytes: ByteArray) {
                                    sendAudioChunk(bytes)
                                }

                                override fun onSoundLevel(level: Double) {
                                    sendSttEvent(mapOf("type" to "sound_level", "level" to level))
                                }

                                override fun onError(message: String) {
                                    sendSttEvent(mapOf("type" to "error", "error" to message))
                                }
                            }
                        )

                        result.success(pipeStarted && captureStarted)
                    }
                    "stopListening" -> {
                        audioCaptureEngine.stopCapture()
                        speechRecognizerPipeManager.stopListening()
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // 2. Audio Stream Channel (Raw PCM chunks)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, audioStreamChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    audioEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    audioEventSink = null
                }
            })

        // 3. STT Events Channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, sttEventsChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sttEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    sttEventSink = null
                }
            })
    }

    private fun sendAudioChunk(bytes: ByteArray) {
        mainHandler.post {
            audioEventSink?.success(bytes)
        }
    }

    private fun sendSttEvent(event: Map<String, Any>) {
        mainHandler.post {
            sttEventSink?.success(event)
        }
    }

    override fun onDestroy() {
        if (::audioCaptureEngine.isInitialized) {
            audioCaptureEngine.stopCapture()
        }
        if (::speechRecognizerPipeManager.isInitialized) {
            speechRecognizerPipeManager.destroy()
        }
        super.onDestroy()
    }
}
