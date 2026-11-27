from typing import Any
from pydantic import BaseModel, Field


class EmotionBreakdownDto(BaseModel):
    """Normalized 7-emotion distribution item for UI and local SQLCipher storage."""

    name: str
    label: str
    emoji: str
    percent: float
    color: str


class JournalDeltaDto(BaseModel):
    """AI-synthesized session delta merged into daily local journal entries."""

    title: str
    summary: str
    content: str
    mood_tag: str
    mood_emoji: str
    emotional_level: int = 3
    ai_insight: str
    emotional_reflection: str
    important_events: list[str] = Field(default_factory=list)
    emotions_breakdown: list[EmotionBreakdownDto] = Field(default_factory=list)


class DASSItemDto(BaseModel):
    """Single extracted DASS-21 item."""

    item_id: int
    scale: str
    question_text: str
    score: int
    evidence: str | None = None
    reason: str | None = None
    confidence: float = 0.0
    is_user_edited: bool = False


class DASSAssessmentPayloadDto(BaseModel):
    """Stateless DASS-21 extraction summary matching LocalDASSDataSource schema."""

    stress_score: int = 0
    anxiety_score: int = 0
    depression_score: int = 0
    stress_category: str = "Normal"
    anxiety_category: str = "Normal"
    depression_category: str = "Normal"
    stress_severity: str = "Normal"
    anxiety_severity: str = "Normal"
    depression_severity: str = "Normal"
    items: list[DASSItemDto] = Field(default_factory=list)


class MemoryCandidateDto(BaseModel):
    """Selective long-term memory candidate requiring explicit user confirmation."""

    candidate_id: str
    category: str
    fact_text: str
    source_type: str = "user_reported"
    source_excerpt: str | None = None
    source_verification: str = "unverified"
    should_require_confirmation: bool = True


class CallSynthesizeResponse(BaseModel):
    """Stateless synthesis artifacts returned to the client without DB persistence."""

    session_id: str
    session_summary: str
    journal_delta: JournalDeltaDto
    dass_assessment: DASSAssessmentPayloadDto | None = None
    memory_candidates: list[MemoryCandidateDto] = Field(default_factory=list)
    metadata: dict[str, Any] = Field(default_factory=dict)
