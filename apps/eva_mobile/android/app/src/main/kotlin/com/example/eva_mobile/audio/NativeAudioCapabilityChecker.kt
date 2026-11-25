package com.example.eva_mobile.audio

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionService
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * Probes Android speech recognition capabilities without hardcoded emulator restrictions.
 * On API 33+, executes SpeechRecognizer.checkRecognitionSupport with a bounded timeout
 * while degrading gracefully on ERROR_CANNOT_CHECK_SUPPORT.
 */
class NativeAudioCapabilityChecker(
    private val context: Context
) : CapabilityProvider {

    companion object {
        private const val TAG = "NativeCapabilityChecker"
        private const val CHECK_SUPPORT_TIMEOUT_MS = 1500L
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun checkCapability(locale: String): NativeCapabilityReport {
        val sdkInt = Build.VERSION.SDK_INT
        val isRecognitionAvailable = try {
            SpeechRecognizer.isRecognitionAvailable(context)
        } catch (e: Exception) {
            Log.w(TAG, "isRecognitionAvailable threw: ${e.message}")
            false
        }

        val isOnDeviceAvailable = if (sdkInt >= Build.VERSION_CODES.S) {
            try {
                SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
            } catch (e: Exception) {
                Log.w(TAG, "isOnDeviceRecognitionAvailable threw: ${e.message}")
                false
            }
        } else {
            false
        }

        val servicePackage = resolveRecognitionServicePackage()
        val supportsAudioSourceApi = sdkInt >= Build.VERSION_CODES.TIRAMISU

        var localeSupported: Boolean? = null
        var checkSupportStatus = "not_applicable_api_below_33"

        if (supportsAudioSourceApi && isRecognitionAvailable) {
            val probe = checkRecognitionSupportApi33(locale)
            localeSupported = probe.first
            checkSupportStatus = probe.second
        } else if (supportsAudioSourceApi && !isRecognitionAvailable) {
            checkSupportStatus = "recognition_unavailable"
        }

        val report = NativeCapabilityReport(
            sdkInt = sdkInt,
            isRecognitionAvailable = isRecognitionAvailable,
            isOnDeviceAvailable = isOnDeviceAvailable,
            recognitionServicePackage = servicePackage,
            supportsAudioSourceApi = supportsAudioSourceApi,
            localeSupported = localeSupported,
            segmentedSessionCandidate = supportsAudioSourceApi && isRecognitionAvailable,
            checkSupportStatus = checkSupportStatus
        )

        Log.i(
            TAG,
            "Capability report: sdk=$sdkInt, recAvail=$isRecognitionAvailable, " +
                "onDevice=$isOnDeviceAvailable, pkg=${servicePackage ?: "unknown"}, " +
                "supportStatus=$checkSupportStatus, localeSupported=$localeSupported"
        )
        return report
    }

    @Suppress("DEPRECATION")
    private fun resolveRecognitionServicePackage(): String? {
        return try {
            val intent = Intent(RecognitionService.SERVICE_INTERFACE)
            val services = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.packageManager.queryIntentServices(
                    intent,
                    PackageManager.ResolveInfoFlags.of(0)
                )
            } else {
                context.packageManager.queryIntentServices(intent, 0)
            }
            services.firstOrNull()?.serviceInfo?.packageName
        } catch (e: Exception) {
            Log.d(TAG, "Unable to query RecognitionService package: ${e.message}")
            null
        }
    }

    private fun checkRecognitionSupportApi33(locale: String): Pair<Boolean?, String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return Pair(null, "not_applicable_api_below_33")
        }

        // Avoid blocking the main looper if called synchronously on the UI thread.
        if (Looper.myLooper() == Looper.getMainLooper()) {
            return Pair(null, "deferred_runtime_probe_main_thread")
        }

        val latch = CountDownLatch(1)
        val resultRef = AtomicReference<Pair<Boolean?, String>>(Pair(null, "timeout"))
        val recognizerRef = AtomicReference<SpeechRecognizer?>(null)
        val callbackExecutor = Executors.newSingleThreadExecutor()

        try {
            mainHandler.post {
                try {
                    val recognizer = SpeechRecognizer.createSpeechRecognizer(context)
                    recognizerRef.set(recognizer)
                    val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                        putExtra(
                            RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                            RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                        )
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                        putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
                    }
                    recognizer.checkRecognitionSupport(
                        intent,
                        callbackExecutor,
                        object : RecognitionSupportCallback {
                            override fun onSupportResult(recognitionSupport: RecognitionSupport) {
                                val normalizedTarget = locale.lowercase().replace("_", "-")
                                val targetLangPrefix = normalizedTarget.substringBefore("-")
                                val allLanguages = (
                                    recognitionSupport.installedOnDeviceLanguages +
                                        recognitionSupport.supportedOnDeviceLanguages +
                                        recognitionSupport.onlineLanguages
                                    ).map { it.lowercase().replace("_", "-") }

                                val matched = allLanguages.any { lang ->
                                    lang == normalizedTarget || lang.substringBefore("-") == targetLangPrefix
                                }
                                val status = if (allLanguages.isEmpty()) {
                                    "supported_empty_list"
                                } else if (matched) {
                                    "supported"
                                } else {
                                    "locale_not_listed"
                                }
                                resultRef.set(Pair(if (allLanguages.isEmpty()) null else matched, status))
                                latch.countDown()
                            }

                            override fun onError(error: Int) {
                                val status = when (error) {
                                    SpeechRecognizer.ERROR_CANNOT_CHECK_SUPPORT -> "cannot_check_support"
                                    SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "language_not_supported"
                                    SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "language_unavailable"
                                    else -> "check_error_$error"
                                }
                                val supportedFlag = if (error == SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED) {
                                    false
                                } else {
                                    null
                                }
                                resultRef.set(Pair(supportedFlag, status))
                                latch.countDown()
                            }
                        }
                    )
                } catch (e: Exception) {
                    resultRef.set(Pair(null, "check_exception:${e.javaClass.simpleName}"))
                    latch.countDown()
                }
            }

            latch.await(CHECK_SUPPORT_TIMEOUT_MS, TimeUnit.MILLISECONDS)
        } finally {
            mainHandler.post {
                try {
                    recognizerRef.getAndSet(null)?.destroy()
                } catch (_: Exception) {
                }
            }
            callbackExecutor.shutdownNow()
        }

        return resultRef.get()
    }
}
