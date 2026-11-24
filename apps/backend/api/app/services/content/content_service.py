from datetime import UTC, datetime
import uuid

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import CrisisConfig, FaqEntry
from app.schemas.content import (
    CreateFaqRequest,
    CrisisConfigResponse,
    FaqDeleteResponse,
    FaqEntryResponse,
    UpdateCrisisConfigRequest,
    UpdateFaqRequest,
)


class ContentService:
    """Domain service managing SafetyNet crisis thresholds and Landing Page FAQ CMS entries."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_crisis_config(self) -> CrisisConfigResponse:
        """Retrieve active SafetyNet crisis configuration with safe clinical defaults."""
        res = await self.db.execute(
            select(CrisisConfig).order_by(CrisisConfig.updated_at.desc()).limit(1)
        )
        config = res.scalar_one_or_none()
        if not config:
            return CrisisConfigResponse(
                hotline_number="119 EXT 8",
                hotline_label="Layanan Darurat Kemenkes RI",
                extreme_depression_threshold=28,
                extreme_anxiety_threshold=20,
                auto_safety_net_modal=True,
                allow_direct_independent_referral=True,
                updated_at=datetime.now(UTC),
            )
        return self._to_crisis_response(config)

    async def update_crisis_config(
        self,
        payload: UpdateCrisisConfigRequest,
    ) -> CrisisConfigResponse:
        """Update or initialize global SafetyNet crisis protocol and DASS-21 thresholds."""
        res = await self.db.execute(
            select(CrisisConfig).order_by(CrisisConfig.updated_at.desc()).limit(1)
        )
        config = res.scalar_one_or_none()
        if not config:
            config = CrisisConfig(
                hotline_number=payload.hotline_number,
                hotline_label=payload.hotline_label,
                extreme_depression_threshold=payload.extreme_depression_threshold,
                extreme_anxiety_threshold=payload.extreme_anxiety_threshold,
                auto_safety_net_modal=payload.auto_safety_net_modal,
                allow_direct_independent_referral=payload.allow_direct_independent_referral,
            )
            self.db.add(config)
        else:
            config.hotline_number = payload.hotline_number
            config.hotline_label = payload.hotline_label
            config.extreme_depression_threshold = payload.extreme_depression_threshold
            config.extreme_anxiety_threshold = payload.extreme_anxiety_threshold
            config.auto_safety_net_modal = payload.auto_safety_net_modal
            config.allow_direct_independent_referral = payload.allow_direct_independent_referral

        await self.db.commit()
        await self.db.refresh(config)
        return self._to_crisis_response(config)

    async def list_faqs(self, *, published_only: bool = False) -> list[FaqEntryResponse]:
        """List website FAQ entries ordered by sort_order ascending then created_at ascending."""
        query = select(FaqEntry).order_by(FaqEntry.sort_order.asc(), FaqEntry.created_at.asc())
        if published_only:
            query = query.where(FaqEntry.is_published.is_(True))
        res = await self.db.execute(query)
        rows = res.scalars().all()
        return [self._to_faq_response(row) for row in rows]

    async def create_faq(self, payload: CreateFaqRequest) -> FaqEntryResponse:
        """Create a new FAQ entry with optional explicit sort_order or auto-increment."""
        sort_order = payload.sort_order
        if sort_order is None:
            max_order = await self.db.scalar(select(func.coalesce(func.max(FaqEntry.sort_order), 0)))
            sort_order = int(max_order or 0) + 1

        entry = FaqEntry(
            category=payload.category,
            question=payload.question,
            answer=payload.answer,
            is_published=payload.is_published,
            sort_order=sort_order,
        )
        self.db.add(entry)
        await self.db.commit()
        await self.db.refresh(entry)
        return self._to_faq_response(entry)

    async def update_faq(self, faq_id: uuid.UUID, payload: UpdateFaqRequest) -> FaqEntryResponse:
        """Update an existing FAQ entry's content, ordering, or publish state."""
        entry = await self._get_faq_or_404(faq_id)
        entry.category = payload.category
        entry.question = payload.question
        entry.answer = payload.answer
        if payload.sort_order is not None:
            entry.sort_order = payload.sort_order
        if payload.is_published is not None:
            entry.is_published = payload.is_published

        await self.db.commit()
        await self.db.refresh(entry)
        return self._to_faq_response(entry)

    async def toggle_faq_published(self, faq_id: uuid.UUID) -> FaqEntryResponse:
        """Toggle visibility of an FAQ entry on the public Landing Page."""
        entry = await self._get_faq_or_404(faq_id)
        entry.is_published = not entry.is_published
        await self.db.commit()
        await self.db.refresh(entry)
        return self._to_faq_response(entry)

    async def delete_faq(self, faq_id: uuid.UUID) -> FaqDeleteResponse:
        """Delete an FAQ entry permanently from PostgreSQL."""
        entry = await self._get_faq_or_404(faq_id)
        question_label = entry.question
        await self.db.delete(entry)
        await self.db.commit()
        return FaqDeleteResponse(
            message=f'Pertanyaan FAQ "{question_label}" berhasil dihapus.',
            deleted_id=str(faq_id),
        )

    async def _get_faq_or_404(self, faq_id: uuid.UUID) -> FaqEntry:
        res = await self.db.execute(select(FaqEntry).where(FaqEntry.id == faq_id))
        entry = res.scalar_one_or_none()
        if not entry:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Entri FAQ tidak ditemukan.",
            )
        return entry

    @staticmethod
    def _to_crisis_response(config: CrisisConfig) -> CrisisConfigResponse:
        return CrisisConfigResponse(
            hotline_number=config.hotline_number,
            hotline_label=config.hotline_label,
            extreme_depression_threshold=config.extreme_depression_threshold,
            extreme_anxiety_threshold=config.extreme_anxiety_threshold,
            auto_safety_net_modal=config.auto_safety_net_modal,
            allow_direct_independent_referral=config.allow_direct_independent_referral,
            updated_at=config.updated_at,
        )

    @staticmethod
    def _to_faq_response(entry: FaqEntry) -> FaqEntryResponse:
        return FaqEntryResponse(
            id=str(entry.id),
            category=entry.category,
            question=entry.question,
            answer=entry.answer,
            is_published=entry.is_published,
            sort_order=entry.sort_order,
            created_at=entry.created_at,
            updated_at=entry.updated_at,
        )
