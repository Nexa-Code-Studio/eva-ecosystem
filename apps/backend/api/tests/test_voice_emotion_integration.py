"""Integration & privacy tests for non-blocking voice emotion orchestration (#143 & #96)."""

from __future__ import annotations

import math
import sys
import time
from array import array
from types import SimpleNamespace
from unittest.mock import patch

import pytest
from app.services.call.audio_segmenter import CANONICAL_SAMPLE_RATE
from app.services.call.emotion_coordinator import CallEmotionCoordinator
from app.services.call.persistence import CallPersistenceService

from packages.ai.interfaces.llm import BaseLLMProvider, LLMMessage
from packages.ai.orchestration.orchestrator import AIOrchestrator
from packages.ai.providers.emotion.mock_emotion import MockEmotionProvider
from packages.ai.providers.tts.mock_tts import MockTTSProvider
from packages.ai.utils.emotion_style_mapper import resolve_dynamic_voice_style
from shared.domain_types import (
    EmotionSource,
    EmotionWindowStatus,
    ResponseMode,
)


class _FastMockLLM(BaseLLMProvider):
    async def generate_response(self, messages: list[LLMMessage], **kwargs) -> str:
        return "Aku mendengarkan ceritamu."

    async def stream_response(self, messages: list[LLMMessage], **kwargs):
        for tok in ["Aku", " mendengarkan", " ceritamu."]:
            yield tok


def _speech_pcm(duration_s: float) -> bytes:
    n = int(duration_s * CANONICAL_SAMPLE_RATE)
    arr = array("h", (int(9000 * math.sin(2.0 * math.pi * 240.0 * (i / CANONICAL_SAMPLE_RATE))) for i in range(n)))
    if sys.byteorder != "little":
        arr.byteswap()
    return arr.tobytes()


@pytest.mark.asyncio
async def test_slow_or_failing_emotion_provider_never_blocks_turn_or_crisis_safety():
    # Provider takes 1.5s and fails — turn commit & orchestrator must still finish in < 100ms
    slow_failing = MockEmotionProvider(
        simulated_latency_ms=1500.0,
        fail_with=RuntimeError("Cloud Run 503"),
    )
    coordinator = CallEmotionCoordinator(provider_getter=lambda: slow_failing)
    coordinator.register_session("sess-slow", privacy_mode="local_private")

    try:
        t0 = time.perf_counter()
        enqueued = coordinator.ingest_pcm_chunk("sess-slow", _speech_pcm(3.0), user_turn_id=1)
        assert enqueued == 1

        # Immediately take snapshot (non-blocking) while HTTP is still in-flight
        snap = coordinator.get_snapshot("sess-slow", current_turn_id=1)
        elapsed_ms = (time.perf_counter() - t0) * 1000.0
        assert elapsed_ms < 200.0
        assert snap.status == EmotionWindowStatus.UNAVAILABLE
        assert snap.scores is None

        orchestrator = AIOrchestrator(llm_provider=_FastMockLLM())
        # Verify crisis safety gate is 100% independent of unavailable acoustic emotion
        crisis_turn = await orchestrator.prepare_turn(
            user_text="Aku sudah tidak sanggup lagi, aku mau bunuh diri malam ini.",
            temporal_emotion=snap,
            allow_sync_audio_fallback=False,
        )
        assert crisis_turn.is_crisis is True
        assert crisis_turn.safety_decision.mode == ResponseMode.CRISIS

        # Verify normal turn runs text-only without fabricated acoustic assertion
        normal_turn = await orchestrator.prepare_turn(
            user_text="Hari ini kerjaan cukup padat.",
            temporal_emotion=snap,
            allow_sync_audio_fallback=False,
        )
        assert normal_turn.is_crisis is False
        assert normal_turn.emotion.source == EmotionSource.UNAVAILABLE
        assert "belum tersedia" in normal_turn.final_system_prompt.lower()
    finally:
        await coordinator.shutdown()


@pytest.mark.asyncio
async def test_incognito_mode_fails_closed_for_cloud_audio():
    provider = MockEmotionProvider(simulated_latency_ms=1.0)
    coordinator = CallEmotionCoordinator(provider_getter=lambda: provider)
    coordinator.register_session("sess-incog", privacy_mode="incognito")

    try:
        enqueued = coordinator.ingest_pcm_chunk("sess-incog", _speech_pcm(6.0), user_turn_id=1)
        assert enqueued == 0
        assert provider.calls == []

        snap = coordinator.get_snapshot("sess-incog")
        assert snap.status == EmotionWindowStatus.UNAVAILABLE
        assert "incognito_audio_disabled" in snap.degradation_reasons
    finally:
        await coordinator.shutdown()


@pytest.mark.asyncio
async def test_private_modes_perform_zero_db_persistence():
    for mode in ("local_private", "incognito"):
        fake_session = SimpleNamespace(
            session_id=f"sess-{mode}",
            privacy_mode=mode,
            is_history_loaded=False,
            db_conversation_id="fake-conv-id",
            user_id="fake-user-id",
            auth_token="fake-token",
            conversation_history=[LLMMessage(role="user", content="Aku sedang sedih")],
        )
        with patch("app.services.call.persistence.AsyncSessionLocal") as mock_db:
            await CallPersistenceService.load_conversation_history(fake_session)
            await CallPersistenceService.save_message(fake_session, "user", "Aku sedang sedih")
            await CallPersistenceService.sync_today_diary(fake_session)
            await CallPersistenceService.sync_today_dass(fake_session)
            mock_db.assert_not_called()


def test_tts_dynamic_voice_guard_prevents_weak_single_label_override():
    # Single partial temporal segment should NOT override baseline TTS voice style
    res_weak = resolve_dynamic_voice_style(
        mode_id="supportive",
        detected_emotion="sad",
        confidence=0.80,
        intensity=0.80,
        risk_level="low",
        emotion_status="partial",
        emotion_source="audio_temporal",
        segment_count=1,
    )
    assert res_weak.is_emotion_override is False

    # Ready temporal window DOES allow empathetic override
    res_ready = resolve_dynamic_voice_style(
        mode_id="supportive",
        detected_emotion="sad",
        confidence=0.80,
        intensity=0.80,
        risk_level="low",
        emotion_status="ready",
        emotion_source="audio_temporal",
        segment_count=10,
    )
    assert res_ready.is_emotion_override is True
    assert res_ready.delivery_style == "soft"

    # High/critical risk ALWAYS enforces grounding regardless of unavailable emotion
    res_crisis = resolve_dynamic_voice_style(
        mode_id="supportive",
        detected_emotion="unknown",
        confidence=0.0,
        intensity=0.0,
        risk_level="critical",
        emotion_status="unavailable",
        emotion_source="unavailable",
        segment_count=0,
    )
    assert res_crisis.delivery_style == "grounding"


def test_call_websocket_streaming_non_blocking_end_to_end(monkeypatch):
    """End-to-end WS test on /api/v1/call/ws/{session_id} with EMOTION_STREAMING_ENABLED=True."""
    from fastapi import FastAPI
    from fastapi.testclient import TestClient

    from app.api.routes.call import router as call_router
    from app.services.call import call_session_manager
    from packages.shared.config import settings

    provider = MockEmotionProvider(simulated_latency_ms=5.0)
    coordinator = CallEmotionCoordinator(provider_getter=lambda: provider)

    monkeypatch.setattr(settings, "EMOTION_STREAMING_ENABLED", True)
    monkeypatch.setattr(call_session_manager, "emotion_coordinator", coordinator)
    monkeypatch.setattr(call_session_manager.orchestrator, "llm_provider", _FastMockLLM())

    ws_app = FastAPI()
    ws_app.include_router(call_router, prefix="/api/v1")
    test_client = TestClient(ws_app)

    with (
        patch("app.services.call.persistence.AsyncSessionLocal") as mock_db,
        patch("app.services.call.session_manager.TTSFactory.get_provider", return_value=MockTTSProvider()),
    ):
        with test_client.websocket_connect(
            "/api/v1/call/ws/e2e_stream_sess?privacy_mode=local_private"
        ) as ws:
            connected = ws.receive_json()
            assert connected["type"] == "call_connected"
            assert connected["privacy_mode_active"] == "local_private"

            ws.send_json({"type": "start_call"})
            assert ws.receive_json()["type"] == "call_started"

            # Stream 3 seconds of active speech PCM16 (96,000 bytes)
            ws.send_bytes(_speech_pcm(3.0))
            # Send client mute boundary hint
            ws.send_json({"type": "audio.boundary", "call_id": "e2e_stream_sess", "reason": "mute"})
            # Commit turn without waiting for emotion inference
            ws.send_json({"type": "user_transcript", "text": "Hari ini aku agak lelah tapi masih semangat."})

            seen_types: list[str] = []
            summary_evt = None
            for _ in range(15):
                evt = ws.receive_json()
                seen_types.append(evt.get("type", ""))
                if evt.get("type") == "voice_session_summary":
                    summary_evt = evt
                    break

            assert "turn.committed" in seen_types
            assert "ai.thinking" in seen_types
            assert summary_evt is not None
            assert summary_evt["emotion_analysis"]["status"] in ("partial", "ready", "unavailable")
            ws.send_json({"type": "end_call", "duration_seconds": 5})

        # Zero durable DB persistence in local_private mode
        mock_db.assert_not_called()
        # Session state purged on disconnect
        assert "e2e_stream_sess" not in coordinator._sessions


def test_call_websocket_chunked_4800b_fanout_and_emotion_failure_isolation(monkeypatch):
    """Verify 4800-byte 150ms PCM fan-out frames + stt.partial/final_segment + audio.boundary
    never stall or fail conversation even when emotion_service raises an error."""
    from app.api.routes.call import router as call_router
    from app.services.call import call_session_manager
    from fastapi import FastAPI
    from fastapi.testclient import TestClient

    from packages.shared.config import settings

    failing_provider = MockEmotionProvider(
        simulated_latency_ms=1.0,
        fail_with=RuntimeError("Simulated emotion_service 503 outage"),
    )
    coordinator = CallEmotionCoordinator(provider_getter=lambda: failing_provider)

    monkeypatch.setattr(settings, "EMOTION_STREAMING_ENABLED", True)
    monkeypatch.setattr(call_session_manager, "emotion_coordinator", coordinator)
    monkeypatch.setattr(call_session_manager.orchestrator, "llm_provider", _FastMockLLM())

    ws_app = FastAPI()
    ws_app.include_router(call_router, prefix="/api/v1")
    test_client = TestClient(ws_app)

    with (
        patch("app.services.call.persistence.AsyncSessionLocal") as mock_db,
        patch(
            "app.services.call.session_manager.TTSFactory.get_provider",
            return_value=MockTTSProvider(),
        ),
    ):
        with test_client.websocket_connect(
            "/api/v1/call/ws/e2e_isolation_sess?privacy_mode=local_private"
        ) as ws:
            assert ws.receive_json()["type"] == "call_connected"
            ws.send_json({"type": "start_call"})
            assert ws.receive_json()["type"] == "call_started"

            # Stream 20 frames * 4800B = 96,000B (3.0s) matching Android AudioCaptureEngine
            full_pcm = _speech_pcm(3.0)
            for offset in range(0, len(full_pcm), 4800):
                ws.send_bytes(full_pcm[offset : offset + 4800])

            # Interleave native STT partial + final_segment + audio.boundary(turn_thinking)
            ws.send_json({
                "type": "stt.partial",
                "call_id": "e2e_isolation_sess",
                "user_turn_id": 1,
                "stt_session_id": 1,
                "sequence": 1,
                "text": "aku lagi merasa",
            })
            ws.send_json({
                "type": "stt.final_segment",
                "call_id": "e2e_isolation_sess",
                "user_turn_id": 1,
                "stt_session_id": 1,
                "sequence": 2,
                "text": "aku lagi merasa cukup cemas hari ini.",
            })
            ws.send_json({
                "type": "audio.boundary",
                "call_id": "e2e_isolation_sess",
                "reason": "turn_thinking",
            })
            ws.send_json({
                "type": "user.force_commit",
                "call_id": "e2e_isolation_sess",
                "user_turn_id": 1,
            })

            seen_types: list[str] = []
            emotion_evt = None
            for _ in range(60):
                evt = ws.receive_json()
                seen_types.append(evt.get("type", ""))
                if evt.get("type") == "emotion_result":
                    emotion_evt = evt
                if evt.get("type") == "voice_session_summary":
                    break

            assert "turn.committed" in seen_types
            assert "ai.thinking" in seen_types
            assert emotion_evt is not None
            # Failure isolation: degraded emotion reports truthful unavailable without breaking call
            assert emotion_evt["status"] == "unavailable"
            ws.send_json({"type": "end_call", "duration_seconds": 4})

        mock_db.assert_not_called()
        assert "e2e_isolation_sess" not in coordinator._sessions

