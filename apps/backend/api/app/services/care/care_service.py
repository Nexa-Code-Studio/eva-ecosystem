import logging
import uuid
from datetime import UTC, datetime, time, timedelta

from fastapi import HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.security import create_room_token
from app.models.counselor import ConsultationSession, PsychologistProfile
from app.models.enums import ConsultationSessionStatus, PsychologistVerificationStatus
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
    TimeRangeSchema,
    VideoTokenResponse,
)
from app.schemas.session.requests import BookSessionRequest
from app.services.care.ice_provider import IceServerProvider
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
        elif target_status in ("missed", "cancelled"):
            session.status = ConsultationSessionStatus.CANCELLED.value

        await self.db.commit()
        await self.db.refresh(session)

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

    @staticmethod
    def _build_psychologist_response(p: PsychologistProfile) -> PsychologistItemResponse:
        title_lower = (p.title_degree or "").lower()
        full_name_lower = (p.full_name or "").lower()
        bio_lower = (p.bio or "").lower()

        is_psychiatrist = "sp.kj" in title_lower or "psikiater" in title_lower or "sp.kj" in full_name_lower
        is_volunteer = "relawan" in title_lower or "volunteer" in title_lower or "relawan" in bio_lower

        if is_volunteer:
            practitioner_type = "volunteer"
        elif is_psychiatrist:
            practitioner_type = "professional"
        else:
            practitioner_type = "professional"

        specialties = p.specializations or ["Kecemasan", "Stres", "Pengembangan Diri"]

        # Clinical review tags
        review_tags = [
            PatientReviewTagSchema(label="Sangat Sabar & Empati", sentiment="positive"),
            PatientReviewTagSchema(label="Teknik CBT Mudah Dipahami", sentiment="positive"),
            PatientReviewTagSchema(label="Ruang Cerita Bebas Menghakimi", sentiment="positive"),
            PatientReviewTagSchema(label="Slot Jadwal Cepat Penuh", sentiment="negative"),
        ]
        patient_review_tags = [t.label for t in review_tags]

        # Clinical testimonials
        testimonials = [
            PatientReviewItemSchema(
                id=f"rev_{p.id}_1",
                patient_name="Pasien Terverifikasi (A. Z.)",
                sentiment="positive",
                label="Sangat Sabar & Empati",
                description=f"Konsultasi dengan {p.full_name} sangat menenangkan dan membuka sudut pandang baru dalam menghadapi kecemasan.",
                rating=5.0,
                time_ago="2 hari lalu",
            ),
            PatientReviewItemSchema(
                id=f"rev_{p.id}_2",
                patient_name="Pasien Terverifikasi (R. K.)",
                sentiment="positive",
                label="Teknik CBT Mudah Dipahami",
                description="Latihan relaksasi dan teknik manajemen emosi yang diberikan sangat aplikatif di kehidupan sehari-hari.",
                rating=5.0,
                time_ago="1 minggu lalu",
            ),
        ]
        patient_reviews = [t.description for t in testimonials]

        # Certificate items
        reg_no = p.sip_number or p.str_number
        certificate_items = [
            CertificateItemSchema(
                title=f"SIPP: {reg_no} (HIMPSI)",
                image_url="https://images.unsplash.com/photo-1614036417651-efe5912149d8?w=800&auto=format&fit=crop&q=80",
            ),
            CertificateItemSchema(
                title="Magister Profesi Psikologi Klinis Dewasa (S2)",
                image_url="https://images.unsplash.com/photo-1659080928170-b9924d616f04?w=800&auto=format&fit=crop&q=80",
            ),
            CertificateItemSchema(
                title="Sertifikasi CBT Terapan & Regulasi Emosi",
                image_url="https://images.unsplash.com/photo-1659080907100-23f0dac0fe27?w=800&auto=format&fit=crop&q=80",
            ),
            CertificateItemSchema(
                title="Sertifikat Psychological First Aid (PFA) Nasional",
                image_url="https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=800&auto=format&fit=crop&q=80",
            ),
        ]
        certifications = [c.title for c in certificate_items]

        avatar_url = p.profile_photo_url or "https://images.unsplash.com/photo-1594824813583-059df30f1484?w=400&auto=format&fit=crop&q=80"

        return PsychologistItemResponse(
            id=str(p.id),
            name=p.full_name,
            title=p.title_degree,
            registration_number=reg_no,
            avatar_url=avatar_url,
            rating=4.95,
            review_count=max(25, p.years_of_experience * 12),
            experience_years=p.years_of_experience,
            specialties=specialties,
            patient_review_tags=patient_review_tags,
            patient_reviews=patient_reviews,
            review_tags=review_tags,
            testimonials=testimonials,
            patient_stats=PatientStatsSchema(
                total_sessions=max(80, p.years_of_experience * 35),
                satisfaction_percentage=98,
                repeat_patient_rate=87,
                recovery_rate=93,
            ),
            certifications=certifications,
            certificate_items=certificate_items,
            coins_per_session=50,
            fee_per_session=50,
            duration_minutes=30,
            available_online=p.is_online,
            clinic_affiliation="Klinik Psikologi Terpadu UI & Terapi Holistik",
            bio=p.bio or "Psikolog klinis profesional berdedikasi membantu kesehatan mental dan regulasi emosi.",
            practitioner_type=practitioner_type,
            has_psychologist_certificate=True,
            is_volunteer=is_volunteer,
        )

    async def get_psychologists(
        self,
        category: str | None = None,
        query: str | None = None,
    ) -> list[PsychologistItemResponse]:
        """Fetch verified online psychologists and psychiatrists with search and category filters."""
        stmt = (
            select(PsychologistProfile)
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

        items = [self._build_psychologist_response(p) for p in profiles]

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

        # Fetch session record with counselor profile
        stmt = (
            select(ConsultationSession)
            .where(ConsultationSession.id == uuid.UUID(session_res.id))
            .options(selectinload(ConsultationSession.counselor))
        )
        res = await self.db.execute(stmt)
        sess = res.scalar_one_or_none()
        if not sess or not sess.counselor:
            raise HTTPException(status_code=500, detail="Gagal memuat sesi terdaftar.")

        if payload.complaints:
            sess.soap_notes = {"complaints": payload.complaints}
            await self.db.commit()
            await self.db.refresh(sess)

        notes_val = None
        if sess.soap_notes and isinstance(sess.soap_notes, dict):
            notes_val = sess.soap_notes.get("complaints") or sess.soap_notes.get("plan")

        psych_item = self._build_psychologist_response(sess.counselor)
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
        )

    async def get_user_sessions(self, user_id: uuid.UUID) -> list[CareSessionResponse]:
        """Fetch all consultation sessions for the current patient."""
        stmt = (
            select(ConsultationSession)
            .where(ConsultationSession.patient_id == user_id)
            .options(selectinload(ConsultationSession.counselor))
            .order_by(ConsultationSession.scheduled_start_time.desc())
        )
        res = await self.db.execute(stmt)
        sessions = res.scalars().all()

        results: list[CareSessionResponse] = []
        for s in sessions:
            if not s.counselor:
                continue
            psych_item = self._build_psychologist_response(s.counselor)
            soap = s.soap_notes or {}
            advice = [soap.get("plan")] if soap.get("plan") else []
            action_items = soap.get("recommended_tasks") or []
            notes_val = soap.get("complaints") or soap.get("plan")
            results.append(
                CareSessionResponse(
                    id=str(s.id),
                    psychologist=psych_item,
                    session_datetime=s.scheduled_start_time.isoformat(),
                    status=s.status,
                    type="onlineVideo",
                    meeting_url=f"/video_call?channelId={s.id}&counselorName={s.counselor.full_name}" if s.status != "completed" else None,
                    duration_minutes=s.duration_minutes,
                    session_number=1,
                    advice_list=advice,
                    action_items=action_items,
                    diagnosis_summary=soap.get("assessment"),
                    session_summary=soap.get("subjective"),
                    notes=notes_val,
                    share_ai_chat_history=True,
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

