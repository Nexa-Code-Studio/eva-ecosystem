package com.example.eva_mobile.audio

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioRecordingConfiguration
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.sqrt

/**
 * Hardware AudioRecord implementation of PcmFrameSource.
 * Prefers VOICE_RECOGNITION and falls back to MIC if HAL initialization fails.
 * Monitors AudioRecordingConfiguration.isClientSilenced() on Android 10+ (API 29+).
 */
class AndroidAudioRecordSource(
    private val context: Context,
    private val sampleRate: Int = AudioCaptureEngine.SAMPLE_RATE,
    private val chunkSizeBytes: Int = AudioCaptureEngine.CHUNK_SIZE_BYTES
) : PcmFrameSource {

    companion object {
        private const val TAG = "AndroidAudioRecordSrc"
    }

    private var audioRecord: AudioRecord? = null
    private var recordingCallback: AudioManager.AudioRecordingCallback? = null

    override val audioSessionId: Int
        get() = audioRecord?.audioSessionId ?: AudioManager.ERROR

    @SuppressLint("MissingPermission")
    override fun start(): Boolean {
        val minBufferSize = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioCaptureEngine.CHANNEL_CONFIG,
            AudioCaptureEngine.AUDIO_FORMAT
        )
        if (minBufferSize == AudioRecord.ERROR || minBufferSize == AudioRecord.ERROR_BAD_VALUE) {
            Log.e(TAG, "Invalid AudioRecord parameters: minBufferSize=$minBufferSize")
            return false
        }

        val bufferSize = maxOf(minBufferSize * 2, chunkSizeBytes * 2)
        val candidateSources = intArrayOf(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            MediaRecorder.AudioSource.MIC
        )

        for (source in candidateSources) {
            var candidate: AudioRecord? = null
            try {
                candidate = AudioRecord(
                    source,
                    sampleRate,
                    AudioCaptureEngine.CHANNEL_CONFIG,
                    AudioCaptureEngine.AUDIO_FORMAT,
                    bufferSize
                )
                if (candidate.state == AudioRecord.STATE_INITIALIZED) {
                    candidate.startRecording()
                    audioRecord = candidate
                    Log.i(TAG, "AudioRecord initialized with source=$source, sessionId=${candidate.audioSessionId}")
                    return true
                }
                candidate.release()
            } catch (e: Exception) {
                Log.w(TAG, "AudioRecord init failed for source=$source: ${e.message}")
                try {
                    candidate?.release()
                } catch (_: Exception) {
                }
            }
        }
        return false
    }

    override fun read(buffer: ByteArray, offset: Int, size: Int): Int {
        return audioRecord?.read(buffer, offset, size) ?: AudioRecord.ERROR_INVALID_OPERATION
    }

    override fun stop() {
        try {
            audioRecord?.let { rec ->
                if (rec.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                    rec.stop()
                }
            }
        } catch (e: Exception) {
            Log.d(TAG, "AudioRecord stop error: ${e.message}")
        }
    }

    override fun release() {
        unregisterSilenceCallback()
        try {
            audioRecord?.release()
        } catch (e: Exception) {
            Log.d(TAG, "AudioRecord release error: ${e.message}")
        } finally {
            audioRecord = null
        }
    }

    override fun registerSilenceCallback(callback: (Boolean) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        val sessionId = audioSessionId
        if (sessionId == AudioManager.ERROR) return

        unregisterSilenceCallback()
        val cb = object : AudioManager.AudioRecordingCallback() {
            override fun onRecordingConfigChanged(configs: MutableList<AudioRecordingConfiguration>?) {
                val matched = configs?.firstOrNull { it.clientAudioSessionId == sessionId }
                if (matched != null) {
                    callback(matched.isClientSilenced)
                }
            }
        }
        recordingCallback = cb
        try {
            audioManager.registerAudioRecordingCallback(cb, Handler(Looper.getMainLooper()))
        } catch (e: Exception) {
            Log.w(TAG, "Failed to register AudioRecordingCallback: ${e.message}")
            recordingCallback = null
        }
    }

    override fun unregisterSilenceCallback() {
        val cb = recordingCallback ?: return
        recordingCallback = null
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            audioManager?.unregisterAudioRecordingCallback(cb)
        } catch (e: Exception) {
            Log.d(TAG, "Failed to unregister AudioRecordingCallback: ${e.message}")
        }
    }
}

/**
 * Single Microphone Capture Engine.
 * Exclusively owns a single PcmFrameSource (AudioRecord) at 16kHz 16-bit mono PCM,
 * stamps session/generation/sequence/timestamp metadata, and pushes frames non-blockingly
 * into AudioFanOutPipeline. Enforces a synchronous thread-join & AudioRecord.release() barrier on stop.
 */
class AudioCaptureEngine(
    private val frameSourceFactory: PcmFrameSourceFactory,
    private val clockMs: () -> Long = { System.currentTimeMillis() },
    private val logSink: AudioLogSink = AudioLogSink.NO_OP
) {
    companion object {
        private const val TAG = "AudioCaptureEngine"
        const val SAMPLE_RATE = 16000
        const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        // 150ms buffer at 16kHz 16-bit mono: 16000 * 2 bytes/sample * 0.150s = 4800 bytes
        const val CHUNK_SIZE_BYTES = 4800

        fun computeNormalizedRms(buffer: ByteArray, bytesRead: Int): Double {
            val samples = bytesRead / 2
            if (samples <= 0) return 0.0
            var sum = 0.0
            var i = 0
            while (i + 1 < bytesRead) {
                val sample = (buffer[i].toInt() and 0xFF) or (buffer[i + 1].toInt() shl 8)
                val shortVal = sample.toShort().toDouble()
                sum += shortVal * shortVal
                i += 2
            }
            val rms = sqrt(sum / samples)
            return (rms / 32767.0).coerceIn(0.0, 1.0)
        }
    }

    interface CaptureCallbacks {
        fun onFrameCaptured(frame: AudioFrame)
        fun onSoundLevel(level: Double)
        fun onClientSilencedChanged(silenced: Boolean)
        fun onCaptureError(message: String)
    }

    private var activeSource: PcmFrameSource? = null
    private var captureThread: Thread? = null
    private val capturing = AtomicBoolean(false)
    private val muted = AtomicBoolean(false)
    private val activeSessionId = AtomicLong(0)
    private val activeGenerationId = AtomicLong(0)
    private val sequenceCounter = AtomicLong(0)

    @Volatile
    private var activeCallbacks: CaptureCallbacks? = null

    fun isCapturing(): Boolean = capturing.get()
    fun isMuted(): Boolean = muted.get()

    fun updateGeneration(sessionId: Long, generationId: Long) {
        activeSessionId.set(sessionId)
        activeGenerationId.set(generationId)
    }

    fun setMuted(isMuted: Boolean) {
        muted.set(isMuted)
        if (isMuted) {
            activeCallbacks?.onSoundLevel(0.0)
        }
    }

    @Synchronized
    fun startCapture(
        sessionId: Long,
        generationId: Long,
        callbacks: CaptureCallbacks
    ): Boolean {
        activeSessionId.set(sessionId)
        activeGenerationId.set(generationId)
        activeCallbacks = callbacks

        if (capturing.get()) {
            logSink.log("I", TAG, "Capture already running; updated session=$sessionId gen=$generationId")
            return true
        }

        sequenceCounter.set(0)
        val source = frameSourceFactory.create(SAMPLE_RATE, CHUNK_SIZE_BYTES)
        if (source == null || !source.start()) {
            source?.release()
            val err = "AudioRecord failed to initialize"
            logSink.log("E", TAG, err)
            callbacks.onCaptureError(err)
            return false
        }

        activeSource = source
        source.registerSilenceCallback { silenced ->
            activeCallbacks?.onClientSilencedChanged(silenced)
        }

        capturing.set(true)
        captureThread = Thread({
            val buffer = ByteArray(CHUNK_SIZE_BYTES)
            logSink.log("I", TAG, "Capture loop started (16kHz 16-bit mono, chunk=${CHUNK_SIZE_BYTES}B)")

            while (capturing.get()) {
                val bytesRead = try {
                    source.read(buffer, 0, buffer.size)
                } catch (e: Exception) {
                    if (capturing.get()) {
                        logSink.log("W", TAG, "Source read exception: ${e.message}")
                    }
                    -1
                }

                if (!capturing.get()) break

                if (bytesRead > 0) {
                    if (muted.get()) {
                        activeCallbacks?.onSoundLevel(0.0)
                        continue
                    }

                    val chunkCopy = buffer.copyOf(bytesRead)
                    val rms = computeNormalizedRms(chunkCopy, bytesRead)
                    val seq = sequenceCounter.incrementAndGet()
                    val frame = AudioFrame(
                        sessionId = activeSessionId.get(),
                        generationId = activeGenerationId.get(),
                        sequence = seq,
                        timestampMs = clockMs(),
                        pcmBytes = chunkCopy,
                        rmsLevel = rms
                    )
                    activeCallbacks?.onSoundLevel(rms)
                    activeCallbacks?.onFrameCaptured(frame)
                } else if (bytesRead < 0) {
                    logSink.log("W", TAG, "PcmFrameSource read returned error=$bytesRead")
                    if (capturing.get()) {
                        activeCallbacks?.onCaptureError("audio_read_error_$bytesRead")
                    }
                    break
                }
            }
            logSink.log("I", TAG, "Capture loop finished")
        }, "EvaSingleAudioCaptureThread").apply {
            start()
        }

        return true
    }

    /**
     * Synchronous Mic-Release Barrier:
     * Stops the source first (unblocking AudioRecord.read), joins the capture thread,
     * and releases the underlying AudioRecord before returning.
     */
    @Synchronized
    fun stopCapture(joinTimeoutMs: Long = 1000L): Boolean {
        val wasCapturing = capturing.getAndSet(false)
        val source = activeSource
        activeSource = null
        activeCallbacks = null

        try {
            source?.stop()
        } catch (e: Exception) {
            logSink.log("W", TAG, "Error stopping PcmFrameSource: ${e.message}")
        }

        val thread = captureThread
        captureThread = null
        var joined = true
        if (thread != null) {
            thread.interrupt()
            if (Thread.currentThread() !== thread) {
                try {
                    thread.join(joinTimeoutMs)
                    if (thread.isAlive) joined = false
                } catch (_: InterruptedException) {
                    joined = false
                }
            }
        }

        try {
            source?.release()
        } catch (e: Exception) {
            logSink.log("W", TAG, "Error releasing PcmFrameSource: ${e.message}")
        }

        if (wasCapturing) {
            logSink.log("I", TAG, "Audio capture stopped & released (joined=$joined)")
        }
        return joined
    }
}
