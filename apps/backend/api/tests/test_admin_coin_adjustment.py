from datetime import UTC, datetime
from decimal import Decimal
import unittest
from unittest.mock import AsyncMock, MagicMock
import uuid

from fastapi import HTTPException

from app.api.routes.admin_coins import router as admin_coins_router
from app.api.routes.admin_counselors import router as admin_counselors_router
from app.models.coin import CoinTransaction
from app.models.counselor import CounselorTransaction, PsychologistProfile
from app.models.enums import (
    CoinTransactionType,
    PsychologistVerificationStatus,
    TransactionStatus,
    TransactionType,
)
from app.models.user import User
from app.schemas.coin import AdminCoinAdjustRequest
from app.schemas.counselor import AdminCounselorCoinAdjustRequest
from app.services.coin import CoinService
from app.services.counselor import CounselorService
from app.services.finances.finance_service import FinanceService


def _scalar_result(value):
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    result.scalars.return_value.first.return_value = value
    result.scalars.return_value.all.return_value = (
        value if isinstance(value, list) else ([value] if value else [])
    )
    return result


class TestAdminCoinAdjustment(unittest.IsolatedAsyncioTestCase):
    async def test_adjust_user_coins_deduct_set_and_guards(self):
        admin_id = uuid.uuid4()
        user_id = uuid.uuid4()
        now = datetime.now(UTC)
        user = User(
            id=user_id,
            email="pasien.adj@eva.id",
            display_name="Raka",
            is_active=True,
            is_admin=False,
            coin_balance=100,
            created_at=now,
        )

        added = []
        db = MagicMock()
        db.execute = AsyncMock(return_value=_scalar_result(user))
        db.add = MagicMock(side_effect=lambda obj: added.append(obj))
        db.commit = AsyncMock()

        async def _refresh(obj):
            if isinstance(obj, CoinTransaction):
                if getattr(obj, "id", None) is None:
                    obj.id = uuid.uuid4()
                if getattr(obj, "created_at", None) is None:
                    obj.created_at = now

        db.refresh = AsyncMock(side_effect=_refresh)
        service = CoinService(db)

        # 1. Valid deduct
        deduct_res = await service.adjust_user_coins(
            admin_id=admin_id,
            target_user_id=user_id,
            payload=AdminCoinAdjustRequest(
                mode="deduct",
                amount=30,
                admin_notes="Koreksi duplikasi top-up",
            ),
        )
        self.assertEqual(deduct_res.user.coin_balance, 70)
        self.assertEqual(deduct_res.transaction.coins_delta, -30)
        self.assertEqual(deduct_res.transaction.balance_after, 70)
        self.assertEqual(deduct_res.transaction.amount_idr, 0)
        self.assertEqual(
            deduct_res.transaction.transaction_type,
            CoinTransactionType.ADMIN_ADJUSTMENT.value,
        )

        # 2. Over-deduct rejected
        with self.assertRaises(HTTPException) as over_ctx:
            await service.adjust_user_coins(
                admin_id=admin_id,
                target_user_id=user_id,
                payload=AdminCoinAdjustRequest(
                    mode="deduct",
                    amount=71,
                    admin_notes="Melebihi saldo",
                ),
            )
        self.assertEqual(over_ctx.exception.status_code, 400)
        self.assertEqual(user.coin_balance, 70)

        # 3. Set balance upward
        set_up_res = await service.adjust_user_coins(
            admin_id=admin_id,
            target_user_id=user_id,
            payload=AdminCoinAdjustRequest(
                mode="set",
                amount=120,
                admin_notes="Set saldo hasil rekonsiliasi",
            ),
        )
        self.assertEqual(set_up_res.user.coin_balance, 120)
        self.assertEqual(set_up_res.transaction.coins_delta, 50)
        self.assertEqual(set_up_res.transaction.balance_after, 120)

        # 4. Set balance downward to zero
        set_zero_res = await service.adjust_user_coins(
            admin_id=admin_id,
            target_user_id=user_id,
            payload=AdminCoinAdjustRequest(
                mode="set",
                amount=0,
                admin_notes="Reset saldo uji coba",
            ),
        )
        self.assertEqual(set_zero_res.user.coin_balance, 0)
        self.assertEqual(set_zero_res.transaction.coins_delta, -120)
        self.assertEqual(set_zero_res.transaction.balance_after, 0)

        # 5. No-op set rejected
        with self.assertRaises(HTTPException) as noop_ctx:
            await service.adjust_user_coins(
                admin_id=admin_id,
                target_user_id=user_id,
                payload=AdminCoinAdjustRequest(
                    mode="set",
                    amount=0,
                    admin_notes="Tidak berubah",
                ),
            )
        self.assertEqual(noop_ctx.exception.status_code, 400)
        self.assertEqual(len(added), 3)

    async def test_adjust_counselor_coins_add_deduct_set_and_guards(self):
        admin_id = uuid.uuid4()
        counselor_id = uuid.uuid4()
        user_id = uuid.uuid4()
        now = datetime.now(UTC)

        user = User(id=user_id, email="psikolog.adj@eva.id", created_at=now)
        profile = PsychologistProfile(
            id=counselor_id,
            user_id=user_id,
            user=user,
            full_name="Dr. Nadia",
            title_degree="M.Psi., Psikolog",
            str_number="STR-999",
            association="HIMPSI",
            specializations=["Klinis"],
            years_of_experience=5,
            verification_status=PsychologistVerificationStatus.VERIFIED.value,
            wallet_balance=Decimal("100.00"),
            created_at=now,
        )

        added = []
        db = MagicMock()
        db.execute = AsyncMock(return_value=_scalar_result(profile))
        db.add = MagicMock(side_effect=lambda obj: added.append(obj))
        db.commit = AsyncMock()

        async def _refresh(obj):
            if isinstance(obj, CounselorTransaction):
                if getattr(obj, "id", None) is None:
                    obj.id = uuid.uuid4()
                if getattr(obj, "created_at", None) is None:
                    obj.created_at = now

        db.refresh = AsyncMock(side_effect=_refresh)
        service = CounselorService(db)

        # 1. Add bonus coins
        add_res = await service.adjust_counselor_coins(
            counselor_id=counselor_id,
            admin_user_id=admin_id,
            payload=AdminCounselorCoinAdjustRequest(
                mode="add",
                amount=50,
                admin_notes="Kompensasi sesi kendala teknis",
            ),
        )
        self.assertEqual(add_res.counselor.wallet_balance, 150.0)
        self.assertEqual(add_res.transaction.amount, 50)
        self.assertEqual(
            add_res.transaction.transaction_type,
            TransactionType.ADMIN_ADJUSTMENT.value,
        )

        # 2. Over-deduct rejected
        with self.assertRaises(HTTPException) as over_ctx:
            await service.adjust_counselor_coins(
                counselor_id=counselor_id,
                admin_user_id=admin_id,
                payload=AdminCounselorCoinAdjustRequest(
                    mode="deduct",
                    amount=200,
                    admin_notes="Potongan terlalu besar",
                ),
            )
        self.assertEqual(over_ctx.exception.status_code, 400)
        self.assertEqual(profile.wallet_balance, Decimal("150.00"))

        # 3. Set balance downward
        set_res = await service.adjust_counselor_coins(
            counselor_id=counselor_id,
            admin_user_id=admin_id,
            payload=AdminCounselorCoinAdjustRequest(
                mode="set",
                amount=80,
                admin_notes="Rekonsiliasi dompet bulanan",
            ),
        )
        self.assertEqual(set_res.counselor.wallet_balance, 80.0)
        self.assertEqual(set_res.transaction.amount, -70)
        self.assertEqual(set_res.transaction.status, TransactionStatus.COMPLETED.value)
        self.assertEqual(len(added), 2)

    async def test_finance_service_maps_admin_adjustment_without_fee_markup(self):
        user_id = uuid.uuid4()
        counselor_id = uuid.uuid4()
        now = datetime.now(UTC)

        profile = PsychologistProfile(
            id=counselor_id,
            user_id=user_id,
            full_name="Dr. Nadia",
            title_degree="M.Psi., Psikolog",
            str_number="STR-999",
            wallet_balance=Decimal("80.00"),
            created_at=now,
        )
        adj_tx = CounselorTransaction(
            id=uuid.uuid4(),
            counselor_id=counselor_id,
            transaction_type=TransactionType.ADMIN_ADJUSTMENT.value,
            status=TransactionStatus.COMPLETED.value,
            amount=Decimal("-70.00"),
            description="[Set Saldo Koin Admin] Rekonsiliasi dompet",
            reference_number="EVA-PADJ-20261128-ABC123",
            created_at=now,
        )

        db = MagicMock()
        db.execute = AsyncMock(
            side_effect=[
                _scalar_result(profile),
                _scalar_result([adj_tx]),
                _scalar_result([]),
            ]
        )
        finance_service = FinanceService(db)
        rows = await finance_service.get_transactions(user_id=user_id)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].patient_name, "Penyesuaian Admin")
        self.assertEqual(rows[0].admin_fee, 0)
        self.assertEqual(rows[0].amount, -70)
        self.assertEqual(rows[0].net_earnings, -70)

    async def test_routes_registered_on_admin_routers(self):
        coin_paths = {route.path for route in admin_coins_router.routes}
        counselor_paths = {route.path for route in admin_counselors_router.routes}
        self.assertIn("/admin/users/{user_id}/coins/adjust", coin_paths)
        self.assertIn("/admin/counselors/{counselor_id}/coins/adjust", counselor_paths)
