"""Per-session coordinator managing half-duplex realtime STT streaming and cost control."""

from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
import logging
import uuid

from packages.ai.factories.stt_factory import STTFactory
from packages.ai.interfaces.stt import BaseRealtimeSTTSession, BaseSTTProvider
from packages.shared.config import settings

logger = logging.getLogger(__name__)

STTPartialCallback = Callable[[str, int, str], Awaitable[None]]
STTCommittedCallback = Callable[[str, int, str], Awaitable[None]]
STTStatusCallback = Callable[[str, int, str], Awaitable[None]]
STTErrorCallback = Callable[[str, int, str], Awaitable[None]]


@dataclass
class _SessionSTTContext:
    session_id: str
    generation_token: str
    privacy_mode: str | None
    stt_allowed: bool
    is_active: bool = False
    stt_session_id: int = 0
    pcm_queue: asyncio.Queue[bytes] = field(default_factory=lambda: asyncio.Queue(maxsize=32))
    worker_task: asyncio.Task[None] | None = None
    active_stt_session: BaseRealtimeSTTSession | None = None
    commit_event: asyncio.Event = field(default_factory=asyncio.Event)
    incognito_notified: bool = False
    dropped_chunks: int = 0
    on_partial: STTPartialCallback | None = None
    on_committed: STTCommittedCallback | None = None
    on_status: STTStatusCallback | None = None
    on_error: STTErrorCallback | None = None


class CallSTTCoordinator:
    """Non-blocking per-session STT coordinator with lazy-open and half-duplex cost control."""

    def __init__(
        self,
        provider_getter: Callable[[], BaseSTTProvider] | None = None,
        *,
        queue_maxsize: int = 32,
        idle_close_timeout_s: float | None = None,
    ) -> None:
        self._provider_getter = provider_getter or STTFactory.get_provider
        self._queue_maxsize = max(4, queue_maxsize)
        self._idle_close_timeout_s = idle_close_timeout_s
        self._sessions: dict[str, _SessionSTTContext] = {}

    def register_session(
        self,
        session_id: str,
        *,
        privacy_mode: str | None = None,
        on_partial: STTPartialCallback | None = None,
        on_committed: STTCommittedCallback | None = None,
        on_status: STTStatusCallback | None = None,
        on_error: STTErrorCallback | None = None,
    ) -> str:
        if session_id in self._sessions:
            self.cleanup_session_nowait(session_id)

        generation_token = uuid.uuid4().hex
        norm_privacy = (privacy_mode or "").strip().lower() or None

        # Fail-closed for incognito mode unless explicitly allowed
        stt_allowed = True
        if norm_privacy == "incognito" and not settings.STT_ALLOW_INCOGNITO_CLOUD_AUDIO:
            stt_allowed = False

        self._sessions[session_id] = _SessionSTTContext(
            session_id=session_id,
            generation_token=generation_token,
            privacy_mode=norm_privacy,
            stt_allowed=stt_allowed,
            is_active=False,
            stt_session_id=0,
            pcm_queue=asyncio.Queue(maxsize=self._queue_maxsize),
            on_partial=on_partial,
            on_committed=on_committed,
            on_status=on_status,
            on_error=on_error,
        )
        return generation_token

    def resume_session(self, session_id: str) -> int:
        """Allow PCM ingestion and lazily open a fresh upstream STT session on next audio frame."""
        ctx = self._sessions.get(session_id)
        if ctx is None:
            return 0
        if ctx.is_active and ctx.stt_session_id > 0:
            return ctx.stt_session_id

        self._drain_queue(ctx.pcm_queue)
        ctx.stt_session_id += 1
        ctx.generation_token = uuid.uuid4().hex
        ctx.is_active = True
        ctx.commit_event.clear()
        return ctx.stt_session_id

    async def pause_session(self, session_id: str, *, reason: str = "paused") -> None:
        """Immediately stop streaming and close upstream STT WebSocket to avoid idle billing."""
        ctx = self._sessions.get(session_id)
        if ctx is None:
            return

        ctx.is_active = False
        ctx.generation_token = uuid.uuid4().hex
        self._drain_queue(ctx.pcm_queue)

        worker = ctx.worker_task
        ctx.worker_task = None
        stt_session = ctx.active_stt_session
        ctx.active_stt_session = None

        if worker and not worker.done():
            worker.cancel()
            try:
                await worker
            except asyncio.CancelledError:
                pass
            except Exception:
                pass

        if stt_session is not None:
            try:
                await stt_session.close()
            except Exception as err:
                logger.warning("[STT COORDINATOR] Close error session=%s err=%s", session_id, type(err).__name__)

        logger.debug("[STT COORDINATOR] Paused session=%s reason=%s", session_id, reason)

    def ingest_pcm_chunk(self, session_id: str, chunk: bytes) -> bool:
        """Non-blocking PCM enqueue with drop-oldest backpressure and lazy upstream connect."""
        ctx = self._sessions.get(session_id)
        if ctx is None or not chunk:
            return False

        if not ctx.stt_allowed:
            if not ctx.incognito_notified:
                ctx.incognito_notified = True
                if ctx.on_status is not None:
                    try:
                        asyncio.create_task(ctx.on_status(session_id, ctx.stt_session_id, "incognito_blocked"))
                    except RuntimeError:
                        pass
            return False

        if not ctx.is_active:
            return False

        if ctx.pcm_queue.full():
            try:
                ctx.pcm_queue.get_nowait()
                ctx.dropped_chunks += 1
            except asyncio.QueueEmpty:
                pass
        try:
            ctx.pcm_queue.put_nowait(chunk)
        except asyncio.QueueFull:
            ctx.dropped_chunks += 1
            return False

        if ctx.worker_task is None or ctx.worker_task.done():
            ctx.worker_task = asyncio.create_task(
                self._run_stt_worker(ctx, ctx.generation_token, ctx.stt_session_id)
            )
        return True

    async def flush_and_commit(self, session_id: str, *, timeout_ms: int = 350) -> bool:
        """Send manual commit to active upstream STT session and await committed transcript within budget."""
        ctx = self._sessions.get(session_id)
        if ctx is None or ctx.active_stt_session is None:
            return False

        ctx.commit_event.clear()
        try:
            await ctx.active_stt_session.commit()
            await asyncio.wait_for(ctx.commit_event.wait(), timeout=max(0.05, timeout_ms / 1000.0))
            return True
        except TimeoutError:
            return False
        except Exception as err:
            logger.warning("[STT COORDINATOR] Force-commit error session=%s err=%s", session_id, type(err).__name__)
            return False

    def is_session_connected(self, session_id: str) -> bool:
        ctx = self._sessions.get(session_id)
        return ctx is not None and ctx.active_stt_session is not None

    async def cleanup_session(self, session_id: str) -> None:
        if session_id in self._sessions:
            await self.pause_session(session_id, reason="cleanup")
            self._sessions.pop(session_id, None)

    def cleanup_session_nowait(self, session_id: str) -> None:
        ctx = self._sessions.pop(session_id, None)
        if ctx is None:
            return
        ctx.is_active = False
        ctx.generation_token = uuid.uuid4().hex
        self._drain_queue(ctx.pcm_queue)
        if ctx.worker_task and not ctx.worker_task.done():
            ctx.worker_task.cancel()
        if ctx.active_stt_session is not None:
            stt_session = ctx.active_stt_session
            ctx.active_stt_session = None
            try:
                asyncio.create_task(stt_session.close())
            except RuntimeError:
                pass

    async def shutdown(self) -> None:
        for sid in list(self._sessions.keys()):
            await self.cleanup_session(sid)

    @staticmethod
    def _drain_queue(queue: asyncio.Queue[bytes]) -> None:
        while True:
            try:
                queue.get_nowait()
            except asyncio.QueueEmpty:
                break

    async def _run_stt_worker(
        self,
        ctx: _SessionSTTContext,
        generation_token: str,
        stt_session_id: int,
    ) -> None:
        stt_session: BaseRealtimeSTTSession | None = None
        sender_task: asyncio.Task[None] | None = None
        receiver_task: asyncio.Task[None] | None = None

        try:
            provider = self._provider_getter()
            stt_session = provider.create_realtime_session(
                sample_rate=16000,
                language_code=settings.ELEVENLABS_STT_LANGUAGE_CODE,
                commit_strategy=settings.ELEVENLABS_STT_COMMIT_STRATEGY,
            )
            await stt_session.connect()

            if ctx.generation_token != generation_token or not ctx.is_active:
                await stt_session.close()
                return

            ctx.active_stt_session = stt_session
            idle_timeout = (
                self._idle_close_timeout_s
                if self._idle_close_timeout_s is not None
                else getattr(settings, "STT_IDLE_CLOSE_TIMEOUT_S", 15.0)
            )

            async def _pump_pcm() -> None:
                while ctx.is_active and ctx.generation_token == generation_token:
                    try:
                        chunk = await asyncio.wait_for(ctx.pcm_queue.get(), timeout=idle_timeout)
                    except TimeoutError:
                        logger.info(
                            "[STT COORDINATOR] Idle audio timeout (%.1fs) closing upstream STT session=%s",
                            idle_timeout,
                            ctx.session_id,
                        )
                        return
                    if not ctx.is_active or ctx.generation_token != generation_token:
                        return
                    await stt_session.send_audio_chunk(chunk)

            async def _consume_events() -> None:
                async for event in stt_session.receive_events():
                    if ctx.generation_token != generation_token:
                        return
                    if event.kind == "session_started":
                        if ctx.on_status is not None:
                            await ctx.on_status(ctx.session_id, stt_session_id, "listening")
                    elif event.kind == "partial":
                        if ctx.on_partial is not None and event.text.strip():
                            await ctx.on_partial(ctx.session_id, stt_session_id, event.text)
                    elif event.kind == "committed":
                        ctx.commit_event.set()
                        if ctx.on_committed is not None and event.text.strip():
                            await ctx.on_committed(ctx.session_id, stt_session_id, event.text)
                    elif event.kind == "status":
                        if ctx.on_status is not None and event.status:
                            await ctx.on_status(ctx.session_id, stt_session_id, event.status)
                    elif event.kind == "error":
                        if ctx.on_error is not None:
                            await ctx.on_error(ctx.session_id, stt_session_id, event.error or "stt_error")
                        return

            sender_task = asyncio.create_task(_pump_pcm())
            receiver_task = asyncio.create_task(_consume_events())

            done, pending = await asyncio.wait(
                {sender_task, receiver_task},
                return_when=asyncio.FIRST_COMPLETED,
            )
            for task in pending:
                task.cancel()
            for task in pending:
                try:
                    await task
                except asyncio.CancelledError:
                    pass
                except Exception:
                    pass
            for task in done:
                exc = task.exception()
                if exc and not isinstance(exc, asyncio.CancelledError):
                    raise exc

        except asyncio.CancelledError:
            pass
        except Exception as err:
            logger.warning(
                "[STT COORDINATOR] Worker error session=%s err=%s",
                ctx.session_id,
                type(err).__name__,
            )
            if ctx.generation_token == generation_token and ctx.on_error is not None:
                try:
                    await ctx.on_error(ctx.session_id, stt_session_id, type(err).__name__)
                except Exception:
                    pass
        finally:
            for task in (sender_task, receiver_task):
                if task and not task.done():
                    task.cancel()
                    try:
                        await task
                    except asyncio.CancelledError:
                        pass
                    except Exception:
                        pass
            if stt_session is not None:
                try:
                    await stt_session.close()
                except Exception:
                    pass
            if ctx.active_stt_session is stt_session:
                ctx.active_stt_session = None


call_stt_coordinator = CallSTTCoordinator()


async def shutdown_stt_coordinator() -> None:
    await call_stt_coordinator.shutdown()
