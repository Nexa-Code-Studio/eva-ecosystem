import logging
import uuid
from datetime import UTC, datetime

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.counselor import PsychologistProfile
from app.models.enums import PsychologistVerificationStatus
from app.models.user import User
from app.schemas.counselor import (
    PsychologistProfileResponse,
    PsychologistPublicResponse,
    PsychologistVerificationResponse,
    RegisterPsychologistRequest,
    ResubmitVerificationRequest,
    UpdateBankDetailsRequest,
    UpdatePsychologistProfileRequest,
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

        # Check existing STR
        str_query = select(PsychologistProfile).where(
            PsychologistProfile.str_number == payload.str_number.strip()
        )
        str_res = await self.db.execute(str_query)
        if str_res.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Nomor STR sudah terdaftar di sistem kredensial Eva.",
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
        profile = PsychologistProfile(
            user_id=new_user.id,
            full_name=payload.full_name.strip(),
            title_degree=payload.title_degree.strip(),
            str_number=payload.str_number.strip(),
            sip_number=payload.sip_number.strip() if payload.sip_number else None,
            association=payload.association.strip(),
            specializations=payload.specializations,
            years_of_experience=payload.years_of_experience,
            bio=payload.bio.strip() if payload.bio else None,
            certificate_doc_url=payload.certificate_doc_url,
            verification_status=PsychologistVerificationStatus.PENDING.value,
            is_online=True,
            buffer_time_minutes=10,
        )
        self.db.add(profile)
        await self.db.commit()
        await self.db.refresh(profile)

        return self._to_profile_response(profile)

    async def get_profile_by_user_id(self, user_id: uuid.UUID) -> PsychologistProfileResponse:
        """Fetch psychologist profile by linked user ID."""
        query = select(PsychologistProfile).where(PsychologistProfile.user_id == user_id)
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
        query = select(PsychologistProfile).where(PsychologistProfile.id == profile_id)
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

        profile.certificate_doc_url = payload.certificate_doc_url
        if payload.str_number:
            profile.str_number = payload.str_number.strip()
        if payload.sip_number:
            profile.sip_number = payload.sip_number.strip()

        profile.verification_status = PsychologistVerificationStatus.PENDING.value
        profile.verification_notes = None

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
        query = (
            select(PsychologistProfile)
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

        return [
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
            )
            for p in profiles
        ]

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

        profile.verification_status = payload.status
        profile.verification_notes = payload.notes
        if payload.status == PsychologistVerificationStatus.VERIFIED.value:
            profile.verified_at = datetime.now(UTC)
            profile.verified_by_user_id = admin_user_id

            # Also update base User verification
            user_query = select(User).where(User.id == profile.user_id)
            user_res = await self.db.execute(user_query)
            user = user_res.scalar_one_or_none()
            if user:
                user.is_verified = True
        else:
            profile.verified_at = None
            profile.verified_by_user_id = None

        await self.db.commit()
        await self.db.refresh(profile)

        return PsychologistVerificationResponse(
            verification_status=profile.verification_status,
            verification_notes=profile.verification_notes,
            verified_at=profile.verified_at,
            message=f"Status verifikasi berhasil diubah menjadi '{payload.status}'.",
        )

    def _to_profile_response(self, profile: PsychologistProfile) -> PsychologistProfileResponse:
        return PsychologistProfileResponse(
            id=str(profile.id),
            user_id=str(profile.user_id),
            full_name=profile.full_name,
            title_degree=profile.title_degree,
            str_number=profile.str_number,
            sip_number=profile.sip_number,
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
            bank_name=profile.bank_name,
            bank_account_number=profile.bank_account_number,
            bank_account_holder=profile.bank_account_holder,
            wallet_balance=float(profile.wallet_balance),
            created_at=profile.created_at,
        )
