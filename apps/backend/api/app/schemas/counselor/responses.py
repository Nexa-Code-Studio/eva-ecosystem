from datetime import datetime
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
    bank_name: str | None = None
    bank_account_number: str | None = None
    bank_account_holder: str | None = None
    wallet_balance: float
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


class PsychologistVerificationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    verification_status: str
    verification_notes: str | None = None
    verified_at: datetime | None = None
    message: str


class PsychologistMessageResponse(BaseModel):
    message: str
