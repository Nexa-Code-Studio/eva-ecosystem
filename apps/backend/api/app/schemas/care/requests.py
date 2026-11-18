from pydantic import BaseModel, Field


class UpdateCallStatusRequest(BaseModel):
    """Payload to update live consultation call status."""

    status: str = Field(..., description="Call status: active, completed, missed, or cancelled")
    duration_seconds: int | None = Field(default=None, ge=0, description="Actual call duration in seconds")
    notes: list[str] | None = Field(default=None, description="Optional quick call notes from counselor")
