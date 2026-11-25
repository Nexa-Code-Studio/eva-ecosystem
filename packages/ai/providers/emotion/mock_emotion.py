"""Deterministic offline MockEmotionProvider for tests and local development."""

from __future__ import annotations

import asyncio
import time

from packages.ai.interfaces.emotion import BaseEmotionProvider
from shared.domain_types import (
    EMOTION2VEC_CANONICAL_CLASSES,
    EmotionSegmentPrediction,
)


class MockEmotionProvider(BaseEmotionProvider):
    """Zero-network deterministic emotion provider supporting latency & fault injection."""

    def __init__(
        self,
        *,
        simulated_latency_ms: float = 5.0,
        default_scores: dict[str, float] | None = None,
        fail_with: Exception | None = None,
        model_revision: str = "mock-v1",
    ) -> None:
        self.simulated_latency_ms = max(0.0, float(simulated_latency_ms))
        self.default_scores = default_scores
        self.fail_with = fail_with
        self.model_revision = model_revision
        self.calls: list[dict[str, int | str]] = []

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
        start_t = time.perf_counter()
        self.calls.append(
            {
                "segment_id": segment_id,
                "bytes_len": len(pcm_bytes),
                "sequence": sequence,
                "user_turn_id": user_turn_id,
            }
        )

        if self.simulated_latency_ms > 0:
            await asyncio.sleep(self.simulated_latency_ms / 1000.0)

        if self.fail_with is not None:
            raise self.fail_with

        if self.default_scores is not None:
            raw = {cls: float(self.default_scores.get(cls, 0.0)) for cls in EMOTION2VEC_CANONICAL_CLASSES}
        else:
            raw = {cls: 0.02 for cls in EMOTION2VEC_CANONICAL_CLASSES}
            raw["neutral"] = 0.56
            raw["sad"] = 0.24
            raw["happy"] = 0.08

        total = sum(raw.values()) or 1.0
        scores = {k: round(v / total, 6) for k, v in raw.items()}
        ordered = sorted(scores.items(), key=lambda item: item[1], reverse=True)
        primary_emotion, confidence = ordered[0]
        secondary_emotion = ordered[1][0] if len(ordered) > 1 else None
        elapsed_ms = round((time.perf_counter() - start_t) * 1000.0, 2)

        return EmotionSegmentPrediction(
            schema_version=1,
            segment_id=segment_id,
            status="ok",
            model="emotion2vec_plus_base",
            model_revision=self.model_revision,
            runtime="mock",
            precision="mock",
            scores=scores,
            primary_emotion=primary_emotion,
            secondary_emotion=secondary_emotion,
            confidence=confidence,
            inference_ms=elapsed_ms,
            valid_speech_ms=valid_speech_ms,
            duration_ms=duration_ms,
            sequence=sequence,
            user_turn_id=user_turn_id,
            capture_epoch=capture_epoch,
            start_offset_ms=start_offset_ms,
            end_offset_ms=end_offset_ms,
        )

    async def health_check(self) -> bool:
        return self.fail_with is None
