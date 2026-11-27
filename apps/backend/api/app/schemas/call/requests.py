from typing import Literal
from pydantic import BaseModel, Field


class SynthesizeTurnInput(BaseModel):
    """Single dialogue turn submitted by a local-first client for stateless synthesis."""

    role: Literal["user", "assistant"]
    text: str = Field(..., min_length=1)
    turn_id: int = 0


class CallSynthesizeRequest(BaseModel):
    """Request payload for POST /api/v1/call/synthesize."""

    session_id: str = Field(..., min_length=1)
    turns: list[SynthesizeTurnInput] = Field(default_factory=list)
    include_dass: bool = True
    include_memory_candidates: bool = True
