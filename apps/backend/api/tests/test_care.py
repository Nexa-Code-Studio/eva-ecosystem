import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal
import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.db.session import engine, AsyncSessionLocal
from app.models.counselor import ConsultationSession, PlatformPricingConfig, PsychologistProfile
from app.models.enums import ConsultationSessionStatus, PricingConfigStatus
from app.models.user import User
from app.main import app


@pytest.fixture(autouse=True)
async def dispose_engine():
    await engine.dispose()
    yield
    await engine.dispose()


@pytest.fixture
async def consultation_fixture():
    async with AsyncSessionLocal() as session:
        # Create Patient user
        patient_email = f"patient.{uuid.uuid4().hex[:6]}@eva.id"
        patient = User(email=patient_email, password_hash="hash123")
        session.add(patient)

        # Create Counselor user & profile
        counselor_email = f"counselor.{uuid.uuid4().hex[:6]}@eva.id"
        counselor_user = User(email=counselor_email, password_hash="hash123")
        session.add(counselor_user)

        # Create unrelated user in database
        unrelated_user = User(email=f"other.{uuid.uuid4().hex[:6]}@eva.id", password_hash="hash123")
        session.add(unrelated_user)
        await session.flush()

        profile = PsychologistProfile(
            user_id=counselor_user.id,
            full_name="Dr. Sarah Video Test, M.Psi.",
            str_number=f"STR-{uuid.uuid4().hex[:8]}",
            specializations=["Telekonsultasi"],
            years_of_experience=4,
        )
        session.add(profile)

        # Pricing config
        pricing = PlatformPricingConfig(
            session_duration_minutes=30,
            price_per_session=Decimal("150000.00"),
            counselor_share_percentage=Decimal("70.00"),
            platform_fee_percentage=Decimal("30.00"),
            extension_price_per_session=Decimal("150000.00"),
            status=PricingConfigStatus.ACTIVE.value,
        )
        session.add(pricing)
        await session.flush()

        # Consultation session
        now = datetime.now(UTC)
        consult_session = ConsultationSession(
            session_code=f"EVA-VC-{uuid.uuid4().hex[:6].upper()}",
            patient_id=patient.id,
            counselor_id=profile.id,
            pricing_config_id=pricing.id,
            scheduled_start_time=now,
            scheduled_end_time=now + timedelta(minutes=30),
            status=ConsultationSessionStatus.SCHEDULED.value,
        )
        session.add(consult_session)
        await session.commit()
        await session.refresh(consult_session)

        # Generate tokens
        from app.core.security import create_access_token
        patient_token = create_access_token(str(patient.id), patient.email, "Patient")
        counselor_token = create_access_token(str(counselor_user.id), counselor_user.email, "Counselor")
        unrelated_token = create_access_token(str(unrelated_user.id), unrelated_user.email, "Other")

        return {
            "session_id": str(consult_session.id),
            "patient_headers": {"Authorization": f"Bearer {patient_token}"},
            "counselor_headers": {"Authorization": f"Bearer {counselor_token}"},
            "unrelated_headers": {"Authorization": f"Bearer {unrelated_token}"},
        }


@pytest.mark.asyncio
async def test_care_video_token_and_status(consultation_fixture):
    session_id = consultation_fixture["session_id"]
    patient_headers = consultation_fixture["patient_headers"]
    counselor_headers = consultation_fixture["counselor_headers"]
    unrelated_headers = consultation_fixture["unrelated_headers"]

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # 1. Patient requests room token
        token_res = await client.post(
            f"/api/v1/care/sessions/{session_id}/video-token",
            headers=patient_headers,
        )
        assert token_res.status_code == 201
        data = token_res.json()
        assert data["session_id"] == session_id
        assert "token" in data
        assert "room_id" in data
        assert len(data["ice_servers"]) >= 1

        # 2. Unrelated user is forbidden
        forbidden_res = await client.post(
            f"/api/v1/care/sessions/{session_id}/video-token",
            headers=unrelated_headers,
        )
        assert forbidden_res.status_code == 403

        # 3. Update call status to live
        status_res = await client.post(
            f"/api/v1/care/sessions/{session_id}/status",
            headers=patient_headers,
            json={"status": "live"},
        )
        assert status_res.status_code == 200
        assert status_res.json()["status"] == "live"

        # 4. Counselor views session detail
        detail_res = await client.get(
            f"/api/v1/sessions/{session_id}",
            headers=counselor_headers,
        )
        assert detail_res.status_code == 200
        assert detail_res.json()["session_id"] == session_id
        assert detail_res.json()["channel_name"] == data["room_id"]

        # 5. Counselor terminates session with duration and quick notes
        end_res = await client.post(
            f"/api/v1/sessions/{session_id}/end",
            headers=counselor_headers,
            json={
                "status": "completed",
                "duration_seconds": 1800,
                "notes": ["Pasien kooperatif", "Keluhan kecemasan menurun"],
            },
        )
        assert end_res.status_code == 200
        assert end_res.json()["status"] == "completed"
