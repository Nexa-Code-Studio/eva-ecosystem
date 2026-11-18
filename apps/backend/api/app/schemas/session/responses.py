from datetime import datetime
from typing import Any
from pydantic import BaseModel, ConfigDict


class TimeSlotResponse(BaseModel):
    start_time: datetime
    end_time: datetime
    duration_minutes: int = 30
    is_available: bool = True


class AvailableSlotsResponse(BaseModel):
    counselor_id: str
    date: str
    buffer_time_minutes: int
    slots: list[TimeSlotResponse]


class ConsultationSessionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    session_code: str
    patient_id: str
    counselor_id: str
    scheduled_start_time: datetime
    scheduled_end_time: datetime
    actual_start_time: datetime | None = None
    actual_end_time: datetime | None = None
    duration_minutes: int
    status: str
    is_extended: bool
    extension_requested_at: datetime | None = None
    extension_granted_at: datetime | None = None
    total_price: float
    counselor_earning: float
    platform_fee: float
    video_room_id: str | None = None
    soap_notes: dict[str, Any] | None = None
    created_at: datetime


class ExtensionAvailabilityResponse(BaseModel):
    session_id: str
    can_extend: bool
    extension_duration_minutes: int = 30
    extension_price: float
    reason: str | None = None
    next_available_slots: list[TimeSlotResponse] = []


class ClinicalNotesResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    session_id: str
    session_code: str
    patient_id: str
    counselor_id: str
    counselor_name: str
    scheduled_start_time: datetime
    soap_notes: dict[str, Any] | None = None


class ConsentStatusResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    patient_id: str
    counselor_id: str
    status: str
    is_granted: bool
    granted_at: datetime | None = None
    expires_at: datetime | None = None
