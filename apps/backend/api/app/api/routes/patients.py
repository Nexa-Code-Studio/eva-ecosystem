import uuid

from fastapi import APIRouter, Depends, status

from app.api.dependencies import get_current_user, get_scheduling_service
from app.models.user import User
from app.schemas.session import (
    ClinicalNotesResponse,
    ConsentStatusResponse,
    UpdateConsentStatusRequest,
)
from app.services.session import SchedulingService

router = APIRouter(prefix="/patients", tags=["Patients"])


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
