"""Unit tests for BoundedEmotionDispatcher: non-blocking enqueue, fairness, deadlines, and cancellation."""

from __future__ import annotations

import asyncio
import time

import pytest
from app.services.call.audio_segmenter import AudioSegment
from app.services.call.emotion_dispatcher import BoundedEmotionDispatcher

from packages.ai.providers.emotion.mock_emotion import MockEmotionProvider
from shared.domain_types import EmotionSegmentPrediction


def _make_seg(
    seg_id: str,
    session_id: str = "s1",
    gen: str = "g1",
    seq: int = 1,
    created_offset_ms: int = 0,
) -> AudioSegment:
    return AudioSegment(
        segment_id=seg_id,
        session_id=session_id,
        generation_token=gen,
        capture_epoch=1,
        user_turn_id=1,
        sequence=seq,
        pcm_bytes=b"\x01\x00" * 48000,
        sample_rate=16000,
        channels=1,
        sample_width_bytes=2,
        start_offset_ms=(seq - 1) * 3000,
        end_offset_ms=seq * 3000,
        duration_ms=3000,
        valid_speech_ms=3000,
        rms_level=0.2,
        is_tail=False,
        created_monotonic_ms=int(time.monotonic() * 1000) + created_offset_ms,
    )


@pytest.mark.asyncio
async def test_dispatcher_non_blocking_enqueue_and_drain():
    provider = MockEmotionProvider(simulated_latency_ms=10.0)
    dispatcher = BoundedEmotionDispatcher(
        provider_getter=lambda: provider,
        max_global_inflight=4,
        per_session_max_inflight=2,
        max_queue_size=16,
    )
    results: list[EmotionSegmentPrediction] = []
    failures: list[tuple[str, str]] = []

    dispatcher.configure_callbacks(
        on_result=lambda _seg, pred: results.append(pred),
        on_failure=lambda seg, reason: failures.append((seg.segment_id, reason)),
        is_session_active=lambda _sid, _gen: True,
    )

    try:
        for i in range(4):
            ok, reason = dispatcher.enqueue(_make_seg(f"seg-{i}", seq=i + 1))
            assert ok is True
            assert reason is None

        drained = await dispatcher.drain_session("s1", timeout_ms=1000)
        assert drained is True
        assert len(results) == 4
        assert failures == []
        assert dispatcher.metrics["completed"] == 4
    finally:
        await dispatcher.shutdown()


@pytest.mark.asyncio
async def test_dispatcher_drops_expired_and_rejects_stale_session():
    provider = MockEmotionProvider(simulated_latency_ms=30.0)
    dispatcher = BoundedEmotionDispatcher(
        provider_getter=lambda: provider,
        max_global_inflight=4,
        segment_deadline_ms=1000,
    )
    active_sessions = {"s1": "g1"}
    results: list[str] = []
    failures: list[tuple[str, str]] = []

    dispatcher.configure_callbacks(
        on_result=lambda _seg, pred: results.append(pred.segment_id),
        on_failure=lambda seg, reason: failures.append((seg.segment_id, reason)),
        is_session_active=lambda sid, gen: active_sessions.get(sid) == gen,
    )

    try:
        # Expired segment (created 5 seconds ago)
        dispatcher.enqueue(_make_seg("expired-1", created_offset_ms=-5000))
        # Valid segment whose session ends mid-flight
        dispatcher.enqueue(_make_seg("late-1", session_id="s1", gen="g1"))
        await asyncio.sleep(0.01)
        active_sessions.pop("s1", None)  # Session ended before HTTP completes

        await asyncio.sleep(0.08)
        assert "late-1" not in results
        assert ("expired-1", "dropped_deadline_exceeded") in failures
        assert dispatcher.metrics["discarded_stale_session"] >= 1
    finally:
        await dispatcher.shutdown()


@pytest.mark.asyncio
async def test_dispatcher_bounded_queue_overflow_and_fairness():
    provider = MockEmotionProvider(simulated_latency_ms=40.0)
    dispatcher = BoundedEmotionDispatcher(
        provider_getter=lambda: provider,
        max_global_inflight=2,
        per_session_max_inflight=1,
        max_queue_size=4,
        per_session_max_queue=2,
    )
    completed_sessions: list[str] = []
    dropped: list[str] = []

    dispatcher.configure_callbacks(
        on_result=lambda seg, _pred: completed_sessions.append(seg.session_id),
        on_failure=lambda _seg, reason: dropped.append(reason),
        is_session_active=lambda _sid, _gen: True,
    )

    try:
        # Noisy session s_noisy pushes 5 segments; fair session s_fair pushes 1 segment
        for i in range(5):
            dispatcher.enqueue(_make_seg(f"noisy-{i}", session_id="s_noisy", seq=i + 1))
        dispatcher.enqueue(_make_seg("fair-0", session_id="s_fair", seq=1))

        await asyncio.sleep(0.20)
        assert "s_fair" in completed_sessions
        assert "dropped_queue_full" in dropped
    finally:
        await dispatcher.shutdown()
