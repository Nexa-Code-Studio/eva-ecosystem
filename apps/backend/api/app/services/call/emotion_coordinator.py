"""Per-session coordinator uniting 3s segmentation, bounded async dispatch, and 30–60s aggregation."""

from __future__ import annotations

import logging
import uuid
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

from app.services.call.audio_segmenter import AudioSegment, SessionAudioSegmenter
from app.services.call.emotion_dispatcher import BoundedEmotionDispatcher
from app.services.call.temporal_emotion_aggregator import SessionTemporalEmotionAggregator

from packages.ai.factories.emotion_factory import EmotionFactory
from packages.ai.interfaces.emotion import BaseEmotionProvider
from packages.shared.config import settings
from shared.domain_types import (
    EmotionDetectionResult,
    EmotionSegmentPrediction,
    EmotionSource,
    EmotionWindowStatus,
    TemporalEmotionSnapshot,
)

logger = logging.getLogger(__name__)


@dataclass
class _SessionEmotionContext:
    session_id: str
    generation_token: str
    privacy_mode: str | None
    audio_inference_allowed: bool
    segmenter: SessionAudioSegmenter
    aggregator: SessionTemporalEmotionAggregator


class CallEmotionCoordinator:
    """High-level non-blocking facade for CallSessionManager emotion orchestration."""

    def __init__(
        self,
        provider_getter: Callable[[], BaseEmotionProvider] | None = None,
        on_snapshot_updated: Callable[[str, TemporalEmotionSnapshot], None] | None = None,
    ) -> None:
        self._provider_getter = provider_getter or EmotionFactory.get_provider
        self._on_snapshot_updated = on_snapshot_updated
        self._sessions: dict[str, _SessionEmotionContext] = {}
        self.dispatcher = BoundedEmotionDispatcher(
            provider_getter=self._provider_getter,
            max_global_inflight=settings.EMOTION_DISPATCHER_MAX_INFLIGHT,
            per_session_max_inflight=settings.EMOTION_DISPATCHER_PER_SESSION_MAX_INFLIGHT,
            max_queue_size=settings.EMOTION_DISPATCHER_QUEUE_SIZE,
            segment_deadline_ms=settings.EMOTION_SEGMENT_DEADLINE_MS,
        )
        self.dispatcher.configure_callbacks(
            on_result=self._handle_segment_result,
            on_failure=self._handle_segment_failure,
            is_session_active=self._is_session_active,
        )

    def register_session(
        self,
        session_id: str,
        *,
        privacy_mode: str | None = None,
        window_target_ms: int | None = None,
    ) -> str:
        # Clean up any prior session with same ID to guarantee strict generation isolation
        if session_id in self._sessions:
            self.cleanup_session(session_id)

        generation_token = uuid.uuid4().hex
        norm_privacy = (privacy_mode or "").strip().lower() or None

        # Fail-closed for incognito mode unless explicitly allowed by privacy contract
        audio_allowed = True
        if norm_privacy == "incognito" and not settings.EMOTION_ALLOW_INCOGNITO_CLOUD_AUDIO:
            audio_allowed = False

        segmenter = SessionAudioSegmenter(
            session_id=session_id,
            generation_token=generation_token,
            segment_duration_ms=settings.EMOTION_SEGMENT_DURATION_MS,
            min_tail_duration_ms=settings.EMOTION_MIN_TAIL_DURATION_MS,
        )
        aggregator = SessionTemporalEmotionAggregator(
            session_id=session_id,
            generation_token=generation_token,
            window_target_ms=window_target_ms or settings.EMOTION_WINDOW_TARGET_MS,
            staleness_ms=settings.EMOTION_WINDOW_STALENESS_MS,
            min_coverage=settings.EMOTION_WINDOW_MIN_COVERAGE,
        )

        self._sessions[session_id] = _SessionEmotionContext(
            session_id=session_id,
            generation_token=generation_token,
            privacy_mode=norm_privacy,
            audio_inference_allowed=audio_allowed,
            segmenter=segmenter,
            aggregator=aggregator,
        )
        return generation_token

    def ingest_pcm_chunk(self, session_id: str, chunk: bytes, *, user_turn_id: int) -> int:
        """Non-blocking ingest of binary PCM16 chunk from WebSocket loop. Returns enqueued segment count."""
        ctx = self._sessions.get(session_id)
        if ctx is None or not ctx.audio_inference_allowed:
            return 0

        emitted, exclusions = ctx.segmenter.ingest(chunk, user_turn_id=user_turn_id)
        for exc in exclusions:
            ctx.aggregator.mark_excluded(exc.reason)

        enqueued = 0
        for seg in emitted:
            ctx.aggregator.mark_pending(seg.segment_id, seg.valid_speech_ms)
            ok, reason = self.dispatcher.enqueue(seg)
            if ok:
                enqueued += 1
            elif reason:
                ctx.aggregator.mark_failed(seg.segment_id, reason, seg.valid_speech_ms)
        return enqueued

    def flush_boundary(
        self,
        session_id: str,
        *,
        user_turn_id: int,
        reason: str = "boundary",
        advance_epoch: bool = True,
    ) -> bool:
        """Flush buffered remainder at turn/mute/barge-in/end boundary without blocking."""
        ctx = self._sessions.get(session_id)
        if ctx is None or not ctx.audio_inference_allowed:
            return False

        seg, exc = ctx.segmenter.flush(
            user_turn_id=user_turn_id,
            reason=reason,
            advance_epoch=advance_epoch,
        )
        if exc is not None:
            ctx.aggregator.mark_excluded(exc.reason)
        if seg is not None:
            ctx.aggregator.mark_pending(seg.segment_id, seg.valid_speech_ms)
            ok, drop_reason = self.dispatcher.enqueue(seg)
            if not ok and drop_reason:
                ctx.aggregator.mark_failed(seg.segment_id, drop_reason, seg.valid_speech_ms)
            return ok
        return False

    def get_snapshot(
        self,
        session_id: str,
        *,
        current_turn_id: int | None = None,
    ) -> TemporalEmotionSnapshot:
        """Immediately return the latest immutable temporal emotion snapshot without waiting."""
        ctx = self._sessions.get(session_id)
        if ctx is None:
            return TemporalEmotionSnapshot(
                source=EmotionSource.UNAVAILABLE,
                status=EmotionWindowStatus.UNAVAILABLE,
                window_target_ms=settings.EMOTION_WINDOW_TARGET_MS,
            )

        extra_reasons = ["incognito_audio_disabled"] if not ctx.audio_inference_allowed else None
        return ctx.aggregator.build_snapshot(
            current_turn_id=current_turn_id,
            extra_degradation_reasons=extra_reasons,
        )

    @staticmethod
    def snapshot_to_detection_result(snapshot: TemporalEmotionSnapshot) -> EmotionDetectionResult | None:
        """Convert a valid temporal snapshot to EmotionDetectionResult (returns None if unavailable/stale)."""
        if (
            snapshot.status in (EmotionWindowStatus.UNAVAILABLE, EmotionWindowStatus.STALE)
            or not snapshot.scores
            or not snapshot.primary_emotion
            or snapshot.confidence is None
        ):
            return None

        return EmotionDetectionResult(
            primary_emotion=snapshot.primary_emotion,
            confidence=round(float(snapshot.confidence), 4),
            intensity=round(float(snapshot.confidence), 4),
            secondary_emotion=snapshot.secondary_emotion,
            scores=dict(snapshot.scores),
            model_used=snapshot.model_version or "emotion2vec_plus_base",
            latency_ms=0.0,
            source=snapshot.source,
            status=snapshot.status,
            temporal_snapshot=snapshot,
        )

    async def drain_and_build_artifact(
        self,
        session_id: str,
        *,
        user_turn_id: int = 0,
        timeout_ms: int | None = None,
    ) -> dict[str, Any]:
        """Flush final tail, bounded-drain pending inference, and return #96-compatible artifact."""
        ctx = self._sessions.get(session_id)
        if ctx is None:
            return {
                "schema_version": 1,
                "source": EmotionSource.UNAVAILABLE.value,
                "status": EmotionWindowStatus.UNAVAILABLE.value,
                "coverage": 0.0,
                "scores": None,
            }

        self.flush_boundary(session_id, user_turn_id=user_turn_id, reason="session_finalize", advance_epoch=True)
        drain_budget = timeout_ms if timeout_ms is not None else settings.EMOTION_FINALIZE_DRAIN_MS
        await self.dispatcher.drain_session(session_id, timeout_ms=drain_budget)
        return ctx.aggregator.build_session_artifact()

    def cleanup_session(self, session_id: str) -> None:
        """Cancel pending jobs and purge all raw buffers & score state from RAM."""
        ctx = self._sessions.pop(session_id, None)
        self.dispatcher.cancel_session(session_id)
        if ctx is not None:
            ctx.segmenter.clear()
            ctx.aggregator.clear()

    async def shutdown(self) -> None:
        for sid in list(self._sessions.keys()):
            self.cleanup_session(sid)
        await self.dispatcher.shutdown()
        await EmotionFactory.close_all()

    def set_snapshot_callback(
        self,
        callback: Callable[[str, TemporalEmotionSnapshot], None] | None,
    ) -> None:
        self._on_snapshot_updated = callback

    def _is_session_active(self, session_id: str, generation_token: str) -> bool:
        ctx = self._sessions.get(session_id)
        return ctx is not None and ctx.generation_token == generation_token

    def _handle_segment_result(self, segment: AudioSegment, prediction: EmotionSegmentPrediction) -> None:
        ctx = self._sessions.get(segment.session_id)
        if ctx is None:
            return
        ctx.aggregator.record_prediction(
            session_id=segment.session_id,
            generation_token=segment.generation_token,
            prediction=prediction,
        )
        if self._on_snapshot_updated is not None:
            try:
                snapshot = ctx.aggregator.build_snapshot(current_turn_id=segment.user_turn_id)
                self._on_snapshot_updated(segment.session_id, snapshot)
            except Exception as err:
                logger.debug("Emotion snapshot callback skipped: %s", type(err).__name__)

    def _handle_segment_failure(self, segment: AudioSegment, reason: str) -> None:
        ctx = self._sessions.get(segment.session_id)
        if ctx is None or ctx.generation_token != segment.generation_token:
            return
        ctx.aggregator.mark_failed(segment.segment_id, reason, segment.valid_speech_ms)


call_emotion_coordinator = CallEmotionCoordinator()


async def shutdown_emotion_coordinator() -> None:
    await call_emotion_coordinator.shutdown()
