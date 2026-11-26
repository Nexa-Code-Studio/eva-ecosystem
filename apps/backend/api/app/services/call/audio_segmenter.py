"""Sample-count-based continuous 3-second PCM16 audio segmenter for voice calls.

Canonical audio format:
- Sample rate: 16,000 Hz
- Channels: 1 (mono)
- Encoding: signed 16-bit PCM little-endian (2 bytes/sample)
- 1 nominal 3-second segment = 48,000 samples = 96,000 bytes
"""

from __future__ import annotations

import logging
import math
import sys
import time
import uuid
from array import array
from dataclasses import dataclass

logger = logging.getLogger(__name__)

CANONICAL_SAMPLE_RATE = 16000
CANONICAL_CHANNELS = 1
CANONICAL_SAMPLE_WIDTH_BYTES = 2
CANONICAL_BYTES_PER_SECOND = CANONICAL_SAMPLE_RATE * CANONICAL_CHANNELS * CANONICAL_SAMPLE_WIDTH_BYTES  # 32,000
CANONICAL_BYTES_PER_MS = CANONICAL_BYTES_PER_SECOND // 1000  # 32 bytes/ms
DEFAULT_SUBFRAME_MS = 20
DEFAULT_SUBFRAME_BYTES = DEFAULT_SUBFRAME_MS * CANONICAL_BYTES_PER_MS  # 640 bytes


@dataclass(frozen=True)
class AudioSegment:
    """Immutable 3-second (or tail) PCM16 segment ready for isolated emotion inference."""

    segment_id: str
    session_id: str
    generation_token: str
    capture_epoch: int
    user_turn_id: int
    sequence: int
    pcm_bytes: bytes
    sample_rate: int
    channels: int
    sample_width_bytes: int
    start_offset_ms: int
    end_offset_ms: int
    duration_ms: int
    valid_speech_ms: int
    rms_level: float
    is_tail: bool
    created_monotonic_ms: int


@dataclass(frozen=True)
class SegmentExclusionEvent:
    """Operational telemetry event for audio excluded or dropped prior to inference."""

    reason: str  # excluded_silence | excluded_too_short | dropped_frame_too_large | dropped_buffer_overflow
    duration_ms: int
    byte_count: int
    capture_epoch: int
    user_turn_id: int


def analyze_pcm16_speech_activity(
    pcm_bytes: bytes,
    rms_threshold: float = 0.008,
    subframe_bytes: int = DEFAULT_SUBFRAME_BYTES,
) -> tuple[int, float]:
    """Estimate active speech duration (ms) and overall normalized RMS (0..1) from PCM16 LE bytes.

    Uses lightweight stdlib `array('h')` in-memory without heavy ML dependencies.
    Preserves natural intra-segment pauses without concatenating across silence.
    """
    aligned_len = len(pcm_bytes) - (len(pcm_bytes) % CANONICAL_SAMPLE_WIDTH_BYTES)
    if aligned_len <= 0:
        return 0, 0.0

    samples = array("h")
    samples.frombytes(pcm_bytes[:aligned_len])
    if sys.byteorder != "little":
        samples.byteswap()

    total_samples = len(samples)
    if total_samples == 0:
        return 0, 0.0

    subframe_samples = max(1, subframe_bytes // CANONICAL_SAMPLE_WIDTH_BYTES)
    active_samples = 0
    total_sq_sum = 0.0

    for start in range(0, total_samples, subframe_samples):
        chunk = samples[start : start + subframe_samples]
        if not chunk:
            continue
        sq_sum = 0.0
        for s in chunk:
            sq_sum += s * s
        total_sq_sum += sq_sum
        sub_rms = math.sqrt(sq_sum / len(chunk)) / 32768.0
        if sub_rms >= rms_threshold:
            active_samples += len(chunk)

    overall_rms = min(1.0, math.sqrt(total_sq_sum / total_samples) / 32768.0)
    valid_speech_ms = int(round((active_samples / CANONICAL_SAMPLE_RATE) * 1000.0))
    return valid_speech_ms, round(overall_rms, 5)


class SessionAudioSegmenter:
    """Bounded per-session PCM16 sample-count segmenter.

    Guarantees:
    - Exact sample-count segmentation (96,000 bytes = 48,000 samples = 3.0s at 16kHz PCM16 mono).
    - Preserves 2-byte PCM16 alignment across arbitrarily fragmented WebSocket binary frames.
    - Emits multiple segments if an oversized frame arrives.
    - Never merges audio across turn boundaries, mute boundaries, or capture epochs.
    - Never fabricates neutral segments for silence or sub-threshold tails.
    """

    def __init__(
        self,
        session_id: str,
        generation_token: str,
        segment_duration_ms: int = 3000,
        min_tail_duration_ms: int = 750,
        min_speech_ms_in_segment: int = 200,
        rms_speech_threshold: float = 0.008,
        max_ws_frame_bytes: int = 262_144,  # 256 KB (~8.19s max single WS frame)
        max_buffer_bytes: int = 384_000,  # 4 x 96,000 bytes (~12s hard memory cap)
    ) -> None:
        self.session_id = session_id
        self.generation_token = generation_token
        self.segment_duration_ms = segment_duration_ms
        self.segment_bytes = segment_duration_ms * CANONICAL_BYTES_PER_MS
        self.min_tail_duration_ms = min_tail_duration_ms
        self.min_tail_bytes = min_tail_duration_ms * CANONICAL_BYTES_PER_MS
        self.min_speech_ms_in_segment = min_speech_ms_in_segment
        self.rms_speech_threshold = rms_speech_threshold
        self.max_ws_frame_bytes = max_ws_frame_bytes
        self.max_buffer_bytes = max(max_buffer_bytes, self.segment_bytes * 2)

        self._buffer = bytearray()
        self._odd_byte_remainder: bytes = b""
        self._capture_epoch: int = 1
        self._sequence: int = 0
        self._session_offset_ms: int = 0
        self._segment_start_offset_ms: int = 0

        # Operational non-PII counters
        self.total_bytes_received: int = 0
        self.eligible_speech_received_ms: int = 0
        self.emitted_segments_count: int = 0
        self.excluded_silence_count: int = 0
        self.excluded_too_short_count: int = 0
        self.dropped_bytes: int = 0

    @property
    def capture_epoch(self) -> int:
        return self._capture_epoch

    @property
    def buffered_bytes(self) -> int:
        return len(self._buffer) + len(self._odd_byte_remainder)

    def ingest(
        self,
        chunk: bytes,
        user_turn_id: int,
    ) -> tuple[list[AudioSegment], list[SegmentExclusionEvent]]:
        """Ingest raw PCM16 LE bytes and emit zero or more 3-second AudioSegments."""
        emitted: list[AudioSegment] = []
        exclusions: list[SegmentExclusionEvent] = []

        if not chunk:
            return emitted, exclusions

        if len(chunk) > self.max_ws_frame_bytes:
            self.dropped_bytes += len(chunk)
            exclusions.append(
                SegmentExclusionEvent(
                    reason="dropped_frame_too_large",
                    duration_ms=len(chunk) // CANONICAL_BYTES_PER_MS,
                    byte_count=len(chunk),
                    capture_epoch=self._capture_epoch,
                    user_turn_id=user_turn_id,
                )
            )
            logger.warning(
                "[AUDIO SEGMENTER] Dropped oversized WS frame (%d bytes > %d) for session %s",
                len(chunk),
                self.max_ws_frame_bytes,
                self.session_id,
            )
            return emitted, exclusions

        self.total_bytes_received += len(chunk)

        # Preserve strict 2-byte PCM16 sample alignment across arbitrary frame splits
        if self._odd_byte_remainder:
            combined = self._odd_byte_remainder + chunk
            self._odd_byte_remainder = b""
        else:
            combined = chunk

        if len(combined) % CANONICAL_SAMPLE_WIDTH_BYTES != 0:
            self._odd_byte_remainder = combined[-1:]
            combined = combined[:-1]

        if not combined:
            return emitted, exclusions

        if not self._buffer:
            self._segment_start_offset_ms = self._session_offset_ms

        self._buffer.extend(combined)

        # Emit all complete nominal 3-second segments
        while len(self._buffer) >= self.segment_bytes:
            raw_slice = bytes(self._buffer[: self.segment_bytes])
            del self._buffer[: self.segment_bytes]
            seg, exc = self._evaluate_and_build_segment(
                pcm_bytes=raw_slice,
                user_turn_id=user_turn_id,
                is_tail=False,
            )
            if seg is not None:
                emitted.append(seg)
            elif exc is not None:
                exclusions.append(exc)
            self._segment_start_offset_ms = self._session_offset_ms

        # Hard memory cap guard (should rarely trigger since full slices emit immediately)
        if len(self._buffer) > self.max_buffer_bytes:
            overflow = len(self._buffer) - self.max_buffer_bytes
            overflow -= overflow % CANONICAL_SAMPLE_WIDTH_BYTES
            if overflow > 0:
                del self._buffer[:overflow]
                self.dropped_bytes += overflow
                overflow_ms = overflow // CANONICAL_BYTES_PER_MS
                self._session_offset_ms += overflow_ms
                self._segment_start_offset_ms = self._session_offset_ms
                exclusions.append(
                    SegmentExclusionEvent(
                        reason="dropped_buffer_overflow",
                        duration_ms=overflow_ms,
                        byte_count=overflow,
                        capture_epoch=self._capture_epoch,
                        user_turn_id=user_turn_id,
                    )
                )

        return emitted, exclusions

    def flush(
        self,
        user_turn_id: int,
        reason: str = "boundary",
        advance_epoch: bool = True,
    ) -> tuple[AudioSegment | None, SegmentExclusionEvent | None]:
        """Flush any buffered remainder at a turn/mute/restart/end-call boundary."""
        segment: AudioSegment | None = None
        exclusion: SegmentExclusionEvent | None = None

        # Discard dangling 1-byte remainder at hard capture boundary to prevent misalignment
        if self._odd_byte_remainder:
            self.dropped_bytes += len(self._odd_byte_remainder)
            self._odd_byte_remainder = b""

        if self._buffer:
            raw_tail = bytes(self._buffer)
            self._buffer.clear()
            duration_ms = len(raw_tail) // CANONICAL_BYTES_PER_MS

            if len(raw_tail) < self.min_tail_bytes:
                self._session_offset_ms += duration_ms
                self.excluded_too_short_count += 1
                exclusion = SegmentExclusionEvent(
                    reason="excluded_too_short",
                    duration_ms=duration_ms,
                    byte_count=len(raw_tail),
                    capture_epoch=self._capture_epoch,
                    user_turn_id=user_turn_id,
                )
            else:
                segment, exclusion = self._evaluate_and_build_segment(
                    pcm_bytes=raw_tail,
                    user_turn_id=user_turn_id,
                    is_tail=True,
                )

        if advance_epoch:
            self._capture_epoch += 1
        self._segment_start_offset_ms = self._session_offset_ms

        logger.debug(
            "[AUDIO SEGMENTER] Flush (%s) session=%s emitted=%s exclusion=%s next_epoch=%d",
            reason,
            self.session_id,
            segment.segment_id if segment else None,
            exclusion.reason if exclusion else None,
            self._capture_epoch,
        )
        return segment, exclusion

    def clear(self) -> None:
        """Immediately release buffered audio from RAM."""
        self._buffer.clear()
        self._odd_byte_remainder = b""

    def _evaluate_and_build_segment(
        self,
        pcm_bytes: bytes,
        user_turn_id: int,
        is_tail: bool,
    ) -> tuple[AudioSegment | None, SegmentExclusionEvent | None]:
        duration_ms = len(pcm_bytes) // CANONICAL_BYTES_PER_MS
        start_ms = self._segment_start_offset_ms
        end_ms = start_ms + duration_ms
        self._session_offset_ms = end_ms

        valid_speech_ms, rms_level = analyze_pcm16_speech_activity(
            pcm_bytes=pcm_bytes,
            rms_threshold=self.rms_speech_threshold,
        )

        # Exclude pure silence/non-speech segments without fabricating neutral scores
        min_required_speech = min(self.min_speech_ms_in_segment, duration_ms)
        if valid_speech_ms < min_required_speech:
            self.excluded_silence_count += 1
            return None, SegmentExclusionEvent(
                reason="excluded_silence",
                duration_ms=duration_ms,
                byte_count=len(pcm_bytes),
                capture_epoch=self._capture_epoch,
                user_turn_id=user_turn_id,
            )

        self._sequence += 1
        self.emitted_segments_count += 1
        self.eligible_speech_received_ms += valid_speech_ms

        seg = AudioSegment(
            segment_id=uuid.uuid4().hex,
            session_id=self.session_id,
            generation_token=self.generation_token,
            capture_epoch=self._capture_epoch,
            user_turn_id=user_turn_id,
            sequence=self._sequence,
            pcm_bytes=pcm_bytes,
            sample_rate=CANONICAL_SAMPLE_RATE,
            channels=CANONICAL_CHANNELS,
            sample_width_bytes=CANONICAL_SAMPLE_WIDTH_BYTES,
            start_offset_ms=start_ms,
            end_offset_ms=end_ms,
            duration_ms=duration_ms,
            valid_speech_ms=valid_speech_ms,
            rms_level=rms_level,
            is_tail=is_tail,
            created_monotonic_ms=int(time.monotonic() * 1000),
        )
        return seg, None
