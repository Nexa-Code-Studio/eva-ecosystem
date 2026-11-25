package com.example.eva_mobile.audio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

class SingleAudioCoordinatorTest {

    private class MicOwnershipTracker {
        val activeOwners = AtomicInteger(0)
        val maxConcurrentOwners = AtomicInteger(0)

        fun acquire() {
            val current = activeOwners.incrementAndGet()
            maxConcurrentOwners.accumulateAndGet(current, ::maxOf)
        }

        fun release() {
            activeOwners.decrementAndGet()
        }
    }

    private class FakePcmFrameSource(
        private val tracker: MicOwnershipTracker
    ) : PcmFrameSource {
        override val audioSessionId: Int = 101
        private val running = AtomicBoolean(false)
        private val released = AtomicBoolean(false)
        @Volatile
        var silenceCallback: ((Boolean) -> Unit)? = null

        override fun start(): Boolean {
            if (running.compareAndSet(false, true)) {
                tracker.acquire()
            }
            return true
        }

        override fun read(buffer: ByteArray, offset: Int, size: Int): Int {
            if (!running.get()) return -1
            try {
                Thread.sleep(5)
            } catch (_: InterruptedException) {
                return -1
            }
            if (!running.get()) return -1
            for (i in offset until (offset + size)) {
                buffer[i] = 0x10
            }
            return size
        }

        override fun stop() {
            running.set(false)
        }

        override fun release() {
            running.set(false)
            if (released.compareAndSet(false, true)) {
                tracker.release()
            }
        }

        override fun registerSilenceCallback(callback: (Boolean) -> Unit) {
            silenceCallback = callback
        }

        override fun unregisterSilenceCallback() {
            silenceCallback = null
        }
    }

    private class FakeSttPipeEngine : SttPipeEngine {
        val startedGenerations = CopyOnWriteArrayList<Long>()
        val pipesByGeneration = mutableMapOf<Long, ByteArrayOutputStream>()
        @Volatile
        var lastListener: SttPipeListener? = null
        @Volatile
        var lastGeneration: Long = 0L
        val stopCount = AtomicInteger(0)
        val destroyCount = AtomicInteger(0)

        override fun startSession(
            generationId: Long,
            locale: String,
            useSegmentedSession: Boolean,
            listener: SttPipeListener
        ): Boolean {
            startedGenerations.add(generationId)
            lastGeneration = generationId
            lastListener = listener
            val out = ByteArrayOutputStream()
            synchronized(pipesByGeneration) {
                pipesByGeneration[generationId] = out
            }
            listener.onPipeCreated(generationId, out)
            return true
        }

        override fun stopAndWait(timeoutMs: Long, destroyRecognizer: Boolean): Boolean {
            stopCount.incrementAndGet()
            if (destroyRecognizer) destroyCount.incrementAndGet()
            return true
        }

        override fun closeWriteEnd(generationId: Long) {
            synchronized(pipesByGeneration) {
                pipesByGeneration[generationId]?.close()
            }
        }

        override fun destroy() {
            destroyCount.incrementAndGet()
        }
    }

    private fun supportedCapability(): CapabilityProvider = CapabilityProvider {
        NativeCapabilityReport(
            sdkInt = 35,
            isRecognitionAvailable = true,
            isOnDeviceAvailable = true,
            recognitionServicePackage = "com.google.android.tts",
            supportsAudioSourceApi = true,
            localeSupported = true,
            segmentedSessionCandidate = true,
            checkSupportStatus = "supported"
        )
    }

    @Test
    fun nativeHybrid_normalFlowValidatesRuntimeAndGuardsStaleCallbacksWithoutLoggingTranscripts() {
        val tracker = MicOwnershipTracker()
        val fakeStt = FakeSttPipeEngine()
        val emittedEvents = CopyOnWriteArrayList<Map<String, Any>>()
        val capturedLogs = CopyOnWriteArrayList<String>()
        val emotionFrameLatch = CountDownLatch(3)

        val captureEngine = AudioCaptureEngine(
            frameSourceFactory = { _, _ -> FakePcmFrameSource(tracker) },
            logSink = { _, _, msg -> capturedLogs.add(msg) }
        )

        val coordinator = SingleAudioCoordinator(
            capabilityProvider = supportedCapability(),
            captureEngine = captureEngine,
            sttPipeEngine = fakeStt,
            onAudioFrameEgress = { emotionFrameLatch.countDown() },
            onSttEvent = { emittedEvents.add(it) },
            probeTimeoutMs = 500L,
            logSink = { _, _, msg -> capturedLogs.add(msg) }
        )

        assertTrue(coordinator.startNativeHybrid(sttSessionId = 42L, locale = "id-ID"))
        val gen1 = fakeStt.lastGeneration
        fakeStt.lastListener?.onReadyForSpeech(gen1)

        assertTrue(coordinator.isRuntimeValidated)
        assertEquals(PipelineState.NATIVE_HYBRID_ACTIVE, coordinator.state)
        assertTrue(emotionFrameLatch.await(2, TimeUnit.SECONDS))

        // Emit partial & final transcript on current gen, plus stale transcript on old gen
        val sensitiveText = "rahasia konseling sensitif 12345"
        fakeStt.lastListener?.onPartial(gen1, sensitiveText)
        fakeStt.lastListener?.onFinal(gen1, sensitiveText, isSegment = true)
        fakeStt.lastListener?.onPartial(gen1 - 1, "stale text should be ignored")

        val partials = emittedEvents.filter { it["type"] == "partial" }
        val finals = emittedEvents.filter { it["type"] == "final" }
        assertEquals(1, partials.size)
        assertEquals(1, finals.size)
        assertEquals(42L, partials.first()["sttSessionId"])
        assertEquals(gen1, partials.first()["generationId"])

        // Privacy invariant: raw transcript must never appear in logs
        assertTrue(capturedLogs.none { it.contains(sensitiveText) })

        assertTrue(coordinator.stopAll(destroyRecognizer = true))
        assertEquals(0, tracker.activeOwners.get())
        assertEquals(1, tracker.maxConcurrentOwners.get())
        coordinator.destroy()
    }

    @Test
    fun pipeReconnect_error11ReattachesNewPipeWithoutStoppingEmotionStream() {
        val tracker = MicOwnershipTracker()
        val fakeStt = FakeSttPipeEngine()
        val emotionCount = AtomicInteger(0)

        val captureEngine = AudioCaptureEngine(
            frameSourceFactory = { _, _ -> FakePcmFrameSource(tracker) }
        )

        val coordinator = SingleAudioCoordinator(
            capabilityProvider = supportedCapability(),
            captureEngine = captureEngine,
            sttPipeEngine = fakeStt,
            onAudioFrameEgress = { emotionCount.incrementAndGet() },
            onSttEvent = {},
            probeTimeoutMs = 1000L,
            reconnectDelayServerDisconnectedMs = 50L
        )

        assertTrue(coordinator.startNativeHybrid(sttSessionId = 10L))
        val gen1 = fakeStt.lastGeneration
        fakeStt.lastListener?.onReadyForSpeech(gen1)

        // Inject ERROR_SERVER_DISCONNECTED (11)
        fakeStt.lastListener?.onError(gen1, SingleAudioCoordinator.ERROR_SERVER_DISCONNECTED, "error_server_disconnected")

        // Wait for synchronized reconnect to start gen2
        val deadline = System.currentTimeMillis() + 2000L
        while (fakeStt.startedGenerations.size < 2 && System.currentTimeMillis() < deadline) {
            Thread.sleep(10)
        }

        assertEquals(2, fakeStt.startedGenerations.size)
        val gen2 = fakeStt.startedGenerations[1]
        assertTrue(gen2 > gen1)
        fakeStt.lastListener?.onReadyForSpeech(gen2)

        assertEquals(PipelineState.NATIVE_HYBRID_ACTIVE, coordinator.state)
        assertEquals(1, coordinator.getDiagnostics().pipeReconnectCount)
        assertEquals(1, tracker.maxConcurrentOwners.get())
        assertTrue(emotionCount.get() > 0)

        coordinator.destroy()
        assertEquals(0, tracker.activeOwners.get())
    }

    @Test
    fun runtimeProbeFailure_isClientSilencedAutoModeReleasesMicAndRequestsFallback() {
        val tracker = MicOwnershipTracker()
        lateinit var activeSource: FakePcmFrameSource
        val fakeStt = FakeSttPipeEngine()
        val fallbackLatch = CountDownLatch(1)
        val fallbackEvents = CopyOnWriteArrayList<Map<String, Any>>()

        val captureEngine = AudioCaptureEngine(
            frameSourceFactory = { _, _ ->
                FakePcmFrameSource(tracker).also { activeSource = it }
            }
        )

        val coordinator = SingleAudioCoordinator(
            capabilityProvider = supportedCapability(),
            captureEngine = captureEngine,
            sttPipeEngine = fakeStt,
            onAudioFrameEgress = {},
            onSttEvent = { event ->
                if (event["type"] == "fallback_required") {
                    fallbackEvents.add(event)
                    fallbackLatch.countDown()
                }
            },
            probeTimeoutMs = 1000L
        )

        assertTrue(
            coordinator.startNativeHybrid(
                sttSessionId = 5L,
                allowAutomaticFallback = true
            )
        )

        // Simulate Android OS silencing our AudioRecord because RecognitionService stole the mic
        activeSource.silenceCallback?.invoke(true)

        assertTrue(fallbackLatch.await(2, TimeUnit.SECONDS))
        assertEquals(0, tracker.activeOwners.get())
        assertFalse(captureEngine.isCapturing())
        assertEquals("mic_silenced_by_recognizer", fallbackEvents.first()["reason"])
        coordinator.destroy()
    }

    @Test
    fun forcedNativeHybrid_neverPerformsSilentFallbackOnProbeTimeout() {
        val tracker = MicOwnershipTracker()
        val fakeStt = FakeSttPipeEngine()
        val failedLatch = CountDownLatch(1)
        val events = CopyOnWriteArrayList<Map<String, Any>>()

        val captureEngine = AudioCaptureEngine(
            frameSourceFactory = { _, _ -> FakePcmFrameSource(tracker) }
        )

        val coordinator = SingleAudioCoordinator(
            capabilityProvider = supportedCapability(),
            captureEngine = captureEngine,
            sttPipeEngine = fakeStt,
            onAudioFrameEgress = {},
            onSttEvent = { event ->
                events.add(event)
                if (event["type"] == "native_hybrid_failed") {
                    failedLatch.countDown()
                }
            },
            probeTimeoutMs = 120L
        )

        // allowAutomaticFallback = false (forced native_hybrid QA mode)
        assertTrue(
            coordinator.startNativeHybrid(
                sttSessionId = 9L,
                allowAutomaticFallback = false
            )
        )

        // Never fire onReadyForSpeech -> probe timeout must fire
        assertTrue(failedLatch.await(2, TimeUnit.SECONDS))
        assertEquals(PipelineState.NATIVE_HYBRID_FAILED, coordinator.state)
        assertEquals(0, tracker.activeOwners.get())
        assertFalse(captureEngine.isCapturing())
        assertTrue("Forced mode must NEVER emit fallback_required", events.none { it["type"] == "fallback_required" })
        coordinator.destroy()
    }

    @Test
    fun idempotentControls_muteUnmuteAndRepeatedStopAreSafe() {
        val tracker = MicOwnershipTracker()
        val fakeStt = FakeSttPipeEngine()
        val captureEngine = AudioCaptureEngine(
            frameSourceFactory = { _, _ -> FakePcmFrameSource(tracker) }
        )

        val coordinator = SingleAudioCoordinator(
            capabilityProvider = supportedCapability(),
            captureEngine = captureEngine,
            sttPipeEngine = fakeStt,
            onAudioFrameEgress = {},
            onSttEvent = {},
            probeTimeoutMs = 1000L
        )

        assertTrue(coordinator.startNativeHybrid(sttSessionId = 1L))
        fakeStt.lastListener?.onReadyForSpeech(fakeStt.lastGeneration)

        // Double mute is idempotent
        assertTrue(coordinator.setMuted(true))
        assertTrue(coordinator.setMuted(true))
        assertEquals(PipelineState.MUTED, coordinator.state)

        // Unmute re-arms STT with a fresh generation
        val genBeforeUnmute = coordinator.currentGenerationId
        assertTrue(coordinator.setMuted(false))
        assertTrue(coordinator.currentGenerationId > genBeforeUnmute)

        // Double stopAll is idempotent
        assertTrue(coordinator.stopAll())
        assertTrue(coordinator.stopAll())
        assertEquals(PipelineState.IDLE, coordinator.state)
        assertEquals(0, tracker.activeOwners.get())

        coordinator.destroy()
        coordinator.destroy()
        assertEquals(PipelineState.DISPOSED, coordinator.state)
    }
}
