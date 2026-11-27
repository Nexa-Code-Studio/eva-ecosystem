import json
from unittest.mock import AsyncMock, patch
import uuid

import pytest
from app.main import app
from app.services.call import AudioStreamBufferService, call_session_manager
from app.services.call.billing_service import AuthenticatedCallUser, CallChargeResult
from fastapi.testclient import TestClient
from packages.ai.providers.llm.mock_llm import MockLLMProvider
from packages.ai.providers.stt.mock_stt import MockSTTProvider
from packages.ai.providers.tts.mock_tts import MockTTSProvider

client = TestClient(app)


@pytest.mark.asyncio
async def test_audio_stream_buffer_collects_chunks():
    service = AudioStreamBufferService()
    chunk = b"\x00\x01\x02\x03\x04"
    result = await service.handle_incoming_audio_chunk("sess_1", chunk)
    assert result["status"] == "audio_received"
    assert result["bytes_len"] == 5
    assert "emotion_detected" not in result

    buf = service.get_or_create_buffer("sess_1")
    assert buf.total_bytes == 5
    assert buf.get_full_audio() == chunk


def test_call_websocket_lifecycle(monkeypatch):
    mock_user = AuthenticatedCallUser(
        user_id=uuid.uuid4(),
        display_name="Test User",
        coin_balance=10,
    )
    mock_charge = CallChargeResult(
        success=True,
        coin_balance=9,
        coins_debited=1,
        minute_index=1,
        invoice_code="EVA-CALL-TEST-001",
    )
    monkeypatch.setattr(call_session_manager.orchestrator, "llm_provider", MockLLMProvider())
    monkeypatch.setattr(call_session_manager.stt_coordinator, "_provider_getter", lambda: MockSTTProvider())
    with (
        patch("app.services.call.session_manager.TTSFactory.get_provider", return_value=MockTTSProvider()),
        patch("app.services.call.session_manager.CallBillingService.resolve_authenticated_user", new=AsyncMock(return_value=mock_user)),
        patch("app.services.call.session_manager.CallBillingService.charge_call_minute", new=AsyncMock(return_value=mock_charge)),
        patch("app.services.call.session_manager.CallBillingService.get_user_coin_balance", new=AsyncMock(return_value=9)),
        client.websocket_connect("/api/v1/call/ws/test_session_999?token=test_token") as websocket,
    ):
        # 1. Server sends call_connected event
        connected_data = websocket.receive_json()
        assert connected_data["type"] == "call_connected"
        assert connected_data["session_id"] == "test_session_999"

        # 2. Client sends start_call
        websocket.send_json({"type": "start_call"})
        started_data = websocket.receive_json()
        assert started_data["type"] == "call_started"

        # 3. Client sends binary audio stream
        websocket.send_bytes(b"\x11\x22\x33\x44\x55")

        # 4. Client sends ping (drain any async stt.* events triggered by audio frame)
        websocket.send_json({"type": "ping"})
        pong_data = websocket.receive_json()
        for _ in range(5):
            if pong_data.get("type") == "pong":
                break
            pong_data = websocket.receive_json()
        assert pong_data["type"] == "pong"

        # 5. Client sends user_transcript (uses Mock LLM / Ollama fallback in test)
        websocket.send_json({"type": "user_transcript", "text": "Halo Eva, selamat pagi!"})
        thinking_data = None
        for _ in range(8):
            evt = websocket.receive_json()
            if evt.get("type") in ("ai_thinking", "ai.thinking"):
                thinking_data = evt
                break
        assert thinking_data is not None
        assert thinking_data["type"] in ("ai_thinking", "ai.thinking")

        # 6. Receive AI transcript / binary TTS audio or finished signal
        received_types = []
        for _ in range(5):
            try:
                msg = websocket.receive()
                if "bytes" in msg and msg["bytes"]:
                    received_types.append("binary_audio")
                elif "text" in msg and msg["text"]:
                    data = json.loads(msg["text"])
                    received_types.append(data.get("type"))
                    if data.get("type") in ("ai.speech_finished", "ai_speech_finished"):
                        break
            except Exception:
                break

        # 7. Client sends end_call
        websocket.send_json({"type": "end_call"})


def test_call_websocket_authenticated_mobile_flow():
    """Validates mobile WebSocket connection with JWT token and voice_mode query params."""
    with TestClient(app) as local_client:
        login_res = local_client.post(
            "/api/v1/auth/login",
            json={"email": "samsul@gmail.com", "password": "password123"},
        )
        assert login_res.status_code == 200
        token = login_res.json()["access_token"]

        mock_charge = CallChargeResult(
            success=True,
            coin_balance=9,
            coins_debited=1,
            minute_index=1,
            invoice_code="EVA-CALL-TEST-002",
        )
        with (
            patch("app.services.call.session_manager.CallBillingService.charge_call_minute", new=AsyncMock(return_value=mock_charge)),
            patch("app.services.call.session_manager.CallBillingService.get_user_coin_balance", new=AsyncMock(return_value=9)),
            local_client.websocket_connect(
                f"/api/v1/call/ws/test_mobile_auth_session?token={token}&voice_mode=supportive"
            ) as websocket,
        ):
            connected = websocket.receive_json()
            assert connected["type"] == "call_connected"
            assert connected["session_id"] == "test_mobile_auth_session"

            websocket.send_json({"type": "start_call", "voice_mode": "supportive"})
            started = websocket.receive_json()
            assert started["type"] == "call_started"
            assert started["billing"]["current_minute"] == 1

            websocket.send_json({"type": "ping"})
            pong = websocket.receive_json()
            assert pong["type"] == "pong"

            websocket.send_json({"type": "end_call"})
