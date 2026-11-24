import uuid

from fastapi import APIRouter, Depends, status
from fastapi.responses import StreamingResponse

from app.api.dependencies import get_certificate_service, get_current_admin, get_current_user
from app.models.user import User
from app.schemas.certificate import (
    CertificateEvaluationSummaryResponse,
    CertificateTemplateResponse,
    CounselorCertificateEligibilityResponse,
    IssueCertificateRequest,
    PsychologistCertificateResponse,
    RevokeCertificateRequest,
    UpsertCertificateTemplateRequest,
)
from app.services.certificate import CertificateService

counselor_router = APIRouter(prefix="/counselor/certificates", tags=["Counselor Certificates"])
admin_router = APIRouter(prefix="/admin/certificates", tags=["Admin Certificates"])


def _pdf_streaming_response(stream, filename: str) -> StreamingResponse:
    headers = {"Content-Disposition": f'attachment; filename="{filename}"'}
    return StreamingResponse(stream, media_type="application/pdf", headers=headers)


@counselor_router.get("", response_model=list[PsychologistCertificateResponse])
async def list_counselor_certificates(
    user: User = Depends(get_current_user),
    service: CertificateService = Depends(get_certificate_service),
) -> list[PsychologistCertificateResponse]:
    """List official active certificates awarded to the authenticated psychologist."""
    return await service.list_my_certificates(user.id)


@counselor_router.get("/{certificate_id}/download")
async def download_counselor_certificate_pdf(
    certificate_id: uuid.UUID,
    user: User = Depends(get_current_user),
    service: CertificateService = Depends(get_certificate_service),
) -> StreamingResponse:
    """Download official watermarked PDF certificate owned by the authenticated psychologist."""
    stream, filename = await service.stream_certificate_pdf(certificate_id, user)
    return _pdf_streaming_response(stream, filename)


@admin_router.get("/templates", response_model=list[CertificateTemplateResponse])
async def list_admin_certificate_templates(
    admin: User = Depends(get_current_admin),
    service: CertificateService = Depends(get_certificate_service),
) -> list[CertificateTemplateResponse]:
    """List all certificate templates and automated issuance rules (Admin)."""
    return await service.list_templates(active_only=False)


@admin_router.post("/templates", response_model=CertificateTemplateResponse, status_code=status.HTTP_201_CREATED)
async def create_certificate_template(
    payload: UpsertCertificateTemplateRequest,
    admin: User = Depends(get_current_admin),
    service: CertificateService = Depends(get_certificate_service),
) -> CertificateTemplateResponse:
    """Create a new certificate template and issuance trigger rule (Admin)."""
    return await service.create_template(payload)


@admin_router.put("/templates/{template_id}", response_model=CertificateTemplateResponse)
async def update_certificate_template(
    template_id: uuid.UUID,
    payload: UpsertCertificateTemplateRequest,
    admin: User = Depends(get_current_admin),
    service: CertificateService = Depends(get_certificate_service),
) -> CertificateTemplateResponse:
    """Update an existing certificate template and trigger thresholds (Admin)."""
    return await service.update_template(template_id, payload)


@admin_router.patch("/templates/{template_id}/toggle", response_model=CertificateTemplateResponse)
async def toggle_certificate_template_active(
    template_id: uuid.UUID,
    admin: User = Depends(get_current_admin),
    service: CertificateService = Depends(get_certificate_service),
) -> CertificateTemplateResponse:
    """Toggle active status of a certificate template (Admin)."""
    return await service.toggle_template_active(template_id)


@admin_router.get("", response_model=list[PsychologistCertificateResponse])
async def list_admin_certificates(
    admin: User = Depends(get_current_admin),
    service: CertificateService = Depends(get_certificate_service),
) -> list[PsychologistCertificateResponse]:
    """List all issued psychologist certificates across the platform (Admin)."""
    return await service.list_admin_certificates()


@admin_router.get("/eligible-counselors", response_model=list[CounselorCertificateEligibilityResponse])
async def list_eligible_counselors(
    admin: User = Depends(get_current_admin),
    service: CertificateService = Depends(get_certificate_service),
) -> list[CounselorCertificateEligibilityResponse]:
    """List verified psychologists with session counts and ratings for issuance (Admin)."""
    return await service.list_eligible_counselors()


@admin_router.post("/issue", response_model=PsychologistCertificateResponse, status_code=status.HTTP_201_CREATED)
async def issue_certificate_manual(
    payload: IssueCertificateRequest,
    admin: User = Depends(get_current_admin),
    service: CertificateService = Depends(get_certificate_service),
) -> PsychologistCertificateResponse:
    """Manually issue an official numbered certificate to a verified psychologist (Admin)."""
    return await service.issue_certificate_manual(admin.id, payload)


@admin_router.post("/evaluate-auto", response_model=CertificateEvaluationSummaryResponse)
async def evaluate_auto_certificates(
    admin: User = Depends(get_current_admin),
    service: CertificateService = Depends(get_certificate_service),
) -> CertificateEvaluationSummaryResponse:
    """Evaluate active milestone/rating rules and automatically issue earned certificates (Admin)."""
    return await service.evaluate_auto_issuance()


@admin_router.patch("/{certificate_id}/revoke", response_model=PsychologistCertificateResponse)
async def revoke_certificate(
    certificate_id: uuid.UUID,
    payload: RevokeCertificateRequest,
    admin: User = Depends(get_current_admin),
    service: CertificateService = Depends(get_certificate_service),
) -> PsychologistCertificateResponse:
    """Revoke an issued certificate with an audit reason (Admin)."""
    return await service.revoke_certificate(certificate_id, payload.reason)


@admin_router.get("/{certificate_id}/download")
async def download_admin_certificate_pdf(
    certificate_id: uuid.UUID,
    admin: User = Depends(get_current_admin),
    service: CertificateService = Depends(get_certificate_service),
) -> StreamingResponse:
    """Download official watermarked PDF certificate for any psychologist (Admin)."""
    stream, filename = await service.stream_certificate_pdf(certificate_id, admin)
    return _pdf_streaming_response(stream, filename)
