import uuid

from fastapi import APIRouter, Depends, status

from app.api.dependencies import get_care_service, get_current_user
from app.models.user import User
from app.schemas.care import (
    CallStatusResponse,
    ClinicalShareRequest,
    ClinicalShareResponse,
    RevokeClinicalShareResponse,
    SharedClinicalBundleResponse,
    UpdateCallStatusRequest,
    VideoTokenResponse,
)
from app.services.care import CareService

router = APIRouter(prefix="/care", tags=["Care"])


@router.post(
    "/sessions/{session_id}/video-token",
    response_model=VideoTokenResponse,
    status_code=status.HTTP_201_CREATED,
)
async def generate_video_token(
    session_id: uuid.UUID,
    user: User = Depends(get_current_user),
    service: CareService = Depends(get_care_service),
) -> VideoTokenResponse:
    """Generate authenticated WebRTC / signaling room token for teleconsultation video call."""
    return await service.get_video_token(session_id, user.id)


@router.post("/sessions/{session_id}/status", response_model=CallStatusResponse)
async def update_call_status(
    session_id: uuid.UUID,
    payload: UpdateCallStatusRequest,
    user: User = Depends(get_current_user),
    service: CareService = Depends(get_care_service),
) -> CallStatusResponse:
    """Update call session connection status, duration, and completion event."""
    return await service.update_call_status(session_id, user.id, payload)


@router.post(
    "/bookings/{booking_id}/clinical-share",
    response_model=ClinicalShareResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_clinical_share(
    booking_id: uuid.UUID,
    payload: ClinicalShareRequest,
    user: User = Depends(get_current_user),
    service: CareService = Depends(get_care_service),
) -> ClinicalShareResponse:
    """Consent-based clinical data share upload by patient for a specific consultation booking."""
    return await service.create_clinical_share(booking_id, user.id, payload)


@router.delete(
    "/bookings/{booking_id}/clinical-share",
    response_model=RevokeClinicalShareResponse,
)
async def revoke_clinical_share(
    booking_id: uuid.UUID,
    user: User = Depends(get_current_user),
    service: CareService = Depends(get_care_service),
) -> RevokeClinicalShareResponse:
    """Revoke consented clinical data sharing for a booking."""
    return await service.revoke_clinical_share(booking_id, user.id)


@router.get(
    "/sessions/{session_id}/shared-clinical-bundle",
    response_model=SharedClinicalBundleResponse,
)
async def get_shared_clinical_bundle(
    session_id: uuid.UUID,
    user: User = Depends(get_current_user),
    service: CareService = Depends(get_care_service),
) -> SharedClinicalBundleResponse:
    """Retrieve consented clinical data bundle for authorized psychologist or patient."""
    return await service.get_shared_clinical_bundle(session_id, user.id)
