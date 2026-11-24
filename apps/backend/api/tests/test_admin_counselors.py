from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock
import unittest
import uuid

from fastapi import HTTPException
from httpx import ASGITransport, AsyncClient
import pytest

from app.db.session import engine
from app.main import app
from app.models.counselor import PsychologistProfile
from app.models.enums import PsychologistVerificationStatus
from app.models.user import User
from app.schemas.counselor import (
    UpdateCounselorStatusRequest,
    VerifyPsychologistRequest,
)
from app.services.counselor import CounselorService


def _scalar_result(value):
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    result.scalars.return_value.all.return_value = value if isinstance(value, list) else ([value] if value else [])
    return result


class TestCounselorAdminService(unittest.IsolatedAsyncioTestCase):
    async def test_verify_counselor_rejects_when_no_document_verified(self):
        counselor_id = uuid.uuid4()
        admin_id = uuid.uuid4()
        profile = PsychologistProfile(
            id=counselor_id,
            user_id=uuid.uuid4(),
            full_name="Dr. Uji Validasi",
            title_degree="M.Psi., Psikolog",
            str_number="STR-12345",
            str_verified=False,
            sip_verified=False,
            verification_status=PsychologistVerificationStatus.PENDING.value,
        )
        db = MagicMock()
        db.execute = AsyncMock(return_value=_scalar_result(profile))

        service = CounselorService(db)
        with self.assertRaises(HTTPException) as ctx:
            await service.verify_counselor(
                counselor_id,
                admin_id,
                VerifyPsychologistRequest(status="verified", notes="Approved"),
            )
        self.assertEqual(ctx.exception.status_code, 400)

    async def test_toggle_document_verification_and_approve(self):
        now = datetime.now(UTC)
        user_id = uuid.uuid4()
        counselor_id = uuid.uuid4()
        admin_id = uuid.uuid4()
        user = User(
            id=user_id,
            email="psikolog.baru@eva.id",
            display_name="Psikolog Baru",
            is_active=True,
            is_verified=False,
            created_at=now,
        )
        profile = PsychologistProfile(
            id=counselor_id,
            user_id=user_id,
            full_name="Psikolog Baru",
            title_degree="M.Psi., Psikolog",
            education="S2 Magister Psikologi Profesi",
            str_number="STR-PK-2026-001",
            sip_number=None,
            association="Himpunan Psikologi Indonesia (HIMPSI)",
            years_of_experience=4,
            str_verified=False,
            sip_verified=False,
            verification_status=PsychologistVerificationStatus.PENDING.value,
            is_online=False,
            created_at=now,
        )
        profile.user = user

        db = MagicMock()
        db.commit = AsyncMock()
        db.refresh = AsyncMock()

        service = CounselorService(db)

        # Toggle SIP when sip_number is None should fail 400
        db.execute = AsyncMock(return_value=_scalar_result(profile))
        with self.assertRaises(HTTPException) as sip_ctx:
            await service.toggle_document_verification(counselor_id, "sip")
        self.assertEqual(sip_ctx.exception.status_code, 400)

        # Toggle STR to True
        db.execute = AsyncMock(return_value=_scalar_result(profile))
        toggled = await service.toggle_document_verification(counselor_id, "str")
        self.assertTrue(toggled.str_verified)
        self.assertEqual(toggled.email, "psikolog.baru@eva.id")

        # Now approve succeeds
        db.execute = AsyncMock(side_effect=[_scalar_result(profile), _scalar_result(user)])
        res = await service.verify_counselor(
            counselor_id,
            admin_id,
            VerifyPsychologistRequest(status="verified", notes="STR valid via HIMPSI"),
        )
        self.assertEqual(res.verification_status, "verified")
        self.assertTrue(profile.is_online)
        self.assertTrue(user.is_verified)

    async def test_suspend_and_reactivate_preserves_user_active(self):
        now = datetime.now(UTC)
        user_id = uuid.uuid4()
        counselor_id = uuid.uuid4()
        admin_id = uuid.uuid4()
        user = User(
            id=user_id,
            email="psikolog.aktif@eva.id",
            display_name="Psikolog Aktif",
            is_active=True,
            is_verified=True,
            created_at=now,
        )
        profile = PsychologistProfile(
            id=counselor_id,
            user_id=user_id,
            full_name="Psikolog Aktif",
            title_degree="M.Psi., Psikolog",
            str_number="STR-PK-999",
            association="Himpunan Psikologi Indonesia (HIMPSI)",
            years_of_experience=6,
            str_verified=True,
            verification_status=PsychologistVerificationStatus.VERIFIED.value,
            is_online=True,
            created_at=now,
        )
        profile.user = user

        db = MagicMock()
        db.execute = AsyncMock(return_value=_scalar_result(profile))
        db.commit = AsyncMock()
        db.refresh = AsyncMock()

        service = CounselorService(db)
        suspended = await service.update_counselor_account_status(
            counselor_id,
            admin_id,
            UpdateCounselorStatusRequest(status="suspended", notes="Cuti panjang"),
        )
        self.assertEqual(suspended.verification_status, "suspended")
        self.assertFalse(suspended.is_online)
        self.assertTrue(user.is_active)

        reactivated = await service.update_counselor_account_status(
            counselor_id,
            admin_id,
            UpdateCounselorStatusRequest(status="verified", notes="Aktif kembali"),
        )
        self.assertEqual(reactivated.verification_status, "verified")
        self.assertTrue(reactivated.is_online)


@pytest.fixture
async def clean_engine():
    await engine.dispose()
    yield
    await engine.dispose()


@pytest.mark.asyncio
async def test_admin_counselor_endpoints_auth_and_listing(clean_engine):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        user_login = await client.post(
            "/api/v1/auth/login",
            json={"email": "samsul@gmail.com", "password": "password123"},
        )
        assert user_login.status_code == 200
        user_headers = {"Authorization": f"Bearer {user_login.json()['access_token']}"}

        # Non-admin must get 403 across all admin counselor endpoints
        non_admin_list = await client.get("/api/v1/admin/counselors", headers=user_headers)
        assert non_admin_list.status_code == 403

        dummy_id = str(uuid.uuid4())
        assert (
            await client.patch(
                f"/api/v1/admin/counselors/{dummy_id}/documents/str/verify",
                headers=user_headers,
            )
        ).status_code == 403
        assert (
            await client.patch(
                f"/api/v1/admin/counselors/{dummy_id}/status",
                headers=user_headers,
                json={"status": "suspended"},
            )
        ).status_code == 403
        assert (
            await client.post(
                f"/api/v1/counselors/{dummy_id}/verify",
                headers=user_headers,
                json={"status": "verified"},
            )
        ).status_code == 403

        # Admin succeeds and receives seeded pending + verified counselors with emails
        admin_login = await client.post(
            "/api/v1/auth/login",
            json={"email": "admin@eva.id", "password": "AdminEva2026!"},
        )
        assert admin_login.status_code == 200
        admin_headers = {"Authorization": f"Bearer {admin_login.json()['access_token']}"}

        list_res = await client.get("/api/v1/admin/counselors", headers=admin_headers)
        assert list_res.status_code == 200
        counselors = list_res.json()
        emails = {c.get("email") for c in counselors}
        assert "khoirotunnisa2507@gmail.com" in emails
        assert "larasati.psi@praktikmandiri.id" in emails
