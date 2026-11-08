import logging

from fastapi import APIRouter, Depends, Query

from app.api.dependencies import get_current_user, get_recommendation_service
from app.models.user import User
from app.schemas.recommendation import (
    CompleteActivityResponse,
    CopingActivityResponse,
    TodayRecommendationResponse,
)
from app.services.recommendation import RecommendationService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/recommendations", tags=["Recommendations"])


@router.get("/today", response_model=TodayRecommendationResponse)
async def get_today_recommendation(
    user: User = Depends(get_current_user),
    service: RecommendationService = Depends(get_recommendation_service),
) -> TodayRecommendationResponse:
    """Retrieve today's tailored coping activities & guidance based on DASS-21, safety crisis, and diary scores."""
    return await service.get_today_recommendation(user.id)


@router.get("", response_model=list[CopingActivityResponse])
async def get_recommendations(
    condition: str | None = Query(None, description="Filter by condition: stress, anxiety, depression, general, crisis"),
    user: User = Depends(get_current_user),
    service: RecommendationService = Depends(get_recommendation_service),
) -> list[CopingActivityResponse]:
    """Get all available recommendations / coping activities sorted by condition."""
    return await service.get_recommendations(user.id, condition=condition)


@router.post("/{recommendation_id}/complete", response_model=CompleteActivityResponse)
async def mark_recommendation_completed(
    recommendation_id: str,
    user: User = Depends(get_current_user),
    service: RecommendationService = Depends(get_recommendation_service),
) -> CompleteActivityResponse:
    """Mark a recommendation or coping activity as completed for today."""
    return await service.mark_completed(user.id, recommendation_id)
