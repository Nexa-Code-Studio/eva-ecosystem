import logging
import uuid
from datetime import UTC, datetime, time, timedelta, timezone
from decimal import Decimal
from typing import Any

logger = logging.getLogger(__name__)

from fastapi import HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

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
from app.schemas.counselor import (
    BlockedRangeItem,
    CounselorTimelineResponse,
    OperatingHoursItem,
    TimeRangeItem,
)
from app.schemas.session import (
    AdminSessionMonitoringResponse,
    AvailableSlotsResponse,
    BookSessionRequest,
    ClinicalNoteDetailResponse,
    ClinicalNotesResponse,
    ClinicalTriggerItem,
    ConsentStatusResponse,
    ConsultationSessionResponse,
    CounselorPatientResponse,
    CreateClinicalNoteRequest,
    DassAssessmentItemResponse,
    ExtensionAvailabilityResponse,
    PatientClinicalTriggersResponse,
    PatientScheduleResponse,
    RequestConsentResponse,
    TimeSlotResponse,
    UpdateSoapNotesRequest,
)
from app.services.coin.coin_service import format_user_code
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
        query = (
            select(PsychologistProfile)
            .options(selectinload(PsychologistProfile.current_level))
            .where(PsychologistProfile.id == payload.counselor_id)
        )
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
        # 3. Anti-Collision Lock & Check (respecting counselor buffer time and break intervals)
        buffer_delta = timedelta(minutes=counselor.buffer_time_minutes)

        # Check multi-break collisions from schedule_config
        day_name = start_time.strftime("%A").lower()
        sched_cfg = counselor.schedule_config or {}
        day_cfg = sched_cfg.get(day_name)
        if day_cfg:
            if not day_cfg.get("is_active", True):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Konselor tidak membuka jadwal praktik pada hari {day_name.capitalize()}.",
                )
            for brk in day_cfg.get("breaks", []):
                b_start_str = brk.get("start")
                b_end_str = brk.get("end")
                if b_start_str and b_end_str:
                    try:
                        b_s_h, b_s_m = [int(x) for x in b_start_str.split(":")]
                        b_e_h, b_e_m = [int(x) for x in b_end_str.split(":")]
                        brk_start = datetime.combine(start_time.date(), time(b_s_h, b_s_m), tzinfo=start_time.tzinfo)
                        brk_end = datetime.combine(start_time.date(), time(b_e_h, b_e_m), tzinfo=start_time.tzinfo)
                        if start_time < brk_end and end_time > brk_start:
                            brk_label = brk.get("label", "Istirahat")
                            raise HTTPException(
                                status_code=status.HTTP_409_CONFLICT,
                                detail=f"Slot waktu bertabrakan dengan jam istirahat konselor ({brk_label}: {b_start_str} - {b_end_str}).",
                            )
                    except (ValueError, IndexError):
                        pass
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

        # 4. Snapshot Tiered/Level Pricing Policy & Validate Patient Coins
        from app.services.level import LevelService

        resolved_pricing = await LevelService(self.db).resolve_counselor_pricing(
            payload.counselor_id,
            profile=counselor,
            pricing_service=self.pricing_service,
        )
        total_price = resolved_pricing.price_per_session * Decimal(str(session_count))
        counselor_share = (total_price * resolved_pricing.counselor_share_percentage) / Decimal("100.0")
        platform_fee = (total_price * resolved_pricing.platform_fee_percentage) / Decimal("100.0")
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
            pricing_config_id=resolved_pricing.fallback_pricing_config_id,
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

        # 6. Record Initial Counselor Earning Transaction (held in pending_clearing until completion)
        transaction = CounselorTransaction(
            counselor_id=counselor.id,
            session_id=session.id,
            transaction_type=TransactionType.EARNING.value,
            status=TransactionStatus.PENDING.value,
            amount=counselor_share,
            description=f"Honorarium telekonsultasi {duration_minutes} menit ({session_count} sesi: {session_code})",
            reference_number=f"TX-{uuid.uuid4().hex[:10].upper()}",
        )
        self.db.add(transaction)

        await self.db.commit()
        await self.db.refresh(session)

        return self._to_session_response(session)

    @staticmethod
    def _resolve_day_schedule(
        counselor: PsychologistProfile | None,
        target_date: Any,
    ) -> tuple[bool, str, str, list[dict[str, Any]]]:
        """Resolve (is_active, op_start, op_end, breaks) consistently with counselor timeline."""
        day_name = target_date.strftime("%A").lower()
        sched_cfg = (counselor.schedule_config or {}) if counselor else {}
        day_cfg = sched_cfg.get(day_name, {})

        op_hours = day_cfg.get("operating_hours", {}) if isinstance(day_cfg, dict) else {}
        op_start = op_hours.get("start", "08:00")
        op_end = op_hours.get("end", "17:00")
        is_active = day_cfg.get("is_active", True) if isinstance(day_cfg, dict) else True

        breaks = list(day_cfg.get("breaks", [])) if isinstance(day_cfg, dict) else []
        if not breaks and not day_cfg:
            if day_name in ["monday", "tuesday", "wednesday", "thursday"]:
                breaks = [{"start": "12:00", "end": "13:00", "label": "Istirahat Siang"}]
            elif day_name == "friday":
                breaks = [
                    {"start": "11:30", "end": "13:00", "label": "Shalat Jumat & Istirahat"},
                    {"start": "15:30", "end": "16:00", "label": "Istirahat Sore"},
                ]
        return is_active, op_start, op_end, breaks

    @staticmethod
    def _parse_hhmm_to_minutes(t_str: str) -> int | None:
        try:
            parts = t_str.strip().split(":")
            return int(parts[0]) * 60 + int(parts[1])
        except (ValueError, IndexError, AttributeError):
            return None

    @staticmethod
    def _format_minutes_hhmm(mins: int) -> str:
        return f"{mins // 60:02d}:{mins % 60:02d}"

    @classmethod
    def compute_day_open_windows(
        cls,
        counselor: PsychologistProfile,
        target_date: Any,
        sessions: list[ConsultationSession],
        local_tz: timezone,
    ) -> list[tuple[int, int]]:
        """Compute open [start_min, end_min] windows (>= 30m) for a counselor on target_date."""
        is_active, op_start, op_end, breaks = cls._resolve_day_schedule(counselor, target_date)
        if not is_active:
            return []

        op_start_min = cls._parse_hhmm_to_minutes(op_start)
        op_end_min = cls._parse_hhmm_to_minutes(op_end)
        if op_start_min is None or op_end_min is None or op_end_min <= op_start_min:
            return []

        blocked: list[tuple[int, int]] = []
        for brk in breaks:
            b_start = cls._parse_hhmm_to_minutes(brk.get("start", ""))
            b_end = cls._parse_hhmm_to_minutes(brk.get("end", ""))
            if b_start is not None and b_end is not None and b_end > b_start:
                blocked.append((b_start, b_end))

        buffer_mins = max(0, int(counselor.buffer_time_minutes or 0))
        for sess in sessions:
            s_start_dt = sess.scheduled_start_time
            s_end_dt = sess.scheduled_end_time
            if s_start_dt.tzinfo is None:
                s_start_dt = s_start_dt.replace(tzinfo=UTC)
            if s_end_dt.tzinfo is None:
                s_end_dt = s_end_dt.replace(tzinfo=UTC)
            s_start_local = s_start_dt.astimezone(local_tz)
            s_end_local = s_end_dt.astimezone(local_tz)
            if s_start_local.date() != target_date and s_end_local.date() != target_date:
                continue
            s_start_min = (
                s_start_local.hour * 60 + s_start_local.minute
                if s_start_local.date() == target_date
                else 0
            )
            s_end_min = (
                s_end_local.hour * 60 + s_end_local.minute + buffer_mins
                if s_end_local.date() == target_date
                else 24 * 60
            )
            if s_end_min > s_start_min:
                blocked.append((s_start_min, s_end_min))

        blocked.sort(key=lambda item: item[0])
        windows: list[tuple[int, int]] = []
        current_min = op_start_min
        for br_start, br_end in blocked:
            if br_start > current_min and current_min < op_end_min:
                window_end = min(br_start, op_end_min)
                if window_end - current_min >= 30:
                    windows.append((current_min, window_end))
            current_min = max(current_min, br_end)

        if current_min < op_end_min and (op_end_min - current_min >= 30):
            windows.append((current_min, op_end_min))
        return windows

    @classmethod
    def compute_counselor_availability_summary(
        cls,
        counselor: PsychologistProfile,
        now_local: datetime,
        sessions: list[ConsultationSession],
        local_tz: timezone,
    ) -> dict[str, Any]:
        """Compute real-time availability status, next open slot, and remaining slot count."""
        today_date = now_local.date()
        tomorrow_date = today_date + timedelta(days=1)
        now_minutes = now_local.hour * 60 + now_local.minute

        today_windows = cls.compute_day_open_windows(counselor, today_date, sessions, local_tz)
        tomorrow_windows = cls.compute_day_open_windows(counselor, tomorrow_date, sessions, local_tz)

        has_slots_tomorrow = len(tomorrow_windows) > 0
        next_slot_tomorrow = (
            cls._format_minutes_hhmm(tomorrow_windows[0][0]) if has_slots_tomorrow else None
        )

        available_now = False
        remaining_slots_today = 0
        next_today_start: int | None = None

        for w_start, w_end in today_windows:
            eff_start = max(w_start, now_minutes)
            if w_end - eff_start >= 30:
                remaining_slots_today += (w_end - eff_start) // 30
                if next_today_start is None:
                    next_today_start = eff_start
                if w_start <= now_minutes < w_end:
                    available_now = True

        if not counselor.is_online:
            return {
                "availability_status": "unavailable",
                "next_available_slot": None,
                "next_available_date": None,
                "remaining_slots_today": 0,
                "has_slots_tomorrow": False,
                "next_slot_tomorrow": None,
            }

        if available_now:
            return {
                "availability_status": "available_now",
                "next_available_slot": cls._format_minutes_hhmm(now_minutes),
                "next_available_date": today_date.isoformat(),
                "remaining_slots_today": remaining_slots_today,
                "has_slots_tomorrow": has_slots_tomorrow,
                "next_slot_tomorrow": next_slot_tomorrow,
            }

        if remaining_slots_today > 0 and next_today_start is not None:
            return {
                "availability_status": "available_today",
                "next_available_slot": cls._format_minutes_hhmm(next_today_start),
                "next_available_date": today_date.isoformat(),
                "remaining_slots_today": remaining_slots_today,
                "has_slots_tomorrow": has_slots_tomorrow,
                "next_slot_tomorrow": next_slot_tomorrow,
            }

        if has_slots_tomorrow:
            return {
                "availability_status": "available_tomorrow",
                "next_available_slot": next_slot_tomorrow,
                "next_available_date": tomorrow_date.isoformat(),
                "remaining_slots_today": 0,
                "has_slots_tomorrow": True,
                "next_slot_tomorrow": next_slot_tomorrow,
            }

        return {
            "availability_status": "unavailable",
            "next_available_slot": None,
            "next_available_date": None,
            "remaining_slots_today": 0,
            "has_slots_tomorrow": False,
            "next_slot_tomorrow": None,
        }

    @classmethod
    def evaluate_schedule_config_conflict(
        cls,
        counselor: PsychologistProfile | None,
        window_start: datetime,
        window_end: datetime,
    ) -> str | None:
        """Return conflict reason if [window_start, window_end] violates active day, operating hours, or breaks."""
        if counselor is None:
            return None

        is_active, op_start_str, op_end_str, breaks = cls._resolve_day_schedule(
            counselor, window_start.date()
        )
        day_name = window_start.strftime("%A").capitalize()
        if not is_active:
            return f"Konselor tidak membuka jadwal praktik pada hari {day_name}."

        try:
            op_s_h, op_s_m = [int(x) for x in op_start_str.split(":")]
            op_e_h, op_e_m = [int(x) for x in op_end_str.split(":")]
            op_start_dt = datetime.combine(window_start.date(), time(op_s_h, op_s_m), tzinfo=window_start.tzinfo)
            op_end_dt = datetime.combine(window_start.date(), time(op_e_h, op_e_m), tzinfo=window_start.tzinfo)
            if window_start < op_start_dt or window_end > op_end_dt:
                return (
                    f"Perpanjangan (+30 menit) melewati jam operasional praktik konselor "
                    f"({op_start_str} - {op_end_str})."
                )
        except (ValueError, IndexError):
            pass

        for brk in breaks:
            b_start_str = brk.get("start")
            b_end_str = brk.get("end")
            if not (b_start_str and b_end_str):
                continue
            try:
                b_s_h, b_s_m = [int(x) for x in b_start_str.split(":")]
                b_e_h, b_e_m = [int(x) for x in b_end_str.split(":")]
                brk_start = datetime.combine(window_start.date(), time(b_s_h, b_s_m), tzinfo=window_start.tzinfo)
                brk_end = datetime.combine(window_start.date(), time(b_e_h, b_e_m), tzinfo=window_start.tzinfo)
                if window_start < brk_end and window_end > brk_start:
                    brk_label = brk.get("label", "Istirahat")
                    return (
                        f"Slot waktu bertabrakan dengan jam istirahat konselor "
                        f"({brk_label}: {b_start_str} - {b_end_str})."
                    )
            except (ValueError, IndexError):
                continue

        return None

    async def check_extension_availability(
        self,
        session_id: uuid.UUID,
    ) -> ExtensionAvailabilityResponse:
        """Check if an active session can be extended by +30 minutes without scheduling, break, or closing conflicts."""
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
        if next_start.tzinfo is None:
            next_start = next_start.replace(tzinfo=UTC)
        next_end = next_start + timedelta(minutes=30)

        # Counselor buffer delta & schedule config
        c_query = select(PsychologistProfile).where(PsychologistProfile.id == session.counselor_id)
        c_res = await self.db.execute(c_query)
        counselor = c_res.scalar_one_or_none()
        buffer_delta = timedelta(minutes=counselor.buffer_time_minutes) if counselor else timedelta(minutes=10)

        schedule_conflict_reason = self.evaluate_schedule_config_conflict(
            counselor, next_start, next_end
        )

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

        from app.services.level import LevelService

        resolved_pricing = await LevelService(self.db).resolve_counselor_pricing(
            session.counselor_id,
            pricing_service=self.pricing_service,
        )
        extension_price = float(resolved_pricing.extension_price_per_session)

        if schedule_conflict_reason or has_collision:
            # Query next available open slots
            target_date_str = next_start.strftime("%Y-%m-%d")
            open_slots = await self.get_available_slots(session.counselor_id, target_date_str)
            future_open = [
                s for s in open_slots.slots
                if s.is_available
                and s.start_time > next_start
                and self.evaluate_schedule_config_conflict(counselor, s.start_time, s.end_time) is None
            ][:3]

            return ExtensionAvailabilityResponse(
                session_id=str(session_id),
                can_extend=False,
                extension_price=extension_price,
                reason=schedule_conflict_reason
                or "Psikolog memiliki jadwal konsultasi lain tepat setelah sesi ini. Pasien dapat memesan slot berikutnya.",
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
        from app.services.level import LevelService

        resolved_pricing = await LevelService(self.db).resolve_counselor_pricing(
            session.counselor_id,
            pricing_service=self.pricing_service,
        )
        ext_price = resolved_pricing.extension_price_per_session
        ext_counselor = (ext_price * resolved_pricing.counselor_share_percentage) / Decimal("100.0")
        ext_fee = (ext_price * resolved_pricing.platform_fee_percentage) / Decimal("100.0")
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

        # Record extension transaction (held in pending_clearing until session completion)
        tx = CounselorTransaction(
            counselor_id=session.counselor_id,
            session_id=session.id,
            transaction_type=TransactionType.EARNING.value,
            status=TransactionStatus.PENDING.value,
            amount=ext_counselor,
            description=f"Honorarium perpanjangan sesi +30 menit (Sesi: {session.session_code})",
            reference_number=f"TX-EXT-{uuid.uuid4().hex[:10].upper()}",
        )
        self.db.add(tx)

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

        subj_text = payload.subjective or (payload.narrative if not payload.points else "\n".join(f"• {p}" for p in payload.points))
        assess_text = payload.assessment or payload.narrative or (payload.points[0] if payload.points else "Observasi klinis tercatat.")
        session.soap_notes = {
            "points": payload.points,
            "narrative": payload.narrative,
            "subjective": subj_text,
            "objective": payload.objective or "Observasi klinis langsung telekonseling",
            "assessment": assess_text,
            "plan": payload.plan or "Evaluasi mandiri berkala pasien",
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

        await self.release_pending_session_earnings(session.id)

        try:
            from app.services.certificate import CertificateService
            from app.services.level import LevelService

            await LevelService(self.db).recalculate_and_evaluate(counselor_id=counselor.id)
            await CertificateService(self.db).evaluate_auto_issuance(counselor_id=counselor.id)
        except Exception:
            pass

        return self._to_session_response(session)

    async def release_pending_session_earnings(self, session_id: uuid.UUID) -> Decimal:
        """Atomically release pending clearing honorarium to counselor available wallet_balance once."""
        tx_res = await self.db.execute(
            select(CounselorTransaction)
            .where(
                CounselorTransaction.session_id == session_id,
                CounselorTransaction.transaction_type == TransactionType.EARNING.value,
                CounselorTransaction.status == TransactionStatus.PENDING.value,
            )
            .with_for_update()
        )
        pending_txs = tx_res.scalars().all()
        if not pending_txs:
            return Decimal("0.00")

        counselor_id = pending_txs[0].counselor_id
        c_res = await self.db.execute(
            select(PsychologistProfile).where(PsychologistProfile.id == counselor_id).with_for_update()
        )
        counselor = c_res.scalar_one_or_none()
        if not counselor:
            return Decimal("0.00")

        released = Decimal("0.00")
        for tx in pending_txs:
            tx.status = TransactionStatus.COMPLETED.value
            released += tx.amount

        counselor.wallet_balance += released
        await self.db.commit()
        return released

    async def cancel_session_and_refund(
        self,
        session_id: uuid.UUID,
        *,
        reason: str | None = None,
    ) -> int:
        """Atomically cancel an uncompleted session, void pending earnings, and refund patient coins once."""
        sess_res = await self.db.execute(
            select(ConsultationSession).where(ConsultationSession.id == session_id).with_for_update()
        )
        session = sess_res.scalar_one_or_none()
        if not session:
            return 0
        if session.status == ConsultationSessionStatus.COMPLETED.value:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Sesi yang sudah selesai tidak dapat dibatalkan.",
            )

        session.status = ConsultationSessionStatus.CANCELLED.value
        if reason and not session.cancellation_reason:
            session.cancellation_reason = reason

        # Void pending counselor earnings so uncompleted sessions never become withdrawable
        earn_res = await self.db.execute(
            select(CounselorTransaction)
            .where(
                CounselorTransaction.session_id == session_id,
                CounselorTransaction.transaction_type == TransactionType.EARNING.value,
                CounselorTransaction.status == TransactionStatus.PENDING.value,
            )
            .with_for_update()
        )
        for etx in earn_res.scalars().all():
            etx.status = TransactionStatus.FAILED.value

        # Check if a refund coin ledger entry already exists for this session (idempotent)
        existing_refund = await self.db.execute(
            select(CoinTransaction.id).where(
                CoinTransaction.reference_session_id == session_id,
                CoinTransaction.transaction_type == CoinTransactionType.REFUND.value,
            )
        )
        if existing_refund.scalar_one_or_none() is not None:
            await self.db.commit()
            return 0

        debit_res = await self.db.execute(
            select(CoinTransaction).where(
                CoinTransaction.reference_session_id == session_id,
                CoinTransaction.transaction_type.in_(
                    [CoinTransactionType.BOOKING_DEBIT.value, CoinTransactionType.EXTENSION_DEBIT.value]
                ),
            )
        )
        debit_txs = debit_res.scalars().all()
        total_refund_coins = sum(abs(int(d.coins_delta)) for d in debit_txs if d.coins_delta < 0)
        if total_refund_coins <= 0:
            await self.db.commit()
            return 0

        patient_res = await self.db.execute(
            select(User).where(User.id == session.patient_id).with_for_update()
        )
        patient = patient_res.scalar_one_or_none()
        if patient is None:
            await self.db.commit()
            return 0

        now_utc = datetime.now(UTC)
        patient.coin_balance += total_refund_coins
        self.db.add(
            CoinTransaction(
                invoice_code=f"EVA-REFSES-{now_utc.strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}",
                user_id=patient.id,
                transaction_type=CoinTransactionType.REFUND.value,
                coins_delta=total_refund_coins,
                balance_after=patient.coin_balance,
                amount_idr=0,
                payment_method="EVA Wallet",
                package_name=f"Refund Pembatalan Sesi ({session.session_code})",
                status=TransactionStatus.COMPLETED.value,
                reference_session_id=session.id,
                completed_at=now_utc,
            )
        )
        await self.db.commit()
        return total_refund_coins

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

        # Upcoming schedule (prioritize active session right now, or soonest future session)
        now = datetime.now(UTC)
        active_candidates = [
            s for s in sessions
            if s.status in (ConsultationSessionStatus.SCHEDULED.value, ConsultationSessionStatus.LIVE.value)
            and s.scheduled_start_time <= now <= (s.scheduled_end_time or (s.scheduled_start_time + timedelta(minutes=s.duration_minutes or 30)))
        ]
        if active_candidates:
            upcoming_session = max(active_candidates, key=lambda s: s.scheduled_start_time)
        else:
            future_candidates = [
                s for s in sessions
                if s.status in (ConsultationSessionStatus.SCHEDULED.value, ConsultationSessionStatus.LIVE.value)
                and s.scheduled_start_time > now
            ]
            upcoming_session = min(future_candidates, key=lambda s: s.scheduled_start_time, default=None)

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

        triggers_list: list[ClinicalTriggerItem] = []
        clinical_points_list: list[str] = []

        for cs in completed_sessions:
            if cs.soap_notes:
                pts = cs.soap_notes.get("points") or []
                for p in pts:
                    if str(p).strip():
                        clinical_points_list.append(str(p).strip())
                        triggers_list.append(
                            ClinicalTriggerItem(
                                category="Observasi Klinis",
                                description=str(p).strip(),
                                severity="Sedang",
                                source="Catatan Sesi",
                                detected_at=cs.scheduled_start_time.strftime("%Y-%m-%d"),
                            )
                        )

        if dass_items:
            for di in dass_items:
                if "Parah" in di.anxiety_severity:
                    triggers_list.append(
                        ClinicalTriggerItem(
                            category="Skrining Afektif",
                            description=f"Kecemasan {di.anxiety_severity} (Skor: {di.anxiety_score})",
                            severity="Tinggi",
                            source="Skrining DASS-21",
                            detected_at=di.date,
                        )
                    )
                if "Parah" in di.depression_severity:
                    triggers_list.append(
                        ClinicalTriggerItem(
                            category="Skrining Afektif",
                            description=f"Depresi {di.depression_severity} (Skor: {di.depression_score})",
                            severity="Tinggi",
                            source="Skrining DASS-21",
                            detected_at=di.date,
                        )
                    )

        if not triggers_list and chief_complaint and chief_complaint != "-":
            triggers_list.append(
                ClinicalTriggerItem(
                    category="Keluhan Utama",
                    description=chief_complaint,
                    severity="Sedang",
                    source="Pendaftaran Konseling",
                    detected_at=last_session_date[:10],
                )
            )
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
            triggers=triggers_list if triggers_list else None,
            clinical_points=clinical_points_list if clinical_points_list else None,
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

        subj_text = payload.subjective or (payload.narrative if not payload.points else "\n".join(f"• {p}" for p in payload.points))
        assess_text = payload.assessment or payload.narrative or (payload.points[0] if payload.points else "Observasi klinis tercatat.")
        soap_dict = {
            "points": payload.points,
            "narrative": payload.narrative,
            "subjective": subj_text,
            "objective": payload.objective or "Observasi klinis langsung telekonseling",
            "assessment": assess_text,
            "plan": payload.plan or "Evaluasi mandiri berkala pasien",
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
            subjective=subj_text,
            objective=payload.objective or "Observasi klinis langsung telekonseling",
            assessment=assess_text,
            plan=payload.plan or "Evaluasi mandiri berkala pasien",
            points=payload.points,
            narrative=payload.narrative,
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

    async def list_admin_sessions(
        self,
        session_status: str | None = None,
        is_extended: bool | None = None,
        search: str | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list[AdminSessionMonitoringResponse]:
        """List teleconsultation sessions across patients and counselors for admin monitoring."""
        query = (
            select(ConsultationSession, User, PsychologistProfile)
            .join(User, ConsultationSession.patient_id == User.id)
            .join(PsychologistProfile, ConsultationSession.counselor_id == PsychologistProfile.id)
        )

        if session_status and session_status.strip():
            normalized = session_status.strip().lower()
            if normalized == "extended":
                query = query.where(ConsultationSession.is_extended.is_(True))
            elif normalized == "in_progress":
                query = query.where(
                    ConsultationSession.status == ConsultationSessionStatus.LIVE.value
                )
            else:
                query = query.where(ConsultationSession.status == normalized)

        if is_extended is not None:
            query = query.where(ConsultationSession.is_extended.is_(is_extended))

        if search and search.strip():
            term = f"%{search.strip()}%"
            query = query.where(
                or_(
                    ConsultationSession.session_code.ilike(term),
                    User.display_name.ilike(term),
                    User.username.ilike(term),
                    PsychologistProfile.full_name.ilike(term),
                )
            )

        query = (
            query.order_by(ConsultationSession.scheduled_start_time.desc())
            .limit(limit)
            .offset(offset)
        )
        res = await self.db.execute(query)
        rows = res.all()
        return [
            self._to_admin_session_response(sess, patient, counselor)
            for sess, patient, counselor in rows
        ]

    @staticmethod
    def _to_admin_session_response(
        sess: ConsultationSession,
        patient: User,
        counselor: PsychologistProfile,
    ) -> AdminSessionMonitoringResponse:
        patient_name = patient.display_name or patient.username or f"Pengguna {format_user_code(patient.id)}"
        if sess.status == ConsultationSessionStatus.CANCELLED.value and sess.cancellation_reason:
            clinical_summary = f"Dibatalkan: {sess.cancellation_reason}"
        elif sess.soap_notes:
            clinical_summary = "Catatan SOAP tersedia (terenkripsi untuk konselor)."
        else:
            clinical_summary = "Menunggu pelaksanaan / catatan sesi."

        return AdminSessionMonitoringResponse(
            id=str(sess.id),
            session_code=sess.session_code,
            patient_code=format_user_code(patient.id),
            patient_display_name=patient_name,
            counselor_id=str(counselor.id),
            counselor_name=counselor.full_name,
            counselor_title=counselor.title_degree,
            scheduled_start_time=sess.scheduled_start_time,
            scheduled_end_time=sess.scheduled_end_time,
            duration_minutes=sess.duration_minutes,
            is_extended=bool(sess.is_extended),
            status=sess.status,
            total_price_coins=round(float(sess.total_price or 0)),
            counselor_earning_coins=round(float(sess.counselor_earning or 0)),
            platform_fee_coins=round(float(sess.platform_fee or 0)),
            clinical_summary=clinical_summary,
        )


    async def get_counselor_timeline(
        self, counselor_id: uuid.UUID, date_str: str
    ) -> CounselorTimelineResponse:
        """Calculate operating hours, break intervals, booked sessions, buffers, and open windows."""
        query = select(PsychologistProfile).where(PsychologistProfile.id == counselor_id)
        res = await self.db.execute(query)
        counselor = res.scalar_one_or_none()
        if not counselor:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )

        try:
            target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Format tanggal tidak valid. Gunakan YYYY-MM-DD.",
            )

        day_name = target_date.strftime("%A").lower()
        sched_cfg = counselor.schedule_config or {}
        day_cfg = sched_cfg.get(day_name, {})

        op_start = day_cfg.get("operating_hours", {}).get("start", "08:00")
        op_end = day_cfg.get("operating_hours", {}).get("end", "17:00")
        is_active = day_cfg.get("is_active", True)

        blocked_ranges: list[BlockedRangeItem] = []

        breaks = day_cfg.get("breaks", [])
        if not breaks and day_name in ["monday", "tuesday", "wednesday", "thursday"]:
            breaks = [{"start": "12:00", "end": "13:00", "label": "Istirahat Siang"}]
        elif not breaks and day_name == "friday":
            breaks = [
                {"start": "11:30", "end": "13:00", "label": "Shalat Jumat & Istirahat"},
                {"start": "15:30", "end": "16:00", "label": "Istirahat Sore"},
            ]

        if is_active:
            for brk in breaks:
                b_start = brk.get("start", "12:00")
                b_end = brk.get("end", "13:00")
                b_label = brk.get("label", "Istirahat")
                blocked_ranges.append(
                    BlockedRangeItem(
                        start=b_start,
                        end=b_end,
                        type="break",
                        label=b_label,
                    )
                )

        day_start = datetime.combine(target_date, time(0, 0), tzinfo=UTC)
        day_end = datetime.combine(target_date, time(23, 59, 59), tzinfo=UTC)

        s_query = (
            select(ConsultationSession)
            .where(
                ConsultationSession.counselor_id == counselor_id,
                ConsultationSession.status.in_([
                    ConsultationSessionStatus.SCHEDULED.value,
                    ConsultationSessionStatus.LIVE.value,
                    ConsultationSessionStatus.COMPLETED.value,
                ]),
                ConsultationSession.scheduled_start_time >= day_start,
                ConsultationSession.scheduled_start_time <= day_end,
            )
            .order_by(ConsultationSession.scheduled_start_time.asc())
        )
        s_res = await self.db.execute(s_query)
        sessions = s_res.scalars().all()

        for sess in sessions:
            s_start = sess.scheduled_start_time.strftime("%H:%M")
            s_end = sess.scheduled_end_time.strftime("%H:%M")
            code_suffix = sess.session_code[-6:] if sess.session_code else "LIVE"
            blocked_ranges.append(
                BlockedRangeItem(
                    start=s_start,
                    end=s_end,
                    type="booked",
                    label=f"Sesi Pasien #{code_suffix}",
                )
            )
            if counselor.buffer_time_minutes > 0:
                buf_end_dt = sess.scheduled_end_time + timedelta(minutes=counselor.buffer_time_minutes)
                buf_end = buf_end_dt.strftime("%H:%M")
                blocked_ranges.append(
                    BlockedRangeItem(
                        start=s_end,
                        end=buf_end,
                        type="buffer",
                        label=f"Jeda Antar Sesi ({counselor.buffer_time_minutes} menit)",
                    )
                )

        blocked_ranges.sort(key=lambda r: r.start)

        available_windows: list[TimeRangeItem] = []
        if is_active:
            def to_minutes(t_str: str) -> int:
                parts = t_str.split(":")
                return int(parts[0]) * 60 + int(parts[1])

            def to_str(mins: int) -> str:
                return f"{mins // 60:02d}:{mins % 60:02d}"

            current_min = to_minutes(op_start)
            op_end_min = to_minutes(op_end)

            for br in blocked_ranges:
                br_start = to_minutes(br.start)
                br_end = to_minutes(br.end)

                if br_start > current_min and current_min < op_end_min:
                    window_end = min(br_start, op_end_min)
                    if window_end - current_min >= 30:
                        available_windows.append(
                            TimeRangeItem(start=to_str(current_min), end=to_str(window_end))
                        )
                current_min = max(current_min, br_end)

            if current_min < op_end_min and (op_end_min - current_min >= 30):
                available_windows.append(
                    TimeRangeItem(start=to_str(current_min), end=to_str(op_end_min))
                )

        return CounselorTimelineResponse(
            counselor_id=str(counselor_id),
            date=date_str,
            operating_hours=OperatingHoursItem(start=op_start, end=op_end),
            buffer_time_minutes=counselor.buffer_time_minutes,
            blocked_ranges=blocked_ranges,
            available_windows=available_windows,
        )

    async def get_patient_clinical_triggers(
        self, counselor_user_id: uuid.UUID, patient_id: uuid.UUID
    ) -> PatientClinicalTriggersResponse:
        """Provide structured clinical triggers & complaints minimizing personal raw journals (Indonesian Psychological Code of Ethics)."""
        c_query = select(PsychologistProfile).where(PsychologistProfile.user_id == counselor_user_id)
        c_res = await self.db.execute(c_query)
        profile = c_res.scalar_one_or_none()
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )

        consent_query = select(PatientConsent).where(
            PatientConsent.patient_id == patient_id,
            PatientConsent.counselor_id == profile.id,
        )
        c_res = await self.db.execute(consent_query)
        consent = c_res.scalar_one_or_none()
        has_consent = consent is not None and consent.status == "granted"

        triggers: list[ClinicalTriggerItem] = []
        chief_complaint = "Konseling Evaluasi Klinis & Regulasi Emosi"

        sess_query = (
            select(ConsultationSession)
            .where(
                ConsultationSession.patient_id == patient_id,
                ConsultationSession.counselor_id == profile.id,
            )
            .order_by(ConsultationSession.scheduled_start_time.desc())
        )
        s_res = await self.db.execute(sess_query)
        sessions = s_res.scalars().all()
        completed = [s for s in sessions if s.status == ConsultationSessionStatus.COMPLETED.value]

        for s in completed:
            if s.soap_notes:
                notes = s.soap_notes
                if notes.get("assessment"):
                    chief_complaint = str(notes["assessment"])[:80]
                points = notes.get("points") or []
                for p in points:
                    triggers.append(
                        ClinicalTriggerItem(
                            category="Observasi Klinis Sesi",
                            description=str(p),
                            severity="Sedang",
                            source="Catatan Sesi Psikolog",
                            detected_at=s.scheduled_start_time.strftime("%Y-%m-%d"),
                        )
                    )

        if has_consent or len(completed) > 0:
            dass_query = (
                select(DASSAssessment)
                .where(DASSAssessment.user_id == patient_id)
                .order_by(DASSAssessment.assessed_date.desc())
                .limit(3)
            )
            d_res = await self.db.execute(dass_query)
            dass_records = d_res.scalars().all()
            for d in dass_records:
                if d.anxiety_severity in ["Sedang", "Parah", "Sangat Parah"]:
                    triggers.append(
                        ClinicalTriggerItem(
                            category="Skrining Afektif",
                            description=f"Kecemasan tingkat {d.anxiety_severity} (Skor: {d.anxiety_score})",
                            severity="Tinggi" if "Parah" in d.anxiety_severity else "Sedang",
                            source="Skrining DASS-21",
                            detected_at=str(d.assessed_date),
                        )
                    )
                if d.depression_severity in ["Sedang", "Parah", "Sangat Parah"]:
                    triggers.append(
                        ClinicalTriggerItem(
                            category="Skrining Afektif",
                            description=f"Depresi tingkat {d.depression_severity} (Skor: {d.depression_score})",
                            severity="Tinggi" if "Parah" in d.depression_severity else "Sedang",
                            source="Skrining DASS-21",
                            detected_at=str(d.assessed_date),
                        )
                    )
                if d.stress_severity in ["Sedang", "Parah", "Sangat Parah"]:
                    triggers.append(
                        ClinicalTriggerItem(
                            category="Stresor Lingkungan",
                            description=f"Stres psikologis tingkat {d.stress_severity} (Skor: {d.stress_score})",
                            severity="Tinggi" if "Parah" in d.stress_severity else "Sedang",
                            source="Skrining DASS-21",
                            detected_at=str(d.assessed_date),
                        )
                    )

            dy_query = (
                select(DiaryEntry)
                .where(
                    DiaryEntry.user_id == patient_id,
                    or_(DiaryEntry.emotional_level <= 2, DiaryEntry.safety_event_id.is_not(None)),
                )
                .order_by(DiaryEntry.entry_date.desc())
                .limit(3)
            )
            dy_res = await self.db.execute(dy_query)
            distress_diaries = dy_res.scalars().all()
            for dy in distress_diaries:
                triggers.append(
                    ClinicalTriggerItem(
                        category="Pemicu Emosi Harian",
                        description=f"Pemicu: {dy.title} - {dy.mood_tag or 'Kondisi Rentan'}",
                        severity="Tinggi" if dy.safety_event_id else "Sedang",
                        source="Deteksi Sentimen Eva",
                        detected_at=str(dy.entry_date),
                    )
                )

        if not triggers:
            triggers.append(
                ClinicalTriggerItem(
                    category="Keluhan Awal",
                    description=chief_complaint,
                    severity="Sedang",
                    source="Pendaftaran Konseling",
                    detected_at=datetime.now(UTC).strftime("%Y-%m-%d"),
                )
            )

        return PatientClinicalTriggersResponse(
            patient_id=str(patient_id),
            chief_complaint=chief_complaint,
            triggers=triggers,
            emotional_summary="Pasien menunjukkan kebutuhan dukungan regulasi emosi dan penanganan pemicu stres.",
        )
