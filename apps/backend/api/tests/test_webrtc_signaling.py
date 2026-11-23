import asyncio
from collections import defaultdict
import logging
from types import SimpleNamespace
from typing import Any
import uuid

from fastapi.testclient import TestClient
import httpx
import pytest

import app.api.dependencies as api_dependencies
from app.api.dependencies import (
    get_webrtc_signaling_manager,
    shutdown_webrtc_signaling_manager,
)
from app.core.security import create_access_token, create_room_token
from app.main import app
from app.services.care.care_service import CareService
from app.services.care.ice_provider import DEFAULT_STUN_URLS, IceServerProvider
from app.services.care.signaling_manager import (
    MAX_SIGNALING_MESSAGE_BYTES,
    WebRtcSignalingManager,
)
from shared.config import BaseConfig, normalize_ws_base_url, settings


class InMemoryRedisPubSub:
    """Async Pub/Sub subscriber bound to an InMemoryRedisBroker."""

    def __init__(self, broker: "InMemoryRedisBroker") -> None:
        self._broker = broker
        self._channels: set[str] = set()
        self._queue: asyncio.Queue[dict[str, Any] | None] = asyncio.Queue()
        self._closed = False

    async def subscribe(self, *channels: str) -> None:
        for ch in channels:
            self._channels.add(ch)
            self._broker.subscribers[ch].add(self._queue)

    async def unsubscribe(self, *channels: str) -> None:
        targets = list(channels) if channels else list(self._channels)
        for ch in targets:
            self._channels.discard(ch)
            self._broker.subscribers[ch].discard(self._queue)

    async def listen(self):
        while not self._closed:
            item = await self._queue.get()
            if item is None:
                break
            yield item

    async def aclose(self) -> None:
        if not self._closed:
            self._closed = True
            await self.unsubscribe()
            await self._queue.put(None)


class InMemoryRedisBroker:
    """Shared async in-memory Redis Hash + KV + Pub/Sub broker to simulate multi-worker Redis."""

    def __init__(self) -> None:
        self.hashes: dict[str, dict[str, str]] = defaultdict(dict)
        self.kv: dict[str, str] = {}
        self.ttls: dict[str, int] = {}
        self.subscribers: dict[str, set[asyncio.Queue[dict[str, Any] | None]]] = defaultdict(set)

    def client(self) -> "InMemoryRedisClient":
        return InMemoryRedisClient(self)


class InMemoryRedisClient:
    def __init__(self, broker: InMemoryRedisBroker) -> None:
        self._broker = broker

    async def hget(self, key: str, field: str) -> str | None:
        return self._broker.hashes.get(key, {}).get(field)

    async def hgetall(self, key: str) -> dict[str, str]:
        return dict(self._broker.hashes.get(key, {}))

    async def hset(self, key: str, field: str, value: str) -> int:
        self._broker.hashes[key][field] = value
        return 1

    async def hdel(self, key: str, *fields: str) -> int:
        bucket = self._broker.hashes.get(key, {})
        removed = 0
        for f in fields:
            if f in bucket:
                del bucket[f]
                removed += 1
        return removed

    async def get(self, key: str) -> str | None:
        return self._broker.kv.get(key)

    async def set(self, key: str, value: str, ex: int | None = None) -> bool:
        self._broker.kv[key] = value
        if ex is not None:
            self._broker.ttls[key] = int(ex)
        return True

    async def expire(self, key: str, ttl: int) -> bool:
        if key in self._broker.kv or key in self._broker.hashes:
            self._broker.ttls[key] = int(ttl)
            return True
        return False

    async def delete(self, *keys: str) -> int:
        removed = 0
        for k in keys:
            if k in self._broker.kv:
                del self._broker.kv[k]
                removed += 1
            self._broker.ttls.pop(k, None)
            if k in self._broker.hashes:
                del self._broker.hashes[k]
                removed += 1
        return removed

    async def publish(self, channel: str, message: str) -> int:
        queues = list(self._broker.subscribers.get(channel, set()))
        payload = {"type": "message", "channel": channel, "data": message}
        for q in queues:
            await q.put(payload)
        return len(queues)

    def pubsub(self) -> InMemoryRedisPubSub:
        return InMemoryRedisPubSub(self._broker)

    async def aclose(self) -> None:
        return None


def _drain_until_type(ws, expected_type: str, max_messages: int = 6) -> dict[str, Any]:
    seen: list[str] = []
    for _ in range(max_messages):
        msg = ws.receive_json()
        seen.append(str(msg.get("type")))
        if msg.get("type") == expected_type:
            return msg
    raise AssertionError(f"Expected message '{expected_type}', but received {seen}")


def test_webrtc_ws_rejects_missing_or_invalid_token() -> None:
    broker = InMemoryRedisBroker()
    manager = WebRtcSignalingManager(broker.client(), grace_seconds=25)
    app.dependency_overrides[get_webrtc_signaling_manager] = lambda: manager

    session_id = str(uuid.uuid4())
    try:
        with TestClient(app) as client:
            with client.websocket_connect(f"/api/v1/care/ws/{session_id}") as ws:
                msg = ws.receive()
                assert msg["type"] == "websocket.close"
                assert msg["code"] == 4401

            access_tok = create_access_token(str(uuid.uuid4()), "user@eva.id", "User")
            with client.websocket_connect(
                f"/api/v1/care/ws/{session_id}?token={access_tok}"
            ) as ws:
                msg = ws.receive()
                assert msg["type"] == "websocket.close"
                assert msg["code"] == 4401

            other_session_tok = create_room_token(
                session_id=str(uuid.uuid4()),
                room_id="eva-room-mismatch",
                user_id=str(uuid.uuid4()),
                role="counselor",
            )
            with client.websocket_connect(
                f"/api/v1/care/ws/{session_id}?token={other_session_tok}"
            ) as ws:
                msg = ws.receive()
                assert msg["type"] == "websocket.close"
                assert msg["code"] == 4403
    finally:
        app.dependency_overrides.pop(get_webrtc_signaling_manager, None)


def test_cross_worker_signaling_relay_without_self_echo() -> None:
    """Simulate two separate worker instances communicating over shared Redis Pub/Sub."""
    broker = InMemoryRedisBroker()
    worker_1 = WebRtcSignalingManager(broker.client(), grace_seconds=25)
    worker_2 = WebRtcSignalingManager(broker.client(), grace_seconds=25)

    # Alternate worker assignment across incoming WebSocket connections (--workers 2)
    workers = [worker_1, worker_2]
    call_idx = {"n": 0}

    def _next_worker() -> WebRtcSignalingManager:
        mgr = workers[call_idx["n"] % 2]
        call_idx["n"] += 1
        return mgr

    app.dependency_overrides[get_webrtc_signaling_manager] = _next_worker

    session_id = str(uuid.uuid4())
    room_id = "eva-room-CSR001"
    counselor_id = str(uuid.uuid4())
    patient_id = str(uuid.uuid4())

    counselor_token = create_room_token(
        session_id=session_id,
        room_id=room_id,
        user_id=counselor_id,
        role="counselor",
    )
    patient_token = create_room_token(
        session_id=session_id,
        room_id=room_id,
        user_id=patient_id,
        role="patient",
    )

    try:
        with TestClient(app) as client:
            with client.websocket_connect(
                f"/api/v1/care/ws/{session_id}?token={counselor_token}"
            ) as counselor_ws:
                c_state = counselor_ws.receive_json()
                assert c_state["type"] == "room_state"
                assert c_state["payload"]["offerer_role"] == "counselor"

                with client.websocket_connect(
                    f"/api/v1/care/ws/{session_id}?token={patient_token}"
                ) as patient_ws:
                    p_state = patient_ws.receive_json()
                    assert p_state["type"] == "room_state"

                    c_ready = _drain_until_type(counselor_ws, "room_ready")
                    p_ready = _drain_until_type(patient_ws, "room_ready")
                    assert c_ready["payload"]["offerer_role"] == "counselor"
                    assert p_ready["payload"]["offerer_role"] == "counselor"

                    # Counselor sends SDP offer on worker 1 -> delivered to patient on worker 2
                    counselor_ws.send_json(
                        {
                            "type": "offer",
                            "payload": {"sdp": "v=0...counselor-offer", "type": "offer"},
                        }
                    )
                    relayed_offer = patient_ws.receive_json()
                    assert relayed_offer["type"] == "offer"
                    assert relayed_offer["sender_role"] == "counselor"
                    assert relayed_offer["sender_id"] == counselor_id
                    assert relayed_offer["payload"]["sdp"] == "v=0...counselor-offer"

                    # Patient sends SDP answer on worker 2 -> delivered to counselor on worker 1
                    patient_ws.send_json(
                        {
                            "type": "answer",
                            "payload": {"sdp": "v=0...patient-answer", "type": "answer"},
                        }
                    )
                    relayed_answer = counselor_ws.receive_json()
                    assert relayed_answer["type"] == "answer"
                    assert relayed_answer["sender_role"] == "patient"
                    assert relayed_answer["sender_id"] == patient_id

                    # Verify ping returns pong to sender without relaying to peer
                    counselor_ws.send_json({"type": "ping", "payload": {"seq": 1}})
                    pong = counselor_ws.receive_json()
                    assert pong["type"] == "pong"
                    assert pong["payload"]["seq"] == 1

                    # Verify ICE candidate, ICE restart, media_state, chat_message, and extensions
                    for event_type, event_payload in [
                        ("ice_candidate", {"candidate": "candidate:1 1 UDP 2122252543"}),
                        ("ice_restart_needed", {"reason": "network_switch"}),
                        ("media_state", {"audio_enabled": True, "video_enabled": False}),
                        ("chat_message", {"text": "Halo, suara saya terdengar?"}),
                        ("extension_requested", {"extend_minutes": 30}),
                        ("extension_updated", {"approved": True, "extend_minutes": 30}),
                    ]:
                        counselor_ws.send_json({"type": event_type, "payload": event_payload})
                        relayed = patient_ws.receive_json()
                        assert relayed["type"] == event_type
                        assert relayed["sender_role"] == "counselor"
                        assert relayed["payload"] == event_payload
    finally:
        app.dependency_overrides.pop(get_webrtc_signaling_manager, None)


def test_abrupt_disconnect_grace_period_and_reconnect_recovery() -> None:
    broker = InMemoryRedisBroker()
    manager = WebRtcSignalingManager(broker.client(), grace_seconds=20)
    app.dependency_overrides[get_webrtc_signaling_manager] = lambda: manager

    session_id = str(uuid.uuid4())
    room_id = "eva-room-GRACE01"
    counselor_token = create_room_token(
        session_id=session_id,
        room_id=room_id,
        user_id=str(uuid.uuid4()),
        role="counselor",
    )
    patient_token = create_room_token(
        session_id=session_id,
        room_id=room_id,
        user_id=str(uuid.uuid4()),
        role="patient",
    )

    try:
        with TestClient(app) as client:
            with client.websocket_connect(
                f"/api/v1/care/ws/{session_id}?token={counselor_token}"
            ) as counselor_ws:
                _drain_until_type(counselor_ws, "room_state")

                with client.websocket_connect(
                    f"/api/v1/care/ws/{session_id}?token={patient_token}"
                ) as patient_ws:
                    _drain_until_type(patient_ws, "room_ready")
                    _drain_until_type(counselor_ws, "room_ready")

                # Patient socket exited without session_ended -> counselor gets peer_reconnecting
                reconnecting_evt = _drain_until_type(counselor_ws, "peer_reconnecting")
                assert reconnecting_evt["payload"]["role"] == "patient"
                assert reconnecting_evt["payload"]["grace_seconds"] == 20
                assert broker.ttls.get(f"eva:webrtc:grace:{room_id}:patient") == 20

                # Patient reconnects before grace period expires -> counselor gets peer_reconnected
                with client.websocket_connect(
                    f"/api/v1/care/ws/{session_id}?token={patient_token}"
                ) as patient_ws_reconnected:
                    _drain_until_type(patient_ws_reconnected, "room_state")
                    reconnected_evt = _drain_until_type(counselor_ws, "peer_reconnected")
                    assert reconnected_evt["payload"]["role"] == "patient"

                    ready_again = _drain_until_type(counselor_ws, "room_ready")
                    assert ready_again["payload"]["offerer_role"] == "counselor"

                    # Explicit session_ended clears room presence and does not emit peer_reconnecting
                    patient_ws_reconnected.send_json(
                        {"type": "session_ended", "payload": {"reason": "completed"}}
                    )
                    ended_evt = _drain_until_type(counselor_ws, "session_ended")
                    assert ended_evt["sender_role"] == "patient"
                    assert f"eva:webrtc:presence:{room_id}" not in broker.hashes
    finally:
        app.dependency_overrides.pop(get_webrtc_signaling_manager, None)


def test_grace_period_expiry_emits_peer_disconnected() -> None:
    broker = InMemoryRedisBroker()
    manager = WebRtcSignalingManager(broker.client(), grace_seconds=0.15)
    app.dependency_overrides[get_webrtc_signaling_manager] = lambda: manager

    session_id = str(uuid.uuid4())
    room_id = "eva-room-EXPIRY01"
    counselor_token = create_room_token(
        session_id=session_id,
        room_id=room_id,
        user_id=str(uuid.uuid4()),
        role="counselor",
    )
    patient_token = create_room_token(
        session_id=session_id,
        room_id=room_id,
        user_id=str(uuid.uuid4()),
        role="patient",
    )

    try:
        with TestClient(app) as client:
            with client.websocket_connect(
                f"/api/v1/care/ws/{session_id}?token={counselor_token}"
            ) as counselor_ws:
                _drain_until_type(counselor_ws, "room_state")

                with client.websocket_connect(
                    f"/api/v1/care/ws/{session_id}?token={patient_token}"
                ) as patient_ws:
                    _drain_until_type(patient_ws, "room_ready")
                    _drain_until_type(counselor_ws, "room_ready")

                _drain_until_type(counselor_ws, "peer_reconnecting")
                disconnected_evt = _drain_until_type(counselor_ws, "peer_disconnected")
                assert disconnected_evt["payload"]["role"] == "patient"
    finally:
        app.dependency_overrides.pop(get_webrtc_signaling_manager, None)


def test_connection_takeover_supersedes_stale_socket_with_4009() -> None:
    broker = InMemoryRedisBroker()
    worker_1 = WebRtcSignalingManager(broker.client(), grace_seconds=25)
    worker_2 = WebRtcSignalingManager(broker.client(), grace_seconds=25)
    workers = [worker_1, worker_2]
    idx = {"n": 0}

    def _next_worker() -> WebRtcSignalingManager:
        mgr = workers[idx["n"] % 2]
        idx["n"] += 1
        return mgr

    app.dependency_overrides[get_webrtc_signaling_manager] = _next_worker

    session_id = str(uuid.uuid4())
    room_id = "eva-room-TAKEOVER01"
    counselor_token = create_room_token(
        session_id=session_id,
        room_id=room_id,
        user_id=str(uuid.uuid4()),
        role="counselor",
    )

    try:
        with TestClient(app) as client:
            with client.websocket_connect(
                f"/api/v1/care/ws/{session_id}?token={counselor_token}"
            ) as stale_ws:
                _drain_until_type(stale_ws, "room_state")

                with client.websocket_connect(
                    f"/api/v1/care/ws/{session_id}?token={counselor_token}"
                ) as fresh_ws:
                    fresh_state = _drain_until_type(fresh_ws, "room_state")
                    assert (
                        fresh_state["payload"]["participants"]["counselor"]["status"]
                        == "connected"
                    )

                    close_frame = stale_ws.receive()
                    assert close_frame["type"] == "websocket.close"
                    assert close_frame["code"] == 4009
    finally:
        app.dependency_overrides.pop(get_webrtc_signaling_manager, None)


@pytest.mark.asyncio
async def test_ice_server_provider_cloudflare_turn_and_fallback() -> None:
    # 1. Blank credentials -> falls back cleanly to STUN URLs
    blank_cfg = SimpleNamespace(
        WEBRTC_STUN_URLS=["stun:stun.cloudflare.com:3478"],
        CLOUDFLARE_TURN_TOKEN_ID="",
        CLOUDFLARE_TURN_API_TOKEN="",
        CLOUDFLARE_TURN_TTL_SECONDS=14400,
    )
    provider_blank = IceServerProvider(config=blank_cfg)
    res_blank = await provider_blank.resolve_ice_servers()
    assert res_blank.ice_servers == ["stun:stun.cloudflare.com:3478"]
    assert len(res_blank.ice_server_configs) == 1
    assert res_blank.ice_server_configs[0].username is None

    # 2. Cloudflare TURN API 200 OK -> merges STUN + TURN credentials
    def _ok_handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["Authorization"] == "Bearer cf-secret-token"
        return httpx.Response(
            200,
            json={
                "iceServers": {
                    "urls": [
                        "stun:stun.cloudflare.com:3478",
                        "turn:turn.cloudflare.com:3478?transport=udp",
                        "turns:turn.cloudflare.com:5349?transport=tcp",
                    ],
                    "username": "cf-temp-user",
                    "credential": "cf-temp-pass",
                }
            },
        )

    cf_cfg = SimpleNamespace(
        WEBRTC_STUN_URLS=DEFAULT_STUN_URLS,
        CLOUDFLARE_TURN_TOKEN_ID="cf-token-id-123",
        CLOUDFLARE_TURN_API_TOKEN="cf-secret-token",
        CLOUDFLARE_TURN_TTL_SECONDS=7200,
    )
    async with httpx.AsyncClient(transport=httpx.MockTransport(_ok_handler)) as mock_client:
        provider_ok = IceServerProvider(config=cf_cfg, http_client=mock_client)
        res_ok = await provider_ok.resolve_ice_servers()
        assert "turn:turn.cloudflare.com:3478?transport=udp" in res_ok.ice_servers
        assert "turns:turn.cloudflare.com:5349?transport=tcp" in res_ok.ice_servers
        assert len(res_ok.ice_server_configs) == 2
        assert res_ok.ice_server_configs[1].username == "cf-temp-user"
        assert res_ok.ice_server_configs[1].credential == "cf-temp-pass"

    # 3. Cloudflare TURN API 500 or network error -> falls back to STUN without raising
    def _err_handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(503, json={"error": "Service Unavailable"})

    async with httpx.AsyncClient(transport=httpx.MockTransport(_err_handler)) as err_client:
        provider_err = IceServerProvider(config=cf_cfg, http_client=err_client)
        res_err = await provider_err.resolve_ice_servers()
        assert res_err.ice_servers == DEFAULT_STUN_URLS
        assert len(res_err.ice_server_configs) == 1
        assert res_err.ice_server_configs[0].username is None


def test_webrtc_ws_returns_error_on_invalid_payloads_and_sets_presence_ttl() -> None:
    broker = InMemoryRedisBroker()
    manager = WebRtcSignalingManager(broker.client(), grace_seconds=25)
    app.dependency_overrides[get_webrtc_signaling_manager] = lambda: manager

    session_id = str(uuid.uuid4())
    room_id = "eva-room-ERR01"
    counselor_token = create_room_token(
        session_id=session_id,
        room_id=room_id,
        user_id=str(uuid.uuid4()),
        role="counselor",
    )

    try:
        with TestClient(app) as client:
            with client.websocket_connect(
                f"/api/v1/care/ws/{session_id}?token={counselor_token}"
            ) as counselor_ws:
                state_evt = counselor_ws.receive_json()
                assert state_evt["type"] == "room_state"
                assert broker.ttls[f"eva:webrtc:presence:{room_id}"] >= 14400

                # 1. Malformed JSON -> structured error frame
                counselor_ws.send_text("{not-valid-json")
                err_json = counselor_ws.receive_json()
                assert err_json["type"] == "error"
                assert err_json["sender_role"] == "system"
                assert err_json["payload"]["code"] == "invalid_json"

                # 2. Unsupported event type -> structured error frame
                counselor_ws.send_json({"type": "unsupported_foo", "payload": {}})
                err_type = counselor_ws.receive_json()
                assert err_type["type"] == "error"
                assert err_type["payload"]["code"] == "unsupported_event_type"

                # 3. Oversized payload -> structured error frame
                counselor_ws.send_text("x" * (MAX_SIGNALING_MESSAGE_BYTES + 1))
                err_size = counselor_ws.receive_json()
                assert err_size["type"] == "error"
                assert err_size["payload"]["code"] == "payload_too_large"

                # 4. Connection stays healthy after non-fatal validation errors
                counselor_ws.send_json({"type": "ping", "payload": {"seq": 7}})
                pong = counselor_ws.receive_json()
                assert pong["type"] == "pong"
                assert pong["payload"]["seq"] == 7
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_shutdown_webrtc_signaling_manager_closes_worker_instance(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    broker = InMemoryRedisBroker()

    class _ClosableRedisClient(type(broker.client())):  # type: ignore[misc]
        def __init__(self, inner_broker: InMemoryRedisBroker) -> None:
            super().__init__(inner_broker)
            self.closed = False

        async def aclose(self) -> None:
            self.closed = True

    redis_client = _ClosableRedisClient(broker)
    manager = WebRtcSignalingManager(redis_client, grace_seconds=25)
    pending_task = asyncio.create_task(asyncio.sleep(10))
    manager._grace_tasks[("room-shutdown", "patient")] = pending_task

    monkeypatch.setattr(api_dependencies, "_webrtc_signaling_manager", manager)
    await shutdown_webrtc_signaling_manager()

    assert redis_client.closed is True
    assert pending_task.cancelled() is True
    assert api_dependencies._webrtc_signaling_manager is None


def test_config_normalizes_ws_base_url_and_parses_csv_stun_urls(
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
) -> None:
    assert normalize_ws_base_url("https://eva.nexacode.dev/") == "wss://eva.nexacode.dev"
    assert normalize_ws_base_url("http://10.0.2.2:8888/") == "ws://10.0.2.2:8888"

    monkeypatch.setattr(settings, "WS_BASE_URL", "https://eva.nexacode.dev/")
    session_id = str(uuid.uuid4())
    assert CareService._build_ws_url(session_id, "tok") == (
        f"wss://eva.nexacode.dev/api/v1/care/ws/{session_id}?token=tok"
    )

    monkeypatch.delenv("WS_BASE_URL", raising=False)
    monkeypatch.delenv("WEBRTC_STUN_URLS", raising=False)
    cfg_csv = BaseConfig(
        _env_file=None,
        WEBRTC_STUN_URLS="stun:a.example:3478, stun:b.example:3478",
    )
    assert cfg_csv.WEBRTC_STUN_URLS == ["stun:a.example:3478", "stun:b.example:3478"]

    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("WS_BASE_URL", "ws://localhost:8888")
    with caplog.at_level(logging.WARNING):
        cfg_prod = BaseConfig(_env_file=None, APP_ENV="production")
    assert cfg_prod.WS_BASE_URL == "ws://localhost:8888"
    assert "points to loopback in production" in caplog.text
