package com.example.eva_mobile.audio

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.OutputStream
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.PI
import kotlin.math.roundToInt
import kotlin.math.sin

class AudioFanOutPipelineTest {

    private fun generateDeterministicPcmFrames(
        frameCount: Int,
        sessionId: Long = 1L,
        generationId: Long = 1L,
        amplitude: Double = 16000.0
    ): List<AudioFrame> {
        val sampleRate = AudioCaptureEngine.SAMPLE_RATE
        val samplesPerFrame = AudioCaptureEngine.CHUNK_SIZE_BYTES / 2
        val frames = mutableListOf<AudioFrame>()
        var sampleIndex = 0
        for (idx in 0 until frameCount) {
            val bytes = ByteArray(AudioCaptureEngine.CHUNK_SIZE_BYTES)
            for (s in 0 until samplesPerFrame) {
                val angle = 2.0 * PI * 440.0 * sampleIndex / sampleRate
                val value = (sin(angle) * amplitude).roundToInt().coerceIn(-32768, 32767)
                bytes[s * 2] = (value and 0xFF).toByte()
                bytes[s * 2 + 1] = ((value ushr 8) and 0xFF).toByte()
                sampleIndex++
            }
            frames.add(
                AudioFrame(
                    sessionId = sessionId,
                    generationId = generationId,
                    sequence = (idx + 1).toLong(),
                    timestampMs = 1000L + idx * 150L,
                    pcmBytes = bytes,
                    rmsLevel = AudioCaptureEngine.computeNormalizedRms(bytes, bytes.size)
                )
            )
        }
        return frames
    }

    @Test
    fun deterministicPcmFixture_bitExactFanOutToBothConsumersAndAccurateRms() {
        val fixtures = generateDeterministicPcmFrames(frameCount = 25, sessionId = 7L, generationId = 3L)
        val expectedConcat = ByteArrayOutputStream()
        fixtures.forEach { expectedConcat.write(it.pcmBytes) }

        val sttStream = ByteArrayOutputStream()
        val emotionReceived = CopyOnWriteArrayList<AudioFrame>()
        val emotionLatch = CountDownLatch(fixtures.size)

        val pipeline = AudioFanOutPipeline(
            sttQueueCapacity = 30,
            emotionQueueCapacity = 30,
            emotionConsumer = { frame ->
                emotionReceived.add(frame)
                emotionLatch.countDown()
            }
        )

        pipeline.start()
        pipeline.attachPipe(generationId = 3L, outputStream = sttStream)

        fixtures.forEach { pipeline.publishFrame(it) }

        assertTrue("Emotion consumer timed out", emotionLatch.await(3, TimeUnit.SECONDS))
        // Wait for STT pipe writer to drain all 25 frames
        val deadline = System.currentTimeMillis() + 3000L
        while (pipeline.sttWrittenFrames < fixtures.size && System.currentTimeMillis() < deadline) {
            Thread.sleep(10)
        }

        assertTrue(pipeline.stopAndJoin(1000L))

        assertEquals(25L, pipeline.capturedFrames)
        assertEquals(25L, pipeline.sttWrittenFrames)
        assertEquals(25L, pipeline.emotionDeliveredFrames)
        assertEquals(0L, pipeline.sttDroppedFrames)
        assertEquals(0L, pipeline.emotionDroppedFrames)
        assertEquals(25L * AudioCaptureEngine.CHUNK_SIZE_BYTES, pipeline.sttBytesWritten)

        // Bit-exact verification for STT pipe consumer
        assertArrayEquals(expectedConcat.toByteArray(), sttStream.toByteArray())

        // Bit-exact & metadata verification for Emotion consumer
        val emotionConcat = ByteArrayOutputStream()
        emotionReceived.forEachIndexed { idx, frame ->
            assertEquals(7L, frame.sessionId)
            assertEquals(3L, frame.generationId)
            assertEquals((idx + 1).toLong(), frame.sequence)
            emotionConcat.write(frame.pcmBytes)
        }
        assertArrayEquals(expectedConcat.toByteArray(), emotionConcat.toByteArray())

        // RMS verification (440Hz sine with amplitude 16000 -> RMS ~ 11313 / 32767 ~ 0.345)
        val firstRms = fixtures.first().rmsLevel
        assertTrue("Expected RMS near 0.345, got $firstRms", firstRms in 0.30..0.40)
        val silenceRms = AudioCaptureEngine.computeNormalizedRms(ByteArray(4800), 4800)
        assertEquals(0.0, silenceRms, 0.0001)
    }

    @Test
    fun failureIsolation_emotionConsumerCrashNeverInterruptsSttPipe() {
        val fixtures = generateDeterministicPcmFrames(frameCount = 10, generationId = 1L)
        val sttStream = ByteArrayOutputStream()

        val pipeline = AudioFanOutPipeline(
            emotionConsumer = { throw RuntimeException("Simulated WS/EventChannel failure") }
        )

        pipeline.start()
        pipeline.attachPipe(generationId = 1L, outputStream = sttStream)
        fixtures.forEach { pipeline.publishFrame(it) }

        val deadline = System.currentTimeMillis() + 3000L
        while (pipeline.sttWrittenFrames < fixtures.size && System.currentTimeMillis() < deadline) {
            Thread.sleep(10)
        }
        while (pipeline.emotionConsumerErrors < fixtures.size && System.currentTimeMillis() < deadline) {
            Thread.sleep(10)
        }

        assertTrue(pipeline.stopAndJoin(1000L))
        assertEquals(10L, pipeline.sttWrittenFrames)
        assertEquals(10L, pipeline.emotionConsumerErrors)
        assertEquals(10 * AudioCaptureEngine.CHUNK_SIZE_BYTES, sttStream.size())
    }

    @Test
    fun failureIsolation_brokenSttPipeNeverInterruptsEmotionConsumer() {
        val fixtures = generateDeterministicPcmFrames(frameCount = 12, generationId = 2L)
        val emotionLatch = CountDownLatch(fixtures.size)
        val pipeErrorReports = AtomicInteger(0)

        val brokenPipe = object : OutputStream() {
            override fun write(b: Int) {
                throw IOException("Broken pipe")
            }

            override fun write(b: ByteArray, off: Int, len: Int) {
                throw IOException("Broken pipe")
            }
        }

        val pipeline = AudioFanOutPipeline(
            emotionConsumer = { emotionLatch.countDown() },
            onPipeWriteError = { _, _ -> pipeErrorReports.incrementAndGet() }
        )

        pipeline.start()
        pipeline.attachPipe(generationId = 2L, outputStream = brokenPipe)
        fixtures.forEach { pipeline.publishFrame(it) }

        assertTrue("Emotion consumer should still receive 100% of frames", emotionLatch.await(3, TimeUnit.SECONDS))
        val deadline = System.currentTimeMillis() + 2000L
        while (pipeErrorReports.get() < 1 && System.currentTimeMillis() < deadline) {
            Thread.sleep(10)
        }

        assertTrue(pipeline.stopAndJoin(1000L))
        assertEquals("Pipe error must be debounced once per generation", 1, pipeErrorReports.get())
        assertEquals(12L, pipeline.emotionDeliveredFrames)
    }

    @Test
    fun generationGuard_pipeSwapSkipsStaleFramesWhileEmotionContinues() {
        val gen1Frames = generateDeterministicPcmFrames(frameCount = 4, generationId = 1L)
        val gen2Frames = generateDeterministicPcmFrames(frameCount = 4, generationId = 2L)
        val pipe2 = ByteArrayOutputStream()
        val emotionLatch = CountDownLatch(8)

        val pipeline = AudioFanOutPipeline(
            emotionConsumer = { emotionLatch.countDown() }
        )
        pipeline.start()
        pipeline.attachPipe(generationId = 2L, outputStream = pipe2)

        // Publish stale gen1 frames followed by valid gen2 frames
        gen1Frames.forEach { pipeline.publishFrame(it) }
        gen2Frames.forEach { pipeline.publishFrame(it) }

        assertTrue(emotionLatch.await(3, TimeUnit.SECONDS))
        val deadline = System.currentTimeMillis() + 3000L
        while (pipeline.sttWrittenFrames < 4 && System.currentTimeMillis() < deadline) {
            Thread.sleep(10)
        }

        assertTrue(pipeline.stopAndJoin(1000L))
        assertEquals(4L, pipeline.sttWrittenFrames)
        assertEquals(4 * AudioCaptureEngine.CHUNK_SIZE_BYTES, pipe2.size())
        assertEquals(8L, pipeline.emotionDeliveredFrames)
    }
}
