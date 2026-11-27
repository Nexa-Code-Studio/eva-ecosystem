"""Unit tests for ElevenLabs Scribe v2 Realtime STT provider, MockSTTProvider, and STTFactory."""

from __future__ import annotations

import asyncio
import base64
import json
from unittest.mock import patch

import pytest

from packages.ai.factories.stt_factory import STTFactory
from packages.ai.providers.stt.elevenlabs_stt import (
    ElevenLabsRealtimeSTTProvider,
    ElevenLabsRealtimeSTTSession,
)
from packages.ai.providers.stt.mock_stt import MockSTTProvider
from packages.shared.config import settings


class _FakeWebSocket:
    def __init__(self, incoming_messages: list[dict]) -> None:
        self.sent_frames: list[dict] = []
        self._incoming: asyncio.Queue[str | None] = asyncio.Queue()
        for msg in incoming_messages:
            self._incoming.put_nowait(json.dumps(msg))
        self.closed = False

    async def send(self, payload: str) -> None:
        self.sent_frames.append(json.loads(payload))

    async def recv(self) -> str:
        item = await self._incoming.get()
        if item is None:
            raise asyncio.CancelledError()
        return item

    async def close(self) -> None:
        self.closed = True
        self._incoming.put_nowait(None)


def test_stt_factory_key_resolution_and_dev_fallback(monkeypatch):
    STTFactory.reset()
    monkeypatch.setattr(settings, "APP_ENV", "development")
    monkeypatch.setattr(settings, "STT_PROVIDER", "elevenlabs")
    monkeypatch.setattr(settings, "ELEVENLABS_STT_API_KEY", "")
    monkeypatch.setattr(settings, "ELEVENLABS_API_KEYS", "your-tts-key-1")
    monkeypatch.setattr(settings, "TTS_API_KEY", "")

    fallback = STTFactory.get_provider(force_new=True)
    assert isinstance(fallback, MockSTTProvider)

    # Reuse ELEVENLABS_API_KEYS when ELEVENLABS_STT_API_KEY is empty
    monkeypatch.setattr(settings, "ELEVENLABS_API_KEYS", "el_shared_key_1,el_shared_key_2")
    shared_provider = STTFactory.get_provider(force_new=True)
    assert isinstance(shared_provider, ElevenLabsRealtimeSTTProvider)
    assert shared_provider.keys == ["el_shared_key_1", "el_shared_key_2"]

    # ELEVENLABS_STT_API_KEY overrides shared keys
    monkeypatch.setattr(settings, "ELEVENLABS_STT_API_KEY", "el_stt_override_key")
    override_provider = STTFactory.get_provider(force_new=True)
    assert isinstance(override_provider, ElevenLabsRealtimeSTTProvider)
    assert override_provider.keys == ["el_stt_override_key"]
    STTFactory.reset()


def test_stt_factory_production_fail_fast(monkeypatch):
    STTFactory.reset()
    monkeypatch.setattr(settings, "APP_ENV", "production")
    monkeypatch.setattr(settings, "STT_PROVIDER", "elevenlabs")
    monkeypatch.setattr(settings, "ELEVENLABS_STT_API_KEY", "")
    monkeypatch.setattr(settings, "ELEVENLABS_API_KEYS", "")
    monkeypatch.setattr(settings, "TTS_API_KEY", "")

    with pytest.raises(RuntimeError, match="No valid ElevenLabs API key"):
        STTFactory.get_provider(force_new=True)

    with pytest.raises(RuntimeError, match="prohibited in production"):
        STTFactory.get_provider("mock", force_new=True)
    STTFactory.reset()


@pytest.mark.asyncio
async def test_elevenlabs_realtime_session_protocol_and_events():
    ElevenLabsRealtimeSTTProvider.reset_key_state()
    fake_ws = _FakeWebSocket(
        incoming_messages=[
            {"message_type": "session_started", "session_id": "el_sess_123"},
            {"message_type": "partial_transcript", "text": "halo eva"},
            {"message_type": "committed_transcript", "text": "Halo Eva, aku capek."},
        ]
    )
    captured_connect: dict = {}

    async def _fake_connect(url: str, additional_headers: dict | None = None):
        captured_connect["url"] = url
        captured_connect["headers"] = additional_headers
        return fake_ws

    session = ElevenLabsRealtimeSTTSession(
        api_key="sk_test_123456",
        model_id="scribe_v2_realtime",
        sample_rate=16000,
        language_code="id",
        commit_strategy="vad",
        vad_silence_threshold_secs=0.8,
        vad_threshold=0.4,
    )

    with patch("packages.ai.providers.stt.elevenlabs_stt.websockets.connect", side_effect=_fake_connect):
        await session.connect()
        assert "model_id=scribe_v2_realtime" in captured_connect["url"]
        assert "audio_format=pcm_16000" in captured_connect["url"]
        assert "language_code=id" in captured_connect["url"]
        assert "commit_strategy=vad" in captured_connect["url"]
        assert captured_connect["headers"] == {"xi-api-key": "sk_test_123456"}

        pcm = b"\x01\x02\x03\x04" * 10
        await session.send_audio_chunk(pcm)
        await session.commit()

        assert len(fake_ws.sent_frames) == 2
        assert fake_ws.sent_frames[0]["message_type"] == "input_audio_chunk"
        assert fake_ws.sent_frames[0]["sample_rate"] == 16000
        assert fake_ws.sent_frames[0]["commit"] is False
        assert base64.b64decode(fake_ws.sent_frames[0]["audio_base_64"]) == pcm
        assert fake_ws.sent_frames[1]["commit"] is True
        assert fake_ws.sent_frames[1]["audio_base_64"] == ""

        received = []
        async for evt in session.receive_events():
            received.append(evt)
            if len(received) == 3:
                await session.close()
                break

        assert [e.kind for e in received] == ["session_started", "partial", "committed"]
        assert received[0].session_id == "el_sess_123"
        assert received[1].text == "halo eva"
        assert received[2].text == "Halo Eva, aku capek."
        assert fake_ws.closed is True


@pytest.mark.asyncio
async def test_elevenlabs_realtime_key_rotation_on_401():
    ElevenLabsRealtimeSTTProvider.reset_key_state()
    fake_ws = _FakeWebSocket(incoming_messages=[{"message_type": "session_started", "session_id": "el_rot_1"}])
    attempted_keys: list[str] = []

    async def _fake_connect(url: str, additional_headers: dict | None = None):
        key = (additional_headers or {}).get("xi-api-key", "")
        attempted_keys.append(key)
        if key == "sk_bad_key_1":
            raise RuntimeError("HTTP 401 Unauthorized")
        return fake_ws

    session = ElevenLabsRealtimeSTTSession(
        api_key="sk_bad_key_1",
        keys=["sk_bad_key_1", "sk_good_key_2"],
    )

    with patch("packages.ai.providers.stt.elevenlabs_stt.websockets.connect", side_effect=_fake_connect):
        await session.connect()
        assert attempted_keys == ["sk_bad_key_1", "sk_good_key_2"]
        assert session.api_key == "sk_good_key_2"
        await session.close()
    ElevenLabsRealtimeSTTProvider.reset_key_state()


@pytest.mark.asyncio
async def test_mock_stt_provider_deterministic_and_fault_injection():
    provider = MockSTTProvider(
        scripted_partials=["halo", "halo eva"],
        scripted_commits=["Halo Eva"],
        commit_every_n_chunks=2,
    )
    session = provider.create_realtime_session()
    await session.connect()
    await session.send_audio_chunk(b"\x00\x01" * 100)
    await session.send_audio_chunk(b"\x00\x02" * 100)
    await session.close()

    events = [evt async for evt in session.receive_events()]
    assert [e.kind for e in events] == ["session_started", "partial", "partial", "committed"]
    assert events[-1].text == "Halo Eva"

    fault_provider = MockSTTProvider(fail_after_chunks=1)
    fault_session = fault_provider.create_realtime_session()
    await fault_session.connect()
    await fault_session.send_audio_chunk(b"\x00\x01" * 100)
    await fault_session.close()
    fault_events = [evt async for evt in fault_session.receive_events()]
    assert any(e.kind == "error" for e in fault_events)
