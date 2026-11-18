import logging
import uuid
from datetime import UTC, datetime, time, timedelta
from decimal import Decimal

from fastapi import HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.counselor import (
    ConsultationSession,
    CounselorTransaction,
    PatientConsent,
    PsychologistProfile,
)
from app.models.enums import (
    ConsultationSessionStatus,
    PsychologistVerificationStatus,
    TransactionStatus,
    TransactionType,
)
from app.schemas.session import (
    AvailableSlotsResponse,
    BookSessionRequest,
    ClinicalNotesResponse,
    ConsentStatusResponse,
    ConsultationSessionResponse,
    ExtensionAvailabilityResponse,
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

            # Check collision with existing sessions (inclusive of buffer)
            is_conflict = False
            for bs in booked_sessions:
                # Interval collision check
                if (slot_start < bs.scheduled_end_time + buffer_delta) and (slot_end > bs.scheduled_start_time):
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

        # 2. Slot Interval Calculation (Fixed 30 Minutes)
        start_time = payload.scheduled_start_time
        if start_time.tzinfo is None:
            start_time = start_time.replace(tzinfo=UTC)
        end_time = start_time + timedelta(minutes=30)

        # 3. Anti-Collision Lock & Check
        collision_query = select(ConsultationSession).where(
            ConsultationSession.counselor_id == payload.counselor_id,
            ConsultationSession.status.in_([
                ConsultationSessionStatus.SCHEDULED.value,
                ConsultationSessionStatus.LIVE.value,
            ]),
            ConsultationSession.scheduled_start_time < end_time,
            ConsultationSession.scheduled_end_time > start_time,
        )
        collision_res = await self.db.execute(collision_query)
        if collision_res.scalars().first():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Slot waktu ini telah dipesan oleh pasien lain. Silakan pilih slot waktu berikutnya.",
            )

        # 4. Snapshot Pricing Policy
        pricing = await self.pricing_service.get_active_pricing()
        total_price = pricing.price_per_session
        counselor_share = (total_price * pricing.counselor_share_percentage) / Decimal("100.0")
        platform_fee = (total_price * pricing.platform_fee_percentage) / Decimal("100.0")

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
            duration_minutes=30,
            status=ConsultationSessionStatus.SCHEDULED.value,
            is_extended=False,
            total_price=total_price,
            counselor_earning=counselor_share,
            platform_fee=platform_fee,
            video_room_id=room_id,
        )
        self.db.add(session)
        await self.db.flush()

        # 6. Record Initial Counselor Earning Transaction
        transaction = CounselorTransaction(
            counselor_id=counselor.id,
            session_id=session.id,
            transaction_type=TransactionType.EARNING.value,
            status=TransactionStatus.COMPLETED.value,
            amount=counselor_share,
            description=f"Honorarium telekonsultasi 30 menit (Sesi: {session_code})",
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

        # Check for conflicts
        collision_query = select(ConsultationSession).where(
            ConsultationSession.counselor_id == session.counselor_id,
            ConsultationSession.id != session_id,
            ConsultationSession.status.in_([
                ConsultationSessionStatus.SCHEDULED.value,
                ConsultationSessionStatus.LIVE.value,
            ]),
            ConsultationSession.scheduled_start_time < next_end,
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

        # Pricing calculation for extension
        pricing = await self.pricing_service.get_active_pricing()
        ext_price = pricing.extension_price_per_session
        ext_counselor = (ext_price * pricing.counselor_share_percentage) / Decimal("100.0")
        ext_fee = (ext_price * pricing.platform_fee_percentage) / Decimal("100.0")

        # Update session
        session.scheduled_end_time = session.scheduled_end_time + timedelta(minutes=30)
        session.duration_minutes = 60
        session.is_extended = True
        session.extension_granted_at = datetime.now(UTC)
        session.total_price += ext_price
        session.counselor_earning += ext_counselor
        session.platform_fee += ext_fee

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
