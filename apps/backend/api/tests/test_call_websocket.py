import json
import pytest
from app.main import app
from app.services.call import AudioStreamBufferService, analyze_audio_placeholder
from fastapi.testclient import TestClient

client = TestClient(app)


@pytest.mark.asyncio
async def test_audio_stream_buffer_placeholder():
    service = AudioStreamBufferService()
    chunk = b"\x00\x01\x02\x03\x04"
    result = await service.handle_incoming_audio_chunk("sess_1", chunk)
    assert result["status"] == "audio_received"
    assert result["bytes_len"] == 5

    buf = service.get_or_create_buffer("sess_1")
    assert buf.total_bytes == 5
    assert buf.get_full_audio() == chunk


def test_call_websocket_lifecycle():
    with client.websocket_connect("/api/v1/call/ws/test_session_999") as websocket:
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

        # 4. Client sends ping
        websocket.send_json({"type": "ping"})
        pong_data = websocket.receive_json()
        assert pong_data["type"] == "pong"

        # 5. Client sends user_transcript (uses Mock LLM / Ollama fallback in test)
        websocket.send_json({"type": "user_transcript", "text": "Halo Eva, selamat pagi!"})
        first_evt = websocket.receive_json()
        if first_evt["type"] == "turn.committed":
            thinking_data = websocket.receive_json()
        else:
            thinking_data = first_evt
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
    login_res = client.post("/api/v1/auth/login", json={"email": "samsul@gmail.com", "password": "password123"})
    assert login_res.status_code == 200
    token = login_res.json()["access_token"]

    with client.websocket_connect(f"/api/v1/call/ws/test_mobile_auth_session?token={token}&voice_mode=supportive") as websocket:
        connected = websocket.receive_json()
        assert connected["type"] == "call_connected"
        assert connected["session_id"] == "test_mobile_auth_session"

        websocket.send_json({"type": "start_call", "voice_mode": "supportive"})
        started = websocket.receive_json()
        assert started["type"] == "call_started"

        websocket.send_json({"type": "ping"})
        pong = websocket.receive_json()
        assert pong["type"] == "pong"

        websocket.send_json({"type": "end_call"})


def test_call_websocket_client_context_and_artifacts_flow():
    """Validates Luna Selective LTM protocol: client_context_v1, context_ack_v1, finalize, and artifacts."""
    with client.websocket_connect("/api/v1/call/ws/test_ltm_flow_session?privacy_mode=local_private") as ws:
        connected = ws.receive_json()
        assert connected["type"] == "call_connected"
        assert connected["protocol_version"] == 1
        assert connected["privacy_mode_active"] == "local_private"
        assert connected["context_supported"] is True

        # Send client_context_v1
        context_payload = {
            "type": "client_context_v1",
            "protocol_version": 1,
            "client_session_id": "test_ltm_flow_session",
            "context_request_id": "req-12345",
            "items": [
                {
                    "id": "mem-01",
                    "category": "coping_strategy",
                    "text": "Jalan santai di taman membantu meredakan rasa cemas",
                    "status": "active",
                },
                {
                    "id": "mem-02",
                    "category": "interaction_preference",
                    "text": "Dengarkan terlebih dahulu sebelum beri saran praktis",
                    "status": "active",
                },
                {
                    "id": "mem-03",
                    "category": "invalid_category_xyz",
                    "text": "Item dengan kategori invalid",
                    "status": "active",
                },
            ],
        }
        ws.send_json(context_payload)
        ack = ws.receive_json()
        assert ack["type"] == "context_ack_v1"
        assert ack["context_request_id"] == "req-12345"
        assert ack["accepted_count"] == 2
        assert ack["rejected_count"] == 1
        assert len(ack["rejection_reasons"]) == 1

        # Request session finalization artifacts
        ws.send_json({
            "type": "session_finalize_v1",
            "client_session_id": "test_ltm_flow_session",
            "request_id": "fin-9988",
            "duration_seconds": 120,
            "request_memory_candidates": True,
        })
        artifacts = ws.receive_json()
        assert artifacts["type"] == "session_artifacts_v1"
        assert artifacts["request_id"] == "fin-9988"
        assert "session_summary" in artifacts
        assert "journal_delta" in artifacts
        assert "memory_candidates" in artifacts
        assert "title" in artifacts["journal_delta"]

        # Send session artifacts ACK
        ws.send_json({
            "type": "session_artifacts_ack_v1",
            "request_id": "fin-9988",
            "status": "committed_locally",
        })
        finalized = ws.receive_json()
        assert finalized["type"] == "session_finalized_v1"
        assert finalized["request_id"] == "fin-9988"
        assert finalized["status"] == "closed"


def test_call_websocket_incognito_mode():
    """Validates that Incognito mode rejects all client context items and persists no state."""
    with client.websocket_connect("/api/v1/call/ws/test_incognito_session?privacy_mode=incognito") as ws:
        connected = ws.receive_json()
        assert connected["type"] == "call_connected"
        assert connected["privacy_mode_active"] == "incognito"

        ws.send_json({
            "type": "client_context_v1",
            "context_request_id": "req-incog-1",
            "items": [
                {
                    "id": "mem-01",
                    "category": "coping_strategy",
                    "text": "Latihan napas",
                }
            ],
        })
        ack = ws.receive_json()
        assert ack["type"] == "context_ack_v1"
        assert ack["accepted_count"] == 0
        assert ack["rejected_count"] == 1
        assert "incognito_mode_active" in ack["rejection_reasons"]
