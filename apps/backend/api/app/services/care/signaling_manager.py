import asyncio
from dataclasses import dataclass
from datetime import UTC, datetime
import json
import logging
from typing import Any
import uuid

from fastapi import WebSocket, WebSocketDisconnect
from starlette.websockets import WebSocketState

from app.core.security import decode_room_token
from shared.config import settings

logger = logging.getLogger(__name__)

ALLOWED_RELAY_TYPES: frozenset[str] = frozenset(
    {
        "offer",
        "answer",
        "ice_candidate",
        "ice_restart_needed",
        "media_state",
        "chat_message",
        "extension_requested",
        "extension_updated",
        "session_ended",
    }
)

VALID_PARTICIPANT_ROLES: frozenset[str] = frozenset({"patient", "counselor"})
MAX_SIGNALING_MESSAGE_BYTES: int = 64 * 1024


@dataclass(slots=True)
class _ActiveConnection:
    connection_id: str
    session_id: str
    room_id: str
    user_id: str
    role: str
    websocket: WebSocket
    superseded: bool = False
    ended_explicitly: bool = False


class WebRtcSignalingManager:
    """Coordinates P2P WebRTC signaling across workers using Redis Pub/Sub and presence grace TTLs."""

    def __init__(
        self,
        redis_client: Any,
        *,
        grace_seconds: float | None = None,
    ) -> None:
        self._redis = redis_client
        configured_grace = (
            grace_seconds
            if grace_seconds is not None
            else getattr(settings, "WEBRTC_RECONNECT_GRACE_SECONDS", 25)
        )
        self._grace_seconds: float = float(configured_grace)
        self._local_connections: dict[tuple[str, str], _ActiveConnection] = {}
        self._grace_tasks: dict[tuple[str, str], asyncio.Task[None]] = {}

    @staticmethod
    def _room_channel(room_id: str) -> str:
        return f"eva:webrtc:room:{room_id}"

    @staticmethod
    def _presence_key(room_id: str) -> str:
        return f"eva:webrtc:presence:{room_id}"

    @staticmethod
    def _grace_key(room_id: str, role: str) -> str:
        return f"eva:webrtc:grace:{room_id}:{role}"

    def _presence_ttl_seconds(self) -> int:
        turn_ttl = int(getattr(settings, "CLOUDFLARE_TURN_TTL_SECONDS", 14400) or 14400)
        grace_floor = max(1, int(round(self._grace_seconds))) * 4
        return max(turn_ttl, grace_floor, 14400)

    async def _write_presence_entry(
        self,
        room_id: str,
        role: str,
        entry: dict[str, Any],
    ) -> str:
        presence_key = self._presence_key(room_id)
        await self._redis.hset(presence_key, role, json.dumps(entry))
        await self._redis.expire(presence_key, self._presence_ttl_seconds())
        return presence_key

    async def _send_error(
        self,
        websocket: WebSocket,
        *,
        code: str,
        detail: str,
    ) -> None:
        error_msg = self._build_envelope(
            msg_type="error",
            sender_role="system",
            sender_id="system",
            payload={"code": code, "detail": detail},
        )
        await self._safe_send_json(websocket, error_msg)

    @staticmethod
    def _now_iso() -> str:
        return datetime.now(UTC).isoformat()

    @classmethod
    def _build_envelope(
        cls,
        *,
        msg_type: str,
        sender_role: str,
        sender_id: str,
        payload: dict[str, Any] | None = None,
        origin_connection_id: str | None = None,
    ) -> dict[str, Any]:
        envelope: dict[str, Any] = {
            "type": msg_type,
            "sender_role": sender_role,
            "sender_id": sender_id,
            "timestamp": cls._now_iso(),
            "payload": payload or {},
        }
        if origin_connection_id is not None:
            envelope["_origin_connection_id"] = origin_connection_id
        return envelope

    async def close(self) -> None:
        tasks = list(self._grace_tasks.values())
        self._grace_tasks.clear()
        for task in tasks:
            if not task.done():
                task.cancel()
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)

        close_fn = getattr(self._redis, "aclose", None) or getattr(self._redis, "close", None)
        if close_fn is not None:
            res = close_fn()
            if asyncio.iscoroutine(res):
                await res

    async def handle_connection(
        self,
        websocket: WebSocket,
        session_id: str,
        token: str | None = None,
    ) -> None:
        await websocket.accept()

        if not token:
            await websocket.close(code=4401, reason="Missing signaling token")
            return

        claims = decode_room_token(token)
        if not claims or claims.get("type") != "video_room":
            await websocket.close(code=4401, reason="Invalid or expired signaling token")
            return

        token_session_id = str(claims.get("session_id") or "")
        role = str(claims.get("role") or "")
        user_id = str(claims.get("user_id") or "")
        room_id = str(claims.get("room_id") or f"eva-room-{session_id}")

        if (
            token_session_id != str(session_id)
            or role not in VALID_PARTICIPANT_ROLES
            or not user_id
        ):
            await websocket.close(code=4403, reason="Forbidden signaling session or role")
            return

        connection_id = uuid.uuid4().hex
        conn = _ActiveConnection(
            connection_id=connection_id,
            session_id=str(session_id),
            room_id=room_id,
            user_id=user_id,
            role=role,
            websocket=websocket,
        )

        pubsub = self._redis.pubsub()
        channel = self._room_channel(room_id)
        await pubsub.subscribe(channel)

        listener_task: asyncio.Task[None] | None = None
        try:
            await self._register_presence_and_notify(conn)
            listener_task = asyncio.create_task(self._pubsub_reader_loop(conn, pubsub))
            await self._websocket_reader_loop(conn)
        except WebSocketDisconnect:
            pass
        except Exception as exc:
            logger.warning(
                "Signaling WebSocket error for session %s (%s): %s",
                session_id,
                role,
                exc,
            )
        finally:
            if listener_task is not None and not listener_task.done():
                listener_task.cancel()
                await asyncio.gather(listener_task, return_exceptions=True)

            try:
                await pubsub.unsubscribe(channel)
            except Exception:
                pass
            close_pubsub = getattr(pubsub, "aclose", None) or getattr(pubsub, "close", None)
            if close_pubsub is not None:
                try:
                    res = close_pubsub()
                    if asyncio.iscoroutine(res):
                        await res
                except Exception:
                    pass

            await self._handle_disconnect(conn)

    async def _register_presence_and_notify(self, conn: _ActiveConnection) -> None:
        key = (conn.room_id, conn.role)
        self._cancel_local_grace_task(conn.room_id, conn.role)

        existing_local = self._local_connections.get(key)
        if existing_local is not None and existing_local.connection_id != conn.connection_id:
            existing_local.superseded = True
            await self._safe_close_websocket(
                existing_local.websocket,
                code=4009,
                reason="Connection superseded by newer session",
            )
        self._local_connections[key] = conn

        presence_key = self._presence_key(conn.room_id)
        grace_key = self._grace_key(conn.room_id, conn.role)

        raw_existing = await self._redis.hget(presence_key, conn.role)
        existing_entry = self._decode_json(raw_existing)
        grace_marker = await self._redis.get(grace_key)
        await self._redis.delete(grace_key)

        was_reconnecting = bool(
            grace_marker
            or (existing_entry and existing_entry.get("status") == "reconnecting")
        )
        previous_connected_id: str | None = None
        if existing_entry and existing_entry.get("status") == "connected":
            prev_id = existing_entry.get("connection_id")
            if isinstance(prev_id, str) and prev_id and prev_id != conn.connection_id:
                previous_connected_id = prev_id

        new_entry = {
            "user_id": conn.user_id,
            "role": conn.role,
            "status": "connected",
            "connection_id": conn.connection_id,
            "updated_at": self._now_iso(),
        }
        await self._write_presence_entry(conn.room_id, conn.role, new_entry)

        if previous_connected_id is not None:
            await self._publish(
                conn.room_id,
                {
                    "_control": "supersede",
                    "target_role": conn.role,
                    "superseded_connection_id": previous_connected_id,
                    "new_connection_id": conn.connection_id,
                },
            )

        participants = await self._get_room_participants(conn.room_id)
        room_state_msg = self._build_envelope(
            msg_type="room_state",
            sender_role="system",
            sender_id="system",
            payload={
                "room_id": conn.room_id,
                "session_id": conn.session_id,
                "offerer_role": "counselor",
                "participants": participants,
            },
        )
        await self._safe_send_json(conn.websocket, room_state_msg)

        if was_reconnecting:
            reconnected_msg = self._build_envelope(
                msg_type="peer_reconnected",
                sender_role="system",
                sender_id=conn.user_id,
                payload={
                    "room_id": conn.room_id,
                    "session_id": conn.session_id,
                    "role": conn.role,
                    "user_id": conn.user_id,
                },
                origin_connection_id=conn.connection_id,
            )
            await self._publish(conn.room_id, reconnected_msg)

        patient_state = participants.get("patient")
        counselor_state = participants.get("counselor")
        if (
            isinstance(patient_state, dict)
            and patient_state.get("status") == "connected"
            and isinstance(counselor_state, dict)
            and counselor_state.get("status") == "connected"
        ):
            room_ready_msg = self._build_envelope(
                msg_type="room_ready",
                sender_role="system",
                sender_id="system",
                payload={
                    "room_id": conn.room_id,
                    "session_id": conn.session_id,
                    "offerer_role": "counselor",
                    "participants": participants,
                },
            )
            await self._publish(conn.room_id, room_ready_msg)

    async def _websocket_reader_loop(self, conn: _ActiveConnection) -> None:
        while not conn.superseded and not conn.ended_explicitly:
            raw_text = await conn.websocket.receive_text()
            if len(raw_text.encode("utf-8", errors="ignore")) > MAX_SIGNALING_MESSAGE_BYTES:
                await self._send_error(
                    conn.websocket,
                    code="payload_too_large",
                    detail="Signaling message exceeds maximum allowed size.",
                )
                continue

            data = self._decode_json(raw_text)
            if not isinstance(data, dict):
                await self._send_error(
                    conn.websocket,
                    code="invalid_json",
                    detail="Signaling message must be a valid JSON object.",
                )
                continue

            msg_type = str(data.get("type") or "").strip()
            raw_payload = data.get("payload")
            payload: dict[str, Any] = raw_payload if isinstance(raw_payload, dict) else {}

            if msg_type == "ping":
                pong = self._build_envelope(
                    msg_type="pong",
                    sender_role="system",
                    sender_id="system",
                    payload=payload,
                )
                await self._safe_send_json(conn.websocket, pong)
                continue

            if msg_type == "pong":
                continue

            if msg_type not in ALLOWED_RELAY_TYPES:
                await self._send_error(
                    conn.websocket,
                    code="unsupported_event_type",
                    detail=f"Unsupported signaling event type: '{msg_type}'.",
                )
                continue

            envelope = self._build_envelope(
                msg_type=msg_type,
                sender_role=conn.role,
                sender_id=conn.user_id,
                payload=payload,
                origin_connection_id=conn.connection_id,
            )

            if msg_type == "session_ended":
                conn.ended_explicitly = True
                await self._clear_room_presence(conn.room_id)
                await self._publish(conn.room_id, envelope)
                await self._safe_close_websocket(conn.websocket, code=1000, reason="Session ended")
                return

            await self._publish(conn.room_id, envelope)

    async def _pubsub_reader_loop(self, conn: _ActiveConnection, pubsub: Any) -> None:
        async for item in pubsub.listen():
            if conn.superseded or conn.ended_explicitly:
                return
            if not isinstance(item, dict) or item.get("type") != "message":
                continue

            parsed = self._decode_json(item.get("data"))
            if not isinstance(parsed, dict):
                continue

            if parsed.get("_control") == "supersede":
                if (
                    parsed.get("target_role") == conn.role
                    and parsed.get("superseded_connection_id") == conn.connection_id
                ):
                    conn.superseded = True
                    await self._safe_close_websocket(
                        conn.websocket,
                        code=4009,
                        reason="Connection superseded by newer session",
                    )
                    return
                continue

            if parsed.get("_origin_connection_id") == conn.connection_id:
                continue

            outbound = {k: v for k, v in parsed.items() if not k.startswith("_")}
            await self._safe_send_json(conn.websocket, outbound)

            if outbound.get("type") == "session_ended":
                conn.ended_explicitly = True

    async def _handle_disconnect(self, conn: _ActiveConnection) -> None:
        key = (conn.room_id, conn.role)
        current_local = self._local_connections.get(key)
        if current_local is not None and current_local.connection_id == conn.connection_id:
            self._local_connections.pop(key, None)

        if conn.superseded or conn.ended_explicitly:
            return

        presence_key = self._presence_key(conn.room_id)
        raw_current = await self._redis.hget(presence_key, conn.role)
        current_entry = self._decode_json(raw_current)
        if (
            isinstance(current_entry, dict)
            and current_entry.get("connection_id") != conn.connection_id
        ):
            return

        grace_ttl = max(1, int(round(self._grace_seconds)))
        reconnecting_entry = {
            "user_id": conn.user_id,
            "role": conn.role,
            "status": "reconnecting",
            "connection_id": conn.connection_id,
            "updated_at": self._now_iso(),
        }
        await self._write_presence_entry(conn.room_id, conn.role, reconnecting_entry)
        await self._redis.set(
            self._grace_key(conn.room_id, conn.role),
            conn.connection_id,
            ex=grace_ttl,
        )

        reconnecting_msg = self._build_envelope(
            msg_type="peer_reconnecting",
            sender_role="system",
            sender_id=conn.user_id,
            payload={
                "room_id": conn.room_id,
                "session_id": conn.session_id,
                "role": conn.role,
                "user_id": conn.user_id,
                "grace_seconds": grace_ttl,
            },
            origin_connection_id=conn.connection_id,
        )
        await self._publish(conn.room_id, reconnecting_msg)

        self._cancel_local_grace_task(conn.room_id, conn.role)
        self._grace_tasks[key] = asyncio.create_task(
            self._expire_grace_period(
                room_id=conn.room_id,
                session_id=conn.session_id,
                role=conn.role,
                user_id=conn.user_id,
                expected_connection_id=conn.connection_id,
            )
        )

    async def _expire_grace_period(
        self,
        *,
        room_id: str,
        session_id: str,
        role: str,
        user_id: str,
        expected_connection_id: str,
    ) -> None:
        try:
            await asyncio.sleep(self._grace_seconds)
            presence_key = self._presence_key(room_id)
            raw_current = await self._redis.hget(presence_key, role)
            current_entry = self._decode_json(raw_current)
            if (
                not isinstance(current_entry, dict)
                or current_entry.get("connection_id") != expected_connection_id
                or current_entry.get("status") != "reconnecting"
            ):
                return

            disconnected_entry = {
                "user_id": user_id,
                "role": role,
                "status": "disconnected",
                "connection_id": expected_connection_id,
                "updated_at": self._now_iso(),
            }
            await self._write_presence_entry(room_id, role, disconnected_entry)
            await self._redis.delete(self._grace_key(room_id, role))

            disconnected_msg = self._build_envelope(
                msg_type="peer_disconnected",
                sender_role="system",
                sender_id=user_id,
                payload={
                    "room_id": room_id,
                    "session_id": session_id,
                    "role": role,
                    "user_id": user_id,
                },
                origin_connection_id=expected_connection_id,
            )
            await self._publish(room_id, disconnected_msg)
        except asyncio.CancelledError:
            return
        except Exception as exc:
            logger.warning("Grace expiry task error for room %s (%s): %s", room_id, role, exc)
        finally:
            key = (room_id, role)
            task = self._grace_tasks.get(key)
            if task is asyncio.current_task():
                self._grace_tasks.pop(key, None)

    def _cancel_local_grace_task(self, room_id: str, role: str) -> None:
        task = self._grace_tasks.pop((room_id, role), None)
        if task is not None and not task.done():
            task.cancel()

    async def _clear_room_presence(self, room_id: str) -> None:
        for role in VALID_PARTICIPANT_ROLES:
            self._cancel_local_grace_task(room_id, role)
            await self._redis.delete(self._grace_key(room_id, role))
        await self._redis.delete(self._presence_key(room_id))

    async def _get_room_participants(self, room_id: str) -> dict[str, dict[str, Any]]:
        raw_map = await self._redis.hgetall(self._presence_key(room_id))
        participants: dict[str, dict[str, Any]] = {}
        if not isinstance(raw_map, dict):
            return participants

        for raw_role, raw_val in raw_map.items():
            role_key = raw_role.decode() if isinstance(raw_role, bytes) else str(raw_role)
            parsed = self._decode_json(raw_val)
            if isinstance(parsed, dict):
                participants[role_key] = {
                    "user_id": parsed.get("user_id"),
                    "role": parsed.get("role", role_key),
                    "status": parsed.get("status"),
                    "updated_at": parsed.get("updated_at"),
                }
        return participants

    async def _publish(self, room_id: str, message: dict[str, Any]) -> None:
        await self._redis.publish(self._room_channel(room_id), json.dumps(message))

    @staticmethod
    def _decode_json(raw: Any) -> dict[str, Any] | None:
        if raw is None:
            return None
        if isinstance(raw, bytes):
            raw = raw.decode("utf-8", errors="ignore")
        if isinstance(raw, str):
            try:
                parsed = json.loads(raw)
                return parsed if isinstance(parsed, dict) else None
            except json.JSONDecodeError:
                return None
        if isinstance(raw, dict):
            return raw
        return None

    @staticmethod
    async def _safe_send_json(websocket: WebSocket, data: dict[str, Any]) -> None:
        if websocket.client_state != WebSocketState.CONNECTED:
            return
        try:
            await websocket.send_json(data)
        except Exception:
            pass

    @staticmethod
    async def _safe_close_websocket(
        websocket: WebSocket,
        *,
        code: int = 1000,
        reason: str = "",
    ) -> None:
        if websocket.client_state == WebSocketState.DISCONNECTED:
            return
        try:
            await websocket.close(code=code, reason=reason)
        except Exception:
            pass
