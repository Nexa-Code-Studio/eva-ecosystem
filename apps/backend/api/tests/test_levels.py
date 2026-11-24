from datetime import UTC, datetime
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock
import unittest
import uuid

from fastapi import HTTPException
from pydantic import ValidationError

from app.models.counselor import ConsultationSession, PlatformPricingConfig, PsychologistProfile
from app.models.enums import ConsultationSessionStatus, PsychologistVerificationStatus
from app.models.level import CounselorReview, PsychologistLevel
from app.models.user import User
from app.schemas.level import (
    CreateSessionReviewRequest,
    UpdateCounselorCustomPricingRequest,
    UpsertPsychologistLevelRequest,
)
from app.services.level import LevelService


def _result(scalar=None, scalars_list=None, one_tuple=None):
    res = MagicMock()
    res.scalar_one_or_none.return_value = scalar
    res.scalars.return_value.all.return_value = scalars_list if scalars_list is not None else []
    if one_tuple is not None:
        res.one.return_value = one_tuple
    return res


def _make_level(
    *,
    tier: int,
    name: str,
    min_sessions: int = 0,
    min_rating: str = "0.00",
    min_hours: str = "0.00",
    min_reviews: int = 0,
    price: str = "150.00",
    fee_pct: str = "20.00",
    allow_custom: bool = False,
    min_custom: str | None = None,
    max_custom: str | None = None,
    is_active: bool = True,
) -> PsychologistLevel:
    now = datetime.now(UTC)
    return PsychologistLevel(
        id=uuid.uuid4(),
        level_tier=tier,
        name=name,
        badge_icon="award",
        min_completed_sessions=min_sessions,
        min_average_rating=Decimal(min_rating),
        min_consultation_hours=Decimal(min_hours),
        min_review_count=min_reviews,
        default_session_price=Decimal(price),
        platform_fee_percentage=Decimal(fee_pct),
        allow_custom_price=allow_custom,
        min_custom_price=Decimal(min_custom) if min_custom is not None else None,
        max_custom_price=Decimal(max_custom) if max_custom is not None else None,
        is_active=is_active,
        created_at=now,
        updated_at=now,
    )


class TestPsychologistLevelsBackend(unittest.IsolatedAsyncioTestCase):
    def test_upsert_request_validates_custom_price_bounds(self):
        with self.assertRaises(ValidationError):
            UpsertPsychologistLevelRequest(
                level_tier=3,
                name="Senior Specialist",
                default_session_price=200,
                platform_fee_percentage=15,
                allow_custom_price=True,
                min_custom_price=250,
                max_custom_price=300,
            )

    async def test_recalculate_and_evaluate_promotes_dynamically_and_obeys_ratchet(self):
        lvl1 = _make_level(tier=1, name="Junior", price="120.00", fee_pct="25.00")
        lvl2 = _make_level(
            tier=2,
            name="Registered",
            min_sessions=5,
            min_rating="4.20",
            min_hours="2.50",
            min_reviews=3,
            price="150.00",
            fee_pct="20.00",
        )
        lvl3 = _make_level(
            tier=3,
            name="Senior",
            min_sessions=20,
            min_rating="4.70",
            min_hours="10.00",
            min_reviews=10,
            price="220.00",
            fee_pct="15.00",
            allow_custom=True,
            min_custom="180.00",
            max_custom="280.00",
        )

        profile = PsychologistProfile(
            id=uuid.uuid4(),
            user_id=uuid.uuid4(),
            full_name="dr. Nadya",
            str_number="STR-123",
            verification_status=PsychologistVerificationStatus.VERIFIED.value,
            current_level_id=lvl1.id,
        )
        profile.current_level = lvl1

        db = MagicMock()
        db.execute = AsyncMock(
            side_effect=[
                _result(scalar=profile),
                _result(one_tuple=(6, 210)),  # 6 sessions, 210 min => 3.50 hours
                _result(one_tuple=(4, Decimal("4.75"))),
                _result(scalars_list=[lvl1, lvl2, lvl3]),
            ]
        )
        db.commit = AsyncMock()
        db.refresh = AsyncMock()

        updated_profile, upgraded = await LevelService(db).recalculate_and_evaluate(profile.id)

        self.assertTrue(upgraded)
        self.assertEqual(updated_profile.current_level_id, lvl2.id)
        self.assertEqual(updated_profile.total_completed_sessions, 6)
        self.assertEqual(updated_profile.total_consultation_hours, Decimal("3.50"))
        self.assertEqual(updated_profile.average_rating, Decimal("4.75"))
        self.assertEqual(updated_profile.rating_count, 4)

        # Ratchet check: admin raises lvl2 requirement to 50 sessions -> counselor keeps lvl2
        lvl2.min_completed_sessions = 50
        db.execute = AsyncMock(
            side_effect=[
                _result(scalar=updated_profile),
                _result(one_tuple=(6, 210)),
                _result(one_tuple=(4, Decimal("4.75"))),
                _result(scalars_list=[lvl1, lvl2, lvl3]),
            ]
        )
        kept_profile, upgraded_again = await LevelService(db).recalculate_and_evaluate(profile.id)
        self.assertFalse(upgraded_again)
        self.assertEqual(kept_profile.current_level_id, lvl2.id)

    async def test_submit_session_review_enforces_uniqueness_and_allows_repeat_patient(self):
        patient_id = uuid.uuid4()
        counselor_id = uuid.uuid4()
        s1_id = uuid.uuid4()
        s2_id = uuid.uuid4()
        s1 = ConsultationSession(
            id=s1_id,
            session_code="EVA-SES-01",
            patient_id=patient_id,
            counselor_id=counselor_id,
            scheduled_start_time=datetime.now(UTC),
            scheduled_end_time=datetime.now(UTC),
            duration_minutes=30,
            status=ConsultationSessionStatus.COMPLETED.value,
        )
        s2 = ConsultationSession(
            id=s2_id,
            session_code="EVA-SES-02",
            patient_id=patient_id,
            counselor_id=counselor_id,
            scheduled_start_time=datetime.now(UTC),
            scheduled_end_time=datetime.now(UTC),
            duration_minutes=30,
            status=ConsultationSessionStatus.COMPLETED.value,
        )
        patient = User(
            id=patient_id,
            email="patient@eva.id",
            password_hash="x",
            display_name="Rani Pratama",
        )
        profile = PsychologistProfile(
            id=counselor_id,
            user_id=uuid.uuid4(),
            full_name="dr. Nadya",
            str_number="STR-123",
            verification_status=PsychologistVerificationStatus.VERIFIED.value,
        )
        profile.current_level = None

        # 1. Submitting duplicate review on s1 returns 409
        db_dup = MagicMock()
        db_dup.execute = AsyncMock(return_value=_result(scalar=s1))
        db_dup.scalar = AsyncMock(return_value=CounselorReview(id=uuid.uuid4()))

        with self.assertRaises(HTTPException) as ctx:
            await LevelService(db_dup).submit_session_review(
                s1_id,
                patient_id,
                CreateSessionReviewRequest(rating=5.0),
            )
        self.assertEqual(ctx.exception.status_code, 409)

        # 2. Same patient submitting review on s2 succeeds and masks anonymous name
        db_ok = MagicMock()
        db_ok.execute = AsyncMock(
            side_effect=[
                _result(scalar=s2),
                _result(scalar=profile),
                _result(one_tuple=(2, 60)),
                _result(one_tuple=(2, Decimal("4.90"))),
                _result(scalars_list=[]),
            ]
        )
        db_ok.scalar = AsyncMock(side_effect=[None, patient])
        db_ok.add = MagicMock()
        db_ok.flush = AsyncMock()
        db_ok.commit = AsyncMock()

        async def _refresh(obj):
            if getattr(obj, "id", None) is None:
                obj.id = uuid.uuid4()
            if getattr(obj, "created_at", None) is None:
                obj.created_at = datetime.now(UTC)

        db_ok.refresh = AsyncMock(side_effect=_refresh)

        resp = await LevelService(db_ok).submit_session_review(
            s2_id,
            patient_id,
            CreateSessionReviewRequest(
                rating=4.9,
                highlight_label="Empatik",
                review_text="Sesi kedua sangat membantu.",
                is_anonymous=True,
            ),
        )
        self.assertEqual(resp.session_id, str(s2_id))
        self.assertEqual(resp.patient_display_name, "Pasien Anonim")
        self.assertEqual(s2.patient_rating, Decimal("4.9"))

    async def test_update_counselor_pricing_enforces_level_bounds_and_resolves_booking_price(self):
        lvl3 = _make_level(
            tier=3,
            name="Senior Specialist",
            price="200.00",
            fee_pct="15.00",
            allow_custom=True,
            min_custom="160.00",
            max_custom="260.00",
        )
        profile = PsychologistProfile(
            id=uuid.uuid4(),
            user_id=uuid.uuid4(),
            full_name="dr. Nadya",
            str_number="STR-123",
            verification_status=PsychologistVerificationStatus.VERIFIED.value,
            current_level_id=lvl3.id,
        )
        profile.current_level = lvl3

        service = LevelService(MagicMock())
        service.recalculate_and_evaluate = AsyncMock(return_value=(profile, False))
        service.db.execute = AsyncMock(return_value=_result(scalar=profile))
        service.db.commit = AsyncMock()
        service.db.refresh = AsyncMock()

        # Out of bounds => 422
        with self.assertRaises(HTTPException) as ctx:
            await service.update_counselor_pricing(
                profile.user_id,
                UpdateCounselorCustomPricingRequest(custom_price_per_session=320.0),
            )
        self.assertEqual(ctx.exception.status_code, 422)

        # Valid inside [160, 260] => succeeds and resolves dynamic fee split
        fallback = PlatformPricingConfig(
            id=uuid.uuid4(),
            price_per_session=Decimal("150.00"),
            counselor_share_percentage=Decimal("80.00"),
            platform_fee_percentage=Decimal("20.00"),
            extension_price_per_session=Decimal("150.00"),
        )
        service.db.execute = AsyncMock(
            side_effect=[
                _result(scalar=profile),
                _result(scalar=profile),
                _result(scalar=fallback),
            ]
        )
        resp = await service.update_counselor_pricing(
            profile.user_id,
            UpdateCounselorCustomPricingRequest(custom_price_per_session=240.0),
        )
        self.assertEqual(resp.effective_session_price, 240.0)
        self.assertEqual(resp.platform_fee_percentage, 15.0)
        self.assertEqual(resp.counselor_share_percentage, 85.0)
