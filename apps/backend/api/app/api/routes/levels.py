import uuid

from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import get_current_admin, get_current_user, get_level_service
from app.models.user import User
from app.schemas.level import (
    CounselorLevelMetricsResponse,
    CounselorPricingResponse,
    CounselorReviewResponse,
    LevelActionMessageResponse,
    LevelEvaluationBatchResponse,
    PsychologistLevelResponse,
    UpdateCounselorCustomPricingRequest,
    UpsertPsychologistLevelRequest,
)
from app.services.level import LevelService

admin_router = APIRouter(prefix="/admin/psychologist-levels", tags=["Admin Psychologist Levels"])
counselor_router = APIRouter(prefix="/counselors", tags=["Counselors"])


@admin_router.get("", response_model=list[PsychologistLevelResponse])
async def list_psychologist_levels(
    active_only: bool = Query(default=False),
    admin: User = Depends(get_current_admin),
    service: LevelService = Depends(get_level_service),
) -> list[PsychologistLevelResponse]:
    """List all configurable psychologist career tiers and pricing rules."""
    return await service.list_levels(active_only=active_only)


@admin_router.post("", response_model=PsychologistLevelResponse, status_code=status.HTTP_201_CREATED)
async def create_psychologist_level(
    payload: UpsertPsychologistLevelRequest,
    admin: User = Depends(get_current_admin),
    service: LevelService = Depends(get_level_service),
) -> PsychologistLevelResponse:
    """Create a new dynamic psychologist career level configuration."""
    return await service.create_level(payload)


@admin_router.put("/{level_id}", response_model=PsychologistLevelResponse)
async def update_psychologist_level(
    level_id: uuid.UUID,
    payload: UpsertPsychologistLevelRequest,
    admin: User = Depends(get_current_admin),
    service: LevelService = Depends(get_level_service),
) -> PsychologistLevelResponse:
    """Update requirements, default tariff, platform fee split, or custom pricing rules."""
    return await service.update_level(level_id, payload)


@admin_router.patch("/{level_id}/toggle", response_model=PsychologistLevelResponse)
async def toggle_psychologist_level(
    level_id: uuid.UUID,
    admin: User = Depends(get_current_admin),
    service: LevelService = Depends(get_level_service),
) -> PsychologistLevelResponse:
    """Toggle active status of a psychologist career tier."""
    return await service.toggle_level_active(level_id)


@admin_router.delete("/{level_id}", response_model=LevelActionMessageResponse)
async def delete_psychologist_level(
    level_id: uuid.UUID,
    admin: User = Depends(get_current_admin),
    service: LevelService = Depends(get_level_service),
) -> LevelActionMessageResponse:
    """Delete or deactivate an obsolete psychologist career tier."""
    await service.delete_level(level_id)
    return LevelActionMessageResponse(message="Konfigurasi tier level berhasil dihapus/dinonaktifkan.")


@admin_router.post("/evaluate-all", response_model=LevelEvaluationBatchResponse)
async def evaluate_all_psychologist_levels(
    admin: User = Depends(get_current_admin),
    service: LevelService = Depends(get_level_service),
) -> LevelEvaluationBatchResponse:
    """Recompute real metrics and evaluate career tier upgrades across all verified counselors."""
    return await service.evaluate_all_counselors()


@counselor_router.get("/me/level-metrics", response_model=CounselorLevelMetricsResponse)
async def get_my_level_metrics(
    user: User = Depends(get_current_user),
    service: LevelService = Depends(get_level_service),
) -> CounselorLevelMetricsResponse:
    """Retrieve dynamic career level metrics, next-tier requirements, and active session tariff."""
    return await service.get_counselor_level_metrics(user.id)


@counselor_router.patch("/me/pricing", response_model=CounselorPricingResponse)
async def update_my_pricing(
    payload: UpdateCounselorCustomPricingRequest,
    user: User = Depends(get_current_user),
    service: LevelService = Depends(get_level_service),
) -> CounselorPricingResponse:
    """Update counselor custom session fee within admin-configured bounds."""
    return await service.update_counselor_pricing(user.id, payload)


@counselor_router.get("/me/reviews", response_model=list[CounselorReviewResponse])
async def list_my_reviews(
    limit: int = Query(default=30, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    user: User = Depends(get_current_user),
    service: LevelService = Depends(get_level_service),
) -> list[CounselorReviewResponse]:
    """List verified patient reviews for the currently authenticated psychologist."""
    return await service.list_counselor_reviews_by_user(user.id, limit=limit, offset=offset)


@counselor_router.get("/{counselor_id}/reviews", response_model=list[CounselorReviewResponse])
async def list_counselor_reviews_public(
    counselor_id: uuid.UUID,
    limit: int = Query(default=30, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    service: LevelService = Depends(get_level_service),
) -> list[CounselorReviewResponse]:
    """List patient reviews for a psychologist profile (anonymous reviews masked)."""
    return await service.list_counselor_reviews(counselor_id, limit=limit, offset=offset)
