import uuid

from fastapi import APIRouter, Depends, status

from app.api.dependencies import get_current_user, get_scheduling_service
from app.models.user import User
from app.schemas.session import (
    ConsultationSessionResponse,
    ExtensionAvailabilityResponse,
    SoapSynthesisResponse,
    SynthesizeSoapRequest,
    UpdateSoapNotesRequest,
)
from app.services.session import SchedulingService

router = APIRouter(prefix="/sessions", tags=["Sessions"])


@router.get("/{session_id}/extension-availability", response_model=ExtensionAvailabilityResponse)
async def check_session_extension_availability(
    session_id: uuid.UUID,
    user: User = Depends(get_current_user),
    service: SchedulingService = Depends(get_scheduling_service),
) -> ExtensionAvailabilityResponse:
    """Check in real-time if an active consultation session can be extended by +30 minutes."""
    return await service.check_extension_availability(session_id)


@router.post("/{session_id}/extend", response_model=ConsultationSessionResponse)
async def extend_active_session(
    session_id: uuid.UUID,
    user: User = Depends(get_current_user),
    service: SchedulingService = Depends(get_scheduling_service),
) -> ConsultationSessionResponse:
    """Extend ongoing consultation session by +30 minutes (60 min total) without interrupting call."""
    return await service.extend_session(session_id, user.id)


@router.put("/{session_id}/soap-notes", response_model=ConsultationSessionResponse)
async def save_session_soap_notes(
    session_id: uuid.UUID,
    payload: UpdateSoapNotesRequest,
    user: User = Depends(get_current_user),
    service: SchedulingService = Depends(get_scheduling_service),
) -> ConsultationSessionResponse:
    """Save verified SOAP clinical notes for a completed teleconsultation session."""
    return await service.save_soap_notes(session_id, user.id, payload)


@router.post("/soap-synthesis", response_model=SoapSynthesisResponse)
async def synthesize_soap_notes(
    payload: SynthesizeSoapRequest,
    user: User = Depends(get_current_user),
    service: SchedulingService = Depends(get_scheduling_service),
) -> SoapSynthesisResponse:
    """Synthesize clinical SOAP note from video call conversation transcript using Eva AI."""
    result = await service.synthesize_soap(
        transcript=payload.transcript,
        patient_name=payload.patient_name,
    )
    return SoapSynthesisResponse(**result)


@router.post("/{session_id}/synthesize-soap", response_model=SoapSynthesisResponse)
async def synthesize_session_soap_notes(
    session_id: uuid.UUID,
    payload: SynthesizeSoapRequest,
    user: User = Depends(get_current_user),
    service: SchedulingService = Depends(get_scheduling_service),
) -> SoapSynthesisResponse:
    """Synthesize clinical SOAP note for a specific consultation session using Eva AI."""
    result = await service.synthesize_soap(
        transcript=payload.transcript,
        patient_name=payload.patient_name,
        session_id=session_id,
    )
    return SoapSynthesisResponse(**result)
