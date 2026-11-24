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
import java.io.OutputStream

/**
 * SpeechRecognizer Pipe Manager.
 * Injects raw PCM audio into Android SpeechRecognizer via ParcelFileDescriptor virtual pipe
 * using RecognizerIntent.EXTRA_AUDIO_SOURCE (Android 13+ / API 33+).
 * Safely maintains SpeechRecognizer lifecycle across turns without destroying Binder IPC repeatedly.
 */
class SpeechRecognizerPipeManager(private val context: Context) {

    companion object {
        private const val TAG = "SpeechRecognizerPipe"
        const val EXTRA_AUDIO_SOURCE = "android.speech.extra.AUDIO_SOURCE"
        const val EXTRA_AUDIO_SOURCE_CHANNEL_COUNT = "android.speech.extra.AUDIO_SOURCE_CHANNEL_COUNT"
        const val EXTRA_AUDIO_SOURCE_ENCODING = "android.speech.extra.AUDIO_SOURCE_ENCODING"
        const val EXTRA_AUDIO_SOURCE_SAMPLING_RATE = "android.speech.extra.AUDIO_SOURCE_SAMPLING_RATE"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var speechRecognizer: SpeechRecognizer? = null
    private var pipe: Array<ParcelFileDescriptor>? = null
    private var pipeOutputStream: OutputStream? = null

    @Volatile
    private var isListening = false
    private var currentLocale: String = "id-ID"
    private var currentListener: SttEventListener? = null

    interface SttEventListener {
        fun onStatus(status: String)
        fun onPartial(text: String)
        fun onFinal(text: String)
        fun onSoundLevel(level: Double)
        fun onError(error: String)
    }

    fun isInjectionSupported(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                SpeechRecognizer.isRecognitionAvailable(context)
    }

    fun getPipeOutputStream(): OutputStream? = pipeOutputStream

    @Synchronized
    private fun closePipeDescriptors() {
        try {
            pipeOutputStream?.close()
        } catch (e: Exception) {
            Log.d(TAG, "Closing pipeOutputStream: ${e.message}")
        }
        pipeOutputStream = null

        try {
            pipe?.let { p ->
                p[0].close()
                p[1].close()
            }
        } catch (e: Exception) {
            Log.d(TAG, "Closing pipe descriptors: ${e.message}")
        }
        pipe = null
    }

    fun startListening(
        locale: String = "id-ID",
        listener: SttEventListener?
    ): Boolean {
        this.currentLocale = locale
        this.currentListener = listener
        this.isListening = true

        // 1. Close any existing pipe and create a fresh virtual pipe
        closePipeDescriptors()

        try {
            // pipe[0] = read end (passed to SpeechRecognizer)
            // pipe[1] = write end (written by AudioCaptureEngine PipeWriterThread)
            val pipeDescriptors = ParcelFileDescriptor.createPipe()
            pipe = pipeDescriptors
            pipeOutputStream = ParcelFileDescriptor.AutoCloseOutputStream(pipeDescriptors[1])

            mainHandler.post {
                try {
                    if (!isListening) return@post

                    // Reuse existing recognizer or create new if not present
                    var recognizer = speechRecognizer
                    if (recognizer == null) {
                        recognizer = SpeechRecognizer.createSpeechRecognizer(context)
                        speechRecognizer = recognizer
                    } else {
                        try {
                            recognizer.cancel()
                        } catch (e: Exception) {
                            Log.d(TAG, "SpeechRecognizer cancel before restart: ${e.message}")
                        }
                    }

                    recognizer.setRecognitionListener(object : RecognitionListener {
                        override fun onReadyForSpeech(params: Bundle?) {
                            Log.d(TAG, "SpeechRecognizer: onReadyForSpeech")
                            if (isListening) {
                                listener?.onStatus("listening")
                            }
                        }

                        override fun onBeginningOfSpeech() {
                            Log.d(TAG, "SpeechRecognizer: onBeginningOfSpeech")
                            if (isListening) {
                                listener?.onStatus("speaking")
                            }
                        }

                        override fun onRmsChanged(rmsdB: Float) {
                            if (isListening) {
                                val normalized = ((rmsdB + 2.0) / 12.0).coerceIn(0.0, 1.0)
                                listener?.onSoundLevel(normalized)
                            }
                        }

                        override fun onBufferReceived(buffer: ByteArray?) {}

                        override fun onEndOfSpeech() {
                            Log.d(TAG, "SpeechRecognizer: onEndOfSpeech")
                            if (isListening) {
                                listener?.onStatus("notListening")
                            }
                        }

                        override fun onError(error: Int) {
                            if (!isListening) {
                                Log.d(TAG, "SpeechRecognizer: onError ($error) ignored because session is already stopped.")
                                return
                            }

                            val errorName = when (error) {
                                SpeechRecognizer.ERROR_AUDIO -> "error_audio"
                                SpeechRecognizer.ERROR_CLIENT -> "error_client"
                                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "error_permission"
                                SpeechRecognizer.ERROR_NETWORK -> "error_network"
                                SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "error_network_timeout"
                                SpeechRecognizer.ERROR_NO_MATCH -> "error_no_match"
                                SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "error_busy"
                                SpeechRecognizer.ERROR_SERVER -> "error_server"
                                SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "error_speech_timeout"
                                11 -> "error_server_disconnected"
                                else -> "error_$error"
                            }
                            Log.w(TAG, "SpeechRecognizer: onError ($error -> $errorName)")

                            // If error 11 (server disconnected), cleanly recover instance with backoff
                            if (error == 11) {
                                Log.i(TAG, "SpeechRecognizer disconnected transiently (error 11). Scheduling reconnection...")
                                try {
                                    speechRecognizer?.setRecognitionListener(null)
                                    speechRecognizer?.destroy()
                                } catch (e: Exception) {
                                    Log.d(TAG, "Clean destroyed recognizer: ${e.message}")
                                }
                                speechRecognizer = null

                                if (isListening) {
                                    mainHandler.postDelayed({
                                        if (isListening) {
                                            Log.i(TAG, "Reconnecting SpeechRecognizer after error 11...")
                                            startListening(currentLocale, currentListener)
                                        }
                                    }, 300)
                                }
                                return
                            }

                            // If network error / timeout (error 1 or 2), schedule automatic reconnection
                            if (error == SpeechRecognizer.ERROR_NETWORK || error == SpeechRecognizer.ERROR_NETWORK_TIMEOUT) {
                                Log.w(TAG, "SpeechRecognizer network error ($error). Scheduling automatic retry...")
                                try {
                                    speechRecognizer?.cancel()
                                } catch (e: Exception) {
                                    Log.d(TAG, "Cancel recognizer on network error: ${e.message}")
                                }

                                if (isListening) {
                                    mainHandler.postDelayed({
                                        if (isListening) {
                                            Log.i(TAG, "Retrying SpeechRecognizer after network error...")
                                            startListening(currentLocale, currentListener)
                                        }
                                    }, 800)
                                }
                                return
                            }

                            // Speech timeout and no match are normal utterance silence pauses
                            if (error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT || error == SpeechRecognizer.ERROR_NO_MATCH) {
                                listener?.onStatus("notListening")
                                return
                            }

                            listener?.onError(errorName)
                        }

                        override fun onResults(results: Bundle?) {
                            if (!isListening) return
                            val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            val text = matches?.firstOrNull() ?: ""
                            Log.i(TAG, "SpeechRecognizer: onResults: '$text'")
                            listener?.onFinal(text)
                        }

                        override fun onPartialResults(partialResults: Bundle?) {
                            if (!isListening) return
                            val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            val text = matches?.firstOrNull() ?: ""
                            Log.d(TAG, "SpeechRecognizer: onPartialResults: '$text'")
                            listener?.onPartial(text)
                        }

                        override fun onEvent(eventType: Int, params: Bundle?) {}
                    })

                    val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                        putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            putExtra(EXTRA_AUDIO_SOURCE, pipeDescriptors[0])
                            putExtra(EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
                            putExtra(EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
                            putExtra(EXTRA_AUDIO_SOURCE_SAMPLING_RATE, 16000)
                        }
                    }

                    recognizer.startListening(intent)
                    Log.i(TAG, "SpeechRecognizer started with pipe injection (Locale: $locale)")
                } catch (e: Exception) {
                    Log.e(TAG, "Exception starting SpeechRecognizer: ${e.message}", e)
                    listener?.onError("exception: ${e.message}")
                }
            }
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Exception creating virtual pipe: ${e.message}", e)
            listener?.onError("pipe_creation_error: ${e.message}")
            return false
        }
    }

    fun stopListening() {
        isListening = false

        mainHandler.post {
            try {
                speechRecognizer?.cancel()
            } catch (e: Exception) {
                Log.d(TAG, "Error cancelling SpeechRecognizer: ${e.message}")
            }
        }

        closePipeDescriptors()
        Log.i(TAG, "SpeechRecognizerPipeManager stopped listening")
    }

    fun destroy() {
        isListening = false

        mainHandler.post {
            try {
                speechRecognizer?.setRecognitionListener(null)
                speechRecognizer?.cancel()
                speechRecognizer?.destroy()
                speechRecognizer = null
            } catch (e: Exception) {
                Log.w(TAG, "Error destroying SpeechRecognizer: ${e.message}")
            }
        }

        closePipeDescriptors()
        Log.i(TAG, "SpeechRecognizerPipeManager destroyed")
    }
}
