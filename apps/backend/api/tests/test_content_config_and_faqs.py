from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock
import unittest
import uuid

from fastapi import HTTPException
from pydantic import ValidationError

from app.models.content import CrisisConfig, FaqEntry
from app.schemas.content import (
    CreateFaqRequest,
    UpdateCrisisConfigRequest,
    UpdateFaqRequest,
)
from app.services.content import ContentService


def _scalar_result(value):
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    result.scalars.return_value.all.return_value = value if isinstance(value, list) else []
    return result


class TestContentConfigAndFaqs(unittest.IsolatedAsyncioTestCase):
    async def test_get_crisis_config_returns_defaults_when_empty(self):
        db = MagicMock()
        db.execute = AsyncMock(return_value=_scalar_result(None))

        service = ContentService(db)
        res = await service.get_crisis_config()

        self.assertEqual(res.hotline_number, "119 EXT 8")
        self.assertEqual(res.hotline_label, "Layanan Darurat Kemenkes RI")
        self.assertEqual(res.extreme_depression_threshold, 28)
        self.assertEqual(res.extreme_anxiety_threshold, 20)
        self.assertTrue(res.auto_safety_net_modal)
        self.assertTrue(res.allow_direct_independent_referral)

    async def test_update_crisis_config_creates_or_updates_singleton(self):
        now = datetime.now(UTC)
        existing = CrisisConfig(
            id=uuid.uuid4(),
            hotline_number="119 EXT 8",
            hotline_label="Layanan Darurat Kemenkes RI",
            extreme_depression_threshold=28,
            extreme_anxiety_threshold=20,
            auto_safety_net_modal=True,
            allow_direct_independent_referral=True,
            created_at=now,
            updated_at=now,
        )
        db = MagicMock()
        db.execute = AsyncMock(return_value=_scalar_result(existing))
        db.commit = AsyncMock()
        db.refresh = AsyncMock()

        service = ContentService(db)
        res = await service.update_crisis_config(
            UpdateCrisisConfigRequest(
                hotline_number=" 119-eva ",
                hotline_label=" Hotline Nasional EVA ",
                extreme_depression_threshold=26,
                extreme_anxiety_threshold=18,
                auto_safety_net_modal=False,
                allow_direct_independent_referral=True,
            )
        )

        self.assertEqual(res.hotline_number, "119-EVA")
        self.assertEqual(res.hotline_label, "Hotline Nasional EVA")
        self.assertEqual(res.extreme_depression_threshold, 26)
        self.assertEqual(res.extreme_anxiety_threshold, 18)
        self.assertFalse(res.auto_safety_net_modal)
        db.commit.assert_awaited_once()

    def test_crisis_threshold_validation_bounds(self):
        with self.assertRaises(ValidationError):
            UpdateCrisisConfigRequest(
                hotline_number="119",
                hotline_label="Kemenkes",
                extreme_depression_threshold=43,
                extreme_anxiety_threshold=20,
            )

    async def test_create_faq_auto_increments_sort_order(self):
        now = datetime.now(UTC)
        db = MagicMock()
        db.scalar = AsyncMock(return_value=5)
        added = []
        db.add = MagicMock(side_effect=lambda obj: added.append(obj))
        db.commit = AsyncMock()

        async def _refresh(obj):
            if getattr(obj, "id", None) is None:
                obj.id = uuid.uuid4()
            obj.created_at = now
            obj.updated_at = now

        db.refresh = AsyncMock(side_effect=_refresh)

        service = ContentService(db)
        res = await service.create_faq(
            CreateFaqRequest(
                category="keamanan & privasi",
                question="Bagaimana keamanan data pasien EVA?",
                answer="Data dienkripsi end-to-end dengan kendali penuh pengguna.",
            )
        )

        self.assertEqual(len(added), 1)
        self.assertEqual(res.category, "KEAMANAN & PRIVASI")
        self.assertEqual(res.sort_order, 6)
        self.assertTrue(res.is_published)

    async def test_update_toggle_and_delete_faq(self):
        now = datetime.now(UTC)
        faq_id = uuid.uuid4()
        entry = FaqEntry(
            id=faq_id,
            category="PRIVASI",
            question="Pertanyaan awal cukup panjang",
            answer="Jawaban awal cukup panjang.",
            is_published=True,
            sort_order=2,
            created_at=now,
            updated_at=now,
        )

        db = MagicMock()
        db.execute = AsyncMock(return_value=_scalar_result(entry))
        db.commit = AsyncMock()
        db.refresh = AsyncMock()
        db.delete = AsyncMock()

        service = ContentService(db)
        updated = await service.update_faq(
            faq_id,
            UpdateFaqRequest(
                category="klinis",
                question="Pertanyaan setelah diedit lengkap",
                answer="Jawaban setelah diperbarui lengkap.",
                sort_order=1,
            ),
        )
        self.assertEqual(updated.category, "KLINIS")
        self.assertEqual(updated.sort_order, 1)

        toggled = await service.toggle_faq_published(faq_id)
        self.assertFalse(toggled.is_published)

        deleted = await service.delete_faq(faq_id)
        self.assertEqual(deleted.deleted_id, str(faq_id))
        db.delete.assert_awaited_once_with(entry)

    async def test_missing_faq_raises_404(self):
        db = MagicMock()
        db.execute = AsyncMock(return_value=_scalar_result(None))

        service = ContentService(db)
        with self.assertRaises(HTTPException) as ctx:
            await service.toggle_faq_published(uuid.uuid4())
        self.assertEqual(ctx.exception.status_code, 404)
