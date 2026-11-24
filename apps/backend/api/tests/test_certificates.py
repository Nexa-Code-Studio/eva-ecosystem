from datetime import UTC, datetime
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock
import unittest
import uuid

from fastapi import HTTPException

from app.models.certificate import CertificateTemplate, PsychologistCertificate
from app.models.counselor import PsychologistProfile
from app.models.enums import PsychologistVerificationStatus
from app.models.user import User
from app.schemas.certificate import IssueCertificateRequest, UpsertCertificateTemplateRequest
from app.services.certificate import CertificateService, render_certificate_pdf_bytes


def _scalar_result(value):
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    result.scalars.return_value.all.return_value = value if isinstance(value, list) else []
    result.all.return_value = value if isinstance(value, list) else []
    return result


class TestCertificatesBackend(unittest.IsolatedAsyncioTestCase):
    async def test_issue_manual_generates_formatted_number_and_placeholders(self):
        admin_id = uuid.uuid4()
        counselor_id = uuid.uuid4()
        tpl_id = uuid.uuid4()
        now = datetime.now(UTC)

        profile = PsychologistProfile(
            id=counselor_id,
            user_id=uuid.uuid4(),
            full_name="dr. Sarah Amelia, M.Psi., Psikolog",
            str_number="STR-PSI-19940822-2024",
            verification_status=PsychologistVerificationStatus.VERIFIED.value,
        )
        template = CertificateTemplate(
            id=tpl_id,
            code="CERT-PRO-01",
            title="SERTIFIKAT PRAKTIK TELEKONSELING KLINIS",
            subtitle="Clinical Tele-Psychology Excellence",
            category_code="PRO",
            category_label="Psikolog Mandiri",
            milestone_criteria="25 Sesi Terverifikasi",
            description="Diberikan kepada {psychologist_name} (STR: {str_number}) No {certificate_number} pada {issue_date}.",
            badge_color="#2563EB",
            trigger_type="sessions_milestone",
            min_completed_sessions=25,
            auto_issue_enabled=True,
            is_active=True,
            created_at=now,
            updated_at=now,
        )

        db = MagicMock()
        db.execute = AsyncMock(
            side_effect=[
                _scalar_result(profile),
                _scalar_result(template),
                _scalar_result(None),
            ]
        )
        db.scalar = AsyncMock(return_value=40)
        db.add = MagicMock()
        db.flush = AsyncMock()
        db.commit = AsyncMock()

        async def _refresh(obj):
            if getattr(obj, "id", None) is None:
                obj.id = uuid.uuid4()

        db.refresh = AsyncMock(side_effect=_refresh)

        service = CertificateService(db)
        res = await service.issue_certificate_manual(
            admin_id=admin_id,
            payload=IssueCertificateRequest(
                counselor_id=str(counselor_id),
                template_id=str(tpl_id),
            ),
        )

        expected_prefix = f"EVA/CERT/{now.year}/PRO/00041"
        self.assertEqual(res.certificate_number, expected_prefix)
        self.assertEqual(res.sequence_number, 41)
        self.assertIn("dr. Sarah Amelia, M.Psi., Psikolog", res.description)
        self.assertIn("STR-PSI-19940822-2024", res.description)
        self.assertIn(expected_prefix, res.description)
        self.assertEqual(res.trigger_source, "manual")

    async def test_evaluate_auto_issuance_matches_session_and_rating_triggers(self):
        counselor_id = uuid.uuid4()
        now = datetime.now(UTC)
        profile = PsychologistProfile(
            id=counselor_id,
            user_id=uuid.uuid4(),
            full_name="dr. Sarah Amelia, M.Psi., Psikolog",
            str_number="STR-PSI-19940822-2024",
            verification_status=PsychologistVerificationStatus.VERIFIED.value,
        )
        tpl_sessions = CertificateTemplate(
            id=uuid.uuid4(),
            code="CERT-PRO-01",
            title="SERTIFIKAT 25 SESI",
            subtitle="Excellence",
            category_code="PRO",
            category_label="Psikolog Mandiri",
            milestone_criteria="25 Sesi",
            description="Selamat {psychologist_name}",
            badge_color="#2563EB",
            trigger_type="sessions_milestone",
            min_completed_sessions=25,
            auto_issue_enabled=True,
            is_active=True,
        )
        tpl_rating = CertificateTemplate(
            id=uuid.uuid4(),
            code="CERT-TOP-01",
            title="KONSELOR TELADAN RATING 4.8+",
            subtitle="Top Rated",
            category_code="TOP",
            category_label="Psikolog Mandiri",
            milestone_criteria="Rating >= 4.8",
            description="Rating prima {psychologist_name}",
            badge_color="#7E22CE",
            trigger_type="rating_milestone",
            min_completed_sessions=20,
            min_average_rating=Decimal("4.80"),
            auto_issue_enabled=True,
            is_active=True,
        )

        stats_result = MagicMock()
        stats_result.all.return_value = [(counselor_id, 30, Decimal("4.92"))]
        existing_pairs_result = MagicMock()
        existing_pairs_result.all.return_value = []

        db = MagicMock()
        db.execute = AsyncMock(
            side_effect=[
                _scalar_result([tpl_sessions, tpl_rating]),
                _scalar_result([profile]),
                stats_result,
                existing_pairs_result,
            ]
        )
        db.scalar = AsyncMock(side_effect=[0, 0])
        db.add = MagicMock()
        db.flush = AsyncMock()
        db.commit = AsyncMock()

        async def _refresh(obj):
            if getattr(obj, "id", None) is None:
                obj.id = uuid.uuid4()
            if getattr(obj, "issued_at", None) is None:
                obj.issued_at = now

        db.refresh = AsyncMock(side_effect=_refresh)

        service = CertificateService(db)
        summary = await service.evaluate_auto_issuance()

        self.assertEqual(summary.evaluated_counselors, 1)
        self.assertEqual(summary.newly_issued_count, 2)
        sources = {c.trigger_source for c in summary.issued_certificates}
        self.assertEqual(sources, {"auto_sessions", "auto_rating"})

    async def test_stream_certificate_pdf_enforces_ownership_and_outputs_valid_pdf(self):
        owner_user_id = uuid.uuid4()
        other_user_id = uuid.uuid4()
        counselor_id = uuid.uuid4()
        cert_id = uuid.uuid4()
        now = datetime.now(UTC)

        cert = PsychologistCertificate(
            id=cert_id,
            certificate_number="EVA/CERT/2026/PRO/00001",
            sequence_number=1,
            issue_year=2026,
            category_code="PRO",
            counselor_id=counselor_id,
            title="SERTIFIKAT PRAKTIK TELEKONSELING KLINIS",
            subtitle="Clinical Tele-Psychology Excellence",
            recipient_name="dr. Sarah Amelia, M.Psi., Psikolog",
            str_number="STR-PSI-19940822-2024",
            milestone_criteria="25 Sesi Terverifikasi",
            category_label="Psikolog Mandiri",
            description="Sertifikat resmi terverifikasi oleh Komite Klinis EVA.",
            badge_color="#2563EB",
            trigger_source="manual",
            status="active",
            issued_at=now,
        )
        raw_pdf = render_certificate_pdf_bytes(cert)
        self.assertTrue(raw_pdf.startswith(b"%PDF-"))

        other_profile = PsychologistProfile(
            id=uuid.uuid4(),
            user_id=other_user_id,
            full_name="Lain",
            str_number="STR-OTHER",
        )
        db = MagicMock()
        db.execute = AsyncMock(
            side_effect=[
                _scalar_result(cert),
                _scalar_result(other_profile),
            ]
        )
        service = CertificateService(db)

        other_user = User(id=other_user_id, email="other@eva.id", is_admin=False)
        with self.assertRaises(HTTPException) as ctx:
            await service.stream_certificate_pdf(cert_id, other_user)
        self.assertEqual(ctx.exception.status_code, 403)

        owner_profile = PsychologistProfile(
            id=counselor_id,
            user_id=owner_user_id,
            full_name="dr. Sarah Amelia, M.Psi., Psikolog",
            str_number="STR-PSI-19940822-2024",
        )
        db2 = MagicMock()
        db2.execute = AsyncMock(
            side_effect=[
                _scalar_result(cert),
                _scalar_result(owner_profile),
            ]
        )
        service2 = CertificateService(db2)
        owner_user = User(id=owner_user_id, email="sarah@eva.id", is_admin=False)
        stream, filename = await service2.stream_certificate_pdf(cert_id, owner_user)
        self.assertEqual(filename, "EVA_CERT_2026_PRO_00001.pdf")
        self.assertTrue(stream.getvalue().startswith(b"%PDF-"))

    async def test_create_template_normalizes_code_and_category(self):
        now = datetime.now(UTC)
        db = MagicMock()
        db.execute = AsyncMock(return_value=_scalar_result(None))
        db.add = MagicMock()
        db.commit = AsyncMock()

        async def _refresh(obj):
            if getattr(obj, "id", None) is None:
                obj.id = uuid.uuid4()
            obj.created_at = now
            obj.updated_at = now

        db.refresh = AsyncMock(side_effect=_refresh)

        service = CertificateService(db)
        tpl = await service.create_template(
            UpsertCertificateTemplateRequest(
                code=" cert pro custom ",
                title="Sertifikat Uji",
                subtitle="Subjudul Uji",
                category_code="pro",
                milestone_criteria="10 Sesi",
                description="Penghargaan untuk {psychologist_name}.",
            )
        )
        self.assertEqual(tpl.code, "CERT-PRO-CUSTOM")
        self.assertEqual(tpl.category_code, "PRO")
