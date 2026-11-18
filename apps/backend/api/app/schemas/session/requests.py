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


class RequestConsentRequest(BaseModel):
    counselor_id: uuid.UUID


class UpdateConsentStatusRequest(BaseModel):
    status: str = Field(..., pattern="^(granted|revoked)$")
