import unittest
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock
import uuid

from fastapi import HTTPException

from app.api.dependencies import get_current_admin
from app.models.coin import CoinTransaction
from app.models.counselor import ConsultationSession, PlatformPricingConfig, PsychologistProfile
from app.models.enums import (
    CoinTransactionType,
    ConsultationSessionStatus,
    PricingConfigStatus,
    PsychologistVerificationStatus,
    TransactionStatus,
)
from app.models.user import User
from app.schemas.coin import AdminCoinTopupRequest, UserCoinBalanceResponse
from app.schemas.session import BookSessionRequest
from app.services.coin import CoinService
from app.services.session.scheduling_service import SchedulingService


def _scalar_result(value):
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    result.scalars.return_value.first.return_value = value
    return result


class TestCoinWalletAndTopup(unittest.IsolatedAsyncioTestCase):
    async def test_get_current_admin_rejects_non_admin(self):
        non_admin = User(email="user@eva.id", is_admin=False, coin_balance=10)
        with self.assertRaises(HTTPException) as ctx:
            await get_current_admin(current_user=non_admin)
        self.assertEqual(ctx.exception.status_code, 403)

    async def test_get_current_admin_allows_admin(self):
        admin = User(email="admin@eva.id", is_admin=True, coin_balance=0)
        res = await get_current_admin(current_user=admin)
        self.assertIs(res, admin)

    async def test_get_user_balance_returns_coins(self):
        user_id = uuid.uuid4()
        user = User(id=user_id, email="samsul@gmail.com", coin_balance=185)
        db = MagicMock()
        db.execute = AsyncMock(return_value=_scalar_result(user))

        service = CoinService(db)
        res = await service.get_user_balance(user_id)
        self.assertIsInstance(res, UserCoinBalanceResponse)
        self.assertEqual(res.user_id, str(user_id))
        self.assertEqual(res.coin_balance, 185)

    async def test_topup_user_coins_conventional_paid_and_free_grant(self):
        admin_id = uuid.uuid4()
        user_id = uuid.uuid4()
        now = datetime.now(UTC)
        user = User(
            id=user_id,
            email="pasien@eva.id",
            display_name="Anindya",
            is_active=True,
            is_admin=False,
            coin_balance=10,
            created_at=now,
        )

        db = MagicMock()
        db.execute = AsyncMock(return_value=_scalar_result(user))
        db.add = MagicMock()
        db.commit = AsyncMock()

        async def _refresh(obj):
            if isinstance(obj, CoinTransaction):
                if getattr(obj, "id", None) is None:
                    obj.id = uuid.uuid4()
                if getattr(obj, "created_at", None) is None:
                    obj.created_at = now

        db.refresh = AsyncMock(side_effect=_refresh)

        service = CoinService(db)
        paid_res = await service.topup_user_coins(
            admin_id=admin_id,
            target_user_id=user_id,
            payload=AdminCoinTopupRequest(
                coins_granted=170,
                amount_idr=45000,
                payment_method="Transfer Bank",
                package_name="Paket Favorit (+170 Koin)",
                admin_notes="Transfer BCA dikonfirmasi WA",
            ),
        )

        self.assertEqual(user.coin_balance, 180)
        self.assertEqual(paid_res.user.coin_balance, 180)
        self.assertEqual(paid_res.transaction.transaction_type, CoinTransactionType.TOPUP_ADMIN.value)
        self.assertEqual(paid_res.transaction.amount_idr, 45000)
        self.assertEqual(paid_res.transaction.balance_after, 180)
        self.assertEqual(paid_res.transaction.status, TransactionStatus.COMPLETED.value)

        grant_res = await service.topup_user_coins(
            admin_id=admin_id,
            target_user_id=user_id,
            payload=AdminCoinTopupRequest(
                coins_granted=30,
                amount_idr=99999,
                payment_method="Grant Admin (Gratis)",
                package_name="Grant Admin (+30 Koin)",
            ),
        )
        self.assertEqual(user.coin_balance, 210)
        self.assertEqual(grant_res.transaction.transaction_type, CoinTransactionType.GRANT_ADMIN.value)
        self.assertEqual(grant_res.transaction.amount_idr, 0)

    async def test_book_session_rejects_insufficient_coins(self):
        counselor_id = uuid.uuid4()
        patient_id = uuid.uuid4()
        counselor = PsychologistProfile(
            id=counselor_id,
            user_id=uuid.uuid4(),
            full_name="Dr. Sarah",
            title_degree="M.Psi., Psikolog",
            str_number="STR-123",
            association="HIMPSI",
            specializations=["Kecemasan Dewasa"],
            years_of_experience=5,
            verification_status=PsychologistVerificationStatus.VERIFIED.value,
            is_online=True,
            buffer_time_minutes=10,
        )
        pricing = PlatformPricingConfig(
            id=uuid.uuid4(),
            session_duration_minutes=30,
            price_per_session=Decimal("150.00"),
            counselor_share_percentage=Decimal("80.00"),
            platform_fee_percentage=Decimal("20.00"),
            extension_price_per_session=Decimal("150.00"),
            status=PricingConfigStatus.ACTIVE.value,
        )
        poor_patient = User(id=patient_id, email="poor@eva.id", coin_balance=60)

        db = MagicMock()
        db.execute = AsyncMock(
            side_effect=[
                _scalar_result(counselor),
                _scalar_result(None),
                _scalar_result(poor_patient),
            ]
        )
        service = SchedulingService(db)
        service.pricing_service.get_active_pricing = AsyncMock(return_value=pricing)

        with self.assertRaises(HTTPException) as ctx:
            await service.book_session(
                patient_id=patient_id,
                payload=BookSessionRequest(
                    counselor_id=counselor_id,
                    scheduled_start_time=datetime.now(UTC) + timedelta(days=1),
                    session_count=1,
                ),
            )
        self.assertEqual(ctx.exception.status_code, 400)
        self.assertIn("Saldo koin tidak mencukupi", ctx.exception.detail)
        self.assertEqual(poor_patient.coin_balance, 60)

    async def test_book_session_debits_patient_coins_and_creates_ledger(self):
        counselor_id = uuid.uuid4()
        patient_id = uuid.uuid4()
        counselor = PsychologistProfile(
            id=counselor_id,
            user_id=uuid.uuid4(),
            full_name="Dr. Sarah",
            title_degree="M.Psi., Psikolog",
            str_number="STR-123",
            association="HIMPSI",
            specializations=["Kecemasan Dewasa"],
            years_of_experience=5,
            verification_status=PsychologistVerificationStatus.VERIFIED.value,
            is_online=True,
            buffer_time_minutes=10,
            wallet_balance=Decimal("0.00"),
        )
        pricing = PlatformPricingConfig(
            id=uuid.uuid4(),
            session_duration_minutes=30,
            price_per_session=Decimal("150.00"),
            counselor_share_percentage=Decimal("80.00"),
            platform_fee_percentage=Decimal("20.00"),
            extension_price_per_session=Decimal("150.00"),
            status=PricingConfigStatus.ACTIVE.value,
        )
        patient = User(id=patient_id, email="rich@eva.id", coin_balance=200)

        added_objects = []
        db = MagicMock()
        db.execute = AsyncMock(
            side_effect=[
                _scalar_result(counselor),
                _scalar_result(None),
                _scalar_result(patient),
            ]
        )
        db.add = MagicMock(side_effect=lambda obj: added_objects.append(obj))
        db.flush = AsyncMock()
        db.commit = AsyncMock()

        async def _refresh(obj):
            if isinstance(obj, ConsultationSession):
                if getattr(obj, "id", None) is None:
                    obj.id = uuid.uuid4()
                if getattr(obj, "created_at", None) is None:
                    obj.created_at = datetime.now(UTC)

        db.refresh = AsyncMock(side_effect=_refresh)

        service = SchedulingService(db)
        service.pricing_service.get_active_pricing = AsyncMock(return_value=pricing)

        session_res = await service.book_session(
            patient_id=patient_id,
            payload=BookSessionRequest(
                counselor_id=counselor_id,
                scheduled_start_time=datetime.now(UTC) + timedelta(days=1),
                session_count=1,
            ),
        )

        self.assertEqual(patient.coin_balance, 50)
        self.assertEqual(session_res.status, ConsultationSessionStatus.SCHEDULED.value)
        coin_txs = [o for o in added_objects if isinstance(o, CoinTransaction)]
        self.assertEqual(len(coin_txs), 1)
        self.assertEqual(coin_txs[0].transaction_type, CoinTransactionType.BOOKING_DEBIT.value)
        self.assertEqual(coin_txs[0].coins_delta, -150)
        self.assertEqual(coin_txs[0].balance_after, 50)
