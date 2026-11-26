from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

BoothVisitorRoleLiteral = Literal["user", "counselor"]


class BoothFeedbackPhotoResponse(BaseModel):
    """Metadata of an uploaded booth selfie photo belonging to a feedback entry."""

    id: str
    mime_type: str
    file_size_bytes: int
    sort_order: int
    created_at: datetime


class BoothFeedbackItemResponse(BaseModel):
    """Detailed booth feedback record returned to Admin Portal reviewers."""

    id: str
    rating: int
    usage_likelihood: int
    recommendation_score: int
    visitor_role: BoothVisitorRoleLiteral = "user"
    message: str
    visitor_name: str | None = None
    visitor_contact: str | None = None
    event_label: str
    photos: list[BoothFeedbackPhotoResponse]
    created_at: datetime


class BoothFeedbackSummaryResponse(BaseModel):
    """Aggregated event booth rating metrics across all saved visitor submissions."""

    total_count: int
    average_rating: float
    rating_counts: dict[int, int]
    role_counts: dict[str, int] = Field(default_factory=lambda: {"user": 0, "counselor": 0})
    average_usage_likelihood: float = 0.0
    high_usage_intent_count: int = 0
    high_usage_intent_percentage: float = 0.0
    average_recommendation_score: float = 0.0
    promoter_count: int = 0
    promoter_percentage: float = 0.0


class AdminBoothFeedbackListResponse(BaseModel):
    """Paginated Admin response containing summary stats and filtered booth feedback items."""

    summary: BoothFeedbackSummaryResponse
    items: list[BoothFeedbackItemResponse]
    total: int
    page: int
    page_size: int


class PublicBoothFeedbackCreateResponse(BaseModel):
    """Confirmation payload returned after a booth visitor submits feedback and selfies."""

    id: str
    rating: int
    usage_likelihood: int
    recommendation_score: int
    visitor_role: BoothVisitorRoleLiteral = "user"
    photo_count: int
    created_at: datetime
    message: str


class BoothFeedbackDeleteResponse(BaseModel):
    """Confirmation payload returned when an admin deletes a booth feedback entry."""

    deleted_id: str
    status: str = "deleted"
