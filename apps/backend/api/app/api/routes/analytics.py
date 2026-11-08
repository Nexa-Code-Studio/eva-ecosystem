import logging

from fastapi import APIRouter, Depends, Query

from app.api.dependencies import get_analytics_service, get_current_user
from app.models.user import User
from app.schemas.analytics import MonitoringDataResponse
from app.services.analytics import AnalyticsService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/analytics", tags=["Analytics"])


@router.get("/monitoring", response_model=MonitoringDataResponse)
async def get_monitoring_data(
    period: str = Query("today", description="Period: today | week | month"),
    user: User = Depends(get_current_user),
    service: AnalyticsService = Depends(get_analytics_service),
) -> MonitoringDataResponse:
    """Fetch emotional rhythm, mental health risks, and AI summary for the requested period."""
    return await service.get_data(user.id, period=period)
