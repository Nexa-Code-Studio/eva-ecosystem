"""Integration tests for full-WebSocket audio fan-out, ElevenLabs STT cost control, fault isolation, and privacy."""

from __future__ import annotations

import logging
import math
import sys
from array import array
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.routes.call import router as call_router
from app.services.call import call_session_manager
from app.services.call.audio_segmenter import CANONICAL_SAMPLE_RATE
from app.services.call.emotion_coordinator import CallEmotionCoordinator
from app.services.call.stt_coordinator import CallSTTCoordinator
from packages.ai.interfaces.llm import BaseLLMProvider, LLMMessage
from packages.ai.providers.emotion.mock_emotion import MockEmotionProvider
from packages.ai.providers.stt.mock_stt import MockSTTProvider
from packages.ai.providers.tts.mock_tts import MockTTSProvider
from packages.shared.config import settings


class _FastMockLLM(BaseLLMProvider):
    async def generate_response(self, messages: list[LLMMessage], **kwargs) -> str:
        return "Aku di sini mendengarkanmu."

    async def stream_response(self, messages: list[LLMMessage], **kwargs):
        for tok in ["Aku", " di", " sini", " mendengarkanmu."]:
            yield tok


def _speech_pcm(duration_s: float) -> bytes:
    n = int(duration_s * CANONICAL_SAMPLE_RATE)
    arr = array(
        "h",
        (int(9000 * math.sin(2.0 * math.pi * 240.0 * (i / CANONICAL_SAMPLE_RATE))) for i in range(n)),
    )
    if sys.byteorder != "little":
        arr.byteswap()
    return arr.tobytes()


def _build_ws_client() -> TestClient:
    ws_app = FastAPI()
    ws_app.include_router(call_router, prefix="/api/v1")
    return TestClient(ws_app)


def test_parallel_fanout_and_half_duplex_cost_control(monkeypatch):
    """Binary PCM fans out to STT + Emotion concurrently; STT closes on AI thinking & mute, reopens on listening."""
    stt_provider = MockSTTProvider(
        scripted_partials=["halo eva", "halo eva aku lagi capek"],
        scripted_commits=["Halo Eva, aku lagi capek."],
        commit_every_n_chunks=2,
    )
    emotion_provider = MockEmotionProvider(simulated_latency_ms=5.0)
    stt_coord = CallSTTCoordinator(provider_getter=lambda: stt_provider)
    emo_coord = CallEmotionCoordinator(provider_getter=lambda: emotion_provider)

    monkeypatch.setattr(settings, "EMOTION_STREAMING_ENABLED", True)
    monkeypatch.setattr(call_session_manager, "stt_coordinator", stt_coord)
    monkeypatch.setattr(call_session_manager, "emotion_coordinator", emo_coord)
    monkeypatch.setattr(call_session_manager.orchestrator, "llm_provider", _FastMockLLM())

    client = _build_ws_client()
    with (
        patch("app.services.call.persistence.AsyncSessionLocal") as mock_db,
        patch("app.services.call.session_manager.TTSFactory.get_provider", return_value=MockTTSProvider()),
    ):
        with client.websocket_connect("/api/v1/call/ws/fanout_sess_1?privacy_mode=local_private") as ws:
            assert ws.receive_json()["type"] == "call_connected"

            ws.send_json({"type": "start_call"})
            assert ws.receive_json()["type"] == "call_started"
            # Lazy open: no STT session opened until PCM arrives
            assert len(stt_provider.sessions) == 0

            # Stream 2 PCM chunks (3s total -> triggers both STT committed & 1 emotion segment)
            ws.send_bytes(_speech_pcm(1.5))
            ws.send_bytes(_speech_pcm(1.5))

            seen_events: list[dict] = []
            for _ in range(10):
                evt = ws.receive_json()
                seen_events.append(evt)
                if evt.get("type") == "stt.final_segment":
                    break

            event_types = [e["type"] for e in seen_events]
            assert "stt.partial" in event_types
            assert "stt.final_segment" in event_types
            assert len(stt_provider.sessions) == 1
            first_stt_session = stt_provider.sessions[0]
            assert first_stt_session.connected is True

            # Force commit -> transitions to ai_thinking and MUST close upstream ElevenLabs STT session
            ws.send_json({"type": "user.force_commit", "call_id": "fanout_sess_1", "user_turn_id": 1})

            ai_events: list[str] = []
            for _ in range(15):
                evt = ws.receive_json()
                ai_events.append(evt.get("type", ""))
                if evt.get("type") == "voice_session_summary":
                    break

            assert "turn.committed" in ai_events
            assert "ai.thinking" in ai_events
            assert first_stt_session.closed is True

            # PCM arriving during ai_speaking MUST NOT reopen STT session
            ws.send_bytes(_speech_pcm(0.5))
            assert len(stt_provider.sessions) == 1

            # playback.finished returns to listening; next PCM lazily opens session #2
            ws.send_json({"type": "playback.finished", "call_id": "fanout_sess_1", "assistant_turn_id": 1})
            sync_evt = ws.receive_json()
            while sync_evt.get("type") != "call.sync_state":
                sync_evt = ws.receive_json()
            assert sync_evt["state"] == "listening"

            ws.send_bytes(_speech_pcm(0.5))
            evt_after_resume = ws.receive_json()
            assert evt_after_resume["type"] in ("stt.status", "stt.partial", "emotion_result")
            assert len(stt_provider.sessions) == 2
            second_stt_session = stt_provider.sessions[1]

            # Mute boundary MUST immediately close active STT session
            ws.send_json({"type": "audio.boundary", "call_id": "fanout_sess_1", "reason": "mute"})
            ws.send_json({"type": "ping"})
            pong = ws.receive_json()
            while pong.get("type") != "pong":
                pong = ws.receive_json()
            assert second_stt_session.closed is True

            # PCM while muted must be dropped (no 3rd STT session opened)
            ws.send_bytes(_speech_pcm(0.5))
            assert len(stt_provider.sessions) == 2

            # Unmute + PCM opens session #3
            ws.send_json({"type": "audio.boundary", "call_id": "fanout_sess_1", "reason": "unmute"})
            ws.send_bytes(_speech_pcm(0.5))
            ws.send_json({"type": "ping"})
            pong2 = ws.receive_json()
            while pong2.get("type") != "pong":
                pong2 = ws.receive_json()
            assert len(stt_provider.sessions) == 3

            ws.send_json({"type": "end_call", "duration_seconds": 6})

        assert stt_provider.sessions[-1].closed is True
        assert len(emotion_provider.calls) >= 1
        # Zero durable DB persistence in local_private mode
        mock_db.assert_not_called()


def test_emotion_failure_never_blocks_stt_and_barge_in_reopens_stt(monkeypatch):
    """Failing emotion service must be completely isolated from live STT and barge-in."""
    stt_provider = MockSTTProvider(
        scripted_partials=["tolong bantu aku"],
        scripted_commits=["Tolong bantu aku sekarang."],
        commit_every_n_chunks=1,
    )
    failing_emotion = MockEmotionProvider(
        simulated_latency_ms=10.0,
        fail_with=RuntimeError("emotion_service 503 unavailable"),
    )
    stt_coord = CallSTTCoordinator(provider_getter=lambda: stt_provider)
    emo_coord = CallEmotionCoordinator(provider_getter=lambda: failing_emotion)

    monkeypatch.setattr(settings, "EMOTION_STREAMING_ENABLED", True)
    monkeypatch.setattr(call_session_manager, "stt_coordinator", stt_coord)
    monkeypatch.setattr(call_session_manager, "emotion_coordinator", emo_coord)
    monkeypatch.setattr(call_session_manager.orchestrator, "llm_provider", _FastMockLLM())

    client = _build_ws_client()
    with patch("app.services.call.session_manager.TTSFactory.get_provider", return_value=MockTTSProvider()):
        with client.websocket_connect("/api/v1/call/ws/fault_iso_sess?privacy_mode=local_private") as ws:
            assert ws.receive_json()["type"] == "call_connected"
            ws.send_json({"type": "start_call"})
            assert ws.receive_json()["type"] == "call_started"

            # Send 3s PCM -> emotion fails, STT must still emit partial + final_segment cleanly
            ws.send_bytes(_speech_pcm(3.0))
            got_final = False
            for _ in range(8):
                evt = ws.receive_json()
                if evt.get("type") == "stt.final_segment":
                    assert evt["text"] == "Tolong bantu aku sekarang."
                    got_final = True
                    break
            assert got_final is True

            # Trigger barge-in -> state returns to listening and next PCM opens new STT session
            ws.send_json({"type": "assistant.interrupt", "call_id": "fault_iso_sess", "assistant_turn_id": 1})
            ack = ws.receive_json()
            while ack.get("type") != "interrupted_ack":
                ack = ws.receive_json()

            ws.send_bytes(_speech_pcm(0.5))
            ws.send_json({"type": "ping"})
            p = ws.receive_json()
            while p.get("type") != "pong":
                p = ws.receive_json()
            assert len(stt_provider.sessions) >= 1

            ws.send_json({"type": "end_call", "duration_seconds": 3})


def test_incognito_fails_closed_for_both_stt_and_emotion(monkeypatch):
    """Incognito mode blocks outbound cloud audio for both ElevenLabs STT and emotion_service."""
    stt_provider = MockSTTProvider()
    emotion_provider = MockEmotionProvider()
    stt_coord = CallSTTCoordinator(provider_getter=lambda: stt_provider)
    emo_coord = CallEmotionCoordinator(provider_getter=lambda: emotion_provider)

    monkeypatch.setattr(settings, "EMOTION_STREAMING_ENABLED", True)
    monkeypatch.setattr(settings, "STT_ALLOW_INCOGNITO_CLOUD_AUDIO", False)
    monkeypatch.setattr(settings, "EMOTION_ALLOW_INCOGNITO_CLOUD_AUDIO", False)
    monkeypatch.setattr(call_session_manager, "stt_coordinator", stt_coord)
    monkeypatch.setattr(call_session_manager, "emotion_coordinator", emo_coord)

    client = _build_ws_client()
    with client.websocket_connect("/api/v1/call/ws/incog_sess?privacy_mode=incognito") as ws:
        assert ws.receive_json()["type"] == "call_connected"
        ws.send_json({"type": "start_call"})
        assert ws.receive_json()["type"] == "call_started"

        ws.send_bytes(_speech_pcm(3.0))
        ws.send_json({"type": "ping"})
        seen: list[dict] = []
        for _ in range(5):
            evt = ws.receive_json()
            seen.append(evt)
            if evt.get("type") == "pong":
                break

        assert stt_provider.sessions == []
        assert emotion_provider.calls == []
        assert any(e.get("type") == "stt.status" and e.get("status") == "incognito_blocked" for e in seen)
        ws.send_json({"type": "end_call", "duration_seconds": 2})


def test_production_logs_contain_zero_raw_transcript(monkeypatch, caplog):
    """Under APP_ENV=production, raw user transcripts must never be written to logs."""
    secret_phrase = "RAHASIA_TRANSKRIP_PENGGUNA_99123"
    stt_provider = MockSTTProvider(
        scripted_partials=[secret_phrase],
        scripted_commits=[secret_phrase],
        commit_every_n_chunks=1,
    )
    stt_coord = CallSTTCoordinator(provider_getter=lambda: stt_provider)

    monkeypatch.setattr(settings, "APP_ENV", "production")
    monkeypatch.setattr(settings, "EMOTION_STREAMING_ENABLED", False)
    monkeypatch.setattr(call_session_manager, "stt_coordinator", stt_coord)
    monkeypatch.setattr(call_session_manager.orchestrator, "llm_provider", _FastMockLLM())

    client = _build_ws_client()
    with (
        caplog.at_level(logging.DEBUG),
        patch("app.services.call.session_manager.TTSFactory.get_provider", return_value=MockTTSProvider()),
    ):
        with client.websocket_connect("/api/v1/call/ws/prod_log_sess?privacy_mode=local_private") as ws:
            assert ws.receive_json()["type"] == "call_connected"
            ws.send_json({"type": "start_call"})
            assert ws.receive_json()["type"] == "call_started"

            ws.send_bytes(_speech_pcm(0.5))
            ws.send_json({"type": "user.force_commit", "call_id": "prod_log_sess", "user_turn_id": 1})
            for _ in range(15):
                evt = ws.receive_json()
                if evt.get("type") == "voice_session_summary":
                    break
            ws.send_json({"type": "end_call", "duration_seconds": 2})

    assert secret_phrase not in caplog.text
