package com.example.eva_mobile.audio

import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.ByteArrayOutputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Android Instrumentation Tests executed on an Android Emulator or physical USB device via:
 *   cd apps/eva_mobile/android && ./gradlew connectedDebugAndroidTest
 */
@RunWith(AndroidJUnit4::class)
class NativeAudioInstrumentationTest {

    @Test
    fun parcelFileDescriptorPipe_transfersBitExactPcmAndClosesWithCleanEof() {
        val pipe = ParcelFileDescriptor.createPipe()
        val readStream = ParcelFileDescriptor.AutoCloseInputStream(pipe[0])
        val writeStream = ParcelFileDescriptor.AutoCloseOutputStream(pipe[1])

        val expected = ByteArray(AudioCaptureEngine.CHUNK_SIZE_BYTES * 5) { idx -> (idx % 251).toByte() }
        val actual = ByteArrayOutputStream()
        val readerDone = CountDownLatch(1)

        val readerThread = Thread {
            readStream.use { input ->
                val buf = ByteArray(1024)
                while (true) {
                    val read = input.read(buf)
                    if (read <= 0) break
                    actual.write(buf, 0, read)
                }
            }
            readerDone.countDown()
        }
        readerThread.start()

        writeStream.use { out ->
            out.write(expected)
            out.flush()
        }

        assertTrue("Pipe reader did not observe clean EOF", readerDone.await(3, TimeUnit.SECONDS))
        assertArrayEquals(expected, actual.toByteArray())
    }

    @Test
    fun capabilityChecker_queriesRecognitionServiceSafelyWithoutHardcodedEmulatorCrash() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val checker = NativeAudioCapabilityChecker(context)
        val report = checker.checkCapability("id-ID")

        assertEquals(Build.VERSION.SDK_INT, report.sdkInt)
        assertEquals(Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU, report.supportsAudioSourceApi)
        assertTrue(report.checkSupportStatus.isNotBlank())
    }
}
