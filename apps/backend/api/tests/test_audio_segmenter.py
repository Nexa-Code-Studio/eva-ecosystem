"""Unit tests for continuous 3-second sample-count PCM16 segmentation and WAV header helper."""

from __future__ import annotations

import io
import math
import sys
import wave
from array import array

from app.services.call.audio_segmenter import (
    CANONICAL_BYTES_PER_SECOND,
    CANONICAL_SAMPLE_RATE,
    SessionAudioSegmenter,
)
from app.services.emotion.ml_detector import ensure_wav_bytes


def _make_speech_pcm16(duration_s: float, amplitude: int = 8000, freq_hz: float = 220.0) -> bytes:
    """Generate deterministic 16kHz mono signed PCM16 LE active speech-like tone."""
    num_samples = int(round(duration_s * CANONICAL_SAMPLE_RATE))
    samples = array(
        "h",
        (int(amplitude * math.sin(2.0 * math.pi * freq_hz * (i / CANONICAL_SAMPLE_RATE))) for i in range(num_samples)),
    )
    if sys.byteorder != "little":
        samples.byteswap()
    return samples.tobytes()


def _make_silence_pcm16(duration_s: float) -> bytes:
    num_samples = int(round(duration_s * CANONICAL_SAMPLE_RATE))
    return b"\x00\x00" * num_samples


def test_60s_continuous_eligible_speech_emits_exact_20_segments():
    seg = SessionAudioSegmenter(session_id="sess-60s", generation_token="gen-1")
    pcm_60s = _make_speech_pcm16(60.0)
    assert len(pcm_60s) == 60 * CANONICAL_BYTES_PER_SECOND  # 1,920,000 bytes

    # Stream in realistic Android native 150ms chunks (4,800 bytes)
    emitted = []
    chunk_size = 4800
    for offset in range(0, len(pcm_60s), chunk_size):
        segs, excs = seg.ingest(pcm_60s[offset : offset + chunk_size], user_turn_id=1)
        assert excs == []
        emitted.extend(segs)

    assert len(emitted) == 20
    assert seg.buffered_bytes == 0
    assert seg.emitted_segments_count == 20
    assert seg.excluded_silence_count == 0
    assert seg.excluded_too_short_count == 0

    for idx, item in enumerate(emitted):
        assert len(item.pcm_bytes) == 96_000
        assert item.duration_ms == 3000
        assert item.sequence == idx + 1
        assert item.start_offset_ms == idx * 3000
        assert item.end_offset_ms == (idx + 1) * 3000
        assert item.valid_speech_ms == 3000
        assert item.is_tail is False


def test_fragmented_odd_byte_and_oversized_ws_frames_preserve_alignment():
    seg = SessionAudioSegmenter(session_id="sess-frag", generation_token="gen-1")
    pcm_6s = _make_speech_pcm16(6.0)

    # Split with deliberately odd byte boundaries (101, 4801, remaining oversized multi-emit)
    s1, e1 = seg.ingest(pcm_6s[:101], user_turn_id=1)
    assert s1 == [] and e1 == []
    s2, e2 = seg.ingest(pcm_6s[101:4902], user_turn_id=1)
    assert s2 == [] and e2 == []
    s3, e3 = seg.ingest(pcm_6s[4902:], user_turn_id=1)

    assert e3 == []
    assert len(s3) == 2
    assert s3[0].pcm_bytes == pcm_6s[:96_000]
    assert s3[1].pcm_bytes == pcm_6s[96_000:192_000]
    assert seg.buffered_bytes == 0


def test_pure_silence_is_excluded_not_fabricated():
    seg = SessionAudioSegmenter(session_id="sess-silent", generation_token="gen-1")
    emitted, exclusions = seg.ingest(_make_silence_pcm16(3.0), user_turn_id=1)

    assert emitted == []
    assert len(exclusions) == 1
    assert exclusions[0].reason == "excluded_silence"
    assert seg.excluded_silence_count == 1
    assert seg.emitted_segments_count == 0


def test_tail_flush_valid_vs_too_short_and_epoch_isolation():
    seg = SessionAudioSegmenter(
        session_id="sess-tail",
        generation_token="gen-1",
        min_tail_duration_ms=750,
    )
    # 1.2s valid speech tail -> should emit on turn flush and advance capture_epoch
    s_in, _ = seg.ingest(_make_speech_pcm16(1.2), user_turn_id=1)
    assert s_in == []
    tail_seg, tail_exc = seg.flush(user_turn_id=1, reason="turn_commit", advance_epoch=True)
    assert tail_exc is None
    assert tail_seg is not None
    assert tail_seg.is_tail is True
    assert tail_seg.duration_ms == 1200
    assert tail_seg.capture_epoch == 1
    assert seg.capture_epoch == 2

    # 0.3s short tail -> excluded_too_short, never merged into next turn
    seg.ingest(_make_speech_pcm16(0.3), user_turn_id=2)
    short_seg, short_exc = seg.flush(user_turn_id=2, reason="mute", advance_epoch=True)
    assert short_seg is None
    assert short_exc is not None
    assert short_exc.reason == "excluded_too_short"
    assert seg.capture_epoch == 3
    assert seg.buffered_bytes == 0


def test_oversized_single_ws_frame_rejected_safely():
    seg = SessionAudioSegmenter(
        session_id="sess-cap",
        generation_token="gen-1",
        max_ws_frame_bytes=10_000,
    )
    emitted, exclusions = seg.ingest(_make_speech_pcm16(1.0), user_turn_id=1)
    assert emitted == []
    assert len(exclusions) == 1
    assert exclusions[0].reason == "dropped_frame_too_large"
    assert seg.dropped_bytes == 32_000


def test_ensure_wav_bytes_adds_valid_header_for_raw_pcm16():
    raw_pcm = _make_speech_pcm16(0.5)
    wav_bytes = ensure_wav_bytes(raw_pcm)
    assert wav_bytes[:4] == b"RIFF"
    assert wav_bytes[8:12] == b"WAVE"
    with wave.open(io.BytesIO(wav_bytes), "rb") as wf:
        assert wf.getframerate() == 16000
        assert wf.getnchannels() == 1
        assert wf.getsampwidth() == 2
        assert wf.getnframes() == 8000

    # Idempotent if already a WAV container
    assert ensure_wav_bytes(wav_bytes) == wav_bytes
