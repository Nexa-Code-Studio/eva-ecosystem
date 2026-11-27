from typing import Literal
import uuid

from fastapi import APIRouter, Depends, Query

from app.api.dependencies import get_counselor_service, get_current_admin
from app.models.user import User
from app.schemas.counselor import (
    PsychologistProfileResponse,
    ToggleDocumentVerificationRequest,
    UpdateCounselorStatusRequest,
)
from app.schemas.finances import TransactionResponse
from app.services.counselor import CounselorService

router = APIRouter(prefix="/admin/counselors", tags=["Admin Counselors"])


@router.get("", response_model=list[PsychologistProfileResponse])
async def list_admin_counselors(
    status: str | None = Query(default=None),
    search: str | None = Query(default=None),
    admin: User = Depends(get_current_admin),
    service: CounselorService = Depends(get_counselor_service),
) -> list[PsychologistProfileResponse]:
    """List all psychologist applicants and profiles across all verification statuses (Admin)."""
    return await service.list_all_counselors_for_admin(
        verification_status=status,
        search=search,
    )


@router.patch("/{counselor_id}/documents/{doc_type}/verify", response_model=PsychologistProfileResponse)
async def toggle_counselor_document_verification(
    counselor_id: uuid.UUID,
    doc_type: Literal["str", "sip"],
    payload: ToggleDocumentVerificationRequest | None = None,
    admin: User = Depends(get_current_admin),
    service: CounselorService = Depends(get_counselor_service),
) -> PsychologistProfileResponse:
    """Toggle or set STR/SIP credential document verification validity (Admin)."""
    verified = payload.verified if payload else None
    return await service.toggle_document_verification(counselor_id, doc_type, verified)


@router.patch("/{counselor_id}/status", response_model=PsychologistProfileResponse)
async def update_counselor_account_status(
    counselor_id: uuid.UUID,
    payload: UpdateCounselorStatusRequest,
    admin: User = Depends(get_current_admin),
    service: CounselorService = Depends(get_counselor_service),
) -> PsychologistProfileResponse:
    """Suspend or reactivate a psychologist profile verification status (Admin)."""
    return await service.update_counselor_account_status(counselor_id, admin.id, payload)


@router.get("/{counselor_id}/transactions", response_model=list[TransactionResponse])
async def list_admin_counselor_transactions(
    counselor_id: uuid.UUID,
    admin: User = Depends(get_current_admin),
    service: CounselorService = Depends(get_counselor_service),
) -> list[TransactionResponse]:
    """List coin earning and payout ledger transactions for a psychologist (Admin)."""
    return await service.list_counselor_transactions_for_admin(counselor_id)
