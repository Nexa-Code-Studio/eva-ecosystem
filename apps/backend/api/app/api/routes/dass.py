import logging
import uuid

from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user, get_dass_service
from app.models.user import User
from app.schemas.dass import DASSAssessmentResponse, DASSAssessmentUpdate
from app.services.dass import DASSService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/dass", tags=["DASS-21"])


@router.get("/today", response_model=DASSAssessmentResponse)
async def get_today_dass(
    user: User = Depends(get_current_user),
    service: DASSService = Depends(get_dass_service),
) -> DASSAssessmentResponse:
    """Retrieve today's DASS-21 assessment status and items for the authenticated user."""
    return await service.get_today_assessment(user.id)


@router.put("/today", response_model=DASSAssessmentResponse)
async def update_today_dass(
    payload: DASSAssessmentUpdate,
    user: User = Depends(get_current_user),
    service: DASSService = Depends(get_dass_service),
) -> DASSAssessmentResponse:
    """Receive user item score corrections and recalculate subscale severity scores."""
    return await service.update_user_assessment(user.id, payload.items)


@router.put("/{assessment_id}", response_model=DASSAssessmentResponse)
async def update_dass_by_id(
    assessment_id: uuid.UUID,
    payload: DASSAssessmentUpdate,
    user: User = Depends(get_current_user),
    service: DASSService = Depends(get_dass_service),
) -> DASSAssessmentResponse:
    """Receive user score corrections for a specific assessment ID."""
    return await service.update_user_assessment(user.id, payload.items, assessment_id=assessment_id)


@router.post("/extract-today", response_model=DASSAssessmentResponse)
async def extract_today_dass(
    user: User = Depends(get_current_user),
    service: DASSService = Depends(get_dass_service),
) -> DASSAssessmentResponse:
    """Trigger AI extraction analysis of 21 DASS items from all conversation transcripts today."""
    return await service.extract_today_assessment(user.id)
