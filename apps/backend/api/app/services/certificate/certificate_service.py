from datetime import UTC, datetime
from decimal import Decimal
from io import BytesIO
import uuid

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.certificate import CertificateTemplate, PsychologistCertificate
from app.models.counselor import ConsultationSession, PsychologistProfile
from app.models.enums import ConsultationSessionStatus, PsychologistVerificationStatus
from app.models.user import User
from app.schemas.certificate import (
    CertificateEvaluationSummaryResponse,
    CertificateTemplateResponse,
    CounselorCertificateEligibilityResponse,
    IssueCertificateRequest,
    PsychologistCertificateResponse,
    UpsertCertificateTemplateRequest,
)
from app.services.certificate.certificate_renderer import (
    format_indonesian_issue_date,
    render_certificate_pdf_bytes,
)


def _render_placeholders(
    raw_text: str,
    *,
    psychologist_name: str,
    str_number: str,
    certificate_number: str,
    issue_date_label: str,
) -> str:
    return (
        raw_text.replace("{psychologist_name}", psychologist_name)
        .replace("{str_number}", str_number)
        .replace("{certificate_number}", certificate_number)
        .replace("{issue_date}", issue_date_label)
    )


class CertificateService:
    """Manages official psychologist certificate templates, auto/manual issuance, numbering, and PDF rendering."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def list_templates(self, *, active_only: bool = False) -> list[CertificateTemplateResponse]:
        query = select(CertificateTemplate).order_by(
            CertificateTemplate.min_completed_sessions.asc(),
            CertificateTemplate.created_at.asc(),
        )
        if active_only:
            query = query.where(CertificateTemplate.is_active.is_(True))
        res = await self.db.execute(query)
        rows = res.scalars().all()
        return [self._to_template_response(t) for t in rows]

    async def create_template(
        self,
        payload: UpsertCertificateTemplateRequest,
    ) -> CertificateTemplateResponse:
        existing = await self.db.execute(
            select(CertificateTemplate).where(func.upper(CertificateTemplate.code) == payload.code)
        )
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f'Kode template "{payload.code}" sudah digunakan.',
            )

        tpl = CertificateTemplate(
            code=payload.code,
            title=payload.title.strip(),
            subtitle=payload.subtitle.strip(),
            category_code=payload.category_code,
            category_label=payload.category_label.strip(),
            milestone_criteria=payload.milestone_criteria.strip(),
            description=payload.description.strip(),
            badge_color=payload.badge_color,
            trigger_type=payload.trigger_type,
            min_completed_sessions=payload.min_completed_sessions,
            min_average_rating=(
                Decimal(str(payload.min_average_rating))
                if payload.min_average_rating is not None
                else None
            ),
            auto_issue_enabled=payload.auto_issue_enabled,
            is_active=payload.is_active,
            svg_body_template=payload.svg_body_template,
        )
        self.db.add(tpl)
        await self.db.commit()
        await self.db.refresh(tpl)
        return self._to_template_response(tpl)

    async def update_template(
        self,
        template_id: uuid.UUID,
        payload: UpsertCertificateTemplateRequest,
    ) -> CertificateTemplateResponse:
        tpl = await self._get_template_or_404(template_id)
        duplicate = await self.db.execute(
            select(CertificateTemplate).where(
                func.upper(CertificateTemplate.code) == payload.code,
                CertificateTemplate.id != template_id,
            )
        )
        if duplicate.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f'Kode template "{payload.code}" sudah digunakan.',
            )

        tpl.code = payload.code
        tpl.title = payload.title.strip()
        tpl.subtitle = payload.subtitle.strip()
        tpl.category_code = payload.category_code
        tpl.category_label = payload.category_label.strip()
        tpl.milestone_criteria = payload.milestone_criteria.strip()
        tpl.description = payload.description.strip()
        tpl.badge_color = payload.badge_color
        tpl.trigger_type = payload.trigger_type
        tpl.min_completed_sessions = payload.min_completed_sessions
        tpl.min_average_rating = (
            Decimal(str(payload.min_average_rating))
            if payload.min_average_rating is not None
            else None
        )
        tpl.auto_issue_enabled = payload.auto_issue_enabled
        tpl.is_active = payload.is_active
        tpl.svg_body_template = payload.svg_body_template

        await self.db.commit()
        await self.db.refresh(tpl)
        return self._to_template_response(tpl)

    async def toggle_template_active(self, template_id: uuid.UUID) -> CertificateTemplateResponse:
        tpl = await self._get_template_or_404(template_id)
        tpl.is_active = not tpl.is_active
        await self.db.commit()
        await self.db.refresh(tpl)
        return self._to_template_response(tpl)

    async def list_admin_certificates(self) -> list[PsychologistCertificateResponse]:
        res = await self.db.execute(
            select(PsychologistCertificate).order_by(PsychologistCertificate.issued_at.desc())
        )
        rows = res.scalars().all()
        return [self._to_certificate_response(c) for c in rows]

    async def list_eligible_counselors(self) -> list[CounselorCertificateEligibilityResponse]:
        prof_res = await self.db.execute(
            select(PsychologistProfile)
            .where(
                PsychologistProfile.verification_status == PsychologistVerificationStatus.VERIFIED.value
            )
            .order_by(PsychologistProfile.full_name.asc())
        )
        profiles = prof_res.scalars().all()
        stats = await self._get_counselor_session_stats()
        cert_counts = await self._get_active_certificate_counts()

        results: list[CounselorCertificateEligibilityResponse] = []
        for prof in profiles:
            completed_count, avg_rating = stats.get(prof.id, (0, None))
            results.append(
                CounselorCertificateEligibilityResponse(
                    counselor_id=str(prof.id),
                    full_name=prof.full_name,
                    str_number=prof.str_number,
                    verification_status=prof.verification_status,
                    completed_sessions_count=completed_count,
                    average_rating=avg_rating,
                    active_certificates_count=cert_counts.get(prof.id, 0),
                )
            )
        return results

    async def issue_certificate_manual(
        self,
        admin_id: uuid.UUID,
        payload: IssueCertificateRequest,
    ) -> PsychologistCertificateResponse:
        try:
            counselor_uuid = uuid.UUID(payload.counselor_id)
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="ID psikolog tidak valid.",
            ) from exc

        prof_res = await self.db.execute(
            select(PsychologistProfile).where(PsychologistProfile.id == counselor_uuid)
        )
        profile = prof_res.scalar_one_or_none()
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )
        if profile.verification_status != PsychologistVerificationStatus.VERIFIED.value:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Sertifikat resmi hanya dapat diterbitkan untuk psikolog berstatus terverifikasi.",
            )

        template: CertificateTemplate | None = None
        if payload.template_id:
            try:
                tpl_uuid = uuid.UUID(payload.template_id)
            except ValueError as exc:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="ID template sertifikat tidak valid.",
                ) from exc
            template = await self._get_template_or_404(tpl_uuid)

            dup_res = await self.db.execute(
                select(PsychologistCertificate).where(
                    PsychologistCertificate.counselor_id == profile.id,
                    PsychologistCertificate.template_id == template.id,
                    PsychologistCertificate.status == "active",
                )
            )
            if dup_res.scalar_one_or_none():
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f'Psikolog "{profile.full_name}" sudah memiliki sertifikat aktif untuk template "{template.title}".',
                )

        title = (payload.custom_title or (template.title if template else "")).strip()
        subtitle = (payload.custom_subtitle or (template.subtitle if template else "Penghargaan Kredensial Klinis EVA")).strip()
        category_code = (payload.custom_category_code or (template.category_code if template else "PRO")).strip().upper()
        category_label = (payload.custom_category_label or (template.category_label if template else "Psikolog Mandiri")).strip()
        milestone_criteria = (
            payload.custom_milestone_criteria
            or (template.milestone_criteria if template else "Penghargaan Resmi Komite Klinis EVA")
        ).strip()
        raw_description = (
            payload.custom_description
            or (template.description if template else "Diberikan kepada {psychologist_name} (STR: {str_number}) atas dedikasi praktik telekonseling resmi EVA.")
        ).strip()
        badge_color = payload.custom_badge_color or (template.badge_color if template else "#2563EB")

        if not title or len(title) < 4:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Pilih template atau isi judul sertifikat minimal 4 karakter.",
            )

        cert = await self._create_certificate_record(
            profile=profile,
            template=template,
            issued_by_user_id=admin_id,
            title=title,
            subtitle=subtitle,
            category_code=category_code,
            category_label=category_label,
            milestone_criteria=milestone_criteria,
            raw_description=raw_description,
            badge_color=badge_color,
            trigger_source="manual",
        )
        await self.db.commit()
        await self.db.refresh(cert)
        return self._to_certificate_response(cert)

    async def evaluate_auto_issuance(
        self,
        *,
        counselor_id: uuid.UUID | None = None,
    ) -> CertificateEvaluationSummaryResponse:
        """Evaluate verified psychologists against active auto-issue templates and issue missing certificates."""
        tpl_res = await self.db.execute(
            select(CertificateTemplate).where(
                CertificateTemplate.is_active.is_(True),
                CertificateTemplate.auto_issue_enabled.is_(True),
                CertificateTemplate.trigger_type.in_(["sessions_milestone", "rating_milestone"]),
            )
        )
        templates = tpl_res.scalars().all()
        if not templates:
            return CertificateEvaluationSummaryResponse(
                evaluated_counselors=0,
                newly_issued_count=0,
                issued_certificates=[],
            )

        prof_query = select(PsychologistProfile).where(
            PsychologistProfile.verification_status == PsychologistVerificationStatus.VERIFIED.value
        )
        if counselor_id is not None:
            prof_query = prof_query.where(PsychologistProfile.id == counselor_id)
        prof_res = await self.db.execute(prof_query)
        profiles = prof_res.scalars().all()
        if not profiles:
            return CertificateEvaluationSummaryResponse(
                evaluated_counselors=0,
                newly_issued_count=0,
                issued_certificates=[],
            )

        stats = await self._get_counselor_session_stats()
        existing_res = await self.db.execute(
            select(PsychologistCertificate.counselor_id, PsychologistCertificate.template_id).where(
                PsychologistCertificate.status == "active",
                PsychologistCertificate.template_id.is_not(None),
            )
        )
        existing_pairs = {(row[0], row[1]) for row in existing_res.all()}

        created_certs: list[PsychologistCertificate] = []
        for profile in profiles:
            completed_count, avg_rating = stats.get(profile.id, (0, None))
            for tpl in templates:
                if (profile.id, tpl.id) in existing_pairs:
                    continue
                if completed_count < tpl.min_completed_sessions:
                    continue

                if tpl.trigger_type == "rating_milestone":
                    min_rating = float(tpl.min_average_rating) if tpl.min_average_rating is not None else 4.8
                    if avg_rating is None or avg_rating < min_rating:
                        continue
                    source = "auto_rating"
                else:
                    source = "auto_sessions"

                cert = await self._create_certificate_record(
                    profile=profile,
                    template=tpl,
                    issued_by_user_id=None,
                    title=tpl.title,
                    subtitle=tpl.subtitle,
                    category_code=tpl.category_code,
                    category_label=tpl.category_label,
                    milestone_criteria=tpl.milestone_criteria,
                    raw_description=tpl.description,
                    badge_color=tpl.badge_color,
                    trigger_source=source,
                )
                existing_pairs.add((profile.id, tpl.id))
                created_certs.append(cert)

        if created_certs:
            await self.db.commit()
            for cert in created_certs:
                await self.db.refresh(cert)

        return CertificateEvaluationSummaryResponse(
            evaluated_counselors=len(profiles),
            newly_issued_count=len(created_certs),
            issued_certificates=[self._to_certificate_response(c) for c in created_certs],
        )

    async def revoke_certificate(
        self,
        certificate_id: uuid.UUID,
        reason: str,
    ) -> PsychologistCertificateResponse:
        cert = await self._get_certificate_or_404(certificate_id)
        if cert.status == "revoked":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Sertifikat ini sudah berstatus dicabut.",
            )
        cert.status = "revoked"
        cert.revoked_at = datetime.now(UTC)
        cert.revocation_reason = reason.strip()
        await self.db.commit()
        await self.db.refresh(cert)
        return self._to_certificate_response(cert)

    async def list_my_certificates(self, user_id: uuid.UUID) -> list[PsychologistCertificateResponse]:
        prof_res = await self.db.execute(
            select(PsychologistProfile).where(PsychologistProfile.user_id == user_id)
        )
        profile = prof_res.scalar_one_or_none()
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan untuk akun ini.",
            )

        res = await self.db.execute(
            select(PsychologistCertificate)
            .where(
                PsychologistCertificate.counselor_id == profile.id,
                PsychologistCertificate.status == "active",
            )
            .order_by(PsychologistCertificate.issued_at.desc())
        )
        rows = res.scalars().all()
        return [self._to_certificate_response(c) for c in rows]

    async def stream_certificate_pdf(
        self,
        certificate_id: uuid.UUID,
        requester: User,
    ) -> tuple[BytesIO, str]:
        cert = await self._get_certificate_or_404(certificate_id)
        if not requester.is_admin:
            prof_res = await self.db.execute(
                select(PsychologistProfile).where(PsychologistProfile.user_id == requester.id)
            )
            profile = prof_res.scalar_one_or_none()
            if not profile or profile.id != cert.counselor_id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Anda tidak memiliki izin mengunduh sertifikat ini.",
                )

        pdf_bytes = render_certificate_pdf_bytes(cert)
        safe_filename = f"{cert.certificate_number.replace('/', '_')}.pdf"
        return BytesIO(pdf_bytes), safe_filename

    async def _create_certificate_record(
        self,
        *,
        profile: PsychologistProfile,
        template: CertificateTemplate | None,
        issued_by_user_id: uuid.UUID | None,
        title: str,
        subtitle: str,
        category_code: str,
        category_label: str,
        milestone_criteria: str,
        raw_description: str,
        badge_color: str,
        trigger_source: str,
    ) -> PsychologistCertificate:
        now = datetime.now(UTC)
        issue_year = now.year
        max_seq_res = await self.db.scalar(
            select(func.coalesce(func.max(PsychologistCertificate.sequence_number), 0)).where(
                PsychologistCertificate.issue_year == issue_year,
                PsychologistCertificate.category_code == category_code,
            )
        )
        next_seq = int(max_seq_res or 0) + 1
        cert_number = f"EVA/CERT/{issue_year}/{category_code}/{next_seq:05d}"
        issue_date_label = format_indonesian_issue_date(now)

        rendered_description = _render_placeholders(
            raw_description,
            psychologist_name=profile.full_name,
            str_number=profile.str_number,
            certificate_number=cert_number,
            issue_date_label=issue_date_label,
        )
        rendered_criteria = _render_placeholders(
            milestone_criteria,
            psychologist_name=profile.full_name,
            str_number=profile.str_number,
            certificate_number=cert_number,
            issue_date_label=issue_date_label,
        )

        cert = PsychologistCertificate(
            certificate_number=cert_number,
            sequence_number=next_seq,
            issue_year=issue_year,
            category_code=category_code,
            counselor_id=profile.id,
            template_id=template.id if template else None,
            issued_by_user_id=issued_by_user_id,
            title=title,
            subtitle=subtitle,
            recipient_name=profile.full_name,
            str_number=profile.str_number,
            milestone_criteria=rendered_criteria,
            category_label=category_label,
            description=rendered_description,
            badge_color=badge_color,
            trigger_source=trigger_source,
            status="active",
            issued_at=now,
        )
        self.db.add(cert)
        await self.db.flush()
        return cert

    async def _get_counselor_session_stats(self) -> dict[uuid.UUID, tuple[int, float | None]]:
        res = await self.db.execute(
            select(
                ConsultationSession.counselor_id,
                func.count(ConsultationSession.id),
                func.avg(ConsultationSession.patient_rating),
            )
            .where(ConsultationSession.status == ConsultationSessionStatus.COMPLETED.value)
            .group_by(ConsultationSession.counselor_id)
        )
        stats: dict[uuid.UUID, tuple[int, float | None]] = {}
        for c_id, total_completed, avg_rating in res.all():
            avg_float = round(float(avg_rating), 2) if avg_rating is not None else None
            stats[c_id] = (int(total_completed or 0), avg_float)
        return stats

    async def _get_active_certificate_counts(self) -> dict[uuid.UUID, int]:
        res = await self.db.execute(
            select(
                PsychologistCertificate.counselor_id,
                func.count(PsychologistCertificate.id),
            )
            .where(PsychologistCertificate.status == "active")
            .group_by(PsychologistCertificate.counselor_id)
        )
        return {c_id: int(cnt or 0) for c_id, cnt in res.all()}

    async def _get_template_or_404(self, template_id: uuid.UUID) -> CertificateTemplate:
        res = await self.db.execute(
            select(CertificateTemplate).where(CertificateTemplate.id == template_id)
        )
        tpl = res.scalar_one_or_none()
        if not tpl:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Template sertifikat tidak ditemukan.",
            )
        return tpl

    async def _get_certificate_or_404(self, certificate_id: uuid.UUID) -> PsychologistCertificate:
        res = await self.db.execute(
            select(PsychologistCertificate).where(PsychologistCertificate.id == certificate_id)
        )
        cert = res.scalar_one_or_none()
        if not cert:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sertifikat tidak ditemukan.",
            )
        return cert

    @staticmethod
    def _to_template_response(tpl: CertificateTemplate) -> CertificateTemplateResponse:
        return CertificateTemplateResponse(
            id=str(tpl.id),
            code=tpl.code,
            title=tpl.title,
            subtitle=tpl.subtitle,
            category_code=tpl.category_code,
            category_label=tpl.category_label,
            milestone_criteria=tpl.milestone_criteria,
            description=tpl.description,
            badge_color=tpl.badge_color,
            trigger_type=tpl.trigger_type,
            min_completed_sessions=tpl.min_completed_sessions,
            min_average_rating=(
                float(tpl.min_average_rating) if tpl.min_average_rating is not None else None
            ),
            auto_issue_enabled=tpl.auto_issue_enabled,
            is_active=tpl.is_active,
            svg_body_template=tpl.svg_body_template,
            created_at=tpl.created_at,
            updated_at=tpl.updated_at,
        )

    @staticmethod
    def _to_certificate_response(cert: PsychologistCertificate) -> PsychologistCertificateResponse:
        return PsychologistCertificateResponse(
            id=str(cert.id),
            certificate_number=cert.certificate_number,
            sequence_number=cert.sequence_number,
            issue_year=cert.issue_year,
            category_code=cert.category_code,
            counselor_id=str(cert.counselor_id),
            template_id=str(cert.template_id) if cert.template_id else None,
            title=cert.title,
            subtitle=cert.subtitle,
            recipient_name=cert.recipient_name,
            str_number=cert.str_number,
            milestone_criteria=cert.milestone_criteria,
            category_label=cert.category_label,
            description=cert.description,
            badge_color=cert.badge_color,
            trigger_source=cert.trigger_source,
            status=cert.status,
            issue_date_label=format_indonesian_issue_date(cert.issued_at),
            issued_at=cert.issued_at,
            revoked_at=cert.revoked_at,
            revocation_reason=cert.revocation_reason,
        )
