package com.example.eva_mobile

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.example.eva_mobile.audio.AndroidAudioRecordSource
import com.example.eva_mobile.audio.AudioCaptureEngine
import com.example.eva_mobile.audio.AudioLogSink
import com.example.eva_mobile.audio.NativeAudioCapabilityChecker
import com.example.eva_mobile.audio.SingleAudioCoordinator
import com.example.eva_mobile.audio.SpeechRecognizerPipeManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/**
 * Thin Flutter Platform Channel Bridge for EVA Mobile's Native Single-Mic Async Fan-Out pipeline.
 * Contains zero hardcoded emulator restrictions and delegates all audio lifecycle orchestration
 * to SingleAudioCoordinator.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val MAX_INFLIGHT_MAIN_LOOPER_FRAMES = 4
    }

    private val methodChannelName = "com.eva.single_audio/methods"
    private val audioStreamChannelName = "com.eva.single_audio/audio_stream"
    private val sttEventsChannelName = "com.eva.single_audio/stt_events"

    private lateinit var coordinator: SingleAudioCoordinator
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pendingMainLooperFrames = AtomicInteger(0)
    private val workerExecutor: ExecutorService = Executors.newSingleThreadExecutor { r ->
        Thread(r, "EvaSingleAudioChannelWorker").apply { isDaemon = true }
    }

    @Volatile
    private var audioEventSink: EventChannel.EventSink? = null

    @Volatile
    private var sttEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val logSink = AudioLogSink { level, tag, message ->
            when (level) {
                "E" -> Log.e(tag, message)
                "W" -> Log.w(tag, message)
                "D" -> Log.d(tag, message)
                else -> Log.i(tag, message)
            }
        }

        val capabilityChecker = NativeAudioCapabilityChecker(applicationContext)
        val captureEngine = AudioCaptureEngine(
            frameSourceFactory = { sampleRate, chunkSizeBytes ->
                AndroidAudioRecordSource(applicationContext, sampleRate, chunkSizeBytes)
            },
            logSink = logSink
        )
        val sttPipeManager = SpeechRecognizerPipeManager(applicationContext)

        coordinator = SingleAudioCoordinator(
            capabilityProvider = capabilityChecker,
            captureEngine = captureEngine,
            sttPipeEngine = sttPipeManager,
            onAudioFrameEgress = { frame ->
                val sink = audioEventSink ?: return@SingleAudioCoordinator
                if (pendingMainLooperFrames.incrementAndGet() > MAX_INFLIGHT_MAIN_LOOPER_FRAMES) {
                    pendingMainLooperFrames.decrementAndGet()
                    return@SingleAudioCoordinator
                }
                mainHandler.post {
                    try {
                        sink.success(frame.pcmBytes)
                    } catch (_: Exception) {
                        // Isolated: EventChannel failure never disrupts audio capture or STT
                    } finally {
                        pendingMainLooperFrames.decrementAndGet()
                    }
                }
            },
            onSttEvent = { eventMap ->
                val sink = sttEventSink ?: return@SingleAudioCoordinator
                mainHandler.post {
                    try {
                        sink.success(eventMap)
                    } catch (_: Exception) {
                    }
                }
            },
            logSink = logSink
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkCapability" -> {
                        val locale = call.argument<String>("locale") ?: "id-ID"
                        workerExecutor.execute {
                            val report = coordinator.checkCapability(locale)
                            mainHandler.post { result.success(report.toMap()) }
                        }
                    }

                    "startNativeHybrid", "startListening" -> {
                        val locale = call.argument<String>("locale") ?: "id-ID"
                        val sttSessionId = (call.argument<Number>("sttSessionId")?.toLong()) ?: 1L
                        val enableSegmented = call.argument<Boolean>("enableSegmentedSession") ?: true
                        val allowFallback = call.argument<Boolean>("allowAutomaticFallback") ?: true
                        workerExecutor.execute {
                            val ok = coordinator.startNativeHybrid(
                                sttSessionId = sttSessionId,
                                locale = locale,
                                enableSegmentedSession = enableSegmented,
                                allowAutomaticFallback = allowFallback
                            )
                            mainHandler.post { result.success(ok) }
                        }
                    }

                    "rearmStt" -> {
                        val locale = call.argument<String>("locale") ?: "id-ID"
                        val sttSessionId = (call.argument<Number>("sttSessionId")?.toLong()) ?: 1L
                        val enableSegmented = call.argument<Boolean>("enableSegmentedSession") ?: true
                        workerExecutor.execute {
                            val ok = coordinator.rearmStt(
                                sttSessionId = sttSessionId,
                                locale = locale,
                                enableSegmentedSession = enableSegmented
                            )
                            mainHandler.post { result.success(ok) }
                        }
                    }

                    "setMuted" -> {
                        val muted = call.argument<Boolean>("muted") ?: false
                        workerExecutor.execute {
                            val ok = coordinator.setMuted(muted)
                            mainHandler.post { result.success(ok) }
                        }
                    }

                    "stopAll", "stopListening", "stopAudioCapture" -> {
                        val destroyRecognizer = call.argument<Boolean>("destroyRecognizer") ?: false
                        workerExecutor.execute {
                            val barrierComplete = coordinator.stopAll(destroyRecognizer = destroyRecognizer)
                            mainHandler.post { result.success(barrierComplete) }
                        }
                    }

                    "getDiagnostics" -> {
                        workerExecutor.execute {
                            val snapshot = coordinator.getDiagnostics().toMap()
                            mainHandler.post { result.success(snapshot) }
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, audioStreamChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    audioEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    audioEventSink = null
                }
            })

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

    override fun onDestroy() {
        audioEventSink = null
        sttEventSink = null
        if (::coordinator.isInitialized) {
            coordinator.destroy()
        }
        workerExecutor.shutdownNow()
        super.onDestroy()
    }
}
