from __future__ import annotations

import asyncio
from collections.abc import AsyncGenerator

from packages.ai.interfaces.stt import (
    BaseRealtimeSTTSession,
    BaseSTTProvider,
    STTTranscriptEvent,
)


class MockRealtimeSTTSession(BaseRealtimeSTTSession):
    """Deterministic in-memory realtime STT session for local dev and automated tests."""

    def __init__(
        self,
        *,
        sample_rate: int = 16000,
        language_code: str = "id",
        commit_strategy: str = "vad",
        scripted_partials: list[str] | None = None,
        scripted_commits: list[str] | None = None,
        commit_every_n_chunks: int | None = 3,
        fail_on_connect: Exception | None = None,
        fail_after_chunks: int | None = None,
        connect_delay_s: float = 0.0,
    ) -> None:
        self.sample_rate = sample_rate
        self.language_code = language_code
        self.commit_strategy = commit_strategy
        self._scripted_partials = list(scripted_partials) if scripted_partials is not None else [
            "halo eva",
            "halo eva hari ini aku capek",
        ]
        self._scripted_commits = list(scripted_commits) if scripted_commits is not None else [
            "Halo Eva, hari ini aku capek sekali."
        ]
        self._commit_every_n_chunks = commit_every_n_chunks
        self._fail_on_connect = fail_on_connect
        self._fail_after_chunks = fail_after_chunks
        self._connect_delay_s = connect_delay_s

        self._event_queue: asyncio.Queue[STTTranscriptEvent | None] = asyncio.Queue()
        self.connected = False
        self.closed = False
        self.sent_chunks: list[bytes] = []
        self.commit_count = 0
        self._partial_idx = 0
        self._commit_idx = 0
        self._last_partial = ""

    async def connect(self, timeout: float = 8.0) -> None:
        if self._connect_delay_s > 0:
            await asyncio.sleep(self._connect_delay_s)
        if self._fail_on_connect is not None:
            raise self._fail_on_connect
        self.connected = True
        await self._event_queue.put(
            STTTranscriptEvent(
                kind="session_started",
                status="listening",
                session_id="mock_stt_session",
                language_code=self.language_code,
            )
        )

    async def send_audio_chunk(self, pcm_bytes: bytes, *, commit: bool = False) -> None:
        if not self.connected or self.closed:
            raise RuntimeError("MockRealtimeSTTSession is not connected")
        if pcm_bytes:
            self.sent_chunks.append(pcm_bytes)
            chunk_num = len(self.sent_chunks)

            if self._fail_after_chunks is not None and chunk_num >= self._fail_after_chunks:
                await self._event_queue.put(
                    STTTranscriptEvent(kind="error", error="mock_stt_fault", status="error")
                )
                return

            if self._scripted_partials:
                partial_text = self._scripted_partials[min(self._partial_idx, len(self._scripted_partials) - 1)]
                self._partial_idx += 1
                self._last_partial = partial_text
                await self._event_queue.put(
                    STTTranscriptEvent(
                        kind="partial",
                        text=partial_text,
                        session_id="mock_stt_session",
                        language_code=self.language_code,
                    )
                )

            if (
                self._commit_every_n_chunks is not None
                and self._commit_every_n_chunks > 0
                and chunk_num % self._commit_every_n_chunks == 0
            ):
                await self._emit_committed()

        if commit:
            await self.commit()

    async def _emit_committed(self) -> None:
        if self._commit_idx < len(self._scripted_commits):
            text = self._scripted_commits[self._commit_idx]
            self._commit_idx += 1
        elif self._last_partial:
            text = self._last_partial
        else:
            return
        self._last_partial = ""
        await self._event_queue.put(
            STTTranscriptEvent(
                kind="committed",
                text=text,
                session_id="mock_stt_session",
                language_code=self.language_code,
            )
        )

    async def commit(self) -> None:
        if not self.connected or self.closed:
            return
        self.commit_count += 1
        await self._emit_committed()

    async def receive_events(self) -> AsyncGenerator[STTTranscriptEvent, None]:
        while True:
            event = await self._event_queue.get()
            if event is None:
                break
            yield event

    async def close(self) -> None:
        if self.closed:
            return
        self.closed = True
        await self._event_queue.put(None)


class MockSTTProvider(BaseSTTProvider):
    """Mock Speech-to-Text provider for local development and automated test suites."""

    def __init__(
        self,
        *,
        scripted_partials: list[str] | None = None,
        scripted_commits: list[str] | None = None,
        commit_every_n_chunks: int | None = 3,
        fail_on_connect: Exception | None = None,
        fail_after_chunks: int | None = None,
        connect_delay_s: float = 0.0,
    ) -> None:
        self.scripted_partials = scripted_partials
        self.scripted_commits = scripted_commits
        self.commit_every_n_chunks = commit_every_n_chunks
        self.fail_on_connect = fail_on_connect
        self.fail_after_chunks = fail_after_chunks
        self.connect_delay_s = connect_delay_s
        self.sessions: list[MockRealtimeSTTSession] = []

    def create_realtime_session(
        self,
        *,
        sample_rate: int = 16000,
        language_code: str | None = None,
        commit_strategy: str | None = None,
    ) -> MockRealtimeSTTSession:
        session = MockRealtimeSTTSession(
            sample_rate=sample_rate,
            language_code=language_code or "id",
            commit_strategy=commit_strategy or "vad",
            scripted_partials=self.scripted_partials,
            scripted_commits=self.scripted_commits,
            commit_every_n_chunks=self.commit_every_n_chunks,
            fail_on_connect=self.fail_on_connect,
            fail_after_chunks=self.fail_after_chunks,
            connect_delay_s=self.connect_delay_s,
        )
        self.sessions.append(session)
        return session

    async def transcribe_audio(self, audio_bytes: bytes, sample_rate: int = 16000) -> str:
        if not audio_bytes:
            return ""
        if self.scripted_commits:
            return self.scripted_commits[0]
        return "Halo Eva, ini transkrip simulasi."

    async def transcribe_stream(
        self, audio_stream: AsyncGenerator[bytes, None]
    ) -> AsyncGenerator[str, None]:
        session = self.create_realtime_session()
        await session.connect()
        try:
            async for chunk in audio_stream:
                await session.send_audio_chunk(chunk)
            await session.commit()
            await session.close()
            async for event in session.receive_events():
                if event.kind in ("partial", "committed") and event.text:
                    yield event.text
        finally:
            await session.close()
