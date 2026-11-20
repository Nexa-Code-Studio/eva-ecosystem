import uuid
from typing import Any

from fastapi import APIRouter, Depends, status

from app.api.dependencies import get_current_user, get_scheduling_service
from app.models.user import User
from app.schemas.session import (
    ClinicalNoteDetailResponse,
    ClinicalNotesResponse,
    ConsentStatusResponse,
    CounselorPatientResponse,
    CreateClinicalNoteRequest,
    RequestConsentResponse,
    UpdateConsentStatusRequest,
)
from app.services.session import SchedulingService

router = APIRouter(prefix="/patients", tags=["Patients"])


@router.get("", response_model=list[CounselorPatientResponse])
async def list_counselor_patients(
    user: User = Depends(get_current_user),
    service: SchedulingService = Depends(get_scheduling_service),
) -> list[CounselorPatientResponse]:
    """List all patients associated with the authenticated counselor."""
    return await service.get_counselor_patients(user.id)


@router.get("/{patient_id}", response_model=CounselorPatientResponse)
async def get_patient_detail(
    patient_id: uuid.UUID,
    user: User = Depends(get_current_user),
    service: SchedulingService = Depends(get_scheduling_service),
) -> CounselorPatientResponse:
    """Retrieve detailed profile, DASS assessment, and history for a patient."""
    return await service.get_patient_detail_for_counselor(user.id, patient_id)


@router.post("/{patient_id}/request-consent", response_model=RequestConsentResponse)
async def request_patient_consent(
    patient_id: uuid.UUID,
    user: User = Depends(get_current_user),
    service: SchedulingService = Depends(get_scheduling_service),
) -> RequestConsentResponse:
    """Send patient record access consent request from counselor."""
    return await service.request_patient_consent(user.id, patient_id)


@router.post("/{patient_id}/clinical-notes", response_model=ClinicalNoteDetailResponse, status_code=status.HTTP_201_CREATED)
async def create_patient_clinical_note(
    patient_id: uuid.UUID,
    payload: CreateClinicalNoteRequest,
    user: User = Depends(get_current_user),
    service: SchedulingService = Depends(get_scheduling_service),
) -> ClinicalNoteDetailResponse:
    """Create and persist a SOAP clinical consultation note."""
    return await service.create_clinical_note(user.id, patient_id, payload)


@router.get("/{patient_id}/clinical-notes", response_model=list[ClinicalNotesResponse])
async def get_patient_clinical_notes(
    patient_id: uuid.UUID,
    user: User = Depends(get_current_user),
    service: SchedulingService = Depends(get_scheduling_service),
) -> list[ClinicalNotesResponse]:
    """Get history of verified SOAP clinical notes for a patient."""
    return await service.get_patient_clinical_notes(patient_id)


@router.get("/{patient_id}/consent/{counselor_id}", response_model=ConsentStatusResponse)
async def get_patient_consent_status(
    patient_id: uuid.UUID,
    counselor_id: uuid.UUID,
    user: User = Depends(get_current_user),
    service: SchedulingService = Depends(get_scheduling_service),
) -> ConsentStatusResponse:
    """Check active consent granting counselor access to patient screening and journal records."""
    return await service.get_consent_status(patient_id, counselor_id)


@router.post("/{patient_id}/consent/{counselor_id}", response_model=ConsentStatusResponse)
async def update_patient_consent_status(
    patient_id: uuid.UUID,
    counselor_id: uuid.UUID,
    payload: UpdateConsentStatusRequest,
    user: User = Depends(get_current_user),
    service: SchedulingService = Depends(get_scheduling_service),
) -> ConsentStatusResponse:
    """Grant, update, or revoke counselor consent for patient data access."""
    return await service.update_consent_status(patient_id, counselor_id, payload.status)
