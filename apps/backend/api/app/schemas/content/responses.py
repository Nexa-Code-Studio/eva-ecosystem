from datetime import datetime
from pydantic import BaseModel, ConfigDict


class CrisisConfigResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    hotline_number: str
    hotline_label: str
    extreme_depression_threshold: int
    extreme_anxiety_threshold: int
    auto_safety_net_modal: bool
    allow_direct_independent_referral: bool
    updated_at: datetime


class FaqEntryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    category: str
    question: str
    answer: str
    is_published: bool
    sort_order: int
    created_at: datetime
    updated_at: datetime


class FaqDeleteResponse(BaseModel):
    message: str
    deleted_id: str
