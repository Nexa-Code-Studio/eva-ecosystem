import uuid
from datetime import datetime
from pydantic import BaseModel, Field


class UpdateCallStatusRequest(BaseModel):
    """Payload to update live consultation call status."""

    status: str = Field(..., description="Call status: active, completed, missed, or cancelled")
    duration_seconds: int | None = Field(default=None, ge=0, description="Actual call duration in seconds")
    notes: list[str] | None = Field(default=None, description="Optional quick call notes from counselor")


class BookConsultationRequest(BaseModel):
    """Payload to book a teleconsultation session supporting flexible field names."""

    psychologist_id: uuid.UUID | None = None
    counselor_id: uuid.UUID | None = None
    preferred_date_time: datetime | None = None
    scheduled_start_time: datetime | None = None
    session_type: str = Field(default="onlineVideo")
    session_count: int = Field(default=1, ge=1, le=4)
    duration_minutes: int = Field(default=30, ge=30, le=120)
    complaints: str | None = None
    share_ai_chat_history: bool = True

    def resolve_counselor_id(self, route_counselor_id: uuid.UUID | None = None) -> uuid.UUID:
        target = route_counselor_id or self.counselor_id or self.psychologist_id
        if not target:
            raise ValueError("counselor_id atau psychologist_id wajib disertakan.")
        return target

    def resolve_start_time(self) -> datetime:
        dt = self.scheduled_start_time or self.preferred_date_time
        if not dt:
            raise ValueError("scheduled_start_time atau preferred_date_time wajib disertakan.")
        return dt


class SubmitRatingRequest(BaseModel):
    """Payload to submit psychologist rating and review."""

    rating: float = Field(..., ge=1.0, le=5.0)
    review_text: str = Field(..., min_length=1, max_length=2000)
    is_anonymous: bool = False
    tags: list[str] = Field(default_factory=list)

