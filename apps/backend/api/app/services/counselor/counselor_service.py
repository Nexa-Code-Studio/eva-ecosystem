import logging
from typing import Literal
import uuid
from datetime import UTC, datetime

from fastapi import HTTPException, status
from sqlalchemy import case, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlalchemy.orm.attributes import flag_modified

from app.core.security import hash_password
from app.models.counselor import PlatformPricingConfig, PsychologistProfile
from app.models.enums import PricingConfigStatus, PsychologistVerificationStatus
from app.models.user import User
from app.services.level import LevelService
from app.schemas.counselor import (
    PsychologistProfileResponse,
    PsychologistPublicResponse,
    PsychologistVerificationResponse,
    RegisterPsychologistRequest,
    ResubmitVerificationRequest,
    ScheduleConfigResponse,
    UpdateBankDetailsRequest,
    UpdateCounselorStatusRequest,
    UpdatePsychologistProfileRequest,
    UpdateScheduleConfigRequest,
    VerifyPsychologistRequest,
)

logger = logging.getLogger(__name__)


class CounselorService:
    """Domain service managing psychologist registration, profile lifecycle, and verification gates."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def register(self, payload: RegisterPsychologistRequest) -> PsychologistProfileResponse:
        """Register a new individual professional psychologist with pending verification."""
        clean_email = payload.email.strip().lower()

        # Check existing user
        query = select(User).where(User.email == clean_email)
        res = await self.db.execute(query)
        if res.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Email sudah terdaftar di sistem Eva.",
            )

        # Check existing STR / SIP
        effective_str = (payload.str_number or payload.sip_number or f"REG-{uuid.uuid4().hex[:8].upper()}").strip()
        if payload.str_number and payload.str_number.strip():
            str_query = select(PsychologistProfile).where(
                PsychologistProfile.str_number == payload.str_number.strip()
            )
            str_res = await self.db.execute(str_query)
            if str_res.scalar_one_or_none():
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Nomor STR sudah terdaftar di sistem kredensial Eva.",
                )
        if payload.sip_number and payload.sip_number.strip():
            sip_query = select(PsychologistProfile).where(
                PsychologistProfile.sip_number == payload.sip_number.strip()
            )
            sip_res = await self.db.execute(sip_query)
            if sip_res.scalar_one_or_none():
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Nomor SIP / SIPP sudah terdaftar di sistem kredensial Eva.",
                )

        # 1. Create base User account
        new_user = User(
            email=clean_email,
            password_hash=hash_password(payload.password),
            display_name=payload.full_name,
            is_active=True,
            is_verified=False,
        )
        self.db.add(new_user)
        await self.db.flush()

        # 2. Create PsychologistProfile linked to User
        effective_edu = (payload.education or payload.last_education or "S2 Magister Psikologi Profesi").strip()
        str_inst = (payload.str_issuing_institution or payload.issuing_institution or "Kemenkes RI / KTKI").strip()
        str_exp = (payload.str_expiry_date or payload.document_expiry_date or "Seumur Hidup (UU Kesehatan No. 17/2023)").strip()
        sip_inst = payload.sip_issuing_institution.strip() if payload.sip_issuing_institution else None
        sip_exp = payload.sip_expiry_date.strip() if payload.sip_expiry_date else None
        bio_info = payload.bio.strip() if payload.bio else (
            f"Pendidikan: {effective_edu} | STR: {str_inst} ({str_exp})"
            + (f" | SIP: {sip_inst or '-'} ({sip_exp or '-'})" if payload.sip_number else "")
        )
        effective_str_doc_url = payload.str_doc_url or payload.certificate_doc_url
        effective_cert_url = effective_str_doc_url or payload.sip_doc_url or payload.certificate_doc_url
        profile = PsychologistProfile(
            user_id=new_user.id,
            full_name=payload.full_name.strip(),
            title_degree=payload.title_degree.strip(),
            education=effective_edu,
            str_number=effective_str,
            str_doc_url=effective_str_doc_url,
            str_issuing_institution=str_inst,
            str_expiry_date=str_exp,
            str_verified=False,
            sip_number=payload.sip_number.strip() if payload.sip_number else None,
            sip_doc_url=payload.sip_doc_url,
            sip_issuing_institution=sip_inst,
            sip_expiry_date=sip_exp,
            sip_verified=False,
            association=payload.association.strip(),
            specializations=payload.specializations,
            years_of_experience=payload.years_of_experience,
            bio=bio_info,
            certificate_doc_url=effective_cert_url,
            verification_status=PsychologistVerificationStatus.PENDING.value,
            is_online=False,
            buffer_time_minutes=10,
        )
        self.db.add(profile)
        await self.db.commit()
        await self.db.refresh(profile)

        return self._to_profile_response(profile, email=clean_email)

    async def get_profile_by_user_id(self, user_id: uuid.UUID) -> PsychologistProfileResponse:
        """Fetch psychologist profile by linked user ID."""
        query = (
            select(PsychologistProfile)
            .options(selectinload(PsychologistProfile.current_level))
            .where(PsychologistProfile.user_id == user_id)
        )
        res = await self.db.execute(query)
        profile = res.scalar_one_or_none()
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )
        return self._to_profile_response(profile)

    async def get_profile_by_id(self, profile_id: uuid.UUID) -> PsychologistProfileResponse:
        """Fetch psychologist profile by primary key UUID."""
        query = (
            select(PsychologistProfile)
            .options(selectinload(PsychologistProfile.current_level))
            .where(PsychologistProfile.id == profile_id)
        )
        res = await self.db.execute(query)
        profile = res.scalar_one_or_none()
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )
        return self._to_profile_response(profile)

    async def update_profile(
        self,
        user_id: uuid.UUID,
        payload: UpdatePsychologistProfileRequest,
    ) -> PsychologistProfileResponse:
        """Update psychologist professional profile information."""
        query = select(PsychologistProfile).where(PsychologistProfile.user_id == user_id)
        res = await self.db.execute(query)
        profile = res.scalar_one_or_none()
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )

        if payload.full_name is not None:
            profile.full_name = payload.full_name.strip()
        if payload.title_degree is not None:
            profile.title_degree = payload.title_degree.strip()
        if payload.association is not None:
            profile.association = payload.association.strip()
        if payload.specializations is not None:
            profile.specializations = payload.specializations
        if payload.years_of_experience is not None:
            profile.years_of_experience = payload.years_of_experience
        if payload.bio is not None:
            profile.bio = payload.bio.strip()
        if payload.profile_photo_url is not None:
            profile.profile_photo_url = payload.profile_photo_url
        if payload.buffer_time_minutes is not None:
            profile.buffer_time_minutes = payload.buffer_time_minutes

        await self.db.commit()
        await self.db.refresh(profile)
        return self._to_profile_response(profile)

    async def resubmit_verification(
        self,
        user_id: uuid.UUID,
        payload: ResubmitVerificationRequest,
    ) -> PsychologistVerificationResponse:
        """Re-upload revised STR/SIP certificate after a rejection or revision request."""
        query = select(PsychologistProfile).where(PsychologistProfile.user_id == user_id)
        res = await self.db.execute(query)
        profile = res.scalar_one_or_none()
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )

        if payload.certificate_doc_url:
            profile.certificate_doc_url = payload.certificate_doc_url
        if payload.str_doc_url is not None:
            profile.str_doc_url = payload.str_doc_url
        if payload.sip_doc_url is not None:
            profile.sip_doc_url = payload.sip_doc_url
        if payload.str_issuing_institution is not None:
            profile.str_issuing_institution = payload.str_issuing_institution.strip()
        if payload.str_expiry_date is not None:
            profile.str_expiry_date = payload.str_expiry_date.strip()
        if payload.sip_issuing_institution is not None:
            profile.sip_issuing_institution = payload.sip_issuing_institution.strip()
        if payload.sip_expiry_date is not None:
            profile.sip_expiry_date = payload.sip_expiry_date.strip()
        if payload.education is not None:
            profile.education = payload.education.strip()
        if payload.str_number:
            profile.str_number = payload.str_number.strip()
        if payload.sip_number:
            profile.sip_number = payload.sip_number.strip()

        profile.str_verified = False
        profile.sip_verified = False
        profile.verification_status = PsychologistVerificationStatus.PENDING.value
        profile.verification_notes = None
        profile.verified_at = None
        profile.verified_by_user_id = None
        profile.is_online = False

        await self.db.commit()
        await self.db.refresh(profile)

        return PsychologistVerificationResponse(
            verification_status=profile.verification_status,
            verification_notes=profile.verification_notes,
            verified_at=profile.verified_at,
            message="Berkas kredensial berhasil diajukan ulang untuk peninjauan admin.",
        )

    async def toggle_availability(self, user_id: uuid.UUID, is_online: bool) -> PsychologistProfileResponse:
        """Toggle psychologist active availability for teleconsultations."""
        query = select(PsychologistProfile).where(PsychologistProfile.user_id == user_id)
        res = await self.db.execute(query)
        profile = res.scalar_one_or_none()
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )

        profile.is_online = is_online
        await self.db.commit()
        await self.db.refresh(profile)
        return self._to_profile_response(profile)

    async def update_bank_details(
        self,
        user_id: uuid.UUID,
        payload: UpdateBankDetailsRequest,
    ) -> PsychologistProfileResponse:
        """Update payout bank account details for honorarium withdrawal."""
        query = select(PsychologistProfile).where(PsychologistProfile.user_id == user_id)
        res = await self.db.execute(query)
        profile = res.scalar_one_or_none()
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )

        profile.bank_name = payload.bank_name.strip()
        profile.bank_account_number = payload.bank_account_number.strip()
        profile.bank_account_holder = payload.bank_account_holder.strip()

        await self.db.commit()
        await self.db.refresh(profile)
        return self._to_profile_response(profile)

    async def list_verified_counselors(
        self,
        limit: int = 20,
        offset: int = 0,
    ) -> list[PsychologistPublicResponse]:
        """List active and verified psychologists available for teleconsultation booking."""
        fallback_res = await self.db.execute(
            select(PlatformPricingConfig)
            .where(PlatformPricingConfig.status == PricingConfigStatus.ACTIVE.value)
            .order_by(PlatformPricingConfig.effective_from.desc())
            .limit(1)
        )
        fallback = fallback_res.scalar_one_or_none()
        fallback_price = fallback.price_per_session if fallback else Decimal("150.00")
        fallback_fee = float(fallback.platform_fee_percentage) if fallback else 20.0

        query = (
            select(PsychologistProfile)
            .options(selectinload(PsychologistProfile.current_level))
            .where(
                PsychologistProfile.verification_status == PsychologistVerificationStatus.VERIFIED.value,
                PsychologistProfile.is_online.is_(True),
            )
            .order_by(PsychologistProfile.years_of_experience.desc())
            .limit(limit)
            .offset(offset)
        )
        res = await self.db.execute(query)
        profiles = res.scalars().all()

        items: list[PsychologistPublicResponse] = []
        for p in profiles:
            lvl = p.current_level if (p.current_level and p.current_level.is_active) else None
            effective_price = float(
                LevelService.compute_effective_price(p, lvl, fallback_price=fallback_price)
            )
            fee_pct = float(lvl.platform_fee_percentage) if lvl else fallback_fee
            items.append(
                PsychologistPublicResponse(
                    id=str(p.id),
                    full_name=p.full_name,
                    title_degree=p.title_degree,
                    association=p.association,
                    specializations=p.specializations or [],
                    years_of_experience=p.years_of_experience,
                    bio=p.bio,
                    profile_photo_url=p.profile_photo_url,
                    is_online=p.is_online,
                    buffer_time_minutes=p.buffer_time_minutes,
                    level_tier=lvl.level_tier if lvl else None,
                    level_name=lvl.name if lvl else None,
                    level_badge_icon=lvl.badge_icon if lvl else None,
                    effective_session_price=effective_price,
                    platform_fee_percentage=fee_pct,
                    total_completed_sessions=p.total_completed_sessions,
                    total_consultation_hours=float(p.total_consultation_hours),
                    average_rating=float(p.average_rating),
                    rating_count=p.rating_count,
                )
            )
        return items

    async def list_all_counselors_for_admin(
        self,
        verification_status: str | None = None,
        search: str | None = None,
    ) -> list[PsychologistProfileResponse]:
        """List all psychologist profiles across every verification status for Admin review."""
        query = (
            select(PsychologistProfile)
            .options(
                selectinload(PsychologistProfile.user),
                selectinload(PsychologistProfile.current_level),
            )
            .join(User, PsychologistProfile.user_id == User.id)
        )

        if verification_status:
            query = query.where(PsychologistProfile.verification_status == verification_status.strip())

        if search and search.strip():
            pattern = f"%{search.strip()}%"
            query = query.where(
                or_(
                    PsychologistProfile.full_name.ilike(pattern),
                    User.email.ilike(pattern),
                    PsychologistProfile.str_number.ilike(pattern),
                    PsychologistProfile.sip_number.ilike(pattern),
                    PsychologistProfile.association.ilike(pattern),
                )
            )

        query = query.order_by(
            case(
                (PsychologistProfile.verification_status == PsychologistVerificationStatus.PENDING.value, 0),
                else_=1,
            ),
            PsychologistProfile.created_at.desc(),
        )
        res = await self.db.execute(query)
        profiles = res.scalars().all()
        return [
            self._to_profile_response(p, email=p.user.email if p.user else None)
            for p in profiles
        ]

    async def toggle_document_verification(
        self,
        counselor_id: uuid.UUID,
        doc_type: Literal["str", "sip"],
        verified: bool | None = None,
    ) -> PsychologistProfileResponse:
        """Toggle or explicitly set STR/SIP document validity for an applicant (Admin)."""
        query = (
            select(PsychologistProfile)
            .options(selectinload(PsychologistProfile.user))
            .where(PsychologistProfile.id == counselor_id)
        )
        res = await self.db.execute(query)
        profile = res.scalar_one_or_none()
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )

        if doc_type == "str":
            if not profile.str_number or not profile.str_number.strip():
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Psikolog tidak memiliki nomor STR terdaftar.",
                )
            profile.str_verified = (not profile.str_verified) if verified is None else verified
        else:
            if not profile.sip_number or not profile.sip_number.strip():
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Psikolog tidak memiliki nomor SIP/SIPP terdaftar.",
                )
            profile.sip_verified = (not profile.sip_verified) if verified is None else verified

        await self.db.commit()
        await self.db.refresh(profile)
        return self._to_profile_response(profile, email=profile.user.email if profile.user else None)

    async def verify_counselor(
        self,
        counselor_id: uuid.UUID,
        admin_user_id: uuid.UUID,
        payload: VerifyPsychologistRequest,
    ) -> PsychologistVerificationResponse:
        """Administrative review action to approve or reject psychologist credentials."""
        query = select(PsychologistProfile).where(PsychologistProfile.id == counselor_id)
        res = await self.db.execute(query)
        profile = res.scalar_one_or_none()
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )

        if payload.status == PsychologistVerificationStatus.VERIFIED.value:
            if not (profile.str_verified or profile.sip_verified):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Minimal 1 dokumen STR atau SIP harus diverifikasi valid sebelum menyetujui psikolog.",
                )
            profile.verification_status = payload.status
            profile.verification_notes = payload.notes
            profile.verified_at = datetime.now(UTC)
            profile.verified_by_user_id = admin_user_id
            profile.is_online = True

            user_query = select(User).where(User.id == profile.user_id)
            user_res = await self.db.execute(user_query)
            user = user_res.scalar_one_or_none()
            if user:
                user.is_verified = True
        else:
            profile.verification_status = payload.status
            profile.verification_notes = payload.notes
            profile.verified_at = None
            profile.verified_by_user_id = None
            profile.is_online = False

        await self.db.commit()
        await self.db.refresh(profile)

        return PsychologistVerificationResponse(
            verification_status=profile.verification_status,
            verification_notes=profile.verification_notes,
            verified_at=profile.verified_at,
            message=f"Status verifikasi berhasil diubah menjadi '{payload.status}'.",
        )

    async def update_counselor_account_status(
        self,
        counselor_id: uuid.UUID,
        admin_user_id: uuid.UUID,
        payload: UpdateCounselorStatusRequest,
    ) -> PsychologistProfileResponse:
        """Suspend or reactivate a psychologist profile verification status (Admin)."""
        query = (
            select(PsychologistProfile)
            .options(selectinload(PsychologistProfile.user))
            .where(PsychologistProfile.id == counselor_id)
        )
        res = await self.db.execute(query)
        profile = res.scalar_one_or_none()
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )

        if payload.status == PsychologistVerificationStatus.SUSPENDED.value:
            profile.verification_status = PsychologistVerificationStatus.SUSPENDED.value
            profile.is_online = False
            if payload.notes is not None and payload.notes.strip():
                profile.verification_notes = payload.notes.strip()
        else:
            if not (profile.str_verified or profile.sip_verified):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Minimal 1 dokumen STR atau SIP harus valid sebelum mengaktifkan kembali akun psikolog.",
                )
            profile.verification_status = PsychologistVerificationStatus.VERIFIED.value
            profile.verified_at = datetime.now(UTC)
            profile.verified_by_user_id = admin_user_id
            profile.is_online = True
            if payload.notes is not None and payload.notes.strip():
                profile.verification_notes = payload.notes.strip()
            if profile.user:
                profile.user.is_verified = True

        await self.db.commit()
        await self.db.refresh(profile)
        return self._to_profile_response(profile, email=profile.user.email if profile.user else None)

    def _to_profile_response(
        self,
        profile: PsychologistProfile,
        email: str | None = None,
    ) -> PsychologistProfileResponse:
        resolved_email = email
        if resolved_email is None and "user" in profile.__dict__ and profile.user is not None:
            resolved_email = profile.user.email

        lvl = (
            profile.current_level
            if "current_level" in profile.__dict__
            and profile.current_level is not None
            and profile.current_level.is_active
            else None
        )
        effective_price = float(LevelService.compute_effective_price(profile, lvl))
        fee_pct = float(lvl.platform_fee_percentage) if lvl else 20.0

        return PsychologistProfileResponse(
            id=str(profile.id),
            user_id=str(profile.user_id),
            email=resolved_email,
            full_name=profile.full_name,
            title_degree=profile.title_degree,
            education=profile.education,
            str_number=profile.str_number,
            str_doc_url=profile.str_doc_url,
            str_issuing_institution=profile.str_issuing_institution,
            str_expiry_date=profile.str_expiry_date,
            str_verified=profile.str_verified,
            sip_number=profile.sip_number,
            sip_doc_url=profile.sip_doc_url,
            sip_issuing_institution=profile.sip_issuing_institution,
            sip_expiry_date=profile.sip_expiry_date,
            sip_verified=profile.sip_verified,
            association=profile.association,
            specializations=profile.specializations or [],
            years_of_experience=profile.years_of_experience,
            bio=profile.bio,
            profile_photo_url=profile.profile_photo_url,
            certificate_doc_url=profile.certificate_doc_url,
            verification_status=profile.verification_status,
            verification_notes=profile.verification_notes,
            verified_at=profile.verified_at,
            is_online=profile.is_online,
            buffer_time_minutes=profile.buffer_time_minutes,
            schedule_config=profile.schedule_config or {},
            bank_name=profile.bank_name,
            bank_account_number=profile.bank_account_number,
            bank_account_holder=profile.bank_account_holder,
            wallet_balance=float(profile.wallet_balance),
            current_level_id=str(lvl.id) if lvl else None,
            level_tier=lvl.level_tier if lvl else None,
            level_name=lvl.name if lvl else None,
            level_badge_icon=lvl.badge_icon if lvl else None,
            effective_session_price=effective_price,
            platform_fee_percentage=fee_pct,
            allow_custom_price=bool(lvl.allow_custom_price) if lvl else False,
            custom_price_per_session=(
                float(profile.custom_price_per_session)
                if profile.custom_price_per_session is not None
                else None
            ),
            total_completed_sessions=profile.total_completed_sessions or 0,
            total_consultation_hours=float(profile.total_consultation_hours or 0),
            average_rating=float(profile.average_rating or 0),
            rating_count=profile.rating_count or 0,
            created_at=profile.created_at,
        )

    async def get_schedule_config(self, user_id: uuid.UUID) -> ScheduleConfigResponse:
        """Retrieve weekly day-by-day practice hours and break periods."""
        query = select(PsychologistProfile).where(PsychologistProfile.user_id == user_id)
        res = await self.db.execute(query)
        profile = res.scalar_one_or_none()
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )

        default_config = {
            "monday": {"is_active": True, "operating_hours": {"start": "08:00", "end": "17:00"}, "breaks": [{"start": "12:00", "end": "13:00", "label": "Istirahat Siang"}]},
            "tuesday": {"is_active": True, "operating_hours": {"start": "08:00", "end": "17:00"}, "breaks": [{"start": "12:00", "end": "13:00", "label": "Istirahat Siang"}]},
            "wednesday": {"is_active": True, "operating_hours": {"start": "08:00", "end": "17:00"}, "breaks": [{"start": "12:00", "end": "13:00", "label": "Istirahat Siang"}]},
            "thursday": {"is_active": True, "operating_hours": {"start": "08:00", "end": "17:00"}, "breaks": [{"start": "12:00", "end": "13:00", "label": "Istirahat Siang"}]},
            "friday": {"is_active": True, "operating_hours": {"start": "08:00", "end": "17:00"}, "breaks": [{"start": "11:30", "end": "13:00", "label": "Shalat Jumat & Istirahat"}, {"start": "15:30", "end": "16:00", "label": "Istirahat Sore"}]},
            "saturday": {"is_active": False, "operating_hours": {"start": "08:00", "end": "17:00"}, "breaks": []},
            "sunday": {"is_active": False, "operating_hours": {"start": "08:00", "end": "17:00"}, "breaks": []},
        }
        cfg = profile.schedule_config if (profile.schedule_config and len(profile.schedule_config) > 0) else default_config

        return ScheduleConfigResponse(
            counselor_id=str(profile.id),
            buffer_time_minutes=profile.buffer_time_minutes,
            schedule_config=cfg,
        )

    async def update_schedule_config(
        self, user_id: uuid.UUID, payload: UpdateScheduleConfigRequest
    ) -> ScheduleConfigResponse:
        """Save day-by-day practice hours and multiple break periods."""
        query = select(PsychologistProfile).where(PsychologistProfile.user_id == user_id)
        res = await self.db.execute(query)
        profile = res.scalar_one_or_none()
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )

        serialized_config = {
            day.strip().lower(): item.model_dump()
            for day, item in payload.schedule_config.items()
        }
        profile.schedule_config = dict(serialized_config)
        flag_modified(profile, "schedule_config")
        if payload.buffer_time_minutes is not None:
            profile.buffer_time_minutes = payload.buffer_time_minutes

        await self.db.commit()
        await self.db.refresh(profile)

        return ScheduleConfigResponse(
            counselor_id=str(profile.id),
            buffer_time_minutes=profile.buffer_time_minutes,
            schedule_config=profile.schedule_config,
        )
