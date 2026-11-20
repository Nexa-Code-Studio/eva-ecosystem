import uuid
from datetime import datetime
from pydantic import BaseModel, Field


class BookSessionRequest(BaseModel):
    counselor_id: uuid.UUID
    scheduled_start_time: datetime


class ExtendSessionRequest(BaseModel):
    confirm: bool = True


class UpdateSoapNotesRequest(BaseModel):
    subjective: str = Field(default="", max_length=5000)
    objective: str = Field(default="", max_length=5000)
    assessment: str = Field(default="", max_length=5000)
    plan: str = Field(default="", max_length=5000)
    status: str = Field(default="verified", pattern="^(draft|verified)$")


class SynthesizeSoapRequest(BaseModel):
    transcript: str = Field(..., min_length=5, max_length=50000, description="Full conversation transcript from video call")
    patient_name: str | None = Field(default=None, max_length=150)


class RequestConsentRequest(BaseModel):
    counselor_id: uuid.UUID


class UpdateConsentStatusRequest(BaseModel):
    status: str = Field(..., pattern="^(granted|revoked|pending)$")


class CreateClinicalNoteRequest(BaseModel):
    patient_id: str
    session_id: str | None = None
    subjective: str = Field(default="", max_length=5000)
    objective: str = Field(default="", max_length=5000)
    assessment: str = Field(default="", max_length=5000)
    plan: str = Field(default="", max_length=5000)
    recommended_tasks: list[str] = Field(default_factory=list)
