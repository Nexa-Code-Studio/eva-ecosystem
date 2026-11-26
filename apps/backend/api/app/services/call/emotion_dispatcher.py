"""Bounded, fair, in-memory async dispatcher for 3-second speech emotion inference.

Invariants:
- Strictly ephemeral in-memory RAM queues (zero Redis/ARQ/DB persistence).
- `enqueue()` is synchronous/non-blocking (`put_nowait` semantics); never blocks WebSocket receive loops.
- Round-robin fairness across sessions with global and per-session in-flight caps.
- Stale deadline enforcement, idempotency by `segment_id`, and `generation_token` rejection for ended sessions.
"""

from __future__ import annotations

import asyncio
import logging
import time
from collections import deque
from collections.abc import Callable
from typing import Any

from app.services.call.audio_segmenter import AudioSegment

from packages.ai.interfaces.emotion import BaseEmotionProvider
from shared.domain_types import EmotionSegmentPrediction

logger = logging.getLogger(__name__)

ResultCallback = Callable[[AudioSegment, EmotionSegmentPrediction], None]
FailureCallback = Callable[[AudioSegment, str], None]
SessionActiveCheck = Callable[[str, str], bool]


class BoundedEmotionDispatcher:
    """In-memory fair dispatcher coordinating bounded async HTTP inference workers."""

    def __init__(
        self,
        provider_getter: Callable[[], BaseEmotionProvider],
        *,
        max_global_inflight: int = 32,
        per_session_max_inflight: int = 4,
        max_queue_size: int = 128,
        per_session_max_queue: int = 16,
        segment_deadline_ms: int = 4000,
    ) -> None:
        self._provider_getter = provider_getter
        self.max_global_inflight = max(1, max_global_inflight)
        self.per_session_max_inflight = max(1, per_session_max_inflight)
        self.max_queue_size = max(4, max_queue_size)
        self.per_session_max_queue = max(2, per_session_max_queue)
        self.segment_deadline_ms = max(500, segment_deadline_ms)

        self._session_queues: dict[str, deque[AudioSegment]] = {}
        self._rr_order: deque[str] = deque()
        self._total_queued: int = 0
        self._seen_segment_ids: set[str] = set()

        self._inflight_global: int = 0
        self._inflight_per_session: dict[str, int] = {}
        self._session_tasks: dict[str, set[asyncio.Task[Any]]] = {}
        self._session_drain_events: dict[str, asyncio.Event] = {}

        self._on_result: ResultCallback | None = None
        self._on_failure: FailureCallback | None = None
        self._is_session_active: SessionActiveCheck | None = None

        self._wakeup = asyncio.Event()
        self._scheduler_task: asyncio.Task[Any] | None = None
        self._stopped = False

        # Non-PII operational metrics
        self.metrics: dict[str, int] = {
            "enqueued": 0,
            "completed": 0,
            "failed": 0,
            "dropped_queue_full": 0,
            "dropped_deadline_exceeded": 0,
            "dropped_duplicate": 0,
            "discarded_stale_session": 0,
        }

    def configure_callbacks(
        self,
        *,
        on_result: ResultCallback,
        on_failure: FailureCallback,
        is_session_active: SessionActiveCheck,
    ) -> None:
        self._on_result = on_result
        self._on_failure = on_failure
        self._is_session_active = is_session_active

    def _ensure_scheduler_running(self) -> None:
        if self._stopped:
            self._stopped = False
        if self._scheduler_task is None or self._scheduler_task.done():
            loop = asyncio.get_running_loop()
            self._scheduler_task = loop.create_task(self._scheduler_loop(), name="emotion_dispatcher_scheduler")

    def enqueue(self, segment: AudioSegment) -> tuple[bool, str | None]:
        """Non-blocking enqueue of a 3s AudioSegment. Returns (accepted, drop_reason)."""
        if segment.segment_id in self._seen_segment_ids:
            self.metrics["dropped_duplicate"] += 1
            return False, "dropped_duplicate"

        try:
            self._ensure_scheduler_running()
        except RuntimeError:
            # No running event loop
            self.metrics["failed"] += 1
            return False, "no_event_loop"

        sid = segment.session_id
        q = self._session_queues.get(sid)
        if q is None:
            q = deque()
            self._session_queues[sid] = q
            self._rr_order.append(sid)

        # Enforce per-session queue cap (evict oldest queued segment for this session)
        if len(q) >= self.per_session_max_queue:
            evicted = q.popleft()
            self._total_queued = max(0, self._total_queued - 1)
            self.metrics["dropped_queue_full"] += 1
            if self._on_failure:
                self._on_failure(evicted, "dropped_queue_full")

        # Enforce global queue cap
        if self._total_queued >= self.max_queue_size:
            self.metrics["dropped_queue_full"] += 1
            if self._on_failure:
                self._on_failure(segment, "dropped_queue_full")
            return False, "dropped_queue_full"

        self._seen_segment_ids.add(segment.segment_id)
        q.append(segment)
        self._total_queued += 1
        self.metrics["enqueued"] += 1

        drain_evt = self._session_drain_events.get(sid)
        if drain_evt is not None:
            drain_evt.clear()

        self._wakeup.set()
        return True, None

    def _pick_next_segment(self) -> AudioSegment | None:
        """Round-robin pick respecting per-session and global in-flight limits."""
        if self._inflight_global >= self.max_global_inflight or self._total_queued <= 0:
            return None

        checked = 0
        total_sessions = len(self._rr_order)
        while checked < total_sessions and self._rr_order:
            sid = self._rr_order.popleft()
            checked += 1
            q = self._session_queues.get(sid)
            if not q:
                self._session_queues.pop(sid, None)
                continue

            # Keep session in RR ring while it still has items
            self._rr_order.append(sid)

            if self._inflight_per_session.get(sid, 0) >= self.per_session_max_inflight:
                continue

            seg = q.popleft()
            self._total_queued = max(0, self._total_queued - 1)
            if not q:
                self._session_queues.pop(sid, None)
                try:
                    self._rr_order.remove(sid)
                except ValueError:
                    pass
            return seg

        return None

    async def _scheduler_loop(self) -> None:
        try:
            while not self._stopped:
                dispatched_any = False
                while True:
                    seg = self._pick_next_segment()
                    if seg is None:
                        break
                    dispatched_any = True
                    self._launch_segment_task(seg)

                if not dispatched_any:
                    self._wakeup.clear()
                    await self._wakeup.wait()
        except asyncio.CancelledError:
            return

    def _launch_segment_task(self, segment: AudioSegment) -> None:
        sid = segment.session_id
        self._inflight_global += 1
        self._inflight_per_session[sid] = self._inflight_per_session.get(sid, 0) + 1

        task = asyncio.create_task(self._execute_segment(segment), name=f"emotion_seg_{segment.segment_id[:8]}")
        self._session_tasks.setdefault(sid, set()).add(task)
        task.add_done_callback(lambda t, s=sid: self._on_task_done(s, t))

    def _on_task_done(self, session_id: str, task: asyncio.Task[Any]) -> None:
        tasks = self._session_tasks.get(session_id)
        if tasks is not None:
            tasks.discard(task)
            if not tasks:
                self._session_tasks.pop(session_id, None)

        self._inflight_global = max(0, self._inflight_global - 1)
        cur = self._inflight_per_session.get(session_id, 0) - 1
        if cur <= 0:
            self._inflight_per_session.pop(session_id, None)
        else:
            self._inflight_per_session[session_id] = cur

        self._maybe_signal_drained(session_id)
        self._wakeup.set()

    def _maybe_signal_drained(self, session_id: str) -> None:
        q = self._session_queues.get(session_id)
        has_queued = bool(q)
        has_inflight = self._inflight_per_session.get(session_id, 0) > 0
        if not has_queued and not has_inflight:
            evt = self._session_drain_events.get(session_id)
            if evt is not None:
                evt.set()

    async def _execute_segment(self, segment: AudioSegment) -> None:
        if self._is_session_active and not self._is_session_active(segment.session_id, segment.generation_token):
            self.metrics["discarded_stale_session"] += 1
            return

        now_mono_ms = int(time.monotonic() * 1000)
        elapsed_ms = max(0, now_mono_ms - segment.created_monotonic_ms)
        remaining_ms = self.segment_deadline_ms - elapsed_ms
        if remaining_ms <= 100:
            self.metrics["dropped_deadline_exceeded"] += 1
            if self._on_failure:
                self._on_failure(segment, "dropped_deadline_exceeded")
            return

        try:
            provider = self._provider_getter()
            prediction = await provider.predict_pcm_segment(
                segment.pcm_bytes,
                segment_id=segment.segment_id,
                sample_rate=segment.sample_rate,
                channels=segment.channels,
                sample_width_bytes=segment.sample_width_bytes,
                valid_speech_ms=segment.valid_speech_ms,
                duration_ms=segment.duration_ms,
                deadline_ms=remaining_ms,
                sequence=segment.sequence,
                user_turn_id=segment.user_turn_id,
                capture_epoch=segment.capture_epoch,
                start_offset_ms=segment.start_offset_ms,
                end_offset_ms=segment.end_offset_ms,
            )

            # Re-verify session generation token after async I/O before updating state
            if self._is_session_active and not self._is_session_active(segment.session_id, segment.generation_token):
                self.metrics["discarded_stale_session"] += 1
                return

            self.metrics["completed"] += 1
            if self._on_result:
                self._on_result(segment, prediction)
        except asyncio.CancelledError:
            self.metrics["discarded_stale_session"] += 1
            raise
        except Exception as err:
            self.metrics["failed"] += 1
            logger.warning(
                "[EMOTION DISPATCHER] Segment %s failed (session=%s): %s",
                segment.segment_id[:8],
                segment.session_id,
                err,
            )
            if self._on_failure:
                self._on_failure(segment, "inference_error")

    async def drain_session(self, session_id: str, timeout_ms: int = 1500) -> bool:
        """Bounded drain of queued and in-flight jobs for a session during finalization."""
        if not self._session_queues.get(session_id) and self._inflight_per_session.get(session_id, 0) == 0:
            return True

        evt = self._session_drain_events.setdefault(session_id, asyncio.Event())
        self._maybe_signal_drained(session_id)
        try:
            await asyncio.wait_for(evt.wait(), timeout=max(0.05, timeout_ms / 1000.0))
            return True
        except TimeoutError:
            return False
        finally:
            self._session_drain_events.pop(session_id, None)

    def cancel_session(self, session_id: str) -> None:
        """Immediately drop queued segments and cancel in-flight tasks for a session."""
        q = self._session_queues.pop(session_id, None)
        if q:
            self._total_queued = max(0, self._total_queued - len(q))
            q.clear()
        try:
            self._rr_order.remove(session_id)
        except ValueError:
            pass

        tasks = list(self._session_tasks.get(session_id, ()))
        for t in tasks:
            if not t.done():
                t.cancel()
        self._session_drain_events.pop(session_id, None)

    async def shutdown(self) -> None:
        """Stop scheduler, cancel pending tasks, and release memory."""
        self._stopped = True
        self._wakeup.set()
        for sid in list(self._session_tasks.keys()):
            self.cancel_session(sid)
        if self._scheduler_task and not self._scheduler_task.done():
            self._scheduler_task.cancel()
            try:
                await self._scheduler_task
            except asyncio.CancelledError:
                pass
        self._scheduler_task = None
        self._session_queues.clear()
        self._rr_order.clear()
        self._seen_segment_ids.clear()
        self._total_queued = 0

    def get_operational_metrics(self) -> dict[str, int]:
        return {
            **self.metrics,
            "inflight_current": self._inflight_global,
            "queue_depth": self._total_queued,
        }
