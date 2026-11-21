import uuid
from pydantic import BaseModel, Field


class UpdateCallStatusRequest(BaseModel):
    """Payload to update live consultation call status."""

    status: str = Field(..., description="Call status: active, completed, missed, or cancelled")
    duration_seconds: int | None = Field(default=None, ge=0, description="Actual call duration in seconds")
    notes: list[str] | None = Field(default=None, description="Optional quick call notes from counselor")


class ClinicalShareComplaintItem(BaseModel):
    text: str
    source: str = "user_confirmed"
    last_confirmed_at: str | None = None


class ClinicalShareDiagnosisItem(BaseModel):
    diagnosis_name: str
    source_label: str = "self_reported"
    notes: str | None = None


class ClinicalShareItems(BaseModel):
    complaints: list[ClinicalShareComplaintItem] = Field(default_factory=list)
    professional_diagnoses: list[ClinicalShareDiagnosisItem] = Field(default_factory=list)


class ClinicalShareRequest(BaseModel):
    version: int = 1
    psychologist_id: uuid.UUID
    consent_version: str = "clinical-share-v1"
    items: ClinicalShareItems
