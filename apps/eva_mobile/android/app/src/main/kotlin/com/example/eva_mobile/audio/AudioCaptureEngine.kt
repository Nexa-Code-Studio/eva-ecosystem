package com.example.eva_mobile.audio

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.sqrt

/**
 * Thread-safe bounded egress queue with drop-oldest backpressure policy so
 * the AudioRecord reader thread never stalls on platform-channel delivery.
 */
internal class BoundedPcmQueue(private val capacity: Int) {
    init {
        require(capacity > 0) { "Queue capacity must be > 0" }
    }

    private val queue = LinkedBlockingQueue<ByteArray>(capacity)
    private val droppedCount = AtomicLong(0)

    fun offerDropOldest(frame: ByteArray) {
        while (!queue.offer(frame)) {
            if (queue.poll() != null) {
                droppedCount.incrementAndGet()
            }
        }
    }

    fun poll(timeoutMs: Long): ByteArray? = queue.poll(timeoutMs, TimeUnit.MILLISECONDS)

    fun clear() {
        queue.clear()
    }

    fun size(): Int = queue.size

    fun droppedFrames(): Long = droppedCount.get()
}

/**
 * Pure PCM16 little-endian signal level helper normalized to [0.0, 1.0].
 */
internal object PcmSignalMetrics {
    fun computeNormalizedRms(buffer: ByteArray, bytesRead: Int): Double {
        val sampleCount = bytesRead / 2
        if (sampleCount <= 0) return 0.0

        var sumSquares = 0.0
        val limit = sampleCount * 2
        var i = 0
        while (i < limit) {
            val lo = buffer[i].toInt() and 0xFF
            val hi = buffer[i + 1].toInt() shl 8
            val sample = (lo or hi).toShort().toDouble()
            sumSquares += sample * sample
            i += 2
        }
        val rms = sqrt(sumSquares / sampleCount)
        return (rms / 32767.0).coerceIn(0.0, 1.0)
    }
}

/**
 * Single-owner raw PCM 16kHz 16-bit mono audio capture engine.
 * Captures 4800-byte (150ms) frames uniformly on physical Android devices and emulators,
 * queues chunks through a single bounded egress queue, and computes normalized RMS levels.
 */
class AudioCaptureEngine {

    companion object {
        private const val TAG = "AudioCaptureEngine"
        const val SAMPLE_RATE = 16000
        const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        // 150ms at 16kHz 16-bit mono: 16000 * 2 bytes/sample * 0.150s = 4800 bytes
        const val CHUNK_SIZE_BYTES = 4800
        const val EGRESS_QUEUE_CAPACITY = 24
    }

    interface AudioCaptureListener {
        fun onAudioChunk(bytes: ByteArray)
        fun onSoundLevel(level: Double)
        fun onError(message: String)
    }

    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null
    private var egressThread: Thread? = null
    private val isCapturing = AtomicBoolean(false)
    private val isMuted = AtomicBoolean(false)
    private val egressQueue = BoundedPcmQueue(EGRESS_QUEUE_CAPACITY)

    @Volatile
    private var activeListener: AudioCaptureListener? = null

    @Synchronized
    @SuppressLint("MissingPermission")
    fun startCapture(listener: AudioCaptureListener?): Boolean {
        activeListener = listener

        if (isCapturing.get()) {
            return true
        }

        val minBufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        if (minBufferSize == AudioRecord.ERROR || minBufferSize == AudioRecord.ERROR_BAD_VALUE) {
            listener?.onError("Invalid AudioRecord parameters: minBufferSize=$minBufferSize")
            return false
        }

        val bufferSize = maxOf(minBufferSize * 2, CHUNK_SIZE_BYTES * 2)

        try {
            val record = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize
            )

            if (record.state != AudioRecord.STATE_INITIALIZED) {
                record.release()
                val err = "AudioRecord failed to initialize (state=${record.state})"
                Log.e(TAG, err)
                listener?.onError(err)
                return false
            }

            egressQueue.clear()
            audioRecord = record
            record.startRecording()
            isCapturing.set(true)

            egressThread = Thread({
                while (isCapturing.get()) {
                    try {
                        val frame = egressQueue.poll(150) ?: continue
                        if (!isMuted.get() && isCapturing.get()) {
                            activeListener?.onAudioChunk(frame)
                        }
                    } catch (_: InterruptedException) {
                        break
                    }
                }
            }, "EvaPcmEgressThread").apply {
                isDaemon = true
                start()
            }

            captureThread = Thread({
                val buffer = ByteArray(CHUNK_SIZE_BYTES)
                Log.i(TAG, "Audio capture started (16kHz 16-bit mono, chunk=${CHUNK_SIZE_BYTES}B)")

                while (isCapturing.get()) {
                    val bytesRead = record.read(buffer, 0, buffer.size)
                    if (bytesRead > 0 && isCapturing.get()) {
                        if (isMuted.get()) {
                            activeListener?.onSoundLevel(0.0)
                            continue
                        }
                        val normalizedLevel = PcmSignalMetrics.computeNormalizedRms(buffer, bytesRead)
                        activeListener?.onSoundLevel(normalizedLevel)
                        egressQueue.offerDropOldest(buffer.copyOf(bytesRead))
                    } else if (bytesRead < 0) {
                        Log.w(TAG, "AudioRecord.read() error code: $bytesRead")
                    }
                }

                Log.i(TAG, "Audio capture loop exited (droppedFrames=${egressQueue.droppedFrames()})")
            }, "EvaPcmCaptureThread").apply {
                isDaemon = true
                start()
            }

            return true
        } catch (e: Exception) {
            val err = "Audio capture initialization error: ${e.message}"
            Log.e(TAG, err, e)
            listener?.onError(err)
            stopCapture()
            return false
        }
    }

    @Synchronized
    fun stopCapture() {
        if (!isCapturing.getAndSet(false)) {
            egressQueue.clear()
            return
        }

        activeListener = null
        egressQueue.clear()

        try {
            egressThread?.interrupt()
            egressThread = null
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping egress thread: ${e.message}")
        }

        try {
            captureThread?.interrupt()
            captureThread = null
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping capture thread: ${e.message}")
        }

        try {
            audioRecord?.apply {
                if (recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                    stop()
                }
                release()
            }
            audioRecord = null
        } catch (e: Exception) {
            Log.w(TAG, "Error releasing AudioRecord: ${e.message}")
        }

        Log.i(TAG, "Audio capture stopped and released")
    }

    fun setMuted(muted: Boolean) {
        isMuted.set(muted)
        if (muted) {
            egressQueue.clear()
        }
    }

    fun isMuted(): Boolean = isMuted.get()

    fun isCapturing(): Boolean = isCapturing.get()
}
