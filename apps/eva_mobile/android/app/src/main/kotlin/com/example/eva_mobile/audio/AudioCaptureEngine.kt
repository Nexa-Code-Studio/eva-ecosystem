package com.example.eva_mobile.audio

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import java.io.OutputStream
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Single Audio Capture Engine.
 * Responsible for exclusively opening the hardware microphone at 16kHz 16-bit Mono PCM
 * and fanning out audio chunks to both the virtual SpeechRecognizer pipe and Flutter EventChannel.
 * Uses a non-blocking queue for the pipe to guarantee the mic recording thread NEVER blocks.
 */
class AudioCaptureEngine {

    companion object {
        private const val TAG = "AudioCaptureEngine"
        const val SAMPLE_RATE = 16000
        const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        // 150ms buffer at 16kHz 16-bit mono: 16000 * 2 bytes/sample * 0.150s = 4800 bytes
        const val CHUNK_SIZE_BYTES = 4800
        private const val PIPE_QUEUE_CAPACITY = 20
    }

    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null
    private var pipeWriterThread: Thread? = null
    private val isCapturing = AtomicBoolean(false)
    private val pipeQueue = LinkedBlockingQueue<ByteArray>(PIPE_QUEUE_CAPACITY)

    @Volatile
    private var activePipeOutputStream: OutputStream? = null

    @Volatile
    private var activeListener: AudioCaptureListener? = null

    interface AudioCaptureListener {
        fun onAudioChunk(bytes: ByteArray)
        fun onSoundLevel(level: Double)
        fun onError(message: String)
    }

    @Synchronized
    fun updatePipeOutputStream(newPipe: OutputStream?) {
        val oldPipe = activePipeOutputStream
        pipeQueue.clear()
        activePipeOutputStream = newPipe
        try {
            oldPipe?.close()
        } catch (e: Exception) {
            Log.d(TAG, "Closing previous pipe stream: ${e.message}")
        }
        Log.i(TAG, "Updated pipe output stream in AudioCaptureEngine (hasNewPipe=${newPipe != null})")
    }

    @SuppressLint("MissingPermission")
    fun startCapture(
        pipeOutputStream: OutputStream?,
        listener: AudioCaptureListener?
    ): Boolean {
        this.activeListener = listener
        updatePipeOutputStream(pipeOutputStream)

        if (isCapturing.get()) {
            Log.i(TAG, "Audio capture is already running; pipe stream refreshed.")
            return true
        }

        val minBufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        if (minBufferSize == AudioRecord.ERROR || minBufferSize == AudioRecord.ERROR_BAD_VALUE) {
            listener?.onError("Invalid AudioRecord parameters: minBufferSize error")
            return false
        }

        val bufferSize = Math.max(minBufferSize * 2, CHUNK_SIZE_BYTES * 2)

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
                val err = "AudioRecord failed to initialize (state != STATE_INITIALIZED)"
                Log.e(TAG, err)
                listener?.onError(err)
                return false
            }

            audioRecord = record
            record.startRecording()
            isCapturing.set(true)

            // Start dedicated non-blocking PipeWriterThread
            pipeWriterThread = Thread({
                Log.i(TAG, "Virtual pipe writer thread started")
                while (isCapturing.get()) {
                    try {
                        val chunk = pipeQueue.poll(200, TimeUnit.MILLISECONDS) ?: continue
                        val pipe = activePipeOutputStream ?: continue
                        try {
                            pipe.write(chunk)
                            pipe.flush()
                        } catch (e: Exception) {
                            Log.d(TAG, "Pipe write exception (${e.message}); draining pipe queue.")
                            pipeQueue.clear()
                        }
                    } catch (ie: InterruptedException) {
                        break
                    }
                }
                Log.i(TAG, "Virtual pipe writer thread finished")
            }, "SingleAudioPipeWriterThread").apply {
                isDaemon = true
                start()
            }

            // Main Audio Capture Loop: Reads MIC, feeds Flutter WebSocket and Sound Level
            captureThread = Thread({
                val buffer = ByteArray(CHUNK_SIZE_BYTES)
                Log.i(TAG, "🎙️ Audio capture thread started (16kHz 16-bit mono)")

                while (isCapturing.get()) {
                    val bytesRead = record.read(buffer, 0, buffer.size)

                    if (bytesRead > 0 && isCapturing.get()) {
                        val chunkCopy = buffer.copyOf(bytesRead)

                        // 1. Calculate sound level RMS (0.0 to 1.0)
                        var sum = 0.0
                        val samples = bytesRead / 2
                        for (i in 0 until bytesRead step 2) {
                            val sample = (buffer[i].toInt() and 0xFF) or (buffer[i + 1].toInt() shl 8)
                            val shortVal = sample.toShort()
                            sum += shortVal * shortVal
                        }
                        val rms = if (samples > 0) Math.sqrt(sum / samples) else 0.0
                        val normalizedLevel = (rms / 32767.0).coerceIn(0.0, 1.0)
                        activeListener?.onSoundLevel(normalizedLevel)

                        // 2. Feed Flutter WebSocket stream listener (NEVER BLOCKED)
                        activeListener?.onAudioChunk(chunkCopy)

                        // 3. Offer to virtual pipe queue for SpeechRecognizer (non-blocking)
                        if (activePipeOutputStream != null) {
                            while (!pipeQueue.offer(chunkCopy)) {
                                pipeQueue.poll() // Drop oldest chunk if reader is lagging
                            }
                        }
                    } else if (bytesRead < 0) {
                        Log.w(TAG, "AudioRecord.read() returned error code: $bytesRead")
                    }
                }

                // Cleanup pipe stream on thread termination
                updatePipeOutputStream(null)
                Log.i(TAG, "🎙️ Audio capture thread finished")
            }, "SingleAudioCaptureThread")

            captureThread?.start()
            return true
        } catch (e: Exception) {
            val err = "Exception initializing audio capture: ${e.message}"
            Log.e(TAG, err, e)
            listener?.onError(err)
            stopCapture()
            return false
        }
    }

    fun stopCapture() {
        if (!isCapturing.getAndSet(false)) {
            return
        }

        updatePipeOutputStream(null)
        activeListener = null

        try {
            pipeWriterThread?.interrupt()
            pipeWriterThread = null
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping pipe writer thread: ${e.message}")
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

    fun isCapturing(): Boolean = isCapturing.get()
}
