package com.example.eva_mobile.audio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.io.OutputStream
import java.util.concurrent.atomic.AtomicInteger

class AudioBackpressureAndLeakTest {

    private fun dummyFrame(seq: Long, gen: Long = 1L): AudioFrame {
        return AudioFrame(
            sessionId = 1L,
            generationId = gen,
            sequence = seq,
            timestampMs = seq * 150L,
            pcmBytes = ByteArray(AudioCaptureEngine.CHUNK_SIZE_BYTES),
            rmsLevel = 0.25
        )
    }

    @Test
    fun backpressure_slowConsumersNeverBlockPublisherAndRespectQueueBounds() {
        val slowPipe = object : OutputStream() {
            override fun write(b: Int) {}
            override fun write(b: ByteArray, off: Int, len: Int) {
                try {
                    Thread.sleep(60)
                } catch (_: InterruptedException) {
                    Thread.currentThread().interrupt()
                }
            }
        }

        val pipeline = AudioFanOutPipeline(
            sttQueueCapacity = 20,
            emotionQueueCapacity = 20,
            emotionConsumer = {
                try {
                    Thread.sleep(60)
                } catch (_: InterruptedException) {
                    Thread.currentThread().interrupt()
                }
            }
        )

        pipeline.start()
        pipeline.attachPipe(generationId = 1L, outputStream = slowPipe)

        val startMs = System.currentTimeMillis()
        for (i in 1..500) {
            pipeline.publishFrame(dummyFrame(i.toLong()))
            assertTrue("STT queue exceeded bound 20", pipeline.sttQueueSize <= 20)
            assertTrue("Emotion queue exceeded bound 20", pipeline.emotionQueueSize <= 20)
        }
        val elapsedMs = System.currentTimeMillis() - startMs

        // Publishing 500 frames non-blockingly must complete quickly (< 1000ms) despite 60ms slow consumers
        assertTrue("publishFrame blocked for ${elapsedMs}ms", elapsedMs < 1000L)
        assertTrue("Expected STT backpressure drops", pipeline.sttDroppedFrames > 0)
        assertTrue("Expected Emotion backpressure drops", pipeline.emotionDroppedFrames > 0)

        assertTrue("Workers failed to join cleanly", pipeline.stopAndJoin(1500L))
    }

    @Test
    fun leakCheck_100StartStopCyclesCloseAllStreamsAndJoinAllThreads() {
        val closedStreams = AtomicInteger(0)
        val createdStreams = AtomicInteger(0)

        val pipeline = AudioFanOutPipeline(
            emotionConsumer = {}
        )

        for (cycle in 1..100) {
            pipeline.start()
            createdStreams.incrementAndGet()
            val trackedStream = object : OutputStream() {
                private var closed = false
                override fun write(b: Int) {}
                override fun write(b: ByteArray, off: Int, len: Int) {}
                override fun close() {
                    if (!closed) {
                        closed = true
                        closedStreams.incrementAndGet()
                    }
                }
            }
            pipeline.attachPipe(generationId = cycle.toLong(), outputStream = trackedStream)
            for (f in 1..10) {
                pipeline.publishFrame(dummyFrame(f.toLong(), gen = cycle.toLong()))
            }
            assertTrue("Cycle $cycle failed clean stopAndJoin", pipeline.stopAndJoin(1000L))
        }

        assertEquals("Every created pipe OutputStream must be closed", createdStreams.get(), closedStreams.get())
        val lingeringWorkers = Thread.getAllStackTraces().keys.count {
            it.isAlive && (it.name == "EvaSttPipeWriterWorker" || it.name == "EvaEmotionEgressWorker")
        }
        assertEquals("Zero lingering worker threads expected", 0, lingeringWorkers)
    }

    @Test
    fun soakTest_accelerated30MinuteConversationWith30TurnRearms() {
        // 12,000 frames * 150ms = 1,800,000ms = 30 minutes of continuous speech
        val totalFrames = 12_000
        val emotionReceived = AtomicInteger(0)
        val pipeline = AudioFanOutPipeline(
            sttQueueCapacity = 20,
            emotionQueueCapacity = 20,
            emotionConsumer = { emotionReceived.incrementAndGet() }
        )

        pipeline.start()
        var currentGen = 1L
        pipeline.attachPipe(currentGen, ByteArrayOutputStream())

        for (i in 1..totalFrames) {
            if (i % 400 == 0) {
                // Simulate 30 turn re-arms (every 60s of simulated speech)
                currentGen++
                pipeline.attachPipe(currentGen, ByteArrayOutputStream())
            }
            pipeline.publishFrame(dummyFrame(i.toLong(), gen = currentGen))
        }

        assertTrue(pipeline.stopAndJoin(2000L))
        assertEquals(totalFrames.toLong(), pipeline.capturedFrames)
        assertEquals(totalFrames.toLong(), pipeline.emotionQueuedFrames)
        assertTrue("Emotion delivered + dropped must not exceed queued",
            pipeline.emotionDeliveredFrames + pipeline.emotionDroppedFrames <= pipeline.emotionQueuedFrames)
        assertTrue("Expected significant emotion frame throughput during soak", emotionReceived.get() > 0)
    }
}
