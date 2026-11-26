"""Per-session 30–60s rolling temporal emotion aggregator (duration-weighted mean).

Invariants:
- Stores per-segment scores only (never raw audio bytes).
- Strict session & generation_token isolation.
- Rejects duplicate segment IDs and mixed model versions.
- Handles out-of-order segment arrivals cleanly using (capture_epoch, sequence, start_offset_ms).
- Never fabricates neutral/stress scores when no analyzed data exists.
"""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from typing import Any

from shared.domain_types import (
    EMOTION2VEC_CANONICAL_CLASSES,
    EmotionSegmentPrediction,
    EmotionSource,
    EmotionWindowStatus,
    TemporalEmotionSnapshot,
)

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class _SegmentEntry:
    segment_id: str
    capture_epoch: int
    sequence: int
    user_turn_id: int
    start_offset_ms: int
    end_offset_ms: int
    duration_ms: int
    valid_speech_ms: int
    scores: dict[str, float]
    model_version: str
    recorded_at_ms: int


class SessionTemporalEmotionAggregator:
    """Computes duration-weighted rolling emotion distributions over a 30–60s speech window."""

    def __init__(
        self,
        session_id: str,
        generation_token: str,
        *,
        window_target_ms: int = 30_000,
        staleness_ms: int = 180_000,
        min_coverage: float = 0.60,
        max_retained_segments: int = 120,
    ) -> None:
        self.session_id = session_id
        self.generation_token = generation_token
        self.window_target_ms = max(10_000, min(60_000, window_target_ms))
        self.staleness_ms = max(10_000, staleness_ms)
        self.min_coverage = max(0.05, min(1.0, min_coverage))
        self.max_retained_segments = max(30, max_retained_segments)

        self._entries: list[_SegmentEntry] = []
        self._seen_segment_ids: set[str] = set()
        self._pending_speech_ms: dict[str, int] = {}
        self._failed_speech_ms: int = 0
        self._failed_count: int = 0
        self._excluded_count: int = 0
        self._degradation_reasons: set[str] = set()
        self._active_model_version: str | None = None
        self._last_updated_ms: int | None = None

    def mark_pending(self, segment_id: str, valid_speech_ms: int) -> None:
        if segment_id not in self._seen_segment_ids:
            self._pending_speech_ms[segment_id] = max(0, int(valid_speech_ms))

    def mark_failed(self, segment_id: str, reason: str, valid_speech_ms: int | None = None) -> None:
        tracked_ms = self._pending_speech_ms.pop(segment_id, None)
        effective_ms = tracked_ms if tracked_ms is not None else max(0, int(valid_speech_ms or 0))
        self._failed_speech_ms += effective_ms
        self._failed_count += 1
        if reason:
            self._degradation_reasons.add(reason)

    def mark_excluded(self, reason: str) -> None:
        self._excluded_count += 1
        if reason and reason not in ("excluded_silence", "excluded_too_short"):
            self._degradation_reasons.add(reason)

    def record_prediction(
        self,
        *,
        session_id: str,
        generation_token: str,
        prediction: EmotionSegmentPrediction,
        now_ms: int | None = None,
    ) -> bool:
        """Record a single verified segment prediction; returns False if rejected."""
        if session_id != self.session_id or generation_token != self.generation_token:
            return False

        if prediction.segment_id in self._seen_segment_ids:
            return False

        model_version = f"{prediction.model}@{prediction.model_revision}"
        if self._active_model_version is None:
            self._active_model_version = model_version
        elif self._active_model_version != model_version:
            self._pending_speech_ms.pop(prediction.segment_id, None)
            self._failed_count += 1
            self._failed_speech_ms += max(0, int(prediction.valid_speech_ms))
            self._degradation_reasons.add("mixed_model_version_rejected")
            logger.warning(
                "[TEMPORAL AGGREGATOR] Rejected mixed model version '%s' (active='%s') for session %s",
                model_version,
                self._active_model_version,
                self.session_id,
            )
            return False

        self._pending_speech_ms.pop(prediction.segment_id, None)
        self._seen_segment_ids.add(prediction.segment_id)

        ts_ms = now_ms if now_ms is not None else int(time.monotonic() * 1000)
        entry = _SegmentEntry(
            segment_id=prediction.segment_id,
            capture_epoch=prediction.capture_epoch,
            sequence=prediction.sequence,
            user_turn_id=prediction.user_turn_id,
            start_offset_ms=prediction.start_offset_ms,
            end_offset_ms=prediction.end_offset_ms,
            duration_ms=max(0, int(prediction.duration_ms)),
            valid_speech_ms=max(1, int(prediction.valid_speech_ms or prediction.duration_ms or 1)),
            scores=dict(prediction.scores),
            model_version=model_version,
            recorded_at_ms=ts_ms,
        )
        self._entries.append(entry)
        # Maintain deterministic chronological order despite out-of-order HTTP responses
        self._entries.sort(key=lambda e: (e.capture_epoch, e.sequence, e.start_offset_ms))

        if len(self._entries) > self.max_retained_segments:
            self._entries = self._entries[-self.max_retained_segments :]

        self._last_updated_ms = max(self._last_updated_ms or ts_ms, ts_ms)
        return True

    def build_snapshot(
        self,
        *,
        current_turn_id: int | None = None,
        now_ms: int | None = None,
        extra_degradation_reasons: list[str] | None = None,
    ) -> TemporalEmotionSnapshot:
        """Build an immutable temporal snapshot for AIOrchestrator / UI / artifacts."""
        current_ms = now_ms if now_ms is not None else int(time.monotonic() * 1000)
        reasons = sorted(self._degradation_reasons | set(extra_degradation_reasons or ()))
        pending_ms = sum(self._pending_speech_ms.values())

        if not self._entries:
            received_ms = pending_ms + self._failed_speech_ms
            return TemporalEmotionSnapshot(
                source=EmotionSource.UNAVAILABLE,
                status=EmotionWindowStatus.UNAVAILABLE,
                window_target_ms=self.window_target_ms,
                wall_span_ms=0,
                speech_analyzed_ms=0,
                speech_received_ms=received_ms,
                coverage=0.0,
                segment_count=0,
                pending_count=len(self._pending_speech_ms),
                failed_count=self._failed_count,
                excluded_count=self._excluded_count,
                scores=None,
                turn_scores=None,
                primary_emotion=None,
                secondary_emotion=None,
                confidence=None,
                model_version=self._active_model_version,
                updated_at_ms=self._last_updated_ms,
                age_ms=None,
                degradation_reasons=reasons,
            )

        age_ms = max(0, current_ms - (self._last_updated_ms or current_ms))

        # Select newest segments backward until window_target_ms of valid speech is reached
        selected: list[_SegmentEntry] = []
        acc_speech_ms = 0
        for entry in reversed(self._entries):
            selected.append(entry)
            acc_speech_ms += entry.valid_speech_ms
            if acc_speech_ms >= self.window_target_ms:
                break
        selected.reverse()

        weighted_scores = self._compute_duration_weighted_mean(selected)
        ordered = sorted(weighted_scores.items(), key=lambda item: item[1], reverse=True)
        primary_emotion, confidence = ordered[0]
        secondary_emotion = ordered[1][0] if len(ordered) > 1 else None

        turn_scores: dict[str, float] | None = None
        if current_turn_id is not None:
            turn_entries = [e for e in selected if e.user_turn_id == current_turn_id]
            if turn_entries:
                turn_scores = self._compute_duration_weighted_mean(turn_entries)

        wall_span_ms = max(0, selected[-1].end_offset_ms - selected[0].start_offset_ms)

        # Coverage compares analyzed valid speech vs all eligible received speech in window scope
        total_analyzed_all = sum(e.valid_speech_ms for e in self._entries)
        total_received_all = total_analyzed_all + pending_ms + self._failed_speech_ms
        coverage = round(min(1.0, total_analyzed_all / total_received_all), 4) if total_received_all > 0 else 0.0

        if age_ms > self.staleness_ms:
            status = EmotionWindowStatus.STALE
        elif acc_speech_ms >= self.window_target_ms and coverage >= self.min_coverage:
            status = EmotionWindowStatus.READY
        else:
            status = EmotionWindowStatus.PARTIAL

        return TemporalEmotionSnapshot(
            source=EmotionSource.AUDIO_TEMPORAL,
            status=status,
            window_target_ms=self.window_target_ms,
            wall_span_ms=wall_span_ms,
            speech_analyzed_ms=acc_speech_ms,
            speech_received_ms=total_received_all,
            coverage=coverage,
            segment_count=len(selected),
            pending_count=len(self._pending_speech_ms),
            failed_count=self._failed_count,
            excluded_count=self._excluded_count,
            scores=weighted_scores,
            turn_scores=turn_scores,
            primary_emotion=primary_emotion,
            secondary_emotion=secondary_emotion,
            confidence=confidence,
            model_version=self._active_model_version,
            updated_at_ms=self._last_updated_ms,
            age_ms=age_ms,
            degradation_reasons=reasons,
        )

    def build_session_artifact(self, *, now_ms: int | None = None) -> dict[str, Any]:
        """Build a versioned, #96-compatible ephemeral session emotion summary payload."""
        snap = self.build_snapshot(now_ms=now_ms)
        return {
            "schema_version": 1,
            "source": snap.source.value,
            "status": snap.status.value,
            "window_target_ms": snap.window_target_ms,
            "wall_span_ms": snap.wall_span_ms,
            "speech_analyzed_ms": snap.speech_analyzed_ms,
            "speech_received_ms": snap.speech_received_ms,
            "coverage": snap.coverage,
            "segment_count": snap.segment_count,
            "primary_emotion": snap.primary_emotion,
            "secondary_emotion": snap.secondary_emotion,
            "confidence": snap.confidence,
            "scores": snap.scores,
            "model_version": snap.model_version,
            "degradation_reasons": snap.degradation_reasons,
            "disclaimer": "Observasi akustik tentatif; bukan diagnosis klinis atau penilaian psikolog.",
        }

    def clear(self) -> None:
        self._entries.clear()
        self._seen_segment_ids.clear()
        self._pending_speech_ms.clear()
        self._degradation_reasons.clear()

    @staticmethod
    def _compute_duration_weighted_mean(entries: list[_SegmentEntry]) -> dict[str, float]:
        total_weight = sum(e.valid_speech_ms for e in entries)
        if total_weight <= 0:
            return {cls: 0.0 for cls in EMOTION2VEC_CANONICAL_CLASSES}

        accum = {cls: 0.0 for cls in EMOTION2VEC_CANONICAL_CLASSES}
        for entry in entries:
            w = float(entry.valid_speech_ms)
            for cls in EMOTION2VEC_CANONICAL_CLASSES:
                accum[cls] += w * float(entry.scores.get(cls, 0.0))

        return {cls: round(accum[cls] / total_weight, 6) for cls in EMOTION2VEC_CANONICAL_CLASSES}
