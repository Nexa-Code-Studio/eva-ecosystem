from __future__ import annotations

import asyncio
import base64
import json
import logging
import time
from collections.abc import AsyncGenerator
from datetime import date, datetime, timedelta, timezone
from typing import Any, ClassVar
from urllib.parse import urlencode

try:
    import websockets
    from websockets.exceptions import ConnectionClosed
except ImportError:
    websockets = None  # type: ignore[assignment]
    ConnectionClosed = Exception  # type: ignore[assignment,misc]

from packages.ai.interfaces.stt import (
    BaseRealtimeSTTSession,
    BaseSTTProvider,
    STTTranscriptEvent,
)
from packages.shared.config import settings

logger = logging.getLogger(__name__)

WIB = timezone(timedelta(hours=7))

NON_FATAL_STT_WARNINGS: frozenset[str] = frozenset(
    {"insufficient_audio_activity", "commit_throttled"}
)
KEY_EXHAUSTION_ERRORS: frozenset[str] = frozenset(
    {"auth_error", "quota_exceeded", "rate_limited", "resource_exhausted"}
)
FATAL_STT_ERRORS: frozenset[str] = frozenset(
    {
        "error",
        "auth_error",
        "quota_exceeded",
        "rate_limited",
        "transcriber_error",
        "input_error",
        "unaccepted_terms",
        "queue_overflow",
        "resource_exhausted",
        "session_time_limit_exceeded",
        "chunk_size_exceeded",
    }
)


def _mask_key(key: str) -> str:
    if not key:
        return "<empty>"
    return f"...{key[-6:]}" if len(key) >= 6 else "***"


class ElevenLabsRealtimeSTTSession(BaseRealtimeSTTSession):
    """Bidirectional WebSocket client for ElevenLabs Scribe v2 Realtime STT."""

    def __init__(
        self,
        api_key: str,
        *,
        keys: list[str] | None = None,
        base_url: str | None = None,
        model_id: str | None = None,
        sample_rate: int = 16000,
        language_code: str | None = None,
        commit_strategy: str | None = None,
        vad_silence_threshold_secs: float | None = None,
        vad_threshold: float | None = None,
    ) -> None:
        self.api_key = api_key
        self.keys = keys or ([api_key] if api_key else [])
        self.base_url = (
            base_url
            or getattr(settings, "ELEVENLABS_STT_URL", "wss://api.elevenlabs.io/v1/speech-to-text/realtime")
        ).rstrip("?")
        self.model_id = model_id or getattr(settings, "ELEVENLABS_STT_MODEL_ID", "scribe_v2_realtime")
        self.sample_rate = sample_rate
        self.audio_format = f"pcm_{sample_rate}"
        self.language_code = (
            language_code
            if language_code is not None
            else getattr(settings, "ELEVENLABS_STT_LANGUAGE_CODE", "id")
        )
        self.commit_strategy = (
            commit_strategy
            or getattr(settings, "ELEVENLABS_STT_COMMIT_STRATEGY", "vad")
        )
        self.vad_silence_threshold_secs = (
            vad_silence_threshold_secs
            if vad_silence_threshold_secs is not None
            else getattr(settings, "ELEVENLABS_STT_VAD_SILENCE_THRESHOLD_SECS", 0.8)
        )
        self.vad_threshold = (
            vad_threshold
            if vad_threshold is not None
            else getattr(settings, "ELEVENLABS_STT_VAD_THRESHOLD", 0.4)
        )

        self.ws: Any | None = None
        self._event_queue: asyncio.Queue[STTTranscriptEvent | None] = asyncio.Queue()
        self._recv_task: asyncio.Task[None] | None = None
        self._is_closed = False
        self._start_time: float = 0.0
        self._remote_session_id: str | None = None

        self.telemetry: dict[str, Any] = {
            "model_id": self.model_id,
            "audio_format": self.audio_format,
            "commit_strategy": self.commit_strategy,
            "chunks_sent": 0,
            "bytes_sent": 0,
            "partials_received": 0,
            "commits_received": 0,
            "duration_ms": None,
        }

    @property
    def url(self) -> str:
        params: dict[str, Any] = {
            "model_id": self.model_id,
            "audio_format": self.audio_format,
            "commit_strategy": self.commit_strategy,
        }
        if self.language_code:
            params["language_code"] = self.language_code
        if self.commit_strategy == "vad":
            if self.vad_silence_threshold_secs is not None:
                params["vad_silence_threshold_secs"] = self.vad_silence_threshold_secs
            if self.vad_threshold is not None:
                params["vad_threshold"] = self.vad_threshold
        return f"{self.base_url}?{urlencode(params)}"

    async def connect(self, timeout: float = 8.0) -> None:
        if websockets is None:
            raise RuntimeError("websockets package is not installed")
        if self._is_closed:
            raise RuntimeError("Cannot connect a closed ElevenLabs STT session")

        candidate_keys = self.keys if self.keys else [self.api_key]
        if not candidate_keys or not any(candidate_keys):
            raise RuntimeError("No ElevenLabs API key configured for Realtime STT")

        last_ex: Exception | None = None
        for attempt in range(len(candidate_keys)):
            current_key = ElevenLabsRealtimeSTTProvider.get_active_key(candidate_keys)
            self.api_key = current_key
            headers = {"xi-api-key": current_key}
            logger.info(
                "[ELEVENLABS STT CONNECTING] attempt=%d/%d key=%s model=%s format=%s lang=%s strategy=%s",
                attempt + 1,
                len(candidate_keys),
                _mask_key(current_key),
                self.model_id,
                self.audio_format,
                self.language_code or "auto",
                self.commit_strategy,
            )
            try:
                self.ws = await asyncio.wait_for(
                    websockets.connect(self.url, additional_headers=headers),
                    timeout=timeout,
                )
                self._start_time = time.perf_counter()
                self._recv_task = asyncio.create_task(self._receive_loop())
                logger.info(
                    "[ELEVENLABS STT CONNECTED] key=%s model=%s format=%s",
                    _mask_key(current_key),
                    self.model_id,
                    self.audio_format,
                )
                return
            except Exception as ex:
                last_ex = ex
                err_str = str(ex).lower()
                if any(code in err_str for code in ("401", "403", "429", "quota", "policy violation")):
                    logger.warning(
                        "[ELEVENLABS STT KEY REJECTED] key=%s rotating to next key",
                        _mask_key(current_key),
                    )
                    ElevenLabsRealtimeSTTProvider.mark_key_exhausted(current_key)
                else:
                    logger.error("[ELEVENLABS STT CONNECT ERROR] %s", type(ex).__name__)
                    raise

        if last_ex:
            raise last_ex

    async def send_audio_chunk(self, pcm_bytes: bytes, *, commit: bool = False) -> None:
        if not self.ws or self._is_closed:
            raise RuntimeError("Cannot send audio chunk: ElevenLabs STT session is not connected")
        if not pcm_bytes and not commit:
            return

        payload = {
            "message_type": "input_audio_chunk",
            "audio_base_64": base64.b64encode(pcm_bytes).decode("ascii") if pcm_bytes else "",
            "sample_rate": self.sample_rate,
            "commit": commit,
        }
        await self.ws.send(json.dumps(payload))
        self.telemetry["chunks_sent"] += 1
        self.telemetry["bytes_sent"] += len(pcm_bytes)

    async def commit(self) -> None:
        if self.ws and not self._is_closed:
            await self.send_audio_chunk(b"", commit=True)

    async def _receive_loop(self) -> None:
        try:
            while not self._is_closed and self.ws:
                raw_msg = await self.ws.recv()
                if isinstance(raw_msg, bytes):
                    raw_msg = raw_msg.decode("utf-8", errors="ignore")
                data = json.loads(raw_msg)
                msg_type = str(data.get("message_type") or "").strip()

                if msg_type == "session_started":
                    self._remote_session_id = data.get("session_id")
                    logger.info(
                        "[ELEVENLABS STT SESSION_STARTED] remote_session_id=%s",
                        self._remote_session_id or "unknown",
                    )
                    await self._event_queue.put(
                        STTTranscriptEvent(
                            kind="session_started",
                            status="listening",
                            session_id=self._remote_session_id,
                            language_code=self.language_code,
                        )
                    )
                elif msg_type == "partial_transcript":
                    text = str(data.get("text") or "")
                    self.telemetry["partials_received"] += 1
                    await self._event_queue.put(
                        STTTranscriptEvent(
                            kind="partial",
                            text=text,
                            session_id=self._remote_session_id,
                            language_code=data.get("language_code") or self.language_code,
                        )
                    )
                elif msg_type in ("committed_transcript", "committed_transcript_with_timestamps"):
                    text = str(data.get("text") or "")
                    self.telemetry["commits_received"] += 1
                    await self._event_queue.put(
                        STTTranscriptEvent(
                            kind="committed",
                            text=text,
                            session_id=self._remote_session_id,
                            language_code=data.get("language_code") or self.language_code,
                        )
                    )
                elif msg_type in NON_FATAL_STT_WARNINGS:
                    logger.debug("[ELEVENLABS STT NOTICE] message_type=%s", msg_type)
                    await self._event_queue.put(
                        STTTranscriptEvent(
                            kind="status",
                            status=msg_type,
                            session_id=self._remote_session_id,
                        )
                    )
                elif msg_type in FATAL_STT_ERRORS or msg_type.endswith("_error") or "error" in data:
                    err_code = msg_type or "error"
                    err_detail = str(data.get("error") or data.get("message") or err_code)
                    err_lower = f"{err_code} {err_detail}".lower()
                    if err_code in KEY_EXHAUSTION_ERRORS or any(
                        token in err_lower for token in ("quota", "credit", "auth", "limit", "401", "403", "429")
                    ):
                        ElevenLabsRealtimeSTTProvider.mark_key_exhausted(self.api_key)
                    logger.warning(
                        "[ELEVENLABS STT SERVER ERROR] type=%s key=%s",
                        err_code,
                        _mask_key(self.api_key),
                    )
                    await self._event_queue.put(
                        STTTranscriptEvent(
                            kind="error",
                            error=err_code,
                            status=err_code,
                            session_id=self._remote_session_id,
                        )
                    )
                    break
        except ConnectionClosed as cc:
            logger.info("[ELEVENLABS STT SOCKET CLOSED] code=%s", getattr(cc, "code", "unknown"))
        except asyncio.CancelledError:
            pass
        except Exception as ex:
            logger.error("[ELEVENLABS STT RECV EXCEPTION] %s", type(ex).__name__)
            await self._event_queue.put(
                STTTranscriptEvent(kind="error", error=type(ex).__name__, status="error")
            )
        finally:
            await self._event_queue.put(None)

    async def receive_events(self) -> AsyncGenerator[STTTranscriptEvent, None]:
        while True:
            event = await self._event_queue.get()
            if event is None:
                break
            yield event

    async def close(self) -> None:
        if self._is_closed:
            return
        self._is_closed = True

        if self._recv_task and not self._recv_task.done():
            self._recv_task.cancel()
            try:
                await self._recv_task
            except asyncio.CancelledError:
                pass
        self._recv_task = None

        if self.ws:
            try:
                await self.ws.close()
            except Exception:
                pass
            self.ws = None

        await self._event_queue.put(None)

        if self._start_time > 0:
            self.telemetry["duration_ms"] = round((time.perf_counter() - self._start_time) * 1000.0, 1)
            logger.info(
                "[ELEVENLABS STT CLOSED] duration_ms=%s chunks=%d bytes=%d partials=%d commits=%d",
                self.telemetry["duration_ms"],
                self.telemetry["chunks_sent"],
                self.telemetry["bytes_sent"],
                self.telemetry["partials_received"],
                self.telemetry["commits_received"],
            )


class ElevenLabsRealtimeSTTProvider(BaseSTTProvider):
    """Speech-to-Text provider backed by ElevenLabs Scribe v2 Realtime WebSocket API."""

    _shared_exhausted_keys: ClassVar[set[str]] = set()
    _shared_current_key_index: ClassVar[int] = 0
    _shared_last_reset_date: ClassVar[date | None] = None

    def __init__(
        self,
        api_key: str | None = None,
        *,
        base_url: str | None = None,
        model_id: str | None = None,
        language_code: str | None = None,
        commit_strategy: str | None = None,
        vad_silence_threshold_secs: float | None = None,
        vad_threshold: float | None = None,
    ) -> None:
        if api_key:
            raw_keys = [k.strip() for k in api_key.split(",") if k.strip()]
        else:
            raw_keys = settings.get_elevenlabs_stt_keys()

        self.keys: list[str] = [
            k for k in raw_keys if k and not k.startswith("your-") and "placeholder" not in k.lower()
        ]
        self.base_url = base_url or getattr(
            settings, "ELEVENLABS_STT_URL", "wss://api.elevenlabs.io/v1/speech-to-text/realtime"
        )
        self.model_id = model_id or getattr(settings, "ELEVENLABS_STT_MODEL_ID", "scribe_v2_realtime")
        self.language_code = (
            language_code
            if language_code is not None
            else getattr(settings, "ELEVENLABS_STT_LANGUAGE_CODE", "id")
        )
        self.commit_strategy = commit_strategy or getattr(settings, "ELEVENLABS_STT_COMMIT_STRATEGY", "vad")
        self.vad_silence_threshold_secs = (
            vad_silence_threshold_secs
            if vad_silence_threshold_secs is not None
            else getattr(settings, "ELEVENLABS_STT_VAD_SILENCE_THRESHOLD_SECS", 0.8)
        )
        self.vad_threshold = (
            vad_threshold
            if vad_threshold is not None
            else getattr(settings, "ELEVENLABS_STT_VAD_THRESHOLD", 0.4)
        )
        self._check_daily_reset()

    @property
    def api_key(self) -> str:
        return self.get_active_key(self.keys)

    @classmethod
    def _check_daily_reset(cls) -> None:
        today_wib = datetime.now(WIB).date()
        if cls._shared_last_reset_date is None or today_wib > cls._shared_last_reset_date:
            cls._shared_exhausted_keys.clear()
            cls._shared_current_key_index = 0
            cls._shared_last_reset_date = today_wib

    @classmethod
    def mark_key_exhausted(cls, key: str) -> None:
        if key and key not in cls._shared_exhausted_keys:
            cls._shared_exhausted_keys.add(key)
            cls._shared_current_key_index += 1
            logger.warning(
                "[ELEVENLABS STT KEY EXHAUSTED] key=%s total_exhausted=%d",
                _mask_key(key),
                len(cls._shared_exhausted_keys),
            )

    @classmethod
    def get_active_key(cls, keys: list[str]) -> str:
        if not keys:
            return ""
        for offset in range(len(keys)):
            idx = (cls._shared_current_key_index + offset) % len(keys)
            candidate = keys[idx]
            if candidate not in cls._shared_exhausted_keys:
                cls._shared_current_key_index = idx
                return candidate
        return keys[cls._shared_current_key_index % len(keys)]

    @classmethod
    def reset_key_state(cls) -> None:
        cls._shared_exhausted_keys.clear()
        cls._shared_current_key_index = 0
        cls._shared_last_reset_date = None

    def create_realtime_session(
        self,
        *,
        sample_rate: int = 16000,
        language_code: str | None = None,
        commit_strategy: str | None = None,
    ) -> ElevenLabsRealtimeSTTSession:
        return ElevenLabsRealtimeSTTSession(
            api_key=self.api_key,
            keys=self.keys,
            base_url=self.base_url,
            model_id=self.model_id,
            sample_rate=sample_rate,
            language_code=language_code if language_code is not None else self.language_code,
            commit_strategy=commit_strategy or self.commit_strategy,
            vad_silence_threshold_secs=self.vad_silence_threshold_secs,
            vad_threshold=self.vad_threshold,
        )

    async def transcribe_audio(self, audio_bytes: bytes, sample_rate: int = 16000) -> str:
        if not audio_bytes:
            return ""
        session = self.create_realtime_session(sample_rate=sample_rate, commit_strategy="manual")
        committed_parts: list[str] = []
        latest_partial = ""
        try:
            await session.connect()
            chunk_size = 4800
            for offset in range(0, len(audio_bytes), chunk_size):
                await session.send_audio_chunk(audio_bytes[offset : offset + chunk_size], commit=False)
            await session.commit()

            async def _collect() -> None:
                nonlocal latest_partial
                async for event in session.receive_events():
                    if event.kind == "partial" and event.text:
                        latest_partial = event.text
                    elif event.kind == "committed" and event.text:
                        committed_parts.append(event.text.strip())
                        break
                    elif event.kind == "error":
                        break

            await asyncio.wait_for(_collect(), timeout=5.0)
        finally:
            await session.close()

        return " ".join(committed_parts).strip() or latest_partial.strip()

    async def transcribe_stream(
        self, audio_stream: AsyncGenerator[bytes, None]
    ) -> AsyncGenerator[str, None]:
        session = self.create_realtime_session()
        try:
            await session.connect()

            async def _sender() -> None:
                async for chunk in audio_stream:
                    await session.send_audio_chunk(chunk)
                await session.commit()

            sender_task = asyncio.create_task(_sender())
            try:
                async for event in session.receive_events():
                    if event.kind in ("partial", "committed") and event.text:
                        yield event.text
                    elif event.kind == "error":
                        break
            finally:
                if not sender_task.done():
                    sender_task.cancel()
                    try:
                        await sender_task
                    except asyncio.CancelledError:
                        pass
        finally:
            await session.close()
