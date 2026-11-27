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


@pytest.mark.asyncio
async def test_clinical_note_coin_release_idempotent_and_h1_deadline(setup_counselor_and_patient):
    from datetime import UTC, datetime, timedelta, timezone
    from decimal import Decimal
    from app.core.security import create_access_token
    from app.models.counselor import CounselorTransaction
    from app.models.enums import TransactionStatus, TransactionType

    data = setup_counselor_and_patient
    wib = timezone(timedelta(hours=7))
    now_wib = datetime.now(wib)

    async with AsyncSessionLocal() as db:
        # Active session today -> still within H+1 23:59 WIB
        active_sess = ConsultationSession(
            session_code=f"EVA-IDEMP-{uuid.uuid4().hex[:6]}",
            patient_id=uuid.UUID(data["patient_id"]),
            counselor_id=uuid.UUID(data["profile_id"]),
            scheduled_start_time=now_wib.astimezone(UTC) - timedelta(hours=1),
            scheduled_end_time=now_wib.astimezone(UTC) - timedelta(minutes=30),
            actual_end_time=now_wib.astimezone(UTC) - timedelta(minutes=30),
            duration_minutes=30,
            status=ConsultationSessionStatus.IN_PROGRESS.value,
            counselor_earning=Decimal("150.00"),
        )
        # Expired session (3 days ago) -> past H+1 23:59 WIB
        expired_sess = ConsultationSession(
            session_code=f"EVA-EXP-{uuid.uuid4().hex[:6]}",
            patient_id=uuid.UUID(data["patient_id"]),
            counselor_id=uuid.UUID(data["profile_id"]),
            scheduled_start_time=now_wib.astimezone(UTC) - timedelta(days=3, hours=1),
            scheduled_end_time=now_wib.astimezone(UTC) - timedelta(days=3),
            actual_end_time=now_wib.astimezone(UTC) - timedelta(days=3),
            duration_minutes=30,
            status=ConsultationSessionStatus.COMPLETED.value,
            counselor_earning=Decimal("150.00"),
        )
        db.add_all([active_sess, expired_sess])
        await db.commit()
        await db.refresh(active_sess)
        await db.refresh(expired_sess)

        pending_tx = CounselorTransaction(
            counselor_id=uuid.UUID(data["profile_id"]),
            session_id=active_sess.id,
            transaction_type=TransactionType.EARNING.value,
            amount=Decimal("150.00"),
            status=TransactionStatus.PENDING.value,
            description="Honorarium sesi uji coba",
        )
        db.add(pending_tx)
        await db.commit()

        active_sess_id = str(active_sess.id)
        expired_sess_id = str(expired_sess.id)

    token = create_access_token(
        user_id=data["counselor_user_id"],
        email=data["counselor_email"],
        name="dr. Penguji",
    )
    headers = {"Authorization": f"Bearer {token}"}

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # 1. First save credits 150 coins once
        res_first = await client.post(
            f"/api/v1/patients/{data['patient_id']}/clinical-notes",
            headers=headers,
            json={
                "patient_id": data["patient_id"],
                "session_id": active_sess_id,
                "subjective": "Catatan pertama.",
                "objective": "Afek stabil.",
                "assessment": "Baik.",
                "plan": "Lanjutkan.",
            },
        )
        assert res_first.status_code == 201
        first_body = res_first.json()
        assert first_body["coins_awarded"] == 150
        balance_after_first = first_body["coin_balance"]

        # 2. Second save within H+1 updates SOAP but awards 0 coins
        res_second = await client.post(
            f"/api/v1/patients/{data['patient_id']}/clinical-notes",
            headers=headers,
            json={
                "patient_id": data["patient_id"],
                "session_id": active_sess_id,
                "subjective": "Catatan revisi.",
                "objective": "Afek stabil.",
                "assessment": "Baik.",
                "plan": "Lanjutkan.",
            },
        )
        assert res_second.status_code == 201
        second_body = res_second.json()
        assert second_body["coins_awarded"] == 0
        assert second_body["coin_balance"] == balance_after_first

        # 3. Save for session past H+1 23:59 WIB is rejected with 400
        res_expired = await client.post(
            f"/api/v1/patients/{data['patient_id']}/clinical-notes",
            headers=headers,
            json={
                "patient_id": data["patient_id"],
                "session_id": expired_sess_id,
                "subjective": "Terlambat.",
                "objective": "Afek stabil.",
                "assessment": "Baik.",
                "plan": "Lanjutkan.",
            },
        )
        assert res_expired.status_code == 400
        assert "H+1" in res_expired.json()["detail"]
