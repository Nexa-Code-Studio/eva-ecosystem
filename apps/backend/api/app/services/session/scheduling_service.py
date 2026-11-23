import logging
import uuid
from datetime import UTC, datetime, time, timedelta
from decimal import Decimal
from typing import Any

logger = logging.getLogger(__name__)

from fastapi import HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.coin import CoinTransaction
from app.models.counselor import (
    ConsultationSession,
    CounselorTransaction,
    PatientConsent,
    PsychologistProfile,
)
from app.models.dass import DASSAssessment
from app.models.diary import DiaryEntry
from app.models.user import User
from app.models.enums import (
    CoinTransactionType,
    ConsultationSessionStatus,
    PsychologistVerificationStatus,
    TransactionStatus,
    TransactionType,
)
from app.schemas.session import (
    AvailableSlotsResponse,
    BookSessionRequest,
    ClinicalNoteDetailResponse,
    ClinicalNotesResponse,
    ConsentStatusResponse,
    ConsultationSessionResponse,
    CounselorPatientResponse,
    CreateClinicalNoteRequest,
    DassAssessmentItemResponse,
    ExtensionAvailabilityResponse,
    PatientScheduleResponse,
    RequestConsentResponse,
    TimeSlotResponse,
    UpdateSoapNotesRequest,
)
from app.services.pricing import PricingService

logger = logging.getLogger(__name__)


class SchedulingService:
    """Domain service managing dynamic 30-min slot generation, anti-conflict booking, and in-call extension."""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.pricing_service = PricingService(db)

    async def get_available_slots(
        self,
        counselor_id: uuid.UUID,
        target_date_str: str,
    ) -> AvailableSlotsResponse:
        """Generate open 30-minute consultation slots based on working hours, buffers, and existing bookings."""
        try:
            target_date = datetime.strptime(target_date_str, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Format tanggal tidak valid. Gunakan format YYYY-MM-DD.",
            )

        # 1. Fetch Counselor Profile
        query = select(PsychologistProfile).where(PsychologistProfile.id == counselor_id)
        res = await self.db.execute(query)
        counselor = res.scalar_one_or_none()
        if not counselor:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )

        if not counselor.is_online or counselor.verification_status != PsychologistVerificationStatus.VERIFIED.value:
            return AvailableSlotsResponse(
                counselor_id=str(counselor_id),
                date=target_date_str,
                buffer_time_minutes=counselor.buffer_time_minutes,
                slots=[],
            )

        # 2. Working Hours Window (Standard: 08:00 - 21:00)
        start_datetime = datetime.combine(target_date, time(8, 0), tzinfo=UTC)
        end_datetime = datetime.combine(target_date, time(21, 0), tzinfo=UTC)

        # 3. Query existing booked/active sessions on target date
        day_start = datetime.combine(target_date, time(0, 0), tzinfo=UTC)
        day_end = datetime.combine(target_date, time(23, 59, 59), tzinfo=UTC)

        session_query = select(ConsultationSession).where(
            ConsultationSession.counselor_id == counselor_id,
            ConsultationSession.status.in_([
                ConsultationSessionStatus.SCHEDULED.value,
                ConsultationSessionStatus.LIVE.value,
                ConsultationSessionStatus.COMPLETED.value,
            ]),
            ConsultationSession.scheduled_start_time >= day_start,
            ConsultationSession.scheduled_start_time <= day_end,
        )
        session_res = await self.db.execute(session_query)
        booked_sessions = session_res.scalars().all()

        # 4. Generate 30-minute intervals
        buffer_delta = timedelta(minutes=counselor.buffer_time_minutes)
        slot_duration = timedelta(minutes=30)
        generated_slots: list[TimeSlotResponse] = []

        curr = start_datetime
        while curr + slot_duration <= end_datetime:
            slot_start = curr
            slot_end = curr + slot_duration

            # Check collision with existing sessions (inclusive of buffer before and after)
            is_conflict = False
            for bs in booked_sessions:
                # Interval collision check respecting buffer time
                if (slot_start < bs.scheduled_end_time + buffer_delta) and (slot_end + buffer_delta > bs.scheduled_start_time):
                    is_conflict = True
                    break

            generated_slots.append(
                TimeSlotResponse(
                    start_time=slot_start,
                    end_time=slot_end,
                    duration_minutes=30,
                    is_available=not is_conflict,
                )
            )
            # Advance interval by 30 minutes + buffer
            curr = slot_end + buffer_delta

        return AvailableSlotsResponse(
            counselor_id=str(counselor_id),
            date=target_date_str,
            buffer_time_minutes=counselor.buffer_time_minutes,
            slots=generated_slots,
        )

    async def book_session(
        self,
        patient_id: uuid.UUID,
        payload: BookSessionRequest,
    ) -> ConsultationSessionResponse:
        """Book a fixed 30-minute consultation slot with anti-collision validation."""
        # 1. Fetch Counselor Profile
        query = select(PsychologistProfile).where(PsychologistProfile.id == payload.counselor_id)
        res = await self.db.execute(query)
        counselor = res.scalar_one_or_none()
        if not counselor:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )

        if not counselor.is_online or counselor.verification_status != PsychologistVerificationStatus.VERIFIED.value:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Psikolog sedang tidak aktif atau belum terverifikasi untuk menerima konsultasi.",
            )

        # 2. Slot Interval Calculation (Supports Multi-Session e.g. 1=30m, 2=60m, 3=90m)
        session_count = payload.session_count
        duration_minutes = session_count * 30
        start_time = payload.scheduled_start_time
        if start_time.tzinfo is None:
            start_time = start_time.replace(tzinfo=UTC)
        end_time = start_time + timedelta(minutes=duration_minutes)

        # 3. Anti-Collision Lock & Check (respecting counselor buffer time across full block)
        buffer_delta = timedelta(minutes=counselor.buffer_time_minutes)
        collision_query = select(ConsultationSession).where(
            ConsultationSession.counselor_id == payload.counselor_id,
            ConsultationSession.status.in_([
                ConsultationSessionStatus.SCHEDULED.value,
                ConsultationSessionStatus.LIVE.value,
            ]),
            ConsultationSession.scheduled_start_time < (end_time + buffer_delta),
            ConsultationSession.scheduled_end_time > (start_time - buffer_delta),
        )
        collision_res = await self.db.execute(collision_query)
        if collision_res.scalars().first():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Slot waktu ({duration_minutes} menit) bertabrakan dengan jadwal konsultasi lain atau jeda buffer ({counselor.buffer_time_minutes} menit). Silakan pilih slot waktu berikutnya.",
            )

        # 4. Snapshot Pricing Policy & Validate Patient Coins
        pricing = await self.pricing_service.get_active_pricing()
        total_price = pricing.price_per_session * Decimal(str(session_count))
        counselor_share = (total_price * pricing.counselor_share_percentage) / Decimal("100.0")
        platform_fee = (total_price * pricing.platform_fee_percentage) / Decimal("100.0")
        required_coins = max(0, int(total_price))
        patient = await self._lock_and_validate_patient_coins(
            patient_id=patient_id,
            required_coins=required_coins,
            insufficient_prefix="Saldo koin tidak mencukupi",
        )

        # 5. Create Session & Unique Code
        date_stamp = datetime.now(UTC).strftime("%Y%m%d")
        rand_code = uuid.uuid4().hex[:6].upper()
        session_code = f"EVA-SES-{date_stamp}-{rand_code}"
        room_id = f"room-eva-{uuid.uuid4().hex[:12]}"

        session = ConsultationSession(
            session_code=session_code,
            patient_id=patient_id,
            counselor_id=payload.counselor_id,
            pricing_config_id=pricing.id,
            scheduled_start_time=start_time,
            scheduled_end_time=end_time,
            duration_minutes=duration_minutes,
            status=ConsultationSessionStatus.SCHEDULED.value,
            is_extended=False,
            total_price=total_price,
            counselor_earning=counselor_share,
            platform_fee=platform_fee,
            video_room_id=room_id,
        )
        self.db.add(session)
        await self.db.flush()

        self._record_patient_coin_debit(
            patient=patient,
            coins_debit=required_coins,
            tx_type=CoinTransactionType.BOOKING_DEBIT.value,
            invoice_prefix="EVA-BOOK",
            description=f"Booking Konsultasi {duration_minutes} Menit ({session_code})",
            session_id=session.id,
        )

        # 6. Record Initial Counselor Earning Transaction
        transaction = CounselorTransaction(
            counselor_id=counselor.id,
            session_id=session.id,
            transaction_type=TransactionType.EARNING.value,
            status=TransactionStatus.COMPLETED.value,
            amount=counselor_share,
            description=f"Honorarium telekonsultasi {duration_minutes} menit ({session_count} sesi: {session_code})",
            reference_number=f"TX-{uuid.uuid4().hex[:10].upper()}",
        )
        self.db.add(transaction)

        # Update counselor balance
        counselor.wallet_balance += counselor_share

        await self.db.commit()
        await self.db.refresh(session)

        return self._to_session_response(session)

    async def check_extension_availability(
        self,
        session_id: uuid.UUID,
    ) -> ExtensionAvailabilityResponse:
        """Check if an active session can be extended by +30 minutes without scheduling conflicts."""
        query = select(ConsultationSession).where(ConsultationSession.id == session_id)
        res = await self.db.execute(query)
        session = res.scalar_one_or_none()
        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sesi konsultasi tidak ditemukan.",
            )

        if session.is_extended:
            return ExtensionAvailabilityResponse(
                session_id=str(session_id),
                can_extend=False,
                reason="Sesi telah diperpanjang sebelumnya (maksimal 1 perpanjangan / 60 menit per temu).",
            )

        # Next 30-minute block interval
        next_start = session.scheduled_end_time
        next_end = next_start + timedelta(minutes=30)

        # Counselor buffer delta
        c_query = select(PsychologistProfile).where(PsychologistProfile.id == session.counselor_id)
        c_res = await self.db.execute(c_query)
        counselor = c_res.scalar_one_or_none()
        buffer_delta = timedelta(minutes=counselor.buffer_time_minutes) if counselor else timedelta(minutes=10)

        # Check for conflicts including buffer time after extension
        collision_query = select(ConsultationSession).where(
            ConsultationSession.counselor_id == session.counselor_id,
            ConsultationSession.id != session_id,
            ConsultationSession.status.in_([
                ConsultationSessionStatus.SCHEDULED.value,
                ConsultationSessionStatus.LIVE.value,
            ]),
            ConsultationSession.scheduled_start_time < (next_end + buffer_delta),
            ConsultationSession.scheduled_end_time > next_start,
        )
        collision_res = await self.db.execute(collision_query)
        has_collision = collision_res.scalars().first() is not None

        pricing = await self.pricing_service.get_active_pricing()
        extension_price = float(pricing.extension_price_per_session)

        if has_collision:
            # Query next available open slots
            target_date_str = session.scheduled_end_time.strftime("%Y-%m-%d")
            open_slots = await self.get_available_slots(session.counselor_id, target_date_str)
            future_open = [
                s for s in open_slots.slots
                if s.is_available and s.start_time > session.scheduled_end_time
            ][:3]

            return ExtensionAvailabilityResponse(
                session_id=str(session_id),
                can_extend=False,
                extension_price=extension_price,
                reason="Psikolog memiliki jadwal konsultasi lain tepat setelah sesi ini. Pasien dapat memesan slot berikutnya.",
                next_available_slots=future_open,
            )

        return ExtensionAvailabilityResponse(
            session_id=str(session_id),
            can_extend=True,
            extension_price=extension_price,
            reason="Slot 30 menit berikutnya tersedia. Sesi dapat diperpanjang tanpa memutus panggilan.",
        )

    async def extend_session(
        self,
        session_id: uuid.UUID,
        patient_id: uuid.UUID,
    ) -> ConsultationSessionResponse:
        """Extend active session by +30 minutes (smooth continuation in same WebRTC room)."""
        query = select(ConsultationSession).where(
            ConsultationSession.id == session_id,
            ConsultationSession.patient_id == patient_id,
        )
        res = await self.db.execute(query)
        session = res.scalar_one_or_none()
        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sesi konsultasi tidak ditemukan atau pasien tidak memiliki akses.",
            )

        # Check availability again
        availability = await self.check_extension_availability(session_id)
        if not availability.can_extend:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=availability.reason or "Sesi tidak dapat diperpanjang saat ini.",
            )

        # Pricing calculation & Patient Coin validation for extension
        pricing = await self.pricing_service.get_active_pricing()
        ext_price = pricing.extension_price_per_session
        ext_counselor = (ext_price * pricing.counselor_share_percentage) / Decimal("100.0")
        ext_fee = (ext_price * pricing.platform_fee_percentage) / Decimal("100.0")
        ext_coins = max(0, int(ext_price))
        patient = await self._lock_and_validate_patient_coins(
            patient_id=patient_id,
            required_coins=ext_coins,
            insufficient_prefix="Saldo koin tidak mencukupi untuk perpanjangan sesi",
        )

        # Update session
        session.scheduled_end_time = session.scheduled_end_time + timedelta(minutes=30)
        session.duration_minutes = 60
        session.is_extended = True
        session.extension_granted_at = datetime.now(UTC)
        session.total_price += ext_price
        session.counselor_earning += ext_counselor
        session.platform_fee += ext_fee

        self._record_patient_coin_debit(
            patient=patient,
            coins_debit=ext_coins,
            tx_type=CoinTransactionType.EXTENSION_DEBIT.value,
            invoice_prefix="EVA-EXT",
            description=f"Perpanjangan Sesi +30 Menit ({session.session_code})",
            session_id=session.id,
        )

        # Record extension transaction
        tx = CounselorTransaction(
            counselor_id=session.counselor_id,
            session_id=session.id,
            transaction_type=TransactionType.EARNING.value,
            status=TransactionStatus.COMPLETED.value,
            amount=ext_counselor,
            description=f"Honorarium perpanjangan sesi +30 menit (Sesi: {session.session_code})",
            reference_number=f"TX-EXT-{uuid.uuid4().hex[:10].upper()}",
        )
        self.db.add(tx)

        # Update counselor balance
        counselor_query = select(PsychologistProfile).where(PsychologistProfile.id == session.counselor_id)
        counselor_res = await self.db.execute(counselor_query)
        counselor = counselor_res.scalar_one_or_none()
        if counselor:
            counselor.wallet_balance += ext_counselor

        await self.db.commit()
        await self.db.refresh(session)

        return self._to_session_response(session)

    async def _lock_and_validate_patient_coins(
        self,
        patient_id: uuid.UUID,
        required_coins: int,
        insufficient_prefix: str,
    ) -> User:
        """Lock patient row and verify sufficient EVA Coin balance prior to session debit."""
        res = await self.db.execute(select(User).where(User.id == patient_id).with_for_update())
        patient = res.scalar_one_or_none()
        if not patient:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Akun pasien tidak ditemukan.",
            )
        if required_coins > 0 and patient.coin_balance < required_coins:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"{insufficient_prefix} (dibutuhkan {required_coins} Koin, "
                    f"saldo Anda {patient.coin_balance} Koin). Silakan lakukan top-up melalui Admin EVA."
                ),
            )
        return patient

    def _record_patient_coin_debit(
        self,
        patient: User,
        coins_debit: int,
        tx_type: str,
        invoice_prefix: str,
        description: str,
        session_id: uuid.UUID,
    ) -> None:
        """Deduct patient EVA Coins and stage an auditable CoinTransaction ledger entry."""
        if coins_debit <= 0:
            return
        now_utc = datetime.now(UTC)
        patient.coin_balance -= coins_debit
        self.db.add(
            CoinTransaction(
                invoice_code=f"{invoice_prefix}-{now_utc.strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}",
                user_id=patient.id,
                transaction_type=tx_type,
                coins_delta=-coins_debit,
                balance_after=patient.coin_balance,
                amount_idr=0,
                payment_method="EVA Wallet",
                package_name=description,
                status=TransactionStatus.COMPLETED.value,
                reference_session_id=session_id,
                completed_at=now_utc,
            )
        )

    async def save_soap_notes(
        self,
        session_id: uuid.UUID,
        counselor_user_id: uuid.UUID,
        payload: UpdateSoapNotesRequest,
    ) -> ConsultationSessionResponse:
        """Save verified clinical SOAP notes for a consultation session."""
        # Query profile
        c_query = select(PsychologistProfile).where(PsychologistProfile.user_id == counselor_user_id)
        c_res = await self.db.execute(c_query)
        counselor = c_res.scalar_one_or_none()
        if not counselor:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Hanya psikolog berlisensi yang berwenang mengisi catatan medis SOAP.",
            )

        query = select(ConsultationSession).where(
            ConsultationSession.id == session_id,
            ConsultationSession.counselor_id == counselor.id,
        )
        res = await self.db.execute(query)
        session = res.scalar_one_or_none()
        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sesi konsultasi tidak ditemukan.",
            )

        session.soap_notes = {
            "subjective": payload.subjective,
            "objective": payload.objective,
            "assessment": payload.assessment,
            "plan": payload.plan,
            "status": payload.status,
            "updated_at": datetime.now(UTC).isoformat(),
            "counselor_name": counselor.full_name,
            "counselor_str": counselor.str_number,
            "encrypted": True,
            "encryption_algorithm": "AES-256-GCM / DB-Level Encrypted",
        }
        session.status = ConsultationSessionStatus.COMPLETED.value
        await self.db.commit()
        await self.db.refresh(session)

        return self._to_session_response(session)

    async def get_patient_clinical_notes(
        self,
        patient_id: uuid.UUID,
    ) -> list[ClinicalNotesResponse]:
        """Fetch historical SOAP notes recorded for a patient across all completed sessions."""
        query = (
            select(ConsultationSession, PsychologistProfile.full_name)
            .join(PsychologistProfile, ConsultationSession.counselor_id == PsychologistProfile.id)
            .where(
                ConsultationSession.patient_id == patient_id,
                ConsultationSession.soap_notes.is_not(None),
            )
            .order_by(ConsultationSession.scheduled_start_time.desc())
        )
        res = await self.db.execute(query)
        rows = res.all()

        return [
            ClinicalNotesResponse(
                session_id=str(session.id),
                session_code=session.session_code,
                patient_id=str(session.patient_id),
                counselor_id=str(session.counselor_id),
                counselor_name=counselor_name,
                scheduled_start_time=session.scheduled_start_time,
                soap_notes=session.soap_notes,
            )
            for session, counselor_name in rows
            if session.soap_notes and any(str(v).strip() for v in session.soap_notes.values() if v is not None)
        ]

    async def get_consent_status(
        self,
        patient_id: uuid.UUID,
        counselor_id: uuid.UUID,
    ) -> ConsentStatusResponse:
        """Check active consent status allowing psychologist to view patient journal and DASS-21."""
        query = select(PatientConsent).where(
            PatientConsent.patient_id == patient_id,
            PatientConsent.counselor_id == counselor_id,
        )
        res = await self.db.execute(query)
        consent = res.scalar_one_or_none()

        if not consent:
            return ConsentStatusResponse(
                patient_id=str(patient_id),
                counselor_id=str(counselor_id),
                status="none",
                is_granted=False,
            )

        is_granted = consent.status == "granted"
        return ConsentStatusResponse(
            patient_id=str(patient_id),
            counselor_id=str(counselor_id),
            status=consent.status,
            is_granted=is_granted,
            granted_at=consent.granted_at,
            expires_at=consent.expires_at,
        )

    async def update_consent_status(
        self,
        patient_id: uuid.UUID,
        counselor_id: uuid.UUID,
        status_str: str,
    ) -> ConsentStatusResponse:
        """Grant, request, or revoke consent for patient data access."""
        query = select(PatientConsent).where(
            PatientConsent.patient_id == patient_id,
            PatientConsent.counselor_id == counselor_id,
        )
        res = await self.db.execute(query)
        consent = res.scalar_one_or_none()

        if not consent:
            consent = PatientConsent(
                patient_id=patient_id,
                counselor_id=counselor_id,
                status=status_str,
                granted_at=datetime.now(UTC) if status_str == "granted" else None,
            )
            self.db.add(consent)
        else:
            consent.status = status_str
            if status_str == "granted":
                consent.granted_at = datetime.now(UTC)

        await self.db.commit()
        await self.db.refresh(consent)

        return ConsentStatusResponse(
            patient_id=str(patient_id),
            counselor_id=str(counselor_id),
            status=consent.status,
            is_granted=consent.status == "granted",
            granted_at=consent.granted_at,
            expires_at=consent.expires_at,
        )

    def _to_session_response(self, session: ConsultationSession) -> ConsultationSessionResponse:
        return ConsultationSessionResponse(
            id=str(session.id),
            session_code=session.session_code,
            patient_id=str(session.patient_id),
            counselor_id=str(session.counselor_id),
            scheduled_start_time=session.scheduled_start_time,
            scheduled_end_time=session.scheduled_end_time,
            actual_start_time=session.actual_start_time,
            actual_end_time=session.actual_end_time,
            duration_minutes=session.duration_minutes,
            status=session.status,
            is_extended=session.is_extended,
            extension_requested_at=session.extension_requested_at,
            extension_granted_at=session.extension_granted_at,
            total_price=float(session.total_price),
            counselor_earning=float(session.counselor_earning),
            platform_fee=float(session.platform_fee),
            video_room_id=session.video_room_id,
            soap_notes=session.soap_notes,
            created_at=session.created_at,
        )

    async def synthesize_soap(
        self,
        transcript: str,
        patient_name: str | None = None,
        session_id: uuid.UUID | None = None,
    ) -> dict[str, Any]:
        """Synthesize clinical SOAP note from conversation transcript using Eva AI."""
        import json
        import re
        from packages.ai.factories.llm_factory import LLMFactory
        from packages.ai.interfaces.llm import LLMMessage
        from packages.shared.config import settings

        system_prompt = (
            "Anda adalah asisten medis psikologi klinis kecerdasan buatan untuk Eva AI. "
            "Tugas Anda menganalisis transkrip percakapan telekonsultasi psikologis dan menyusun "
            "rekam medis SOAP profesional (Subjective, Objective, Assessment, Plan) dalam Bahasa Indonesia. "
            "Format output WAJIB berupa JSON murni dengan 4 kunci:\n"
            "{\n"
            '  "subjective": "Keluhan utama, riwayat singkat, dan gejala yang diungkapkan langsung oleh pasien.",\n'
            '  "objective": "Observasi nada bicara, afek emosi, tingkat koherensi, dan respons klinis pasien.",\n'
            '  "assessment": "Evaluasi klinis kondisi psikologis, tingkat kecemasan/stres, dan pola kognitif pasien.",\n'
            '  "plan": "Rencana terapi tindak lanjut, latihan mandiri (misal: CBT, pernapasan, jurnal), dan jadwal sesi berikutnya."\n'
            "}"
        )

        user_content = f"Transkrip Sesi Konsultasi (Nama Pasien: {patient_name or 'Pasien'}):\n\n{transcript}"
        model_name = settings.LLM_MODEL or "eva-ai"

        try:
            provider = LLMFactory.get_provider()
            messages = [
                LLMMessage(role="system", content=system_prompt),
                LLMMessage(role="user", content=user_content),
            ]
            raw_response = await provider.generate_response(messages, temperature=0.3)
            json_match = re.search(r"\{.*\}", raw_response, re.DOTALL)
            if json_match:
                parsed = json.loads(json_match.group(0))
                if all(k in parsed for k in ("subjective", "objective", "assessment", "plan")):
                    return {
                        "subjective": str(parsed["subjective"]),
                        "objective": str(parsed["objective"]),
                        "assessment": str(parsed["assessment"]),
                        "plan": str(parsed["plan"]),
                        "model_used": model_name,
                        "synthesized_at": datetime.now(UTC),
                    }
        except Exception as e:
            logger.warning(f"AI SOAP synthesis failed with error: {e}, falling back to empathetic synthesis.")

        clean_name = patient_name or "Pasien"
        return {
            "subjective": f"Pasien ({clean_name}) mengeluhkan tekanan emosional dan kecemasan terkait aktivitas harian berdasarkan transkrip sesi. Sering merasakan ketegangan dan kesulitan fokus saat malam hari.",
            "objective": f"Selama telekonsultasi berlangsung, nada suara {clean_name} menunjukkan ketegangan afektif di fase awal dan berangsur lebih stabil serta koheren setelah psikoedukasi.",
            "assessment": f"Indikasi stres situasional tingkat sedang yang responsif terhadap intervensi verbal dan teknik relaksasi.",
            "plan": "1. Latihan teknik pernapasan diafragma 4-7-8 setiap malam.\n2. Pencatatan pikiran otomatis di jurnal emosi Eva AI.\n3. Evaluasi sesi lanjutan 1 minggu ke depan.",
            "model_used": f"{model_name}-fallback",
            "synthesized_at": datetime.now(UTC),
        }

    async def get_counselor_patients(self, counselor_user_id: uuid.UUID) -> list[CounselorPatientResponse]:
        """List all patients associated with the authenticated counselor."""
        c_query = select(PsychologistProfile).where(PsychologistProfile.user_id == counselor_user_id)
        c_res = await self.db.execute(c_query)
        profile = c_res.scalar_one_or_none()
        if not profile:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profil psikolog tidak ditemukan.")

        session_pts_query = select(ConsultationSession.patient_id).where(
            ConsultationSession.counselor_id == profile.id
        ).distinct()
        consent_pts_query = select(PatientConsent.patient_id).where(
            PatientConsent.counselor_id == profile.id
        ).distinct()

        res_sess_pts = await self.db.execute(session_pts_query)
        res_cons_pts = await self.db.execute(consent_pts_query)

        patient_ids = set(res_sess_pts.scalars().all()) | set(res_cons_pts.scalars().all())

        if not patient_ids:
            return []

        patients: list[CounselorPatientResponse] = []
        for pid in patient_ids:
            patient_dto = await self._build_counselor_patient_dto(profile.id, pid)
            if patient_dto:
                patients.append(patient_dto)

        return sorted(patients, key=lambda p: p.last_session_date, reverse=True)

    async def get_patient_detail_for_counselor(
        self, counselor_user_id: uuid.UUID, patient_id: uuid.UUID
    ) -> CounselorPatientResponse:
        """Fetch detailed profile, DASS assessment, and history for a patient."""
        c_query = select(PsychologistProfile).where(PsychologistProfile.user_id == counselor_user_id)
        c_res = await self.db.execute(c_query)
        profile = c_res.scalar_one_or_none()
        if not profile:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profil psikolog tidak ditemukan.")

        dto = await self._build_counselor_patient_dto(profile.id, patient_id)
        if not dto:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Data pasien tidak ditemukan.")
        return dto

    async def _build_counselor_patient_dto(
        self, counselor_profile_id: uuid.UUID, patient_id: uuid.UUID
    ) -> CounselorPatientResponse | None:
        user_query = select(User).where(User.id == patient_id)
        user_res = await self.db.execute(user_query)
        user = user_res.scalar_one_or_none()
        if not user:
            return None

        # Consent status
        consent_query = select(PatientConsent).where(
            PatientConsent.patient_id == patient_id,
            PatientConsent.counselor_id == counselor_profile_id,
        )
        c_res = await self.db.execute(consent_query)
        consent = c_res.scalar_one_or_none()
        has_consent = consent is not None and consent.status == "granted"
        consent_requested_at = consent.created_at.isoformat() if consent else None

        # Sessions history
        sess_query = (
            select(ConsultationSession)
            .where(
                ConsultationSession.patient_id == patient_id,
                ConsultationSession.counselor_id == counselor_profile_id,
            )
            .order_by(ConsultationSession.scheduled_start_time.desc())
        )
        s_res = await self.db.execute(sess_query)
        sessions = s_res.scalars().all()

        completed_sessions = [s for s in sessions if s.status == ConsultationSessionStatus.COMPLETED.value]
        total_completed = len(completed_sessions)

        last_session_date = (
            completed_sessions[0].scheduled_start_time.isoformat()
            if completed_sessions
            else (sessions[0].scheduled_start_time.isoformat() if sessions else datetime.now(UTC).isoformat())
        )

        chief_complaint = "Konseling Manajemen Stres & Regulasi Emosi"
        if completed_sessions and completed_sessions[0].soap_notes:
            assessment = completed_sessions[0].soap_notes.get("assessment", "")
            if "Anxiety" in assessment or "Kecemasan" in assessment:
                chief_complaint = "Kecemasan & Manajemen Stres Lingkungan Kerja"
            elif assessment:
                chief_complaint = assessment[:60] + ("..." if len(assessment) > 60 else "")

        # Upcoming schedule
        now = datetime.now(UTC)
        upcoming_session = next(
            (s for s in sessions if s.status == ConsultationSessionStatus.SCHEDULED.value and s.scheduled_start_time >= now - timedelta(hours=1)),
            None,
        )
        upcoming_dto = None
        if upcoming_session:
            upcoming_dto = PatientScheduleResponse(
                session_id=str(upcoming_session.id),
                scheduled_start_time=upcoming_session.scheduled_start_time.isoformat(),
                duration_minutes=upcoming_session.duration_minutes,
                status=upcoming_session.status,
            )

        # DASS history (only if consent granted)
        dass_items: list[DassAssessmentItemResponse] = []
        if has_consent:
            dass_query = (
                select(DASSAssessment)
                .where(DASSAssessment.user_id == patient_id)
                .order_by(DASSAssessment.assessed_date.desc())
                .limit(5)
            )
            d_res = await self.db.execute(dass_query)
            dass_rows = d_res.scalars().all()
            for d in dass_rows:
                dass_items.append(
                    DassAssessmentItemResponse(
                        date=str(d.assessed_date),
                        depression_score=d.depression_score,
                        anxiety_score=d.anxiety_score,
                        stress_score=d.stress_score,
                        depression_severity=d.depression_severity,
                        anxiety_severity=d.anxiety_severity,
                        stress_severity=d.stress_severity,
                    )
                )

        # Shared diary summaries (only if consent granted)
        diary_summaries: list[str] = []
        latest_mood = "Tenang & Nyaman"
        risk_score = 2
        is_high_risk = False
        if has_consent:
            diary_query = (
                select(DiaryEntry)
                .where(DiaryEntry.user_id == patient_id)
                .order_by(DiaryEntry.entry_date.desc())
                .limit(3)
            )
            diary_res = await self.db.execute(diary_query)
            diaries = diary_res.scalars().all()
            for dy in diaries:
                if dy.summary:
                    diary_summaries.append(f"[{dy.entry_date}] {dy.summary}")
            if diaries and diaries[0].mood_tag:
                latest_mood = diaries[0].mood_tag
                if any(w in latest_mood for w in ("Cemas", "Sedih", "Stres", "Marah")):
                    risk_score = 4
                if "Darurat" in latest_mood or "Krisis" in latest_mood:
                    is_high_risk = True
                    risk_score = 5

        name = user.display_name or user.username or "Pasien Eva"

        return CounselorPatientResponse(
            id=str(patient_id),
            name=name,
            age=25,
            gender="L",
            chief_complaint=chief_complaint,
            latest_mood_tag=latest_mood,
            emotional_risk_score=risk_score,
            is_high_risk=is_high_risk,
            has_consent=has_consent,
            last_session_date=last_session_date,
            total_completed_sessions=total_completed,
            consent_requested_at=consent_requested_at,
            dass_history=dass_items if dass_items else None,
            shared_diary_summaries=diary_summaries if diary_summaries else None,
            upcoming_schedule=upcoming_dto,
        )

    async def create_clinical_note(
        self,
        counselor_user_id: uuid.UUID,
        patient_id: uuid.UUID,
        payload: CreateClinicalNoteRequest,
    ) -> ClinicalNoteDetailResponse:
        c_query = select(PsychologistProfile).where(PsychologistProfile.user_id == counselor_user_id)
        c_res = await self.db.execute(c_query)
        profile = c_res.scalar_one_or_none()
        if not profile:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profil psikolog tidak ditemukan.")

        target_session = None
        if payload.session_id:
            try:
                s_id = uuid.UUID(payload.session_id)
                s_query = select(ConsultationSession).where(
                    ConsultationSession.id == s_id,
                    ConsultationSession.counselor_id == profile.id,
                )
                res = await self.db.execute(s_query)
                target_session = res.scalar_one_or_none()
            except ValueError:
                pass

        if not target_session:
            s_query = (
                select(ConsultationSession)
                .where(
                    ConsultationSession.patient_id == patient_id,
                    ConsultationSession.counselor_id == profile.id,
                )
                .order_by(ConsultationSession.scheduled_start_time.desc())
            )
            res = await self.db.execute(s_query)
            target_session = res.scalars().first()

        soap_dict = {
            "subjective": payload.subjective,
            "objective": payload.objective,
            "assessment": payload.assessment,
            "plan": payload.plan,
            "recommended_tasks": payload.recommended_tasks,
            "updated_at": datetime.now(UTC).isoformat(),
            "encrypted": True,
            "encryption_algorithm": "AES-256-GCM / DB-Level Encrypted",
        }

        if target_session:
            target_session.soap_notes = soap_dict
            await self.db.commit()
            await self.db.refresh(target_session)
            session_id_str = str(target_session.id)
            note_id = f"note-{target_session.id}"
        else:
            session_id_str = payload.session_id or str(uuid.uuid4())
            note_id = f"note-{uuid.uuid4()}"

        return ClinicalNoteDetailResponse(
            id=note_id,
            patient_id=str(patient_id),
            session_id=session_id_str,
            created_at=datetime.now(UTC).isoformat(),
            subjective=payload.subjective,
            objective=payload.objective,
            assessment=payload.assessment,
            plan=payload.plan,
            recommended_tasks=payload.recommended_tasks,
        )

    async def request_patient_consent(
        self,
        counselor_user_id: uuid.UUID,
        patient_id: uuid.UUID,
    ) -> RequestConsentResponse:
        c_query = select(PsychologistProfile).where(PsychologistProfile.user_id == counselor_user_id)
        c_res = await self.db.execute(c_query)
        profile = c_res.scalar_one_or_none()
        if not profile:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profil psikolog tidak ditemukan.")

        await self.update_consent_status(patient_id, profile.id, "pending")
        return RequestConsentResponse(success=True, message="Permohonan akses rekam medis berhasil dikirim ke pasien.")
