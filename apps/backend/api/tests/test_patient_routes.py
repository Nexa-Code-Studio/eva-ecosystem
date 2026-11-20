import uuid
import pytest
from httpx import ASGITransport, AsyncClient

from app.db.session import engine, AsyncSessionLocal
from app.models.counselor import PsychologistProfile, ConsultationSession, PatientConsent
from app.models.user import User
from app.models.enums import PsychologistVerificationStatus, ConsultationSessionStatus
from app.main import app


@pytest.fixture(autouse=True)
async def dispose_engine():
    await engine.dispose()
    yield
    await engine.dispose()


@pytest.fixture
async def setup_counselor_and_patient():
    async with AsyncSessionLocal() as session:
        # Create Patient User
        patient = User(
            email=f"patient.{uuid.uuid4().hex[:6]}@example.com",
            display_name="Pasien Uji Coba",
            is_active=True,
            is_verified=True,
        )
        # Create Counselor User
        counselor_user = User(
            email=f"counselor.{uuid.uuid4().hex[:6]}@eva.id",
            display_name="dr. Penguji, M.Psi.",
            is_active=True,
            is_verified=True,
        )
        session.add_all([patient, counselor_user])
        await session.commit()
        await session.refresh(patient)
        await session.refresh(counselor_user)

        # Create PsychologistProfile
        profile = PsychologistProfile(
            user_id=counselor_user.id,
            full_name="dr. Penguji, M.Psi.",
            str_number=f"STR-{uuid.uuid4().hex[:8]}",
            verification_status=PsychologistVerificationStatus.VERIFIED.value,
            is_online=True,
        )
        session.add(profile)
        await session.commit()
        await session.refresh(profile)

        # Create Session between Patient and Counselor
        from datetime import datetime, UTC, timedelta
        consult_session = ConsultationSession(
            session_code=f"TEST-{uuid.uuid4().hex[:6]}",
            patient_id=patient.id,
            counselor_id=profile.id,
            scheduled_start_time=datetime.now(UTC),
            scheduled_end_time=datetime.now(UTC) + timedelta(minutes=30),
            status=ConsultationSessionStatus.COMPLETED.value,
            soap_notes={
                "subjective": "Keluhan cemas awal.",
                "objective": "Tenang.",
                "assessment": "Stres ringan.",
                "plan": "Relaksasi napas.",
            },
        )
        # Create Consent
        consent = PatientConsent(
            patient_id=patient.id,
            counselor_id=profile.id,
            status="granted",
            granted_at=datetime.now(UTC),
        )
        session.add_all([consult_session, consent])
        await session.commit()

        yield {
            "counselor_user_id": str(counselor_user.id),
            "counselor_email": counselor_user.email,
            "profile_id": str(profile.id),
            "patient_id": str(patient.id),
        }


@pytest.mark.asyncio
async def test_counselor_patients_api(setup_counselor_and_patient):
    data = setup_counselor_and_patient
    from app.core.security import create_access_token

    token = create_access_token(
        user_id=data["counselor_user_id"],
        email=data["counselor_email"],
        name="dr. Penguji",
    )
    headers = {"Authorization": f"Bearer {token}"}

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # 1. List patients
        res_list = await client.get("/api/v1/patients", headers=headers)
        assert res_list.status_code == 200
        patients = res_list.json()
        assert isinstance(patients, list)
        assert len(patients) >= 1
        assert any(p["id"] == data["patient_id"] for p in patients)

        # 2. Get patient detail
        res_detail = await client.get(f"/api/v1/patients/{data['patient_id']}", headers=headers)
        assert res_detail.status_code == 200
        detail = res_detail.json()
        assert detail["id"] == data["patient_id"]
        assert detail["name"] == "Pasien Uji Coba"
        assert detail["has_consent"] is True

        # 3. Create clinical note
        res_note = await client.post(
            f"/api/v1/patients/{data['patient_id']}/clinical-notes",
            headers=headers,
            json={
                "patient_id": data["patient_id"],
                "subjective": "Pasien merasa lebih segar.",
                "objective": "Afek stabil.",
                "assessment": "Progres membaik.",
                "plan": "Sesi selesai.",
                "recommended_tasks": ["Jalan pagi"],
            },
        )
        assert res_note.status_code == 201
        note_data = res_note.json()
        assert note_data["subjective"] == "Pasien merasa lebih segar."
        assert note_data["recommended_tasks"] == ["Jalan pagi"]

        # 4. Request consent
        res_consent = await client.post(
            f"/api/v1/patients/{data['patient_id']}/request-consent",
            headers=headers,
        )
        assert res_consent.status_code == 200
        assert res_consent.json()["success"] is True
