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
    is_granted: bool = False
    granted_at: datetime | None = None
    expires_at: datetime | None = None


class SoapSynthesisResponse(BaseModel):
    subjective: str
    objective: str
    assessment: str
    plan: str
    model_used: str
    synthesized_at: datetime


class PatientScheduleResponse(BaseModel):
    session_id: str
    scheduled_start_time: str
    duration_minutes: int = 30
    status: str = "scheduled"


class DassAssessmentItemResponse(BaseModel):
    date: str
    depression_score: int = 0
    anxiety_score: int = 0
    stress_score: int = 0
    depression_severity: str = "Normal"
    anxiety_severity: str = "Normal"
    stress_severity: str = "Normal"


class ClinicalTriggerItem(BaseModel):
    category: str
    description: str
    severity: str = "Sedang"
    source: str = "Observasi Klinis"
    detected_at: str


class PatientClinicalTriggersResponse(BaseModel):
    patient_id: str
    chief_complaint: str
    triggers: list[ClinicalTriggerItem] = []
    emotional_summary: str = ""
    privacy_ethics_notice: str = (
        "Berdasarkan Kode Etik Psikologi Indonesia (HIMPSI Bab IV Pasal 24 Kerahasiaan Rekam dan Data Pribadi Pasien), "
        "seluruh data pemicu dan keluhan dibatasi pada data esensial klinis dan dilindungi kerahasiaannya."
    )
class CounselorPatientResponse(BaseModel):
    id: str
    name: str
    age: int = 25
    gender: str = "L"
    chief_complaint: str = "-"
    latest_mood_tag: str = "Tenang & Nyaman"
    emotional_risk_score: int = 2
    is_high_risk: bool = False
    has_consent: bool = False
    last_session_date: str
    total_completed_sessions: int = 0
    consent_requested_at: str | None = None
    dass_history: list[DassAssessmentItemResponse] | None = None
    shared_diary_summaries: list[str] | None = None
    triggers: list[ClinicalTriggerItem] | None = None
    clinical_points: list[str] | None = None
    upcoming_schedule: PatientScheduleResponse | None = None


class RequestConsentResponse(BaseModel):
    success: bool = True
    message: str = "Permohonan akses rekam medis berhasil dikirim ke pasien."


class ClinicalNoteDetailResponse(BaseModel):
    id: str
    patient_id: str
    session_id: str
    created_at: str
    subjective: str
    objective: str
    assessment: str
    plan: str
    points: list[str] = []
    narrative: str = ""
    recommended_tasks: list[str] = []
    coins_awarded: int = 0
    coin_balance: int | None = None
    soap_edit_deadline: datetime | None = None
    is_soap_editable: bool = True


class AdminSessionMonitoringResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    session_code: str
    patient_code: str
    patient_display_name: str
    counselor_id: str
    counselor_name: str
    counselor_title: str
    scheduled_start_time: datetime
    scheduled_end_time: datetime
    duration_minutes: int
    is_extended: bool
    status: str
    total_price_coins: int
    counselor_earning_coins: int
    platform_fee_coins: int
    clinical_summary: str | None = None
