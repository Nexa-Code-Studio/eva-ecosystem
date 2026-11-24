import uuid

from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import (

    get_counselor_service,
    get_current_admin,
    get_current_user,
    get_scheduling_service,
)
from app.models.user import User
from app.schemas.care import (
    BookConsultationRequest,
    CareRatingResponse,
    CareSessionResponse,
    CounselorTimelineResponse,
    SubmitRatingRequest,
)
from app.schemas.counselor import (
    CounselorTimelineResponse,
    PsychologistProfileResponse,
    PsychologistPublicResponse,
    PsychologistVerificationResponse,
    RegisterPsychologistRequest,
    ResubmitVerificationRequest,
    ScheduleConfigResponse,
    ToggleAvailabilityRequest,
    UpdateBankDetailsRequest,
    UpdatePsychologistProfileRequest,
    UpdateScheduleConfigRequest,
    VerifyPsychologistRequest,
)
from app.schemas.session import AvailableSlotsResponse, BookSessionRequest, ConsultationSessionResponse
from app.services.care import CareService
from app.services.counselor import CounselorService
from app.services.session import SchedulingService

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


@router.get("/me/schedule-config", response_model=ScheduleConfigResponse)
async def get_my_schedule_config(
    user: User = Depends(get_current_user),
    service: CounselorService = Depends(get_counselor_service),
) -> ScheduleConfigResponse:
    """Retrieve counselor weekly schedule configuration and break periods."""
    return await service.get_schedule_config(user.id)


@router.put("/me/schedule-config", response_model=ScheduleConfigResponse)
async def update_my_schedule_config(
    payload: UpdateScheduleConfigRequest,
    user: User = Depends(get_current_user),
    service: CounselorService = Depends(get_counselor_service),
) -> ScheduleConfigResponse:
    """Update counselor weekly schedule configuration with multi-breaks."""
    return await service.update_schedule_config(user.id, payload)


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
    admin: User = Depends(get_current_admin),
    service: CounselorService = Depends(get_counselor_service),
) -> PsychologistVerificationResponse:
    """Review and verify or reject a psychologist's professional credentials (Admin)."""
    return await service.verify_counselor(counselor_id, admin.id, payload)


@router.get("/{counselor_id}/available-slots", response_model=AvailableSlotsResponse)
async def get_counselor_available_slots(
    counselor_id: uuid.UUID,
    date: str = Query(..., pattern=r"^\d{4}-\d{2}-\d{2}$"),
    service: SchedulingService = Depends(get_scheduling_service),
) -> AvailableSlotsResponse:
    """Get dynamic 30-minute teleconsultation slots based on counselor availability and buffers."""
    return await service.get_available_slots(counselor_id, date)


@router.get("/{counselor_id}/timeline", response_model=CounselorTimelineResponse)
async def get_counselor_timeline(
    counselor_id: uuid.UUID,
    date: str = Query(..., pattern=r"^\d{4}-\d{2}-\d{2}$"),
    service: SchedulingService = Depends(get_scheduling_service),
) -> CounselorTimelineResponse:
    """Get counselor availability timeline with operating hours, multi-breaks, and booked slots."""
    return await service.get_counselor_timeline(counselor_id, date)


@router.post("/{counselor_id}/book", response_model=ConsultationSessionResponse, status_code=status.HTTP_201_CREATED)
async def book_counselor_session(
    counselor_id: uuid.UUID,
    payload: BookConsultationRequest,
    patient: User = Depends(get_current_user),
    service: CareService = Depends(get_care_service),
) -> CareSessionResponse:
    """Book a teleconsultation session with dynamic duration and anti-collision validation."""
    return await service.book_consultation(patient.id, counselor_id, payload)


@router.post("/{counselor_id}/ratings", response_model=CareRatingResponse)
async def submit_counselor_rating(
    counselor_id: uuid.UUID,
    payload: SubmitRatingRequest,
    user: User = Depends(get_current_user),
    service: CareService = Depends(get_care_service),
) -> CareRatingResponse:
    """Submit rating review and feedback for a psychologist."""
    return await service.submit_counselor_rating(user.id, counselor_id, payload)


