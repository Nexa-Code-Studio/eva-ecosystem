from dataclasses import dataclass
from decimal import Decimal
from typing import Any
import uuid

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.counselor import ConsultationSession, PlatformPricingConfig, PsychologistProfile
from app.models.enums import (
    ConsultationSessionStatus,
    PricingConfigStatus,
    PsychologistVerificationStatus,
)
from app.models.level import CounselorReview, PsychologistLevel
from app.models.user import User
from app.schemas.level import (
    CounselorLevelMetricsResponse,
    CounselorPricingResponse,
    CounselorReviewResponse,
    CreateSessionReviewRequest,
    LevelEvaluationBatchResponse,
    LevelProgressRequirementResponse,
    PsychologistLevelResponse,
    UpdateCounselorCustomPricingRequest,
    UpsertPsychologistLevelRequest,
)


@dataclass(frozen=True)
class ResolvedCounselorPricing:
    price_per_session: Decimal
    extension_price_per_session: Decimal
    platform_fee_percentage: Decimal
    counselor_share_percentage: Decimal
    fallback_pricing_config_id: uuid.UUID | None
    level_id: uuid.UUID | None = None
    level_name: str | None = None


class LevelService:
    """Service managing dynamic psychologist levels, quantitative evaluation, reviews, and tiered pricing."""

    def __init__(self, db: AsyncSession):
        self.db = db

    @staticmethod
    def to_level_response(level: PsychologistLevel) -> PsychologistLevelResponse:
        return PsychologistLevelResponse(
            id=str(level.id),
            level_tier=level.level_tier,
            name=level.name,
            badge_icon=level.badge_icon,
            min_completed_sessions=level.min_completed_sessions,
            min_average_rating=float(level.min_average_rating),
            min_consultation_hours=float(level.min_consultation_hours),
            min_review_count=level.min_review_count,
            default_session_price=float(level.default_session_price),
            platform_fee_percentage=float(level.platform_fee_percentage),
            allow_custom_price=level.allow_custom_price,
            min_custom_price=float(level.min_custom_price) if level.min_custom_price is not None else None,
            max_custom_price=float(level.max_custom_price) if level.max_custom_price is not None else None,
            is_active=level.is_active,
            created_at=level.created_at,
            updated_at=level.updated_at,
        )

    @staticmethod
    def compute_effective_price(
        profile: PsychologistProfile,
        level: PsychologistLevel | None,
        fallback_price: Decimal = Decimal("150.00"),
    ) -> Decimal:
        """Resolve effective session price from counselor custom override + level default."""
        if level and level.is_active:
            if level.allow_custom_price and profile.custom_price_per_session is not None:
                custom_val = profile.custom_price_per_session
                if level.min_custom_price is not None and custom_val < level.min_custom_price:
                    return level.min_custom_price
                if level.max_custom_price is not None and custom_val > level.max_custom_price:
                    return level.max_custom_price
                return custom_val
            return level.default_session_price
        return fallback_price

    async def _get_fallback_pricing_config(self) -> PlatformPricingConfig | None:
        res = await self.db.execute(
            select(PlatformPricingConfig)
            .where(PlatformPricingConfig.status == PricingConfigStatus.ACTIVE.value)
            .order_by(PlatformPricingConfig.effective_from.desc())
            .limit(1)
        )
        return res.scalar_one_or_none()

    async def resolve_counselor_pricing(
        self,
        counselor_id: uuid.UUID,
        *,
        profile: PsychologistProfile | None = None,
        pricing_service: Any | None = None,
    ) -> ResolvedCounselorPricing:
        """Resolve session price & platform split for booking/extension based on counselor tier."""
        target_profile = profile
        if target_profile is None:
            profile_res = await self.db.execute(
                select(PsychologistProfile)
                .options(selectinload(PsychologistProfile.current_level))
                .where(PsychologistProfile.id == counselor_id)
            )
            target_profile = profile_res.scalar_one_or_none()
        elif target_profile.current_level_id is not None and "current_level" not in target_profile.__dict__:
            lvl_res = await self.db.execute(
                select(PsychologistLevel).where(
                    PsychologistLevel.id == target_profile.current_level_id
                )
            )
            target_profile.current_level = lvl_res.scalar_one_or_none()

        level = (
            target_profile.current_level
            if target_profile and "current_level" in target_profile.__dict__
            else None
        )

        if pricing_service is not None:
            fallback = await pricing_service.get_active_pricing()
        else:
            fallback = await self._get_fallback_pricing_config()

        fallback_price = fallback.price_per_session if fallback else Decimal("150.00")
        fallback_fee_pct = fallback.platform_fee_percentage if fallback else Decimal("20.00")
        fallback_id = fallback.id if fallback else None

        if target_profile and level and level.is_active:
            price = self.compute_effective_price(target_profile, level, fallback_price=fallback_price)
            fee_pct = level.platform_fee_percentage
            counselor_pct = Decimal("100.00") - fee_pct
            return ResolvedCounselorPricing(
                price_per_session=price,
                extension_price_per_session=price,
                platform_fee_percentage=fee_pct,
                counselor_share_percentage=counselor_pct,
                fallback_pricing_config_id=fallback_id,
                level_id=level.id,
                level_name=level.name,
            )

        ext_price = fallback.extension_price_per_session if fallback else fallback_price
        counselor_pct = (
            fallback.counselor_share_percentage if fallback else (Decimal("100.00") - fallback_fee_pct)
        )
        return ResolvedCounselorPricing(
            price_per_session=fallback_price,
            extension_price_per_session=ext_price,
            platform_fee_percentage=fallback_fee_pct,
            counselor_share_percentage=counselor_pct,
            fallback_pricing_config_id=fallback_id,
        )

    # ------------------------------------------------------------------
    # Admin CRUD for Master Levels
    # ------------------------------------------------------------------
    async def list_levels(self, active_only: bool = False) -> list[PsychologistLevelResponse]:
        query = select(PsychologistLevel)
        if active_only:
            query = query.where(PsychologistLevel.is_active.is_(True))
        query = query.order_by(PsychologistLevel.level_tier.asc(), PsychologistLevel.created_at.asc())
        res = await self.db.execute(query)
        return [self.to_level_response(lvl) for lvl in res.scalars().all()]

    async def create_level(self, payload: UpsertPsychologistLevelRequest) -> PsychologistLevelResponse:
        existing_tier = await self.db.scalar(
            select(PsychologistLevel).where(PsychologistLevel.level_tier == payload.level_tier)
        )
        if existing_tier:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Tier level #{payload.level_tier} sudah digunakan. Pilih urutan tier lain.",
            )

        level = PsychologistLevel(
            level_tier=payload.level_tier,
            name=payload.name.strip(),
            badge_icon=payload.badge_icon.strip() or "award",
            min_completed_sessions=payload.min_completed_sessions,
            min_average_rating=Decimal(str(round(payload.min_average_rating, 2))),
            min_consultation_hours=Decimal(str(round(payload.min_consultation_hours, 2))),
            min_review_count=payload.min_review_count,
            default_session_price=Decimal(str(round(payload.default_session_price, 2))),
            platform_fee_percentage=Decimal(str(round(payload.platform_fee_percentage, 2))),
            allow_custom_price=payload.allow_custom_price,
            min_custom_price=(
                Decimal(str(round(payload.min_custom_price, 2)))
                if payload.allow_custom_price and payload.min_custom_price is not None
                else None
            ),
            max_custom_price=(
                Decimal(str(round(payload.max_custom_price, 2)))
                if payload.allow_custom_price and payload.max_custom_price is not None
                else None
            ),
            is_active=payload.is_active,
        )
        self.db.add(level)
        await self.db.commit()
        await self.db.refresh(level)
        return self.to_level_response(level)

    async def update_level(
        self,
        level_id: uuid.UUID,
        payload: UpsertPsychologistLevelRequest,
    ) -> PsychologistLevelResponse:
        res = await self.db.execute(
            select(PsychologistLevel).where(PsychologistLevel.id == level_id)
        )
        level = res.scalar_one_or_none()
        if not level:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Konfigurasi level psikolog tidak ditemukan.",
            )

        if payload.level_tier != level.level_tier:
            dup = await self.db.scalar(
                select(PsychologistLevel).where(
                    PsychologistLevel.level_tier == payload.level_tier,
                    PsychologistLevel.id != level_id,
                )
            )
            if dup:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Tier level #{payload.level_tier} sudah digunakan tier lain.",
                )

        level.level_tier = payload.level_tier
        level.name = payload.name.strip()
        level.badge_icon = payload.badge_icon.strip() or "award"
        level.min_completed_sessions = payload.min_completed_sessions
        level.min_average_rating = Decimal(str(round(payload.min_average_rating, 2)))
        level.min_consultation_hours = Decimal(str(round(payload.min_consultation_hours, 2)))
        level.min_review_count = payload.min_review_count
        level.default_session_price = Decimal(str(round(payload.default_session_price, 2)))
        level.platform_fee_percentage = Decimal(str(round(payload.platform_fee_percentage, 2)))
        level.allow_custom_price = payload.allow_custom_price
        level.min_custom_price = (
            Decimal(str(round(payload.min_custom_price, 2)))
            if payload.allow_custom_price and payload.min_custom_price is not None
            else None
        )
        level.max_custom_price = (
            Decimal(str(round(payload.max_custom_price, 2)))
            if payload.allow_custom_price and payload.max_custom_price is not None
            else None
        )
        level.is_active = payload.is_active

        await self.db.commit()
        await self.db.refresh(level)
        return self.to_level_response(level)

    async def toggle_level_active(self, level_id: uuid.UUID) -> PsychologistLevelResponse:
        res = await self.db.execute(
            select(PsychologistLevel).where(PsychologistLevel.id == level_id)
        )
        level = res.scalar_one_or_none()
        if not level:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Konfigurasi level psikolog tidak ditemukan.",
            )
        level.is_active = not level.is_active
        await self.db.commit()
        await self.db.refresh(level)
        return self.to_level_response(level)

    async def delete_level(self, level_id: uuid.UUID) -> None:
        res = await self.db.execute(
            select(PsychologistLevel).where(PsychologistLevel.id == level_id)
        )
        level = res.scalar_one_or_none()
        if not level:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Konfigurasi level psikolog tidak ditemukan.",
            )

        assigned_count = await self.db.scalar(
            select(func.count(PsychologistProfile.id)).where(
                PsychologistProfile.current_level_id == level_id
            )
        )
        if assigned_count and int(assigned_count) > 0:
            # Soft-deactivate when referenced by existing counselors so history stays intact
            level.is_active = False
            await self.db.commit()
            return

        await self.db.delete(level)
        await self.db.commit()

    # ------------------------------------------------------------------
    # Quantitative Evaluation Engine (Ratchet / Monotone Upward)
    # ------------------------------------------------------------------
    async def recalculate_and_evaluate(
        self,
        counselor_id: uuid.UUID,
        *,
        commit: bool = True,
    ) -> tuple[PsychologistProfile, bool]:
        """Recompute real counselor metrics from sessions & reviews and evaluate career tier."""
        profile_res = await self.db.execute(
            select(PsychologistProfile)
            .options(selectinload(PsychologistProfile.current_level))
            .where(PsychologistProfile.id == counselor_id)
        )
        profile = profile_res.scalar_one_or_none()
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )

        # 1. Aggregate completed sessions & consultation hours
        session_stats_res = await self.db.execute(
            select(
                func.count(ConsultationSession.id),
                func.coalesce(func.sum(ConsultationSession.duration_minutes), 0),
            ).where(
                ConsultationSession.counselor_id == counselor_id,
                ConsultationSession.status == ConsultationSessionStatus.COMPLETED.value,
            )
        )
        completed_count_raw, total_minutes_raw = session_stats_res.one()
        completed_count = int(completed_count_raw or 0)
        total_hours = (Decimal(str(total_minutes_raw or 0)) / Decimal("60")).quantize(
            Decimal("0.01")
        )

        # 2. Aggregate per-session ratings from counselor_reviews
        review_stats_res = await self.db.execute(
            select(
                func.count(CounselorReview.id),
                func.avg(CounselorReview.rating),
            ).where(CounselorReview.counselor_id == counselor_id)
        )
        review_count_raw, avg_rating_raw = review_stats_res.one()
        review_count = int(review_count_raw or 0)
        avg_rating = (
            Decimal(str(avg_rating_raw)).quantize(Decimal("0.01"))
            if avg_rating_raw is not None
            else Decimal("0.00")
        )

        profile.total_completed_sessions = completed_count
        profile.total_consultation_hours = total_hours
        profile.rating_count = review_count
        profile.average_rating = avg_rating

        # 3. Evaluate against dynamic active tiers
        levels_res = await self.db.execute(
            select(PsychologistLevel)
            .where(PsychologistLevel.is_active.is_(True))
            .order_by(PsychologistLevel.level_tier.asc())
        )
        active_levels = list(levels_res.scalars().all())

        upgraded = False
        if active_levels:
            eligible_level: PsychologistLevel | None = None
            for lvl in active_levels:
                if (
                    completed_count >= lvl.min_completed_sessions
                    and avg_rating >= lvl.min_average_rating
                    and total_hours >= lvl.min_consultation_hours
                    and review_count >= lvl.min_review_count
                ):
                    eligible_level = lvl

            # Fallback to entry tier if counselor meets zero higher thresholds yet
            if eligible_level is None:
                eligible_level = active_levels[0]

            current = profile.current_level
            if current is None or not current.is_active:
                if profile.current_level_id != eligible_level.id:
                    upgraded = current is None or eligible_level.level_tier > current.level_tier
                    profile.current_level_id = eligible_level.id
                    profile.current_level = eligible_level
            elif eligible_level.level_tier > current.level_tier:
                # Monotone ratchet: only promote automatically; never demote active tier holders
                profile.current_level_id = eligible_level.id
                profile.current_level = eligible_level
                upgraded = True

            # Revalidate counselor custom price if tier changed or bounds tightened
            effective_level = profile.current_level
            if effective_level and profile.custom_price_per_session is not None:
                if not effective_level.allow_custom_price:
                    profile.custom_price_per_session = None
                elif (
                    effective_level.min_custom_price is not None
                    and profile.custom_price_per_session < effective_level.min_custom_price
                ):
                    profile.custom_price_per_session = effective_level.min_custom_price
                elif (
                    effective_level.max_custom_price is not None
                    and profile.custom_price_per_session > effective_level.max_custom_price
                ):
                    profile.custom_price_per_session = effective_level.max_custom_price

        if commit:
            await self.db.commit()
            await self.db.refresh(profile)

        return profile, upgraded

    async def evaluate_all_counselors(self) -> LevelEvaluationBatchResponse:
        """Evaluate quantitative metrics and career levels across all verified psychologists."""
        res = await self.db.execute(
            select(PsychologistProfile.id).where(
                PsychologistProfile.verification_status
                == PsychologistVerificationStatus.VERIFIED.value
            )
        )
        counselor_ids = list(res.scalars().all())
        upgraded_count = 0
        for cid in counselor_ids:
            _, did_upgrade = await self.recalculate_and_evaluate(cid, commit=False)
            if did_upgrade:
                upgraded_count += 1

        await self.db.commit()
        return LevelEvaluationBatchResponse(
            evaluated_counselors=len(counselor_ids),
            upgraded_count=upgraded_count,
            message=(
                f"Evaluasi selesai untuk {len(counselor_ids)} psikolog terverifikasi; "
                f"{upgraded_count} psikolog naik tier level."
            ),
        )

    # ------------------------------------------------------------------
    # Counselor Level Metrics, Custom Pricing & Patient Reviews
    # ------------------------------------------------------------------
    async def get_counselor_level_metrics(
        self,
        user_id: uuid.UUID,
    ) -> CounselorLevelMetricsResponse:
        profile_res = await self.db.execute(
            select(PsychologistProfile)
            .options(selectinload(PsychologistProfile.current_level))
            .where(PsychologistProfile.user_id == user_id)
        )
        profile = profile_res.scalar_one_or_none()
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )

        # Ensure metrics and initial tier are synchronized
        profile, _ = await self.recalculate_and_evaluate(profile.id, commit=True)

        levels_res = await self.db.execute(
            select(PsychologistLevel)
            .where(PsychologistLevel.is_active.is_(True))
            .order_by(PsychologistLevel.level_tier.asc())
        )
        active_levels = list(levels_res.scalars().all())
        current = profile.current_level if (profile.current_level and profile.current_level.is_active) else (
            active_levels[0] if active_levels else None
        )

        next_level: PsychologistLevel | None = None
        if current and active_levels:
            for lvl in active_levels:
                if lvl.level_tier > current.level_tier:
                    next_level = lvl
                    break

        pricing = await self.resolve_counselor_pricing(profile.id)

        progress = None
        if next_level:
            progress = LevelProgressRequirementResponse(
                completed_sessions=profile.total_completed_sessions,
                min_completed_sessions=next_level.min_completed_sessions,
                consultation_hours=float(profile.total_consultation_hours),
                min_consultation_hours=float(next_level.min_consultation_hours),
                average_rating=float(profile.average_rating),
                min_average_rating=float(next_level.min_average_rating),
                review_count=profile.rating_count,
                min_review_count=next_level.min_review_count,
            )

        return CounselorLevelMetricsResponse(
            counselor_id=str(profile.id),
            total_completed_sessions=profile.total_completed_sessions,
            total_consultation_hours=float(profile.total_consultation_hours),
            average_rating=float(profile.average_rating),
            rating_count=profile.rating_count,
            effective_session_price=float(pricing.price_per_session),
            platform_fee_percentage=float(pricing.platform_fee_percentage),
            counselor_share_percentage=float(pricing.counselor_share_percentage),
            custom_price_per_session=(
                float(profile.custom_price_per_session)
                if profile.custom_price_per_session is not None
                else None
            ),
            current_level=self.to_level_response(current) if current else None,
            next_level=self.to_level_response(next_level) if next_level else None,
            next_level_progress=progress,
            all_levels=[self.to_level_response(lvl) for lvl in active_levels],
        )

    async def update_counselor_pricing(
        self,
        user_id: uuid.UUID,
        payload: UpdateCounselorCustomPricingRequest,
    ) -> CounselorPricingResponse:
        profile_res = await self.db.execute(
            select(PsychologistProfile)
            .options(selectinload(PsychologistProfile.current_level))
            .where(PsychologistProfile.user_id == user_id)
        )
        profile = profile_res.scalar_one_or_none()
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )

        profile, _ = await self.recalculate_and_evaluate(profile.id, commit=False)
        level = profile.current_level
        if not level or not level.is_active:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Level psikolog aktif belum tersedia.",
            )

        if payload.custom_price_per_session is None:
            profile.custom_price_per_session = None
        else:
            if not level.allow_custom_price:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Tier {level.name} belum mengizinkan penetapan tarif mandiri.",
                )
            proposed = Decimal(str(round(payload.custom_price_per_session, 2)))
            if level.min_custom_price is not None and proposed < level.min_custom_price:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=(
                        f"Tarif kustom minimal untuk tier {level.name} adalah "
                        f"{float(level.min_custom_price):.0f} Koin."
                    ),
                )
            if level.max_custom_price is not None and proposed > level.max_custom_price:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=(
                        f"Tarif kustom maksimal untuk tier {level.name} adalah "
                        f"{float(level.max_custom_price):.0f} Koin."
                    ),
                )
            profile.custom_price_per_session = proposed

        await self.db.commit()
        await self.db.refresh(profile)
        resolved = await self.resolve_counselor_pricing(profile.id)

        return CounselorPricingResponse(
            counselor_id=str(profile.id),
            current_level_id=str(level.id),
            current_level_name=level.name,
            default_session_price=float(level.default_session_price),
            custom_price_per_session=(
                float(profile.custom_price_per_session)
                if profile.custom_price_per_session is not None
                else None
            ),
            effective_session_price=float(resolved.price_per_session),
            allow_custom_price=level.allow_custom_price,
            min_custom_price=float(level.min_custom_price) if level.min_custom_price is not None else None,
            max_custom_price=float(level.max_custom_price) if level.max_custom_price is not None else None,
            platform_fee_percentage=float(resolved.platform_fee_percentage),
            counselor_share_percentage=float(resolved.counselor_share_percentage),
            message="Tarif sesi mandiri berhasil diperbarui.",
        )

    async def submit_session_review(
        self,
        session_id: uuid.UUID,
        patient_id: uuid.UUID,
        payload: CreateSessionReviewRequest,
    ) -> CounselorReviewResponse:
        session_res = await self.db.execute(
            select(ConsultationSession).where(ConsultationSession.id == session_id)
        )
        session = session_res.scalar_one_or_none()
        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sesi konsultasi tidak ditemukan.",
            )
        if session.patient_id != patient_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Hanya pasien pemilik sesi ini yang dapat memberikan ulasan.",
            )
        if session.status != ConsultationSessionStatus.COMPLETED.value:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Ulasan hanya dapat dikirim setelah sesi konsultasi berstatus selesai.",
            )

        existing_review = await self.db.scalar(
            select(CounselorReview).where(CounselorReview.session_id == session_id)
        )
        if existing_review:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Sesi konsultasi ini sudah memiliki ulasan.",
            )

        rating_decimal = Decimal(str(round(payload.rating, 2)))
        review = CounselorReview(
            session_id=session.id,
            counselor_id=session.counselor_id,
            patient_id=patient_id,
            rating=rating_decimal,
            highlight_label=payload.highlight_label.strip() if payload.highlight_label else None,
            review_text=payload.review_text.strip() if payload.review_text else None,
            is_anonymous=payload.is_anonymous,
        )
        session.patient_rating = rating_decimal
        self.db.add(review)
        await self.db.flush()

        # Recompute counselor metrics and re-evaluate tier automatically
        await self.recalculate_and_evaluate(session.counselor_id, commit=False)
        await self.db.commit()
        await self.db.refresh(review)

        patient = await self.db.scalar(select(User).where(User.id == patient_id))
        display_name = (
            "Pasien Anonim"
            if review.is_anonymous
            else (patient.display_name if patient and patient.display_name else "Pasien EVA")
        )
        return CounselorReviewResponse(
            id=str(review.id),
            session_id=str(review.session_id),
            counselor_id=str(review.counselor_id),
            patient_id=str(review.patient_id),
            patient_display_name=display_name,
            rating=float(review.rating),
            highlight_label=review.highlight_label,
            review_text=review.review_text,
            is_anonymous=review.is_anonymous,
            created_at=review.created_at,
        )

    async def list_counselor_reviews_by_user(
        self,
        user_id: uuid.UUID,
        limit: int = 30,
        offset: int = 0,
    ) -> list[CounselorReviewResponse]:
        profile = await self.db.scalar(
            select(PsychologistProfile).where(PsychologistProfile.user_id == user_id)
        )
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan.",
            )
        return await self.list_counselor_reviews(profile.id, limit=limit, offset=offset)

    async def list_counselor_reviews(
        self,
        counselor_id: uuid.UUID,
        limit: int = 30,
        offset: int = 0,
    ) -> list[CounselorReviewResponse]:
        res = await self.db.execute(
            select(CounselorReview)
            .options(selectinload(CounselorReview.patient))
            .where(CounselorReview.counselor_id == counselor_id)
            .order_by(CounselorReview.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        rows = res.scalars().all()
        items: list[CounselorReviewResponse] = []
        for rev in rows:
            display_name = (
                "Pasien Anonim"
                if rev.is_anonymous
                else (
                    rev.patient.display_name
                    if rev.patient and rev.patient.display_name
                    else "Pasien EVA"
                )
            )
            items.append(
                CounselorReviewResponse(
                    id=str(rev.id),
                    session_id=str(rev.session_id),
                    counselor_id=str(rev.counselor_id),
                    patient_id=str(rev.patient_id),
                    patient_display_name=display_name,
                    rating=float(rev.rating),
                    highlight_label=rev.highlight_label,
                    review_text=rev.review_text,
                    is_anonymous=rev.is_anonymous,
                    created_at=rev.created_at,
                )
            )
        return items
