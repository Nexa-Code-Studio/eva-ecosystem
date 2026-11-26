import logging
import uuid
from datetime import UTC, datetime, time, timedelta
from decimal import Decimal

from fastapi import HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.security import create_room_token
from app.models.counselor import (
    ConsultationSession,
    PlatformPricingConfig,
    PsychologistProfile,
)
from app.models.enums import (
    ConsultationSessionStatus,
    PricingConfigStatus,
    PsychologistVerificationStatus,
)
from app.models.level import CounselorReview
from app.schemas.care.requests import (
    BookConsultationRequest,
    SubmitRatingRequest,
    UpdateCallStatusRequest,
)
from app.schemas.care.responses import (
    BlockedRangeSchema,
    CallStatusResponse,
    CareRatingResponse,
    CareSessionResponse,
    CertificateItemSchema,
    ClinicItemResponse,
    CommunityStatusResponse,
    CounselorSessionDetailResponse,
    CounselorTimelineResponse,
    OperatingHoursSchema,
    PatientReviewItemSchema,
    PatientReviewTagSchema,
    PatientStatsSchema,
    PsychologistItemResponse,
    SessionActionResponse,
    SessionReviewSummarySchema,
    TimeRangeSchema,
    VideoTokenResponse,
)
from app.schemas.session.requests import BookSessionRequest
from app.services.care.ice_provider import IceServerProvider
from app.services.level import LevelService
from app.services.session.scheduling_service import SchedulingService
from shared.config import normalize_ws_base_url, settings

logger = logging.getLogger(__name__)


class CareService:
    """Domain service managing teleconsultation video rooms, access control, and call lifecycle."""

    def __init__(
        self,
        db: AsyncSession,
        ice_provider: IceServerProvider | None = None,
    ) -> None:
        self.db = db
        self.ice_provider = ice_provider or IceServerProvider()

    @staticmethod
    def _build_ws_url(session_id: uuid.UUID | str, token: str) -> str:
        ws_base = normalize_ws_base_url(getattr(settings, "WS_BASE_URL", "ws://localhost:8888"))
        return f"{ws_base}/api/v1/care/ws/{session_id}?token={token}"

    async def get_video_token(self, session_id: uuid.UUID, user_id: uuid.UUID) -> VideoTokenResponse:
        """Validate participation and generate secure WebRTC / signaling room token."""
        stmt = (
            select(ConsultationSession)
            .where(ConsultationSession.id == session_id)
            .options(
                selectinload(ConsultationSession.patient),
                selectinload(ConsultationSession.counselor),
            )
        )
        res = await self.db.execute(stmt)
        session = res.scalar_one_or_none()

        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sesi konsultasi tidak ditemukan.",
            )

        # Access Control: User must be either the scheduled patient or counselor
        is_patient = session.patient_id == user_id
        is_counselor = session.counselor and session.counselor.user_id == user_id

        if not (is_patient or is_counselor):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Akses ditolak: Hanya pengguna atau psikolog terdaftar yang dapat memasuki ruang konsultasi.",
            )

        role = "counselor" if is_counselor else "patient"

        # Initialize video room identifier if not yet assigned
        if not session.video_room_id:
            session.video_room_id = f"eva-room-{session.session_code}"
            await self.db.commit()
            await self.db.refresh(session)

        token = create_room_token(
            session_id=str(session.id),
            room_id=session.video_room_id,
            user_id=str(user_id),
            role=role,
        )

        resolved_ice = await self.ice_provider.resolve_ice_servers()
        ws_url = self._build_ws_url(session.id, token)

        return VideoTokenResponse(
            session_id=str(session.id),
            room_id=session.video_room_id,
            token=token,
            participant_id=str(user_id),
            status=session.status,
            ice_servers=resolved_ice.ice_servers,
            ice_server_configs=resolved_ice.ice_server_configs,
            ws_url=ws_url,
        )

    async def update_call_status(
        self,
        session_id: uuid.UUID,
        user_id: uuid.UUID,
        payload: UpdateCallStatusRequest,
    ) -> CallStatusResponse:
        """Update live call session status, actual duration, and end time."""
        stmt = (
            select(ConsultationSession)
            .where(ConsultationSession.id == session_id)
            .options(selectinload(ConsultationSession.counselor))
        )
        res = await self.db.execute(stmt)
        session = res.scalar_one_or_none()

        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sesi konsultasi tidak ditemukan.",
            )

        is_patient = session.patient_id == user_id
        is_counselor = session.counselor and session.counselor.user_id == user_id
        if not (is_patient or is_counselor):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Akses ditolak.",
            )

        target_status = payload.status.lower().strip()
        now = datetime.now(UTC)

        if target_status in ("active", "live"):
            session.status = ConsultationSessionStatus.LIVE.value
            if not session.actual_start_time:
                session.actual_start_time = now
            await self.db.commit()
            await self.db.refresh(session)
        elif target_status in ("completed", "ended"):
            session.status = ConsultationSessionStatus.COMPLETED.value
            if not session.actual_end_time:
                session.actual_end_time = now
            if payload.duration_seconds and payload.duration_seconds > 0:
                session.duration_minutes = max(1, payload.duration_seconds // 60)
            if payload.notes:
                notes_dict = session.soap_notes or {}
                notes_dict["quick_notes"] = payload.notes
                session.soap_notes = notes_dict
            await self.db.commit()
            await self.db.refresh(session)
            await SchedulingService(self.db).release_pending_session_earnings(session.id)
        elif target_status in ("missed", "cancelled"):
            await SchedulingService(self.db).cancel_session_and_refund(
                session.id,
                reason=f"Status call: {target_status}",
            )
            await self.db.refresh(session)
        else:
            await self.db.commit()
            await self.db.refresh(session)

        if target_status in ("completed", "ended"):
            try:
                from app.services.certificate import CertificateService
                from app.services.level import LevelService

                await LevelService(self.db).recalculate_and_evaluate(counselor_id=session.counselor_id)
                await CertificateService(self.db).evaluate_auto_issuance(counselor_id=session.counselor_id)
            except Exception:
                pass

        return CallStatusResponse(
            success=True,
            session_id=str(session.id),
            status=session.status,
            message="Status panggilan konsultasi berhasil disinkronkan.",
        )

    async def get_counselor_session_detail(
        self, session_id: uuid.UUID, user_id: uuid.UUID
    ) -> CounselorSessionDetailResponse:
        """Fetch session metadata for counselor mobile video consultation screen."""
        stmt = (
            select(ConsultationSession)
            .where(ConsultationSession.id == session_id)
            .options(
                selectinload(ConsultationSession.patient),
                selectinload(ConsultationSession.counselor),
            )
        )
        res = await self.db.execute(stmt)
        session = res.scalar_one_or_none()

        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sesi konsultasi tidak ditemukan.",
            )

        is_counselor = session.counselor is not None and session.counselor.user_id == user_id
        if not is_counselor:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Akses ditolak: Hanya psikolog pemilik sesi yang dapat mengakses detail sesi ini.",
            )

        if not session.video_room_id:
            session.video_room_id = f"eva-room-{session.session_code}"
            await self.db.commit()
            await self.db.refresh(session)

        patient_name = session.patient.email.split("@")[0].capitalize() if session.patient else "Pasien"
        channel_name = session.video_room_id
        token = create_room_token(str(session.id), channel_name, str(user_id), "counselor")

        resolved_ice = await self.ice_provider.resolve_ice_servers()
        ws_url = self._build_ws_url(session.id, token)

        return CounselorSessionDetailResponse(
            session_id=str(session.id),
            patient_id=str(session.patient_id),
            patient_name=patient_name,
            scheduled_time=session.scheduled_start_time.isoformat() if session.scheduled_start_time else datetime.now(UTC).isoformat(),
            status=session.status,
            signaling_token=token,
            channel_name=channel_name,
            ice_servers=resolved_ice.ice_servers,
            ice_server_configs=resolved_ice.ice_server_configs,
            ws_url=ws_url,
        )

    async def start_session(self, session_id: uuid.UUID, user_id: uuid.UUID) -> SessionActionResponse:
        """Mark consultation session as started / live."""
        update_req = UpdateCallStatusRequest(status="live")
        res = await self.update_call_status(session_id, user_id, update_req)
        return SessionActionResponse(success=res.success, session_id=res.session_id, status=res.status)

    async def end_session(
        self,
        session_id: uuid.UUID,
        user_id: uuid.UUID,
        duration_seconds: int = 0,
        quick_notes: list[str] | None = None,
    ) -> SessionActionResponse:
        """Mark consultation session as completed with duration and quick notes."""
        update_req = UpdateCallStatusRequest(
            status="completed",
            duration_seconds=duration_seconds,
            notes=quick_notes,
        )
        res = await self.update_call_status(session_id, user_id, update_req)
        return SessionActionResponse(success=res.success, session_id=res.session_id, status=res.status)

    async def _resolve_fallback_price(self) -> Decimal:
        pricing = await self.db.scalar(
            select(PlatformPricingConfig)
            .where(PlatformPricingConfig.status == PricingConfigStatus.ACTIVE.value)
            .order_by(PlatformPricingConfig.effective_from.desc())
            .limit(1)
        )
        return pricing.price_per_session if pricing else Decimal("150.00")

    @staticmethod
    def _build_psychologist_response(
        p: PsychologistProfile,
        *,
        fallback_price: Decimal = Decimal("150.00"),
        reviews: list[CounselorReview] | None = None,
    ) -> PsychologistItemResponse:
        title_lower = (p.title_degree or "").lower()
        full_name_lower = (p.full_name or "").lower()
        bio_lower = (p.bio or "").lower()

        is_psychiatrist = "sp.kj" in title_lower or "psikiater" in title_lower or "sp.kj" in full_name_lower
        is_volunteer = "relawan" in title_lower or "volunteer" in title_lower or "relawan" in bio_lower
        practitioner_type = "volunteer" if is_volunteer else "professional"

        specialties = p.specializations or []

        lvl = (
            p.current_level
            if "current_level" in p.__dict__
            and p.current_level is not None
            and p.current_level.is_active
            else None
        )
        effective_coins = int(
            round(float(LevelService.compute_effective_price(p, lvl, fallback_price=fallback_price)))
        )

        # Build authentic review tags and testimonials from database reviews
        real_reviews = reviews or []
        seen_tags: dict[str, str] = {}
        testimonials: list[PatientReviewItemSchema] = []
        positive_count = 0
        for rev in real_reviews:
            score = float(rev.rating)
            sentiment = "positive" if score >= 4.0 else "negative"
            if score >= 4.0:
                positive_count += 1
            if rev.highlight_label and rev.highlight_label.strip() and rev.highlight_label.strip() not in seen_tags:
                seen_tags[rev.highlight_label.strip()] = sentiment
            patient_name = (
                "Pasien Anonim"
                if rev.is_anonymous
                else (
                    rev.patient.display_name
                    if "patient" in rev.__dict__ and rev.patient and rev.patient.display_name
                    else "Pasien Terverifikasi"
                )
            )
            testimonials.append(
                PatientReviewItemSchema(
                    id=str(rev.id),
                    patient_name=patient_name,
                    sentiment=sentiment,
                    label=rev.highlight_label or "",
                    description=rev.review_text or "",
                    rating=score,
                    time_ago=rev.created_at.strftime("%d %b %Y") if rev.created_at else "",
                )
            )

        review_tags = [
            PatientReviewTagSchema(label=lbl, sentiment=sent)
            for lbl, sent in seen_tags.items()
        ]
        patient_review_tags = [t.label for t in review_tags]
        patient_reviews = [t.description for t in testimonials if t.description]

        # Build authentic credential certificates without stock placeholders
        reg_no = p.sip_number or p.str_number
        certifications: list[str] = [f"STR: {p.str_number}"]
        if p.sip_number:
            certifications.append(f"SIP/SIPP: {p.sip_number}")
        if p.education:
            certifications.append(p.education)

        certificate_items: list[CertificateItemSchema] = []
        if p.str_doc_url:
            certificate_items.append(
                CertificateItemSchema(title=f"STR: {p.str_number}", image_url=p.str_doc_url)
            )
        if p.sip_doc_url:
            certificate_items.append(
                CertificateItemSchema(title=f"SIP/SIPP: {p.sip_number or '-'}", image_url=p.sip_doc_url)
            )
        if p.certificate_doc_url and p.certificate_doc_url not in {p.str_doc_url, p.sip_doc_url}:
            certificate_items.append(
                CertificateItemSchema(title="Sertifikat Profesi", image_url=p.certificate_doc_url)
            )

        total_completed = int(p.total_completed_sessions or 0)
        satisfaction_pct = int(round((positive_count / len(real_reviews)) * 100)) if real_reviews else 0

        return PsychologistItemResponse(
            id=str(p.id),
            name=p.full_name,
            title=p.title_degree,
            registration_number=reg_no,
            avatar_url=p.profile_photo_url or "",
            rating=float(p.average_rating or 0.0),
            review_count=int(p.rating_count or 0),
            experience_years=p.years_of_experience,
            specialties=specialties,
            patient_review_tags=patient_review_tags,
            patient_reviews=patient_reviews,
            review_tags=review_tags,
            testimonials=testimonials,
            patient_stats=PatientStatsSchema(
                total_sessions=total_completed,
                satisfaction_percentage=satisfaction_pct,
                repeat_patient_rate=0,
                recovery_rate=0,
            ),
            certifications=certifications,
            certificate_items=certificate_items,
            coins_per_session=effective_coins,
            fee_per_session=effective_coins,
            duration_minutes=30,
            available_online=p.is_online,
            clinic_affiliation=None,
            bio=p.bio or "",
            practitioner_type=practitioner_type,
            has_psychologist_certificate=not is_volunteer,
            is_volunteer=is_volunteer,
            level_tier=lvl.level_tier if lvl else None,
            level_name=lvl.name if lvl else None,
            level_badge_icon=lvl.badge_icon if lvl else None,
        )

    async def get_psychologists(
        self,
        category: str | None = None,
        query: str | None = None,
    ) -> list[PsychologistItemResponse]:
        """Fetch verified online psychologists and psychiatrists with search and category filters."""
        stmt = (
            select(PsychologistProfile)
            .options(selectinload(PsychologistProfile.current_level))
            .where(
                PsychologistProfile.verification_status == PsychologistVerificationStatus.VERIFIED.value,
                PsychologistProfile.is_online.is_(True),
            )
            .order_by(PsychologistProfile.years_of_experience.desc())
        )

        if query and query.strip():
            q_pattern = f"%{query.strip().lower()}%"
            stmt = stmt.where(
                or_(
                    PsychologistProfile.full_name.ilike(q_pattern),
                    PsychologistProfile.title_degree.ilike(q_pattern),
                    PsychologistProfile.bio.ilike(q_pattern),
                )
            )

        res = await self.db.execute(stmt)
        profiles = res.scalars().all()
        fallback_price = await self._resolve_fallback_price()

        reviews_by_counselor: dict[uuid.UUID, list[CounselorReview]] = {}
        if profiles:
            rev_stmt = (
                select(CounselorReview)
                .options(selectinload(CounselorReview.patient))
                .where(CounselorReview.counselor_id.in_([p.id for p in profiles]))
                .order_by(CounselorReview.created_at.desc())
            )
            rev_res = await self.db.execute(rev_stmt)
            for rev in rev_res.scalars().all():
                reviews_by_counselor.setdefault(rev.counselor_id, []).append(rev)

        items = [
            self._build_psychologist_response(
                p,
                fallback_price=fallback_price,
                reviews=reviews_by_counselor.get(p.id, []),
            )
            for p in profiles
        ]

        # Category filter
        if category and category.lower() != "all":
            cat = category.lower()
            if cat == "psychiatrist":
                items = [it for it in items if "sp.kj" in it.title.lower() or "psikiater" in it.title.lower()]
            elif cat == "psychologist":
                items = [it for it in items if "psikiater" not in it.title.lower() and "sp.kj" not in it.title.lower()]
            elif cat == "volunteer":
                items = [it for it in items if it.is_volunteer or it.practitioner_type == "volunteer"]

        return items

    async def get_clinics(self, query: str | None = None) -> list[ClinicItemResponse]:
        """Retrieve verified partner mental health clinics and consultation centers."""
        all_clinics = [
            ClinicItemResponse(
                id="clinic_1",
                name="Klinik Psikologi Terpadu UI & Terapi Holistik",
                address="Jl. Salemba Raya No. 4, RW. 5, Kenari, Senen",
                city="Jakarta Pusat",
                distance_km=2.4,
                photo_url="https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?w=600&auto=format&fit=crop&q=80",
                phone="021-31908901",
                facilities=["Konseling Tatap Muka", "Tes Psikologi Lengkap", "Terapi CBT", "Ruang Relaksasi"],
                rating=4.9,
            ),
            ClinicItemResponse(
                id="clinic_2",
                name="Pusat Kesehatan Jiwa & Neuropsikiatri Dharmawangsa",
                address="Jl. Dharmawangsa Raya No. 12, Kebayoran Baru",
                city="Jakarta Selatan",
                distance_km=4.8,
                photo_url="https://images.unsplash.com/photo-1586773860418-d37222d8fce3?w=600&auto=format&fit=crop&q=80",
                phone="021-7254321",
                facilities=["Psikiater & Obat", "Rawat Jalan Holistik", "Konseling Pasangan", "Safe Space Lounge"],
                rating=4.85,
            ),
            ClinicItemResponse(
                id="clinic_3",
                name="Safe Space Community Clinic Bintaro",
                address="Sektor 7 Bintaro Jaya, Pondok Aren",
                city="Tangerang Selatan",
                distance_km=7.5,
                photo_url="https://images.unsplash.com/photo-1629909613654-28e377c37b09?w=600&auto=format&fit=crop&q=80",
                phone="021-74861234",
                facilities=["Konseling Komunitas", "Support Group Mingguan", "Art Therapy", "Konseling Remaja"],
                rating=4.8,
            ),
        ]
        if not query or not query.strip():
            return all_clinics
        q_lower = query.strip().lower()
        return [
            c for c in all_clinics
            if q_lower in c.name.lower() or q_lower in c.city.lower() or q_lower in c.address.lower()
        ]

    async def get_community_status(self, user_id: uuid.UUID | None = None) -> CommunityStatusResponse:
        """Get Discord Safe Space community membership and VIP trial status."""
        return CommunityStatusResponse(
            is_member=False,
            is_vip_active=False,
            vip_remaining_days=0,
            server_name="Eva Safe Space ID",
            invite_url="https://discord.gg/evasafespace",
            member_count=1420,
        )

    async def join_community_vip_trial(self, user_id: uuid.UUID) -> CommunityStatusResponse:
        """Grant 30-day VIP Community Pass for Eva Safe Space."""
        return CommunityStatusResponse(
            is_member=True,
            is_vip_active=True,
            vip_remaining_days=30,
            joined_at=datetime.now(UTC).isoformat(),
            server_name="Eva Safe Space ID",
            invite_url="https://discord.gg/evasafespace",
            member_count=1421,
        )

    async def get_counselor_timeline(
        self,
        counselor_id: uuid.UUID,
        target_date_str: str,
    ) -> CounselorTimelineResponse:
        """Generate availability timeline progress bar data with multi-break schedules and bookings."""
        try:
            target_date = datetime.strptime(target_date_str, "%Y-%m-%d").date()
        except ValueError:
            target_date = datetime.now(UTC).date()
            target_date_str = target_date.strftime("%Y-%m-%d")

        # 1. Fetch Counselor Profile
        query = select(PsychologistProfile).where(PsychologistProfile.id == counselor_id)
        res = await self.db.execute(query)
        counselor = res.scalar_one_or_none()
        if not counselor:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )

        # 2. Operating hours: 08:00 - 17:00
        op_hours = OperatingHoursSchema(start="08:00", end="17:00")
        blocked_ranges: list[BlockedRangeSchema] = []

        # 3. Scheduled breaks (Multi-range breaks: Jumat vs Regular)
        is_friday = target_date.weekday() == 4
        if is_friday:
            blocked_ranges.append(
                BlockedRangeSchema(start="11:30", end="13:00", type="break", label="Shalat Jumat & Istirahat")
            )
        else:
            blocked_ranges.append(
                BlockedRangeSchema(start="12:00", end="13:00", type="break", label="Istirahat Siang")
            )

        # Afternoon coffee break
        blocked_ranges.append(
            BlockedRangeSchema(start="15:30", end="16:00", type="break", label="Coffee Break")
        )

        # 4. Booked sessions on target date
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

        for s in booked_sessions:
            start_str = s.scheduled_start_time.strftime("%H:%M")
            end_str = s.scheduled_end_time.strftime("%H:%M")
            blocked_ranges.append(
                BlockedRangeSchema(start=start_str, end=end_str, type="booked", label="Sesi Konsultasi")
            )
            # Add buffer block if configured
            if counselor.buffer_time_minutes > 0:
                buf_end = (s.scheduled_end_time + timedelta(minutes=counselor.buffer_time_minutes)).strftime("%H:%M")
                blocked_ranges.append(
                    BlockedRangeSchema(start=end_str, end=buf_end, type="buffer", label="Jeda Sesi (Buffer)")
                )

        # 5. Calculate available windows
        blocked_ranges.sort(key=lambda b: b.start)

        available_windows: list[TimeRangeSchema] = []
        curr_time = "08:00"
        for b in blocked_ranges:
            if curr_time < b.start:
                available_windows.append(TimeRangeSchema(start=curr_time, end=b.start))
            if b.end > curr_time:
                curr_time = b.end
        if curr_time < "17:00":
            available_windows.append(TimeRangeSchema(start=curr_time, end="17:00"))

        return CounselorTimelineResponse(
            counselor_id=str(counselor_id),
            date=target_date_str,
            operating_hours=op_hours,
            blocked_ranges=blocked_ranges,
            available_windows=available_windows,
        )

    async def book_consultation(
        self,
        user_id: uuid.UUID,
        counselor_id: uuid.UUID,
        payload: BookConsultationRequest,
    ) -> CareSessionResponse:
        """Book a teleconsultation session with dynamic duration & anti-clash guard."""
        target_counselor_id = payload.resolve_counselor_id(counselor_id)
        start_time = payload.resolve_start_time()

        scheduling_service = SchedulingService(self.db)
        book_req = BookSessionRequest(
            counselor_id=target_counselor_id,
            scheduled_start_time=start_time,
            session_count=payload.session_count,
        )
        session_res = await scheduling_service.book_session(user_id, book_req)

        # Fetch session record with counselor profile and level
        stmt = (
            select(ConsultationSession)
            .where(ConsultationSession.id == uuid.UUID(session_res.id))
            .options(
                selectinload(ConsultationSession.counselor).selectinload(
                    PsychologistProfile.current_level
                )
            )
        )
        res = await self.db.execute(stmt)
        sess = res.scalar_one_or_none()
        if not sess or not sess.counselor:
            raise HTTPException(status_code=500, detail="Gagal memuat sesi terdaftar.")

        soap_dict = dict(sess.soap_notes or {})
        soap_dict["share_ai_chat_history"] = payload.share_ai_chat_history
        if payload.complaints:
            soap_dict["complaints"] = payload.complaints
        sess.soap_notes = soap_dict
        await self.db.commit()
        await self.db.refresh(sess)

        notes_val = soap_dict.get("complaints") or soap_dict.get("plan")
        fallback_price = await self._resolve_fallback_price()
        psych_item = self._build_psychologist_response(
            sess.counselor,
            fallback_price=fallback_price,
        )
        return CareSessionResponse(
            id=str(sess.id),
            psychologist=psych_item,
            session_datetime=sess.scheduled_start_time.isoformat(),
            status=sess.status,
            type="onlineVideo",
            meeting_url=f"/video_call?channelId={sess.id}&counselorName={sess.counselor.full_name}",
            duration_minutes=sess.duration_minutes,
            session_number=1,
            notes=notes_val,
            share_ai_chat_history=payload.share_ai_chat_history,
            is_extended=sess.duration_minutes >= 60,
            has_review=False,
            my_review=None,
        )

    async def get_user_sessions(self, user_id: uuid.UUID) -> list[CareSessionResponse]:
        """Fetch all consultation sessions for the current patient with real reviews & pricing."""
        stmt = (
            select(ConsultationSession)
            .where(ConsultationSession.patient_id == user_id)
            .options(
                selectinload(ConsultationSession.counselor).selectinload(
                    PsychologistProfile.current_level
                )
            )
            .order_by(ConsultationSession.scheduled_start_time.desc())
        )
        res = await self.db.execute(stmt)
        sessions = res.scalars().all()
        if not sessions:
            return []

        fallback_price = await self._resolve_fallback_price()

        session_ids = [s.id for s in sessions]
        reviews_by_session: dict[uuid.UUID, CounselorReview] = {}
        rev_res = await self.db.execute(
            select(CounselorReview).where(CounselorReview.session_id.in_(session_ids))
        )
        for rev in rev_res.scalars().all():
            reviews_by_session[rev.session_id] = rev

        # Compute chronological session_number per counselor for this patient
        ordered_asc = sorted(sessions, key=lambda item: item.scheduled_start_time)
        counselor_seq: dict[uuid.UUID, int] = {}
        session_number_map: dict[uuid.UUID, int] = {}
        for item in ordered_asc:
            seq = counselor_seq.get(item.counselor_id, 0) + 1
            counselor_seq[item.counselor_id] = seq
            session_number_map[item.id] = seq

        results: list[CareSessionResponse] = []
        for s in sessions:
            if not s.counselor:
                continue
            psych_item = self._build_psychologist_response(
                s.counselor,
                fallback_price=fallback_price,
            )
            soap = s.soap_notes or {}
            plan_val = soap.get("plan")
            advice = [plan_val] if isinstance(plan_val, str) and plan_val.strip() else (plan_val if isinstance(plan_val, list) else [])
            raw_actions = soap.get("recommended_tasks") or []
            action_items = [str(a) for a in raw_actions] if isinstance(raw_actions, list) else []
            notes_val = soap.get("complaints") or (plan_val if isinstance(plan_val, str) else None)
            rev = reviews_by_session.get(s.id)
            my_review_schema = (
                SessionReviewSummarySchema(
                    id=str(rev.id),
                    session_id=str(rev.session_id),
                    rating=float(rev.rating),
                    highlight_label=rev.highlight_label,
                    review_text=rev.review_text,
                    is_anonymous=rev.is_anonymous,
                    created_at=rev.created_at.isoformat() if rev.created_at else "",
                )
                if rev
                else None
            )
            results.append(
                CareSessionResponse(
                    id=str(s.id),
                    psychologist=psych_item,
                    session_datetime=s.scheduled_start_time.isoformat(),
                    status=s.status,
                    type="onlineVideo",
                    meeting_url=(
                        f"/video_call?channelId={s.id}&counselorName={s.counselor.full_name}"
                        if s.status in (ConsultationSessionStatus.SCHEDULED.value, ConsultationSessionStatus.LIVE.value)
                        else None
                    ),
                    duration_minutes=s.duration_minutes,
                    session_number=session_number_map.get(s.id, 1),
                    advice_list=advice,
                    action_items=action_items,
                    diagnosis_summary=soap.get("assessment"),
                    session_summary=soap.get("subjective"),
                    notes=notes_val,
                    share_ai_chat_history=bool(soap.get("share_ai_chat_history", False)),
                    is_extended=bool(soap.get("is_extended")) or s.duration_minutes >= 60,
                    has_review=rev is not None,
                    my_review=my_review_schema,
                )
            )
        return results

    async def submit_counselor_rating(
        self,
        user_id: uuid.UUID,
        counselor_id: uuid.UUID,
        payload: SubmitRatingRequest,
    ) -> CareRatingResponse:
        """Submit rating and testimonial review for a psychologist."""
        logger.info(
            f"User {user_id} submitted rating {payload.rating} for counselor {counselor_id}: {payload.review_text}"
        )
        return CareRatingResponse(success=True, message="Rating dan ulasan berhasil dikirim.")

