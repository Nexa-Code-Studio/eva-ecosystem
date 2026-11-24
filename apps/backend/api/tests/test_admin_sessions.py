from datetime import UTC, datetime, timedelta
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock
import unittest
import uuid

from httpx import ASGITransport, AsyncClient
import pytest

from app.db.session import engine
from app.main import app
from app.models.counselor import ConsultationSession, PsychologistProfile
from app.models.enums import ConsultationSessionStatus
from app.models.user import User
from app.services.session import SchedulingService


class TestAdminSessionsUnit(unittest.IsolatedAsyncioTestCase):
    async def test_list_admin_sessions_sanitizes_soap_and_maps_fields(self):
        now = datetime.now(UTC)
        patient_id = uuid.uuid4()
        counselor_id = uuid.uuid4()

        patient = User(
            id=patient_id,
            email="rahasia.pasien@eva.id",
            display_name="Samsul",
        )
        counselor = PsychologistProfile(
            id=counselor_id,
            user_id=uuid.uuid4(),
            full_name="dr. Sarah Amelia",
            title_degree="M.Psi., Psikolog Klinis",
            str_number="STR-001",
            association="HIMPSI",
            years_of_experience=7,
        )
        sess = ConsultationSession(
            id=uuid.uuid4(),
            session_code="EVA-TEST-60M",
            patient_id=patient_id,
            counselor_id=counselor_id,
            scheduled_start_time=now,
            scheduled_end_time=now + timedelta(minutes=60),
            duration_minutes=60,
            is_extended=True,
            status=ConsultationSessionStatus.LIVE.value,
            total_price=Decimal("300.00"),
            counselor_earning=Decimal("240.00"),
            platform_fee=Decimal("60.00"),
            soap_notes={"subjective": "RAW_PRIVATE_CLINICAL_NOTE_DO_NOT_LEAK"},
        )

        result = MagicMock()
        result.all.return_value = [(sess, patient, counselor)]
        db = MagicMock()
        db.execute = AsyncMock(return_value=result)

        service = SchedulingService(db)
        rows = await service.list_admin_sessions(session_status="extended", search="Sarah")

        self.assertEqual(len(rows), 1)
        row = rows[0]
        self.assertEqual(row.session_code, "EVA-TEST-60M")
        self.assertTrue(row.patient_code.startswith("EVA-USR-"))
        self.assertEqual(row.patient_display_name, "Samsul")
        self.assertEqual(row.counselor_name, "dr. Sarah Amelia")
        self.assertEqual(row.total_price_coins, 300)
        self.assertEqual(row.counselor_earning_coins, 240)
        self.assertEqual(row.platform_fee_coins, 60)
        self.assertTrue(row.is_extended)
        self.assertNotIn("RAW_PRIVATE_CLINICAL_NOTE_DO_NOT_LEAK", row.clinical_summary or "")


@pytest.fixture
async def clean_engine():
    await engine.dispose()
    yield
    await engine.dispose()


@pytest.mark.asyncio
async def test_admin_sessions_endpoint_auth_and_filtering(clean_engine):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        user_login = await client.post(
            "/api/v1/auth/login",
            json={"email": "samsul@gmail.com", "password": "password123"},
        )
        assert user_login.status_code == 200
        user_headers = {"Authorization": f"Bearer {user_login.json()['access_token']}"}

        forbidden_res = await client.get("/api/v1/admin/sessions", headers=user_headers)
        assert forbidden_res.status_code == 403

        admin_login = await client.post(
            "/api/v1/auth/login",
            json={"email": "admin@eva.id", "password": "AdminEva2026!"},
        )
        assert admin_login.status_code == 200
        admin_headers = {"Authorization": f"Bearer {admin_login.json()['access_token']}"}

        list_res = await client.get("/api/v1/admin/sessions", headers=admin_headers)
        assert list_res.status_code == 200
        sessions = list_res.json()
        codes = {s["session_code"] for s in sessions}
        assert "EVA-20261120-001" in codes
        assert "EVA-20261120-003" in codes

        extended_res = await client.get(
            "/api/v1/admin/sessions?is_extended=true",
            headers=admin_headers,
        )
        assert extended_res.status_code == 200
        ext_list = extended_res.json()
        assert len(ext_list) >= 1
        assert all(item["is_extended"] is True for item in ext_list)
        ext_sample = next(item for item in ext_list if item["session_code"] == "EVA-20261120-003")
        assert ext_sample["duration_minutes"] == 60
        assert ext_sample["total_price_coins"] == 300
        assert "email" not in ext_sample
