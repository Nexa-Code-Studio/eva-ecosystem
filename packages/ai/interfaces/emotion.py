"""Abstract provider interface for isolated speech emotion inference."""

from __future__ import annotations

from abc import ABC, abstractmethod

from shared.domain_types import EmotionSegmentPrediction


class BaseEmotionProvider(ABC):
    """Contract for async speech emotion inference providers (Mock, Local, Remote Cloud Run)."""

    @abstractmethod
    async def predict_pcm_segment(
        self,
        pcm_bytes: bytes,
        *,
        segment_id: str,
        sample_rate: int = 16000,
        channels: int = 1,
        sample_width_bytes: int = 2,
        valid_speech_ms: int = 0,
        duration_ms: int = 0,
        deadline_ms: int | None = None,
        sequence: int = 0,
        user_turn_id: int = 0,
        capture_epoch: int = 0,
        start_offset_ms: int = 0,
        end_offset_ms: int = 0,
    ) -> EmotionSegmentPrediction:
        """Run non-blocking emotion prediction on a single canonical PCM16 LE segment."""

    @abstractmethod
    async def health_check(self) -> bool:
        """Return True if the inference provider is ready to accept segments."""

    async def close(self) -> None:
        """Release pooled connections or resources cleanly."""
        return None
