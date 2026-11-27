package com.example.eva_mobile.audio

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AudioCaptureEngineTest {

    @Test
    fun chunkSizeMatches150MsAt16kHzPcm16Mono() {
        assertEquals(16000, AudioCaptureEngine.SAMPLE_RATE)
        assertEquals(4800, AudioCaptureEngine.CHUNK_SIZE_BYTES)
    }

    @Test
    fun boundedQueueDropsOldestWhenCapacityExceeded() {
        val queue = BoundedPcmQueue(capacity = 3)
        queue.offerDropOldest(byteArrayOf(1))
        queue.offerDropOldest(byteArrayOf(2))
        queue.offerDropOldest(byteArrayOf(3))
        queue.offerDropOldest(byteArrayOf(4))
        queue.offerDropOldest(byteArrayOf(5))

        assertEquals(3, queue.size())
        assertEquals(2L, queue.droppedFrames())
        assertArrayEquals(byteArrayOf(3), queue.poll(10))
        assertArrayEquals(byteArrayOf(4), queue.poll(10))
        assertArrayEquals(byteArrayOf(5), queue.poll(10))
    }

    @Test
    fun computeNormalizedRmsHandlesSilenceAndFullScale() {
        val silence = ByteArray(4800)
        assertEquals(0.0, PcmSignalMetrics.computeNormalizedRms(silence, silence.size), 1e-6)

        val fullScale = ByteArray(4)
        // Little-endian Short.MAX_VALUE (32767 = 0x7FFF) repeated twice
        fullScale[0] = 0xFF.toByte()
        fullScale[1] = 0x7F.toByte()
        fullScale[2] = 0xFF.toByte()
        fullScale[3] = 0x7F.toByte()
        assertEquals(1.0, PcmSignalMetrics.computeNormalizedRms(fullScale, fullScale.size), 1e-4)

        val halfScale = ByteArray(2)
        // 16384 = 0x4000
        halfScale[0] = 0x00
        halfScale[1] = 0x40
        assertEquals(0.5, PcmSignalMetrics.computeNormalizedRms(halfScale, halfScale.size), 0.01)
    }

    @Test
    fun stopAndMuteOperationsAreIdempotentWithoutHardware() {
        val engine = AudioCaptureEngine()
        assertFalse(engine.isCapturing())
        assertFalse(engine.isMuted())

        engine.stopCapture()
        engine.stopCapture()
        assertFalse(engine.isCapturing())

        engine.setMuted(true)
        assertTrue(engine.isMuted())
        engine.setMuted(true)
        assertTrue(engine.isMuted())

        engine.setMuted(false)
        assertFalse(engine.isMuted())
    }
}
