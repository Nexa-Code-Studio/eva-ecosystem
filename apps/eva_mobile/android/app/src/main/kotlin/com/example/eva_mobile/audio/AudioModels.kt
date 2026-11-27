package com.example.eva_mobile.audio

import java.io.OutputStream

enum class PipelineState {
    IDLE,
    PROBING,
    NATIVE_HYBRID_STARTING,
    NATIVE_HYBRID_ACTIVE,
    MUTED,
    RECONNECTING_STT_PIPE,
    RELEASING_FOR_FALLBACK,
    NATIVE_HYBRID_FAILED,
    STOPPING,
    DISPOSED
}

data class AudioFrame(
    val sessionId: Long,
    val generationId: Long,
    val sequence: Long,
    val timestampMs: Long,
    val pcmBytes: ByteArray,
    val rmsLevel: Double
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is AudioFrame) return false
        return sessionId == other.sessionId &&
            generationId == other.generationId &&
            sequence == other.sequence &&
            timestampMs == other.timestampMs &&
            pcmBytes.contentEquals(other.pcmBytes) &&
            rmsLevel == other.rmsLevel
    }

    override fun hashCode(): Int {
        var result = sessionId.hashCode()
        result = 31 * result + generationId.hashCode()
        result = 31 * result + sequence.hashCode()
        result = 31 * result + timestampMs.hashCode()
        result = 31 * result + pcmBytes.contentHashCode()
        result = 31 * result + rmsLevel.hashCode()
        return result
    }
}

data class PipelineMetrics(
    val state: String,
    val sessionId: Long,
    val generationId: Long,
    val capturedFrames: Long,
    val sttQueuedFrames: Long,
    val sttWrittenFrames: Long,
    val sttBytesWritten: Long,
    val sttDroppedFrames: Long,
    val emotionQueuedFrames: Long,
    val emotionDeliveredFrames: Long,
    val emotionDroppedFrames: Long,
    val emotionConsumerErrors: Long,
    val pipeReconnectCount: Int,
    val isClientSilenced: Boolean,
    val isMuted: Boolean,
    val runtimeValidated: Boolean,
    val lastFailureReason: String?
) {
    fun toMap(): Map<String, Any> {
        val map = mutableMapOf<String, Any>(
            "state" to state,
            "sessionId" to sessionId,
            "generationId" to generationId,
            "capturedFrames" to capturedFrames,
            "sttQueuedFrames" to sttQueuedFrames,
            "sttWrittenFrames" to sttWrittenFrames,
            "sttBytesWritten" to sttBytesWritten,
            "sttDroppedFrames" to sttDroppedFrames,
            "emotionQueuedFrames" to emotionQueuedFrames,
            "emotionDeliveredFrames" to emotionDeliveredFrames,
            "emotionDroppedFrames" to emotionDroppedFrames,
            "emotionConsumerErrors" to emotionConsumerErrors,
            "pipeReconnectCount" to pipeReconnectCount,
            "isClientSilenced" to isClientSilenced,
            "isMuted" to isMuted,
            "runtimeValidated" to runtimeValidated
        )
        if (lastFailureReason != null) {
            map["lastFailureReason"] = lastFailureReason
        }
        return map
    }
}

data class NativeCapabilityReport(
    val sdkInt: Int,
    val isRecognitionAvailable: Boolean,
    val isOnDeviceAvailable: Boolean,
    val recognitionServicePackage: String?,
    val supportsAudioSourceApi: Boolean,
    val localeSupported: Boolean?,
    val segmentedSessionCandidate: Boolean,
    val checkSupportStatus: String
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "supported" to (supportsAudioSourceApi && isRecognitionAvailable),
        "sdkInt" to sdkInt,
        "isRecognitionAvailable" to isRecognitionAvailable,
        "isOnDeviceAvailable" to isOnDeviceAvailable,
        "recognitionServicePackage" to recognitionServicePackage,
        "supportsAudioSourceApi" to supportsAudioSourceApi,
        "localeSupported" to localeSupported,
        "segmentedSessionCandidate" to segmentedSessionCandidate,
        "checkSupportStatus" to checkSupportStatus
    )
}

fun interface AudioLogSink {
    fun log(level: String, tag: String, message: String)

    companion object {
        val NO_OP = AudioLogSink { _, _, _ -> }
    }
}

interface PcmFrameSource {
    val audioSessionId: Int
    fun start(): Boolean
    fun read(buffer: ByteArray, offset: Int, size: Int): Int
    fun stop()
    fun release()
    fun registerSilenceCallback(callback: (Boolean) -> Unit) {}
    fun unregisterSilenceCallback() {}
}

fun interface PcmFrameSourceFactory {
    fun create(sampleRate: Int, chunkSizeBytes: Int): PcmFrameSource?
}

interface SttPipeListener {
    fun onPipeCreated(generationId: Long, writeStream: OutputStream)
    fun onReadyForSpeech(generationId: Long)
    fun onStatus(generationId: Long, status: String)
    fun onPartial(generationId: Long, text: String)
    fun onFinal(generationId: Long, text: String, isSegment: Boolean)
    fun onSoundLevel(generationId: Long, level: Double)
    fun onError(generationId: Long, errorCode: Int, errorName: String)
    fun onEndOfSegmentedSession(generationId: Long)
}

interface SttPipeEngine {
    fun startSession(
        generationId: Long,
        locale: String,
        useSegmentedSession: Boolean,
        listener: SttPipeListener
    ): Boolean

    fun stopAndWait(timeoutMs: Long = 1000L, destroyRecognizer: Boolean = false): Boolean
    fun closeWriteEnd(generationId: Long)
    fun destroy()
}

fun interface CapabilityProvider {
    fun checkCapability(locale: String): NativeCapabilityReport
}
