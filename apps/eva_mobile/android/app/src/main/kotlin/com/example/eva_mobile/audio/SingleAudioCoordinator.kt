package com.example.eva_mobile.audio

import java.io.OutputStream
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

/**
 * Single authoritative native coordinator for EVA Mobile's single-mic async fan-out pipeline.
 * Owns the state machine, generation guards, runtime validation probe, synchronized pipe reconnect,
 * failure isolation, and synchronous Mic-Release Barrier for deterministic fallback.
 *
 * Pure Kotlin (no direct Android Looper dependency) so every transition and fault scenario is
 * deterministically unit-testable on JVM.
 */
class SingleAudioCoordinator(
    private val capabilityProvider: CapabilityProvider,
    private val captureEngine: AudioCaptureEngine,
    private val sttPipeEngine: SttPipeEngine,
    private val onAudioFrameEgress: (AudioFrame) -> Unit,
    private val onSttEvent: (Map<String, Any>) -> Unit,
    private val probeTimeoutMs: Long = DEFAULT_PROBE_TIMEOUT_MS,
    private val reconnectDelayServerDisconnectedMs: Long = 300L,
    private val reconnectDelayNetworkMs: Long = 800L,
    private val maxConsecutiveReconnects: Int = 2,
    private val clockMs: () -> Long = { System.currentTimeMillis() },
    private val logSink: AudioLogSink = AudioLogSink.NO_OP
) {
    companion object {
        private const val TAG = "SingleAudioCoordinator"
        const val DEFAULT_PROBE_TIMEOUT_MS = 2500L

        const val ERROR_AUDIO = 3
        const val ERROR_CLIENT = 5
        const val ERROR_INSUFFICIENT_PERMISSIONS = 9
        const val ERROR_NETWORK = 2
        const val ERROR_NETWORK_TIMEOUT = 1
        const val ERROR_NO_MATCH = 7
        const val ERROR_SPEECH_TIMEOUT = 6
        const val ERROR_SERVER_DISCONNECTED = 11
        const val ERROR_LANGUAGE_NOT_SUPPORTED = 12
    }

    private val stateRef = AtomicReference(PipelineState.IDLE)
    private val sessionIdCounter = AtomicLong(0)
    private val generationIdCounter = AtomicLong(0)
    private val sttSequenceCounter = AtomicLong(0)
    private val pipeReconnectCount = AtomicInteger(0)
    private val consecutiveReconnectFailures = AtomicInteger(0)
    private val clientSilenced = AtomicBoolean(false)
    private val runtimeValidated = AtomicBoolean(false)
    private val readyForSpeechSeen = AtomicBoolean(false)
    private val segmentedDowngraded = AtomicBoolean(false)
    private val allowAutomaticFallbackFlag = AtomicBoolean(true)

    @Volatile
    private var activeLocale: String = "id-ID"

    @Volatile
    private var lastFailureReason: String? = null

    private val scheduler: ScheduledExecutorService = Executors.newSingleThreadScheduledExecutor { runnable ->
        Thread(runnable, "EvaAudioCoordinatorTimer").apply { isDaemon = true }
    }

    private var probeTimeoutTask: ScheduledFuture<*>? = null
    private var reconnectTask: ScheduledFuture<*>? = null

    private val fanOutPipeline = AudioFanOutPipeline(
        emotionConsumer = { frame -> onAudioFrameEgress(frame) },
        onPipeWriteError = { genId, msg -> handlePipeWriteError(genId, msg) },
        logSink = logSink
    )

    val state: PipelineState get() = stateRef.get()
    val currentSessionId: Long get() = sessionIdCounter.get()
    val currentGenerationId: Long get() = generationIdCounter.get()
    val isRuntimeValidated: Boolean get() = runtimeValidated.get()

    fun checkCapability(locale: String = "id-ID"): NativeCapabilityReport {
        return capabilityProvider.checkCapability(locale)
    }

    @Synchronized
    fun startNativeHybrid(
        sttSessionId: Long,
        locale: String = "id-ID",
        enableSegmentedSession: Boolean = true,
        allowAutomaticFallback: Boolean = true
    ): Boolean {
        if (stateRef.get() == PipelineState.DISPOSED) {
            return false
        }

        cancelScheduledTasksLocked()
        activeLocale = locale
        allowAutomaticFallbackFlag.set(allowAutomaticFallback)
        lastFailureReason = null
        sessionIdCounter.set(sttSessionId)
        sttSequenceCounter.set(0)
        consecutiveReconnectFailures.set(0)
        clientSilenced.set(false)
        readyForSpeechSeen.set(false)

        val generationId = generationIdCounter.incrementAndGet()
        val useSegmented = enableSegmentedSession && !segmentedDowngraded.get()

        stateRef.set(PipelineState.NATIVE_HYBRID_STARTING)
        fanOutPipeline.start()

        val captureOk = captureEngine.startCapture(
            sessionId = sttSessionId,
            generationId = generationId,
            callbacks = createCaptureCallbacks()
        )
        if (!captureOk) {
            handleFatalOrFallbackLocked(
                generationId = generationId,
                reason = "audio_record_init_failed"
            )
            return false
        }

        val sttStarted = sttPipeEngine.startSession(
            generationId = generationId,
            locale = locale,
            useSegmentedSession = useSegmented,
            listener = createSttPipeListener(useSegmented)
        )
        if (!sttStarted) {
            handleFatalOrFallbackLocked(
                generationId = generationId,
                reason = "stt_pipe_start_failed"
            )
            return false
        }

        scheduleRuntimeProbeTimeoutLocked(generationId)
        logSink.log(
            "I",
            TAG,
            "Started Native Hybrid (session=$sttSessionId, gen=$generationId, " +
                "segmented=$useSegmented, allowFallback=$allowAutomaticFallback)"
        )
        return true
    }

    /**
     * Re-arms SpeechRecognizer with a fresh virtual pipe without stopping AudioRecord
     * or interrupting the Emotion2Vec stream.
     */
    @Synchronized
    fun rearmStt(
        sttSessionId: Long,
        locale: String = activeLocale,
        enableSegmentedSession: Boolean = true
    ): Boolean {
        val currentState = stateRef.get()
        if (currentState == PipelineState.DISPOSED || currentState == PipelineState.IDLE ||
            currentState == PipelineState.NATIVE_HYBRID_FAILED
        ) {
            return startNativeHybrid(
                sttSessionId = sttSessionId,
                locale = locale,
                enableSegmentedSession = enableSegmentedSession,
                allowAutomaticFallback = allowAutomaticFallbackFlag.get()
            )
        }

        cancelScheduledTasksLocked()
        activeLocale = locale
        sessionIdCounter.set(sttSessionId)
        sttSequenceCounter.set(0)
        readyForSpeechSeen.set(false)

        val generationId = generationIdCounter.incrementAndGet()
        captureEngine.updateGeneration(sttSessionId, generationId)

        if (currentState == PipelineState.MUTED || captureEngine.isMuted()) {
            return true
        }

        stateRef.set(PipelineState.RECONNECTING_STT_PIPE)
        val useSegmented = enableSegmentedSession && !segmentedDowngraded.get()
        val restarted = sttPipeEngine.startSession(
            generationId = generationId,
            locale = locale,
            useSegmentedSession = useSegmented,
            listener = createSttPipeListener(useSegmented)
        )
        if (!restarted) {
            handleFatalOrFallbackLocked(generationId, "stt_rearm_failed")
            return false
        }

        pipeReconnectCount.incrementAndGet()
        scheduleRuntimeProbeTimeoutLocked(generationId)
        return true
    }

    @Synchronized
    fun setMuted(muted: Boolean): Boolean {
        val current = stateRef.get()
        if (current == PipelineState.DISPOSED) return false
        captureEngine.setMuted(muted)

        if (muted) {
            if (current == PipelineState.NATIVE_HYBRID_ACTIVE ||
                current == PipelineState.NATIVE_HYBRID_STARTING ||
                current == PipelineState.RECONNECTING_STT_PIPE
            ) {
                cancelScheduledTasksLocked()
                sttPipeEngine.closeWriteEnd(generationIdCounter.get())
                fanOutPipeline.detachPipe()
                sttPipeEngine.stopAndWait(timeoutMs = 500L, destroyRecognizer = false)
                stateRef.set(PipelineState.MUTED)
            }
        } else if (current == PipelineState.MUTED) {
            return rearmStt(
                sttSessionId = sessionIdCounter.get(),
                locale = activeLocale,
                enableSegmentedSession = !segmentedDowngraded.get()
            )
        }
        return true
    }

    /**
     * Synchronous Mic-Release Barrier:
     * Stops capture, joins worker threads, closes pipes, releases AudioRecord,
     * and cancels/optionally destroys SpeechRecognizer before returning.
     */
    @Synchronized
    fun stopAll(destroyRecognizer: Boolean = false): Boolean {
        val current = stateRef.get()
        if (current == PipelineState.DISPOSED) return true

        stateRef.set(PipelineState.STOPPING)
        cancelScheduledTasksLocked()

        // Invalidate any stale callbacks before releasing resources
        generationIdCounter.incrementAndGet()

        val captureJoined = captureEngine.stopCapture(joinTimeoutMs = 1000L)
        val pipelineJoined = fanOutPipeline.stopAndJoin(timeoutMs = 1000L)
        val sttStopped = sttPipeEngine.stopAndWait(timeoutMs = 1000L, destroyRecognizer = destroyRecognizer)

        stateRef.set(PipelineState.IDLE)
        logSink.log(
            "I",
            TAG,
            "stopAll barrier complete (captureJoined=$captureJoined, pipelineJoined=$pipelineJoined, sttStopped=$sttStopped)"
        )
        return captureJoined && pipelineJoined && sttStopped
    }

    @Synchronized
    fun destroy() {
        if (stateRef.get() == PipelineState.DISPOSED) return
        stopAll(destroyRecognizer = true)
        stateRef.set(PipelineState.DISPOSED)
        sttPipeEngine.destroy()
        scheduler.shutdownNow()
    }

    fun getDiagnostics(): PipelineMetrics {
        return PipelineMetrics(
            state = stateRef.get().name,
            sessionId = sessionIdCounter.get(),
            generationId = generationIdCounter.get(),
            capturedFrames = fanOutPipeline.capturedFrames,
            sttQueuedFrames = fanOutPipeline.sttQueuedFrames,
            sttWrittenFrames = fanOutPipeline.sttWrittenFrames,
            sttBytesWritten = fanOutPipeline.sttBytesWritten,
            sttDroppedFrames = fanOutPipeline.sttDroppedFrames,
            emotionQueuedFrames = fanOutPipeline.emotionQueuedFrames,
            emotionDeliveredFrames = fanOutPipeline.emotionDeliveredFrames,
            emotionDroppedFrames = fanOutPipeline.emotionDroppedFrames,
            emotionConsumerErrors = fanOutPipeline.emotionConsumerErrors,
            pipeReconnectCount = pipeReconnectCount.get(),
            isClientSilenced = clientSilenced.get(),
            isMuted = captureEngine.isMuted(),
            runtimeValidated = runtimeValidated.get(),
            lastFailureReason = lastFailureReason
        )
    }

    private fun createCaptureCallbacks(): AudioCaptureEngine.CaptureCallbacks {
        return object : AudioCaptureEngine.CaptureCallbacks {
            override fun onFrameCaptured(frame: AudioFrame) {
                fanOutPipeline.publishFrame(frame)
            }

            override fun onSoundLevel(level: Double) {
                emitSttEvent(
                    type = "sound_level",
                    generationId = generationIdCounter.get(),
                    extras = mapOf("level" to level)
                )
            }

            override fun onClientSilencedChanged(silenced: Boolean) {
                val previous = clientSilenced.getAndSet(silenced)
                if (silenced && !previous) {
                    logSink.log("W", TAG, "AudioRecord client silenced detected by Android audio policy")
                    synchronized(this@SingleAudioCoordinator) {
                        val current = stateRef.get()
                        if (current == PipelineState.NATIVE_HYBRID_STARTING ||
                            current == PipelineState.NATIVE_HYBRID_ACTIVE ||
                            current == PipelineState.RECONNECTING_STT_PIPE
                        ) {
                            handleFatalOrFallbackLocked(
                                generationId = generationIdCounter.get(),
                                reason = "mic_silenced_by_recognizer"
                            )
                        }
                    }
                }
            }

            override fun onCaptureError(message: String) {
                synchronized(this@SingleAudioCoordinator) {
                    val current = stateRef.get()
                    if (current == PipelineState.NATIVE_HYBRID_STARTING ||
                        current == PipelineState.NATIVE_HYBRID_ACTIVE ||
                        current == PipelineState.RECONNECTING_STT_PIPE
                    ) {
                        handleFatalOrFallbackLocked(
                            generationId = generationIdCounter.get(),
                            reason = "capture_error:$message"
                        )
                    }
                }
            }
        }
    }

    private fun createSttPipeListener(usedSegmentedMode: Boolean): SttPipeListener {
        return object : SttPipeListener {
            override fun onPipeCreated(generationId: Long, writeStream: OutputStream) {
                if (generationId != generationIdCounter.get()) {
                    try {
                        writeStream.close()
                    } catch (_: Exception) {
                    }
                    return
                }
                fanOutPipeline.attachPipe(generationId, writeStream)
            }

            override fun onReadyForSpeech(generationId: Long) {
                synchronized(this@SingleAudioCoordinator) {
                    if (generationId != generationIdCounter.get()) return
                    readyForSpeechSeen.set(true)
                    consecutiveReconnectFailures.set(0)
                    cancelProbeTimeoutLocked()
                    if (!clientSilenced.get()) {
                        runtimeValidated.set(true)
                        stateRef.set(PipelineState.NATIVE_HYBRID_ACTIVE)
                    }
                }
            }

            override fun onStatus(generationId: Long, status: String) {
                if (generationId != generationIdCounter.get()) return
                emitSttEvent(
                    type = "status",
                    generationId = generationId,
                    extras = mapOf("status" to status)
                )
            }

            override fun onPartial(generationId: Long, text: String) {
                if (generationId != generationIdCounter.get()) return
                val seq = sttSequenceCounter.incrementAndGet()
                emitSttEvent(
                    type = "partial",
                    generationId = generationId,
                    extras = mapOf("text" to text, "sequence" to seq)
                )
            }

            override fun onFinal(generationId: Long, text: String, isSegment: Boolean) {
                if (generationId != generationIdCounter.get()) return
                val seq = sttSequenceCounter.incrementAndGet()
                emitSttEvent(
                    type = "final",
                    generationId = generationId,
                    extras = mapOf(
                        "text" to text,
                        "sequence" to seq,
                        "isSegment" to isSegment
                    )
                )
            }

            override fun onSoundLevel(generationId: Long, level: Double) {
                // Capture engine RMS is primary; keep SpeechRecognizer RMS ignored to prevent duplicate chatter
            }

            override fun onEndOfSegmentedSession(generationId: Long) {
                if (generationId != generationIdCounter.get()) return
                emitSttEvent(
                    type = "status",
                    generationId = generationId,
                    extras = mapOf("status" to "notListening")
                )
            }

            override fun onError(generationId: Long, errorCode: Int, errorName: String) {
                synchronized(this@SingleAudioCoordinator) {
                    if (generationId != generationIdCounter.get()) return
                    val current = stateRef.get()
                    if (current == PipelineState.IDLE ||
                        current == PipelineState.STOPPING ||
                        current == PipelineState.DISPOSED ||
                        current == PipelineState.MUTED
                    ) {
                        return
                    }

                    // Normal silence pauses are not errors; notify Flutter turn controller
                    if (errorCode == ERROR_SPEECH_TIMEOUT || errorCode == ERROR_NO_MATCH) {
                        emitSttEvent(
                            type = "status",
                            generationId = generationId,
                            extras = mapOf("status" to "notListening")
                        )
                        return
                    }

                    // If segmented session failed before readiness, degrade once to non-segmented EXTRA_AUDIO_SOURCE
                    if (usedSegmentedMode && !readyForSpeechSeen.get() && !segmentedDowngraded.get() &&
                        (errorCode == ERROR_CLIENT || errorCode == ERROR_SERVER_DISCONNECTED)
                    ) {
                        segmentedDowngraded.set(true)
                        logSink.log("W", TAG, "Downgrading segmented mode to standard EXTRA_AUDIO_SOURCE after $errorName")
                        scheduleReconnectLocked(generationId, delayMs = 150L, reason = "segmented_downgrade")
                        return
                    }

                    // Transient reconnectable errors (ERROR_SERVER_DISCONNECTED / ERROR_NETWORK / TIMEOUT)
                    if (errorCode == ERROR_SERVER_DISCONNECTED ||
                        errorCode == ERROR_NETWORK ||
                        errorCode == ERROR_NETWORK_TIMEOUT
                    ) {
                        val failures = consecutiveReconnectFailures.incrementAndGet()
                        if (failures <= maxConsecutiveReconnects) {
                            val delayMs = if (errorCode == ERROR_SERVER_DISCONNECTED) {
                                reconnectDelayServerDisconnectedMs
                            } else {
                                reconnectDelayNetworkMs
                            }
                            logSink.log(
                                "W",
                                TAG,
                                "Transient STT error $errorName (attempt $failures/$maxConsecutiveReconnects); scheduling pipe reconnect"
                            )
                            scheduleReconnectLocked(generationId, delayMs = delayMs, reason = errorName)
                            return
                        }
                        handleFatalOrFallbackLocked(
                            generationId = generationId,
                            reason = "max_stt_reconnects_exceeded:$errorName"
                        )
                        return
                    }

                    // Fatal / unsupported errors trigger deterministic fallback (or explicit error in forced mode)
                    if (errorCode == ERROR_AUDIO ||
                        errorCode == ERROR_CLIENT ||
                        errorCode == ERROR_INSUFFICIENT_PERMISSIONS ||
                        errorCode == ERROR_LANGUAGE_NOT_SUPPORTED
                    ) {
                        handleFatalOrFallbackLocked(
                            generationId = generationId,
                            reason = "recognizer_fatal:$errorName"
                        )
                        return
                    }

                    emitSttEvent(
                        type = "error",
                        generationId = generationId,
                        extras = mapOf("error" to errorName)
                    )
                }
            }
        }
    }

    private fun handlePipeWriteError(generationId: Long, message: String) {
        synchronized(this) {
            if (generationId != generationIdCounter.get()) return
            val current = stateRef.get()
            if (current != PipelineState.NATIVE_HYBRID_STARTING &&
                current != PipelineState.NATIVE_HYBRID_ACTIVE
            ) {
                return
            }

            if (!runtimeValidated.get() && !readyForSpeechSeen.get()) {
                handleFatalOrFallbackLocked(
                    generationId = generationId,
                    reason = "pipe_write_failed_during_probe:$message"
                )
                return
            }

            val failures = consecutiveReconnectFailures.incrementAndGet()
            if (failures <= maxConsecutiveReconnects) {
                scheduleReconnectLocked(generationId, delayMs = reconnectDelayServerDisconnectedMs, reason = "broken_pipe")
            } else {
                handleFatalOrFallbackLocked(
                    generationId = generationId,
                    reason = "pipe_write_repeated_failure:$message"
                )
            }
        }
    }

    private fun scheduleRuntimeProbeTimeoutLocked(expectedGenerationId: Long) {
        cancelProbeTimeoutLocked()
        if (runtimeValidated.get()) return

        probeTimeoutTask = scheduler.schedule({
            synchronized(this@SingleAudioCoordinator) {
                if (expectedGenerationId != generationIdCounter.get()) return@schedule
                val current = stateRef.get()
                if (current != PipelineState.NATIVE_HYBRID_STARTING &&
                    current != PipelineState.RECONNECTING_STT_PIPE
                ) {
                    return@schedule
                }
                if (!readyForSpeechSeen.get()) {
                    val reason = if (fanOutPipeline.sttBytesWritten == 0L) {
                        "pipe_unresponsive_zero_bytes"
                    } else {
                        "ready_for_speech_timeout"
                    }
                    handleFatalOrFallbackLocked(expectedGenerationId, reason)
                }
            }
        }, probeTimeoutMs, TimeUnit.MILLISECONDS)
    }

    private fun scheduleReconnectLocked(
        failedGenerationId: Long,
        delayMs: Long,
        reason: String
    ) {
        cancelScheduledTasksLocked()
        stateRef.set(PipelineState.RECONNECTING_STT_PIPE)
        fanOutPipeline.detachPipe(failedGenerationId)

        reconnectTask = scheduler.schedule({
            synchronized(this@SingleAudioCoordinator) {
                if (failedGenerationId != generationIdCounter.get()) return@schedule
                if (stateRef.get() != PipelineState.RECONNECTING_STT_PIPE) return@schedule
                if (!captureEngine.isCapturing() || captureEngine.isMuted()) return@schedule

                val newGen = generationIdCounter.incrementAndGet()
                captureEngine.updateGeneration(sessionIdCounter.get(), newGen)
                pipeReconnectCount.incrementAndGet()

                val useSegmented = !segmentedDowngraded.get()
                logSink.log("I", TAG, "Executing synchronized STT pipe reconnect (newGen=$newGen, reason=$reason)")
                val restarted = sttPipeEngine.startSession(
                    generationId = newGen,
                    locale = activeLocale,
                    useSegmentedSession = useSegmented,
                    listener = createSttPipeListener(useSegmented)
                )
                if (!restarted) {
                    handleFatalOrFallbackLocked(newGen, "stt_reconnect_start_failed")
                } else {
                    scheduleRuntimeProbeTimeoutLocked(newGen)
                }
            }
        }, delayMs, TimeUnit.MILLISECONDS)
    }

    private fun handleFatalOrFallbackLocked(generationId: Long, reason: String) {
        if (stateRef.get() == PipelineState.DISPOSED) return
        cancelScheduledTasksLocked()
        lastFailureReason = reason

        val allowFallback = allowAutomaticFallbackFlag.get()
        stateRef.set(if (allowFallback) PipelineState.RELEASING_FOR_FALLBACK else PipelineState.STOPPING)

        // Advance generation so all lingering callbacks are discarded
        val barrierGen = generationIdCounter.incrementAndGet()

        // Enforce Mic-Release Barrier before notifying Flutter
        captureEngine.stopCapture(joinTimeoutMs = 1000L)
        fanOutPipeline.stopAndJoin(timeoutMs = 1000L)
        sttPipeEngine.stopAndWait(timeoutMs = 1000L, destroyRecognizer = true)

        if (allowFallback) {
            stateRef.set(PipelineState.IDLE)
            logSink.log("W", TAG, "Mic-Release Barrier complete; requesting STT_ONLY fallback (reason=$reason)")
            emitSttEvent(
                type = "fallback_required",
                generationId = barrierGen,
                extras = mapOf(
                    "reason" to reason,
                    "diagnostics" to getDiagnostics().toMap()
                )
            )
        } else {
            stateRef.set(PipelineState.NATIVE_HYBRID_FAILED)
            logSink.log("E", TAG, "Forced native_hybrid failed without silent fallback (reason=$reason)")
            emitSttEvent(
                type = "native_hybrid_failed",
                generationId = barrierGen,
                extras = mapOf(
                    "reason" to reason,
                    "diagnostics" to getDiagnostics().toMap()
                )
            )
        }
    }

    private fun cancelProbeTimeoutLocked() {
        probeTimeoutTask?.cancel(false)
        probeTimeoutTask = null
    }

    private fun cancelScheduledTasksLocked() {
        cancelProbeTimeoutLocked()
        reconnectTask?.cancel(false)
        reconnectTask = null
    }

    private fun emitSttEvent(
        type: String,
        generationId: Long,
        extras: Map<String, Any> = emptyMap()
    ) {
        val payload = mutableMapOf<String, Any>(
            "type" to type,
            "sttSessionId" to sessionIdCounter.get(),
            "generationId" to generationId,
            "timestampMs" to clockMs()
        )
        payload.putAll(extras)
        try {
            onSttEvent(payload)
        } catch (e: Exception) {
            logSink.log("W", TAG, "onSttEvent listener threw: ${e.message}")
        }
    }
}
