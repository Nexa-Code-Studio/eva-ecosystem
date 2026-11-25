package com.example.eva_mobile.audio

import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import com.example.eva_mobile.BuildConfig
import java.io.OutputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong

/**
 * Android SpeechRecognizer virtual pipe manager (API 33+ EXTRA_AUDIO_SOURCE).
 * - Enforces monotonic generation guards across all Binder callbacks.
 * - Supports both segmented session (onSegmentResults/onEndOfSegmentedSession) and standard onResults.
 * - Notifies coordinator synchronously whenever a new ParcelFileDescriptor pipe is created.
 * - Never logs raw user transcripts in production builds.
 */
class SpeechRecognizerPipeManager(
    private val context: Context
) : SttPipeEngine {

    companion object {
        private const val TAG = "SpeechRecognizerPipe"
        const val EXTRA_AUDIO_SOURCE = "android.speech.extra.AUDIO_SOURCE"
        const val EXTRA_AUDIO_SOURCE_CHANNEL_COUNT = "android.speech.extra.AUDIO_SOURCE_CHANNEL_COUNT"
        const val EXTRA_AUDIO_SOURCE_ENCODING = "android.speech.extra.AUDIO_SOURCE_ENCODING"
        const val EXTRA_AUDIO_SOURCE_SAMPLING_RATE = "android.speech.extra.AUDIO_SOURCE_SAMPLING_RATE"
        const val EXTRA_SEGMENTED_SESSION = "android.speech.extra.SEGMENTED_SESSION"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val activeGenerationId = AtomicLong(0)

    private var speechRecognizer: SpeechRecognizer? = null
    private var readDescriptor: ParcelFileDescriptor? = null
    private var writeStream: OutputStream? = null

    @Synchronized
    private fun closeDescriptorsLocked() {
        try {
            writeStream?.close()
        } catch (_: Exception) {
        }
        writeStream = null

        try {
            readDescriptor?.close()
        } catch (_: Exception) {
        }
        readDescriptor = null
    }

    @Synchronized
    override fun closeWriteEnd(generationId: Long) {
        if (generationId != activeGenerationId.get()) return
        try {
            writeStream?.close()
        } catch (_: Exception) {
        }
        writeStream = null
    }

    override fun startSession(
        generationId: Long,
        locale: String,
        useSegmentedSession: Boolean,
        listener: SttPipeListener
    ): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return false
        }

        activeGenerationId.set(generationId)

        val pipeDescriptors: Array<ParcelFileDescriptor>
        val newWriteStream: OutputStream
        synchronized(this) {
            closeDescriptorsLocked()
            try {
                // pipe[0] = read end passed to SpeechRecognizer via EXTRA_AUDIO_SOURCE
                // pipe[1] = write end owned by AudioFanOutPipeline SttPipeWriterWorker
                pipeDescriptors = ParcelFileDescriptor.createPipe()
                readDescriptor = pipeDescriptors[0]
                newWriteStream = ParcelFileDescriptor.AutoCloseOutputStream(pipeDescriptors[1])
                writeStream = newWriteStream
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create virtual audio pipe (gen=$generationId): ${e.message}")
                return false
            }
        }

        // Synchronously hand off the write stream so AudioFanOutPipeline attaches immediately
        listener.onPipeCreated(generationId, newWriteStream)

        val launchBlock = Runnable {
            if (activeGenerationId.get() != generationId) return@Runnable
            try {
                var recognizer = speechRecognizer
                if (recognizer == null) {
                    recognizer = SpeechRecognizer.createSpeechRecognizer(context)
                    speechRecognizer = recognizer
                } else {
                    try {
                        recognizer.cancel()
                    } catch (e: Exception) {
                        Log.d(TAG, "Recognizer cancel prior to startListening: ${e.message}")
                    }
                }

                recognizer.setRecognitionListener(createGenerationGuardedListener(generationId, listener))

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(
                        RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                        RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                    )
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                    putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
                    putExtra(EXTRA_AUDIO_SOURCE, pipeDescriptors[0])
                    putExtra(EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
                    putExtra(EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
                    putExtra(EXTRA_AUDIO_SOURCE_SAMPLING_RATE, AudioCaptureEngine.SAMPLE_RATE)
                    if (useSegmentedSession) {
                        putExtra(EXTRA_SEGMENTED_SESSION, EXTRA_AUDIO_SOURCE)
                    }
                }

                recognizer.startListening(intent)
                Log.i(
                    TAG,
                    "SpeechRecognizer started (gen=$generationId, locale=$locale, segmented=$useSegmentedSession)"
                )
            } catch (e: Exception) {
                Log.e(TAG, "Exception starting SpeechRecognizer (gen=$generationId): ${e.message}")
                if (activeGenerationId.get() == generationId) {
                    listener.onError(generationId, SpeechRecognizer.ERROR_CLIENT, "error_client")
                }
            }
        }

        if (Looper.myLooper() == Looper.getMainLooper()) {
            launchBlock.run()
        } else {
            mainHandler.post(launchBlock)
        }
        return true
    }

    private fun createGenerationGuardedListener(
        generationId: Long,
        listener: SttPipeListener
    ): RecognitionListener {
        return object : RecognitionListener {
            private fun isCurrent(): Boolean = activeGenerationId.get() == generationId

            override fun onReadyForSpeech(params: Bundle?) {
                if (!isCurrent()) return
                Log.d(TAG, "onReadyForSpeech (gen=$generationId)")
                listener.onReadyForSpeech(generationId)
                listener.onStatus(generationId, "listening")
            }

            override fun onBeginningOfSpeech() {
                if (!isCurrent()) return
                listener.onStatus(generationId, "speaking")
            }

            override fun onRmsChanged(rmsdB: Float) {
                if (!isCurrent()) return
                val normalized = ((rmsdB + 2.0) / 12.0).coerceIn(0.0, 1.0)
                listener.onSoundLevel(generationId, normalized)
            }

            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {
                if (!isCurrent()) return
                listener.onStatus(generationId, "notListening")
            }

            override fun onError(error: Int) {
                if (!isCurrent()) return
                val errorName = mapErrorName(error)
                Log.w(TAG, "onError (gen=$generationId, code=$error, name=$errorName)")
                if (error == 11) {
                    // ERROR_SERVER_DISCONNECTED: reset broken binder instance cleanly
                    try {
                        speechRecognizer?.setRecognitionListener(null)
                        speechRecognizer?.destroy()
                    } catch (_: Exception) {
                    }
                    speechRecognizer = null
                }
                listener.onError(generationId, error, errorName)
            }

            override fun onResults(results: Bundle?) {
                if (!isCurrent()) return
                val text = extractTopTranscript(results)
                if (BuildConfig.DEBUG) {
                    Log.d(TAG, "onResults (gen=$generationId, len=${text.length})")
                }
                if (text.isNotEmpty()) {
                    listener.onFinal(generationId, text, isSegment = false)
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                if (!isCurrent()) return
                val text = extractTopTranscript(partialResults)
                if (BuildConfig.DEBUG) {
                    Log.d(TAG, "onPartialResults (gen=$generationId, len=${text.length})")
                }
                if (text.isNotEmpty()) {
                    listener.onPartial(generationId, text)
                }
            }

            override fun onSegmentResults(segmentResults: Bundle) {
                if (!isCurrent()) return
                val text = extractTopTranscript(segmentResults)
                if (BuildConfig.DEBUG) {
                    Log.d(TAG, "onSegmentResults (gen=$generationId, len=${text.length})")
                }
                if (text.isNotEmpty()) {
                    listener.onFinal(generationId, text, isSegment = true)
                }
            }

            override fun onEndOfSegmentedSession() {
                if (!isCurrent()) return
                Log.d(TAG, "onEndOfSegmentedSession (gen=$generationId)")
                listener.onEndOfSegmentedSession(generationId)
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        }
    }

    private fun extractTopTranscript(bundle: Bundle?): String {
        val matches = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        return matches?.firstOrNull()?.trim() ?: ""
    }

    private fun mapErrorName(error: Int): String = when (error) {
        SpeechRecognizer.ERROR_AUDIO -> "error_audio"
        SpeechRecognizer.ERROR_CLIENT -> "error_client"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "error_permission"
        SpeechRecognizer.ERROR_NETWORK -> "error_network"
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "error_network_timeout"
        SpeechRecognizer.ERROR_NO_MATCH -> "error_no_match"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "error_busy"
        SpeechRecognizer.ERROR_SERVER -> "error_server"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "error_speech_timeout"
        10 -> "error_too_many_requests"
        11 -> "error_server_disconnected"
        12 -> "error_language_not_supported"
        13 -> "error_language_unavailable"
        14 -> "error_cannot_check_support"
        else -> "error_$error"
    }

    override fun stopAndWait(timeoutMs: Long, destroyRecognizer: Boolean): Boolean {
        // Invalidate all in-flight callbacks immediately
        activeGenerationId.incrementAndGet()

        synchronized(this) {
            closeDescriptorsLocked()
        }

        val stopAction = Runnable {
            try {
                speechRecognizer?.setRecognitionListener(null)
                speechRecognizer?.cancel()
                if (destroyRecognizer) {
                    speechRecognizer?.destroy()
                    speechRecognizer = null
                }
            } catch (e: Exception) {
                Log.d(TAG, "Error stopping SpeechRecognizer: ${e.message}")
            }
        }

        if (Looper.myLooper() == Looper.getMainLooper()) {
            stopAction.run()
            return true
        }

        val latch = CountDownLatch(1)
        val posted = mainHandler.post {
            try {
                stopAction.run()
            } finally {
                latch.countDown()
            }
        }
        if (!posted) return false
        return try {
            latch.await(timeoutMs, TimeUnit.MILLISECONDS)
        } catch (_: InterruptedException) {
            false
        }
    }

    override fun destroy() {
        stopAndWait(timeoutMs = 1000L, destroyRecognizer = true)
    }
}
