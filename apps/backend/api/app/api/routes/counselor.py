import uuid

from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import get_counselor_service, get_current_user
from app.models.user import User
from app.schemas.counselor import (
    PsychologistProfileResponse,
    PsychologistPublicResponse,
    PsychologistVerificationResponse,
    RegisterPsychologistRequest,
    ResubmitVerificationRequest,
    ToggleAvailabilityRequest,
    UpdateBankDetailsRequest,
    UpdatePsychologistProfileRequest,
    VerifyPsychologistRequest,
)
from app.services.counselor import CounselorService

router = APIRouter(prefix="/counselors", tags=["Counselors"])


@router.post("/register", response_model=PsychologistProfileResponse, status_code=status.HTTP_201_CREATED)
async def register_counselor(
    payload: RegisterPsychologistRequest,
    service: CounselorService = Depends(get_counselor_service),
) -> PsychologistProfileResponse:
    """Register a new professional psychologist with STR/SIP credentials and pending status."""
    return await service.register(payload)


@router.get("/me", response_model=PsychologistProfileResponse)
async def get_my_counselor_profile(
    user: User = Depends(get_current_user),
    service: CounselorService = Depends(get_counselor_service),
) -> PsychologistProfileResponse:
    """Get active counselor profile for current authenticated user."""
    return await service.get_profile_by_user_id(user.id)


@router.put("/me", response_model=PsychologistProfileResponse)
async def update_my_counselor_profile(
    payload: UpdatePsychologistProfileRequest,
    user: User = Depends(get_current_user),
    service: CounselorService = Depends(get_counselor_service),
) -> PsychologistProfileResponse:
    """Update profile information for current authenticated counselor."""
    return await service.update_profile(user.id, payload)


@router.post("/me/resubmit-verification", response_model=PsychologistVerificationResponse)
async def resubmit_counselor_verification(
    payload: ResubmitVerificationRequest,
    user: User = Depends(get_current_user),
    service: CounselorService = Depends(get_counselor_service),
) -> PsychologistVerificationResponse:
    """Submit revised STR/SIP certificate for verification reconsideration."""
    return await service.resubmit_verification(user.id, payload)


@router.patch("/me/availability", response_model=PsychologistProfileResponse)
async def toggle_counselor_availability(
    payload: ToggleAvailabilityRequest,
    user: User = Depends(get_current_user),
    service: CounselorService = Depends(get_counselor_service),
) -> PsychologistProfileResponse:
    """Toggle online availability status for incoming consultation bookings."""
    return await service.toggle_availability(user.id, payload.is_online)


@router.put("/me/bank-details", response_model=PsychologistProfileResponse)
async def update_counselor_bank_details(
    payload: UpdateBankDetailsRequest,
    user: User = Depends(get_current_user),
    service: CounselorService = Depends(get_counselor_service),
) -> PsychologistProfileResponse:
    """Update counselor bank account information for honorarium payouts."""
    return await service.update_bank_details(user.id, payload)


@router.get("", response_model=list[PsychologistPublicResponse])
async def list_verified_counselors(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    service: CounselorService = Depends(get_counselor_service),
) -> list[PsychologistPublicResponse]:
    """Public directory of active, verified psychologists available for teleconsultations."""
    return await service.list_verified_counselors(limit=limit, offset=offset)


@router.get("/{counselor_id}", response_model=PsychologistProfileResponse)
async def get_counselor_profile_by_id(
    counselor_id: uuid.UUID,
    service: CounselorService = Depends(get_counselor_service),
) -> PsychologistProfileResponse:
    """Get counselor profile by ID."""
    return await service.get_profile_by_id(counselor_id)


@router.post("/{counselor_id}/verify", response_model=PsychologistVerificationResponse)
async def verify_counselor(
    counselor_id: uuid.UUID,
    payload: VerifyPsychologistRequest,
    admin: User = Depends(get_current_user),
    service: CounselorService = Depends(get_counselor_service),
) -> PsychologistVerificationResponse:
    """Review and verify or reject a psychologist's professional credentials (Admin)."""
    return await service.verify_counselor(counselor_id, admin.id, payload)
