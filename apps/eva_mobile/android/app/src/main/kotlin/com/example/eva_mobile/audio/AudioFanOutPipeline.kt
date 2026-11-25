package com.example.eva_mobile.audio

import java.io.OutputStream
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

/**
 * Pure-Kotlin asynchronous fan-out pipeline with two independent bounded queues:
 *  - Consumer A (STT virtual pipe): dedicated writer thread + drop-oldest backpressure.
 *  - Consumer B (Emotion2Vec stream): dedicated egress thread + drop-oldest backpressure + full error isolation.
 *
 * Neither consumer can ever block the single AudioRecord capture loop or crash the other consumer.
 */
class AudioFanOutPipeline(
    private val sttQueueCapacity: Int = DEFAULT_QUEUE_CAPACITY,
    private val emotionQueueCapacity: Int = DEFAULT_QUEUE_CAPACITY,
    private val emotionConsumer: (AudioFrame) -> Unit,
    private val onPipeWriteError: (generationId: Long, message: String) -> Unit = { _, _ -> },
    private val logSink: AudioLogSink = AudioLogSink.NO_OP
) {
    companion object {
        private const val TAG = "AudioFanOutPipeline"
        const val DEFAULT_QUEUE_CAPACITY = 20 // 20 * 150ms = 3.0s bounded buffer (~96KB)
        private const val POLL_TIMEOUT_MS = 100L
    }

    private data class ActivePipe(
        val generationId: Long,
        val outputStream: OutputStream,
        val errorReported: AtomicBoolean = AtomicBoolean(false)
    )

    private val sttPipeQueue = ArrayBlockingQueue<AudioFrame>(sttQueueCapacity)
    private val emotionEgressQueue = ArrayBlockingQueue<AudioFrame>(emotionQueueCapacity)

    private val activePipeRef = AtomicReference<ActivePipe?>(null)
    private val running = AtomicBoolean(false)

    private var sttWriterThread: Thread? = null
    private var emotionEgressThread: Thread? = null

    private val capturedFramesCount = AtomicLong(0)
    private val sttQueuedFramesCount = AtomicLong(0)
    private val sttWrittenFramesCount = AtomicLong(0)
    private val sttBytesWrittenCount = AtomicLong(0)
    private val sttDroppedFramesCount = AtomicLong(0)
    private val emotionQueuedFramesCount = AtomicLong(0)
    private val emotionDeliveredFramesCount = AtomicLong(0)
    private val emotionDroppedFramesCount = AtomicLong(0)
    private val emotionConsumerErrorsCount = AtomicLong(0)

    val capturedFrames: Long get() = capturedFramesCount.get()
    val sttQueuedFrames: Long get() = sttQueuedFramesCount.get()
    val sttWrittenFrames: Long get() = sttWrittenFramesCount.get()
    val sttBytesWritten: Long get() = sttBytesWrittenCount.get()
    val sttDroppedFrames: Long get() = sttDroppedFramesCount.get()
    val emotionQueuedFrames: Long get() = emotionQueuedFramesCount.get()
    val emotionDeliveredFrames: Long get() = emotionDeliveredFramesCount.get()
    val emotionDroppedFrames: Long get() = emotionDroppedFramesCount.get()
    val emotionConsumerErrors: Long get() = emotionConsumerErrorsCount.get()

    val sttQueueSize: Int get() = sttPipeQueue.size
    val emotionQueueSize: Int get() = emotionEgressQueue.size
    val isRunning: Boolean get() = running.get()

    @Synchronized
    fun start() {
        if (running.getAndSet(true)) {
            return
        }

        sttWriterThread = Thread({
            logSink.log("I", TAG, "SttPipeWriterWorker started")
            while (running.get()) {
                try {
                    val frame = sttPipeQueue.poll(POLL_TIMEOUT_MS, TimeUnit.MILLISECONDS) ?: continue
                    val pipe = activePipeRef.get() ?: continue
                    if (frame.generationId != pipe.generationId) {
                        continue
                    }
                    try {
                        pipe.outputStream.write(frame.pcmBytes)
                        pipe.outputStream.flush()
                        sttWrittenFramesCount.incrementAndGet()
                        sttBytesWrittenCount.addAndGet(frame.pcmBytes.size.toLong())
                    } catch (e: Exception) {
                        // Drain stale STT frames only; never touch emotion queue
                        sttPipeQueue.clear()
                        if (pipe.errorReported.compareAndSet(false, true)) {
                            logSink.log("W", TAG, "STT pipe write error (gen=${pipe.generationId}): ${e.message}")
                            try {
                                pipe.outputStream.close()
                            } catch (_: Exception) {
                            }
                            activePipeRef.compareAndSet(pipe, null)
                            try {
                                onPipeWriteError(pipe.generationId, e.message ?: "pipe_write_error")
                            } catch (cbErr: Exception) {
                                logSink.log("W", TAG, "Pipe error callback threw: ${cbErr.message}")
                            }
                        }
                    }
                } catch (_: InterruptedException) {
                    if (!running.get()) break
                }
            }
            logSink.log("I", TAG, "SttPipeWriterWorker finished")
        }, "EvaSttPipeWriterWorker").apply {
            isDaemon = true
            start()
        }

        emotionEgressThread = Thread({
            logSink.log("I", TAG, "EmotionEgressWorker started")
            while (running.get()) {
                try {
                    val frame = emotionEgressQueue.poll(POLL_TIMEOUT_MS, TimeUnit.MILLISECONDS) ?: continue
                    try {
                        emotionConsumer(frame)
                        emotionDeliveredFramesCount.incrementAndGet()
                    } catch (e: Exception) {
                        emotionConsumerErrorsCount.incrementAndGet()
                        logSink.log("W", TAG, "Emotion egress consumer isolated error: ${e.message}")
                    }
                } catch (_: InterruptedException) {
                    if (!running.get()) break
                }
            }
            logSink.log("I", TAG, "EmotionEgressWorker finished")
        }, "EvaEmotionEgressWorker").apply {
            isDaemon = true
            start()
        }
    }

    /**
     * Atomically swaps the STT virtual pipe output stream when a turn starts or reconnects,
     * keeping the Emotion2Vec queue and worker completely uninterrupted.
     */
    @Synchronized
    fun attachPipe(generationId: Long, outputStream: OutputStream?) {
        val nextPipe = outputStream?.let { ActivePipe(generationId, it) }
        val previous = activePipeRef.getAndSet(nextPipe)
        sttPipeQueue.clear()
        if (previous != null && previous.outputStream !== outputStream) {
            try {
                previous.outputStream.close()
            } catch (_: Exception) {
            }
        }
        logSink.log("I", TAG, "Attached STT pipe (gen=$generationId, hasStream=${outputStream != null})")
    }

    @Synchronized
    fun detachPipe(generationId: Long? = null) {
        val current = activePipeRef.get() ?: return
        if (generationId != null && current.generationId != generationId) {
            return
        }
        if (activePipeRef.compareAndSet(current, null)) {
            sttPipeQueue.clear()
            try {
                current.outputStream.close()
            } catch (_: Exception) {
            }
        }
    }

    /**
     * Non-blocking fan-out from the single AudioRecord capture loop.
     */
    fun publishFrame(frame: AudioFrame) {
        if (!running.get()) return
        capturedFramesCount.incrementAndGet()

        // Consumer B: Emotion2Vec bounded queue (always fed regardless of STT pipe state)
        offerDropOldest(emotionEgressQueue, frame, emotionDroppedFramesCount)
        emotionQueuedFramesCount.incrementAndGet()

        // Consumer A: STT virtual pipe bounded queue (only if a matching pipe is attached)
        val pipe = activePipeRef.get()
        if (pipe != null && pipe.generationId == frame.generationId) {
            offerDropOldest(sttPipeQueue, frame, sttDroppedFramesCount)
            sttQueuedFramesCount.incrementAndGet()
        }
    }

    private fun offerDropOldest(
        queue: ArrayBlockingQueue<AudioFrame>,
        frame: AudioFrame,
        dropCounter: AtomicLong
    ) {
        while (!queue.offer(frame)) {
            if (queue.poll() != null) {
                dropCounter.incrementAndGet()
            }
        }
    }

    fun resetMetrics() {
        capturedFramesCount.set(0)
        sttQueuedFramesCount.set(0)
        sttWrittenFramesCount.set(0)
        sttBytesWrittenCount.set(0)
        sttDroppedFramesCount.set(0)
        emotionQueuedFramesCount.set(0)
        emotionDeliveredFramesCount.set(0)
        emotionDroppedFramesCount.set(0)
        emotionConsumerErrorsCount.set(0)
    }

    @Synchronized
    fun stopAndJoin(timeoutMs: Long = 1000L): Boolean {
        val wasRunning = running.getAndSet(false)
        detachPipe()

        val sttThread = sttWriterThread
        val emoThread = emotionEgressThread
        sttWriterThread = null
        emotionEgressThread = null

        sttThread?.interrupt()
        emoThread?.interrupt()

        var allJoined = true
        if (sttThread != null) {
            try {
                sttThread.join(timeoutMs)
                if (sttThread.isAlive) allJoined = false
            } catch (_: InterruptedException) {
                allJoined = false
            }
        }
        if (emoThread != null) {
            try {
                emoThread.join(timeoutMs)
                if (emoThread.isAlive) allJoined = false
            } catch (_: InterruptedException) {
                allJoined = false
            }
        }

        sttPipeQueue.clear()
        emotionEgressQueue.clear()

        if (wasRunning) {
            logSink.log("I", TAG, "Fan-out pipeline stopped (allJoined=$allJoined)")
        }
        return allJoined
    }
}
