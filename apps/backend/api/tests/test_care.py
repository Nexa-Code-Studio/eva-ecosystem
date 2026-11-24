import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal
import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.db.session import engine, AsyncSessionLocal
from app.models.counselor import ConsultationSession, PlatformPricingConfig, PsychologistProfile
from app.models.enums import ConsultationSessionStatus, PricingConfigStatus, PsychologistVerificationStatus
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
        patient = User(email=patient_email, password_hash="hash123", coin_balance=1000000)
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
            verification_status=PsychologistVerificationStatus.VERIFIED.value,
            is_online=True,
            buffer_time_minutes=15,
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
            "counselor_id": str(profile.id),
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
        assert len(data["ice_server_configs"]) >= 1
        assert data["ws_url"].endswith(f"/api/v1/care/ws/{session_id}?token={data['token']}")

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

        # 4. Counselor views session detail (and non-counselors receive 403)
        detail_res = await client.get(
            f"/api/v1/sessions/{session_id}",
            headers=counselor_headers,
        )
        assert detail_res.status_code == 200
        detail_json = detail_res.json()
        assert detail_json["session_id"] == session_id
        assert detail_json["channel_name"] == data["room_id"]
        assert len(detail_json["ice_servers"]) >= 1
        assert len(detail_json["ice_server_configs"]) >= 1
        assert detail_json["ws_url"].endswith(
            f"/api/v1/care/ws/{session_id}?token={detail_json['signaling_token']}"
        )

        patient_detail_res = await client.get(
            f"/api/v1/sessions/{session_id}",
            headers=patient_headers,
        )
        assert patient_detail_res.status_code == 403

        unrelated_detail_res = await client.get(
            f"/api/v1/sessions/{session_id}",
            headers=unrelated_headers,
        )
        assert unrelated_detail_res.status_code == 403

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


@pytest.mark.asyncio
async def test_care_psychologists_and_clinics_endpoints(consultation_fixture):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # 1. Get Psychologists
        res = await client.get("/api/v1/care/psychologists")
        assert res.status_code == 200
        psychs = res.json()
        assert isinstance(psychs, list)
        assert len(psychs) >= 1
        first = psychs[0]
        assert "name" in first
        assert "registration_number" in first
        assert "testimonials" in first
        assert "patient_stats" in first

        # 2. Filter by category
        res_cat = await client.get("/api/v1/care/psychologists?category=psychologist")
        assert res_cat.status_code == 200

        # 3. Get Clinics
        res_clinics = await client.get("/api/v1/care/clinics")
        assert res_clinics.status_code == 200
        clinics = res_clinics.json()
        assert isinstance(clinics, list)
        assert len(clinics) >= 1
        assert "facilities" in clinics[0]


@pytest.mark.asyncio
async def test_care_community_and_timeline_and_booking(consultation_fixture):
    patient_headers = consultation_fixture["patient_headers"]
    counselor_id = consultation_fixture["counselor_id"]
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # 1. Community Status
        res_comm = await client.get("/api/v1/community/status")
        assert res_comm.status_code == 200
        assert res_comm.json()["server_name"] == "Eva Safe Space ID"

        res_join = await client.post("/api/v1/community/join", headers=patient_headers)
        assert res_join.status_code == 200
        assert res_join.json()["is_member"] is True

        # 2. Timeline
        today_str = datetime.now(UTC).strftime("%Y-%m-%d")
        res_timeline = await client.get(f"/api/v1/counselors/{counselor_id}/timeline?date={today_str}")
        assert res_timeline.status_code == 200
        timeline = res_timeline.json()
        assert "operating_hours" in timeline
        assert "blocked_ranges" in timeline
        assert "available_windows" in timeline

        # 3. Dynamic Multi-Session Booking
        future_start = (datetime.now(UTC) + timedelta(days=2)).replace(hour=14, minute=0, second=0, microsecond=0)
        book_payload = {
            "psychologist_id": counselor_id,
            "preferred_date_time": future_start.isoformat(),
            "session_type": "onlineVideo",
            "session_count": 2,
            "duration_minutes": 60,
            "complaints": "Kecemasan menghadapi presentasi kerja",
            "share_ai_chat_history": True,
        }
        res_book = await client.post(
            f"/api/v1/counselors/{counselor_id}/book",
            headers=patient_headers,
            json=book_payload,
        )
        assert res_book.status_code == 201
        booked_sess = res_book.json()
        assert booked_sess["duration_minutes"] == 60
        assert "psychologist" in booked_sess
        assert booked_sess["notes"] == "Kecemasan menghadapi presentasi kerja"

        # 4. User Care Sessions list
        res_sessions = await client.get("/api/v1/care/sessions", headers=patient_headers)
        assert res_sessions.status_code == 200
        my_sessions = res_sessions.json()
        assert len(my_sessions) >= 1

        # 5. Rating submission
        res_rate = await client.post(
            f"/api/v1/counselors/{counselor_id}/ratings",
            headers=patient_headers,
            json={
                "rating": 5.0,
                "review_text": "Sesi sangat membantu dan memberi kejelasan.",
                "is_anonymous": True,
                "tags": ["Sangat Sabar & Empati"],
            },
        )
        assert res_rate.status_code == 200
        assert res_rate.json()["success"] is True

