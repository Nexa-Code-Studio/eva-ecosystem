"""WAV audio loading, resampling to 16kHz mono PCM, and dynamic duration slicing."""

from __future__ import annotations

import array
import wave
from pathlib import Path
from typing import Iterator

TARGET_SAMPLE_RATE = 16000
TARGET_CHANNELS = 1
TARGET_SAMPLE_WIDTH = 2  # 16-bit PCM


def _downmix_stereo_to_mono(samples: array.array[int]) -> array.array[int]:
    """Average L/R pairs of 16-bit signed PCM into mono."""
    mono = array.array("h")
    for idx in range(0, len(samples) - 1, 2):
        mono.append((samples[idx] + samples[idx + 1]) // 2)
    return mono


def _resample_linear(
    samples: array.array[int], src_rate: int, dst_rate: int
) -> array.array[int]:
    """Resample mono 16-bit PCM using integer-safe linear decimation/interpolation."""
    if src_rate == dst_rate or not samples:
        return samples
    out_len = max(1, int(round(len(samples) * dst_rate / src_rate)))
    ratio = src_rate / dst_rate
    out = array.array("h")
    max_idx = len(samples) - 1
    for i in range(out_len):
        pos = i * ratio
        idx = int(pos)
        frac = pos - idx
        s0 = samples[min(idx, max_idx)]
        s1 = samples[min(idx + 1, max_idx)]
        out.append(int(s0 + (s1 - s0) * frac))
    return out


def load_wav_as_pcm16k(path: Path) -> bytes:
    """Read a 16-bit WAV file and return 16kHz mono 16-bit little-endian PCM bytes."""
    with wave.open(str(path), "rb") as wf:
        channels = wf.getnchannels()
        sampwidth = wf.getsampwidth()
        framerate = wf.getframerate()
        raw = wf.readframes(wf.getnframes())

    if sampwidth != TARGET_SAMPLE_WIDTH:
        raise ValueError(
            f"Unsupported WAV sample width ({sampwidth * 8}-bit) in {path}; expected 16-bit."
        )

    samples = array.array("h")
    samples.frombytes(raw)
    if channels == 2:
        samples = _downmix_stereo_to_mono(samples)
    elif channels != 1:
        raise ValueError(f"Unsupported channel count ({channels}) in {path}")

    if framerate != TARGET_SAMPLE_RATE:
        samples = _resample_linear(samples, framerate, TARGET_SAMPLE_RATE)

    return samples.tobytes()


def discover_audio_files(
    audio_dir: str, audio_sample_path: str | None = None
) -> list[Path]:
    """Resolve explicit audio file or ordered 1.wav..N.wav / *.wav files from audio_dir."""
    if audio_sample_path:
        path = Path(audio_sample_path)
        if not path.is_file():
            raise FileNotFoundError(f"Audio sample file not found: {path}")
        return [path]

    directory = Path(audio_dir)
    if not directory.is_dir():
        raise FileNotFoundError(f"Audio directory not found: {directory}")

    numbered = [
        p for p in sorted(directory.glob("*.wav")) if p.stem.isdigit()
    ]
    if numbered:
        return numbered

    all_wavs = sorted(directory.glob("*.wav"))
    if not all_wavs:
        raise FileNotFoundError(f"No .wav files found in {directory}")
    return all_wavs


def load_pcm_pool(
    audio_dir: str, audio_sample_path: str | None = None
) -> bytes:
    """Concatenate resolved WAV clips into a contiguous 16kHz mono PCM pool."""
    files = discover_audio_files(audio_dir, audio_sample_path)
    return b"".join(load_wav_as_pcm16k(f) for f in files)


def build_pcm_for_duration(pcm_16k: bytes, duration_seconds: float) -> bytes:
    """Slice or loop a 16kHz 16-bit mono PCM buffer to match duration_seconds exactly."""
    if not pcm_16k or duration_seconds <= 0:
        return b""
    bytes_per_sample = TARGET_CHANNELS * TARGET_SAMPLE_WIDTH
    target_samples = int(round(duration_seconds * TARGET_SAMPLE_RATE))
    target_bytes = target_samples * bytes_per_sample
    aligned_len = (len(pcm_16k) // bytes_per_sample) * bytes_per_sample
    if aligned_len == 0:
        return b""
    src = pcm_16k[:aligned_len]
    if len(src) >= target_bytes:
        return src[:target_bytes]
    repeats = (target_bytes // len(src)) + 1
    return (src * repeats)[:target_bytes]


def iter_pcm_chunks(pcm_16k: bytes, chunk_ms: int = 100) -> Iterator[bytes]:
    """Yield fixed-duration PCM chunks (default 100ms = 3200 bytes at 16kHz mono 16-bit)."""
    chunk_samples = max(1, (TARGET_SAMPLE_RATE * chunk_ms) // 1000)
    chunk_bytes = chunk_samples * TARGET_CHANNELS * TARGET_SAMPLE_WIDTH
    for offset in range(0, len(pcm_16k), chunk_bytes):
        yield pcm_16k[offset : offset + chunk_bytes]
