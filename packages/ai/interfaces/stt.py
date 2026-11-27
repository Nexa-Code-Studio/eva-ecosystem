from __future__ import annotations

from abc import ABC, abstractmethod
from collections.abc import AsyncGenerator
from dataclasses import dataclass
from typing import Literal

STTEventKind = Literal["session_started", "partial", "committed", "status", "error"]


@dataclass(frozen=True)
class STTTranscriptEvent:
    """Typed realtime event emitted by a streaming STT session."""

    kind: STTEventKind
    text: str = ""
    status: str | None = None
    error: str | None = None
    session_id: str | None = None
    language_code: str | None = None


class BaseRealtimeSTTSession(ABC):
    """Provider-agnostic contract for a live bidirectional streaming STT session."""

    @abstractmethod
    async def connect(self, timeout: float = 8.0) -> None:
        """Open the upstream realtime transcription connection."""
        pass

    @abstractmethod
    async def send_audio_chunk(self, pcm_bytes: bytes, *, commit: bool = False) -> None:
        """Stream a raw PCM audio chunk to the upstream STT engine."""
        pass

    @abstractmethod
    async def commit(self) -> None:
        """Request immediate finalization of buffered speech."""
        pass

    @abstractmethod
    async def receive_events(self) -> AsyncGenerator[STTTranscriptEvent, None]:
        """Yield typed partial, committed, status, and error events until closed."""
        pass

    @abstractmethod
    async def close(self) -> None:
        """Close the upstream connection and release session resources."""
        pass


class BaseSTTProvider(ABC):
    """Provider-agnostic interface for Speech-To-Text services."""

    @abstractmethod
    def create_realtime_session(
        self,
        *,
        sample_rate: int = 16000,
        language_code: str | None = None,
        commit_strategy: str | None = None,
    ) -> BaseRealtimeSTTSession:
        """Create a new streaming realtime STT session."""
        pass

    @abstractmethod
    async def transcribe_audio(self, audio_bytes: bytes, sample_rate: int = 16000) -> str:
        """Transcribe complete audio payload into text."""
        pass

    @abstractmethod
    async def transcribe_stream(
        self, audio_stream: AsyncGenerator[bytes, None]
    ) -> AsyncGenerator[str, None]:
        """Stream audio chunks and yield real-time transcripts."""
        pass
