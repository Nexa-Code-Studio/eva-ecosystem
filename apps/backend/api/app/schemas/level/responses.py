from datetime import datetime

from pydantic import BaseModel, ConfigDict


class PsychologistLevelResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    level_tier: int
    name: str
    badge_icon: str
    min_completed_sessions: int
    min_average_rating: float
    min_consultation_hours: float
    min_review_count: int
    default_session_price: float
    platform_fee_percentage: float
    allow_custom_price: bool
    min_custom_price: float | None = None
    max_custom_price: float | None = None
    is_active: bool
    created_at: datetime
    updated_at: datetime


class LevelProgressRequirementResponse(BaseModel):
    completed_sessions: int
    min_completed_sessions: int
    consultation_hours: float
    min_consultation_hours: float
    average_rating: float
    min_average_rating: float
    review_count: int
    min_review_count: int


class CounselorLevelMetricsResponse(BaseModel):
    counselor_id: str
    total_completed_sessions: int
    total_consultation_hours: float
    average_rating: float
    rating_count: int
    effective_session_price: float
    platform_fee_percentage: float
    counselor_share_percentage: float
    custom_price_per_session: float | None = None
    current_level: PsychologistLevelResponse | None = None
    next_level: PsychologistLevelResponse | None = None
    next_level_progress: LevelProgressRequirementResponse | None = None
    all_levels: list[PsychologistLevelResponse] = []


class CounselorPricingResponse(BaseModel):
    counselor_id: str
    current_level_id: str | None = None
    current_level_name: str | None = None
    default_session_price: float
    custom_price_per_session: float | None = None
    effective_session_price: float
    allow_custom_price: bool
    min_custom_price: float | None = None
    max_custom_price: float | None = None
    platform_fee_percentage: float
    counselor_share_percentage: float
    message: str


class CounselorReviewResponse(BaseModel):
    id: str
    session_id: str
    counselor_id: str
    patient_id: str
    patient_display_name: str
    rating: float
    highlight_label: str | None = None
    review_text: str | None = None
    is_anonymous: bool
    created_at: datetime


class LevelEvaluationBatchResponse(BaseModel):
    evaluated_counselors: int
    upgraded_count: int
    message: str


class LevelActionMessageResponse(BaseModel):
    message: str
