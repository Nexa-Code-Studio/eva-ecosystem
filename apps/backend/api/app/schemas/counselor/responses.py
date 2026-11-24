from datetime import datetime
from typing import Any
from pydantic import BaseModel, ConfigDict


class PsychologistProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    email: str | None = None
    full_name: str
    title_degree: str
    education: str | None = None
    str_number: str
    str_doc_url: str | None = None
    str_issuing_institution: str | None = None
    str_expiry_date: str | None = None
    str_verified: bool = False
    sip_number: str | None = None
    sip_doc_url: str | None = None
    sip_issuing_institution: str | None = None
    sip_expiry_date: str | None = None
    sip_verified: bool = False
    association: str
    specializations: list[str] = []
    years_of_experience: int
    bio: str | None = None
    profile_photo_url: str | None = None
    certificate_doc_url: str | None = None
    verification_status: str
    verification_notes: str | None = None
    verified_at: datetime | None = None
    is_online: bool
    buffer_time_minutes: int
    schedule_config: dict[str, Any] = {}
    bank_name: str | None = None
    bank_account_number: str | None = None
    bank_account_holder: str | None = None
    wallet_balance: float
    current_level_id: str | None = None
    level_tier: int | None = None
    level_name: str | None = None
    level_badge_icon: str | None = None
    effective_session_price: float = 150.0
    platform_fee_percentage: float = 20.0
    allow_custom_price: bool = False
    custom_price_per_session: float | None = None
    total_completed_sessions: int = 0
    total_consultation_hours: float = 0.0
    average_rating: float = 0.0
    rating_count: int = 0
    created_at: datetime


class PsychologistPublicResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    full_name: str
    title_degree: str
    association: str
    specializations: list[str] = []
    years_of_experience: int
    bio: str | None = None
    profile_photo_url: str | None = None
    is_online: bool
    buffer_time_minutes: int
    level_tier: int | None = None
    level_name: str | None = None
    level_badge_icon: str | None = None
    effective_session_price: float = 150.0
    platform_fee_percentage: float = 20.0
    total_completed_sessions: int = 0
    total_consultation_hours: float = 0.0
    average_rating: float = 0.0
    rating_count: int = 0


class PsychologistVerificationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    verification_status: str
    verification_notes: str | None = None
    verified_at: datetime | None = None
    message: str


class PsychologistMessageResponse(BaseModel):
    message: str


class DayBreakResponse(BaseModel):
    start: str
    end: str
    label: str = "Istirahat"


class DayScheduleResponse(BaseModel):
    is_active: bool = True
    operating_hours: dict[str, str] = {"start": "08:00", "end": "17:00"}
    breaks: list[DayBreakResponse] = []


class ScheduleConfigResponse(BaseModel):
    counselor_id: str
    buffer_time_minutes: int
    schedule_config: dict[str, Any]


class OperatingHoursItem(BaseModel):
    start: str
    end: str


class BlockedRangeItem(BaseModel):
    start: str
    end: str
    type: str  # "break", "booked", "buffer"
    label: str | None = None


class TimeRangeItem(BaseModel):
    start: str
    end: str


class CounselorTimelineResponse(BaseModel):
    counselor_id: str
    date: str
    operating_hours: OperatingHoursItem
    buffer_time_minutes: int
    blocked_ranges: list[BlockedRangeItem] = []
    available_windows: list[TimeRangeItem] = []
