from datetime import UTC, datetime, timedelta
from decimal import Decimal
import uuid

from fastapi import FastAPI
import httpx
import pytest
from sqlalchemy import delete

from app.api.dependencies import get_admin_finance_service, get_payout_gateway
from app.api.routes.admin_finance import router as admin_finance_router
from app.core.crypto import encrypt_bank_account
from app.core.security import create_access_token
from app.db.session import AsyncSessionLocal, engine
from app.models.coin import CoinPackage, CoinTransaction
from app.models.counselor import ConsultationSession, PsychologistProfile
from app.models.enums import (
    BankVerificationStatus,
    CoinTransactionType,
    ConsultationSessionStatus,
    PayoutStatus,
    PsychologistVerificationStatus,
    ReconciliationStatus,
    TopupOrderStatus,
)
from app.models.payment import (
    CoinTopupOrder,
    CounselorBankAccount,
    CounselorWithdrawal,
    CounselorWithdrawalEvent,
    PaymentWebhookInbox,
    PayoutQuote,
)
from app.models.user import User
from app.services.admin_finance import AdminFinanceService, ReconciliationService
from app.services.payment import MockPaymentGatewayAdapter
from app.services.payout import MockPayoutGatewayAdapter
from shared.config import settings


@pytest.fixture(autouse=True)
async def dispose_engine():
    await engine.dispose()
    yield
    await engine.dispose()


def _admin_app(gateway: MockPayoutGatewayAdapter) -> FastAPI:
    app = FastAPI()
    app.include_router(admin_finance_router, prefix="/api/v1")

    async def override_admin_finance_service():
        async with AsyncSessionLocal() as db:
            yield AdminFinanceService(db, payout_gateway=gateway)

    app.dependency_overrides[get_payout_gateway] = lambda: gateway
    app.dependency_overrides[get_admin_finance_service] = override_admin_finance_service
    return app


@pytest.mark.asyncio
async def test_c5_admin_finance_rbac_kpi_separation_sanitization_and_reconciliation(monkeypatch):
    monkeypatch.setattr(settings, "BANK_ACCOUNT_ENCRYPTION_KEY", "test-bank-encryption-secret-key-2026")
    suffix = uuid.uuid4().hex[:8]
    admin_id = uuid.uuid4()
    non_admin_id = uuid.uuid4()
    counselor_id = uuid.uuid4()
    pkg_id = uuid.uuid4()
    topup_paid_id = uuid.uuid4()
    topup_pending_id = uuid.uuid4()
    grant_tx_id = uuid.uuid4()
    bank_id = uuid.uuid4()
    quote_id = uuid.uuid4()
    withdrawal_id = uuid.uuid4()
    session_id = uuid.uuid4()

    now = datetime.now(UTC)

    async with AsyncSessionLocal() as db:
        admin_user = User(
            id=admin_id,
            email=f"admin-fin-{suffix}@eva.id",
            password_hash="x",
            display_name="Admin EVA",
            is_active=True,
            is_admin=True,
            coin_balance=0,
        )
        regular_user = User(
            id=non_admin_id,
            email=f"patient-fin-{suffix}@eva.id",
            password_hash="x",
            display_name="Pasien Reguler",
            is_active=True,
            is_admin=False,
            coin_balance=10,
        )
        counselor = PsychologistProfile(
            id=counselor_id,
            user_id=admin_id,
            full_name="Dr. Citra Dewi",
            str_number=f"STR-ADM-{suffix}",
            verification_status=PsychologistVerificationStatus.VERIFIED.value,
            wallet_balance=Decimal("100000"),
            locked_withdrawal_balance=Decimal("0"),
        )
        pkg = CoinPackage(
            id=pkg_id,
            code=f"PKG-{suffix}",
            name="Paket Audit",
            coins=50,
            bonus_coins=5,
            price_idr=50000,
            is_active=True,
        )
        paid_order = CoinTopupOrder(
            id=topup_paid_id,
            order_id=f"EVA-TOPUP-PAID-{suffix}",
            user_id=non_admin_id,
            package_id=pkg_id,
            package_code=pkg.code,
            package_name=pkg.name,
            coins_snapshot=50,
            bonus_coins_snapshot=5,
            total_coins_snapshot=55,
            amount_idr=50000,
            currency="IDR",
            payment_method="qris",
            idempotency_key=f"idem-paid-{suffix}",
            request_hash="a" * 64,
            status=TopupOrderStatus.PAID.value,
            provider_transaction_id=f"mtx-{suffix}",
            paid_at=now,
            reconciliation_status=ReconciliationStatus.MATCHED.value,
        )
        pending_order = CoinTopupOrder(
            id=topup_pending_id,
            order_id=f"EVA-TOPUP-PEND-{suffix}",
            user_id=non_admin_id,
            package_id=pkg_id,
            package_code=pkg.code,
            package_name=pkg.name,
            coins_snapshot=50,
            bonus_coins_snapshot=0,
            total_coins_snapshot=50,
            amount_idr=25000,
            currency="IDR",
            payment_method="qris",
            idempotency_key=f"idem-pend-{suffix}",
            request_hash="b" * 64,
            status=TopupOrderStatus.PENDING.value,
            reconciliation_status=ReconciliationStatus.PENDING.value,
        )
        admin_grant_tx = CoinTransaction(
            id=grant_tx_id,
            user_id=non_admin_id,
            transaction_type=CoinTransactionType.GRANT_ADMIN.value,
            coins_delta=100,
            balance_after=110,
            amount_idr=0,
            payment_method="admin_grant",
            package_name="Admin Free Grant",
            invoice_code=f"EVA-GRANT-{suffix}",
            admin_notes="Admin free grant audit test",
        )
        bank = CounselorBankAccount(
            id=bank_id,
            counselor_id=counselor_id,
            bank_code="bca",
            bank_name="Bank Central Asia (BCA)",
            account_number_encrypted=encrypt_bank_account("9988776655"),
            account_number_masked="****6655",
            account_holder_name="CITRA DEWI",
            verification_status=BankVerificationStatus.VERIFIED.value,
            verified_at=now,
            account_revision=1,
            is_active=True,
        )
        quote = PayoutQuote(
            id=quote_id,
            counselor_id=counselor_id,
            bank_account_id=bank_id,
            account_revision=1,
            amount_idr=80000,
            fee_idr=5000,
            fee_bearer="counselor",
            net_amount_idr=75000,
            wallet_debit_idr=80000,
            expires_at=now + timedelta(minutes=5),
            used_at=now,
        )
        withdrawal = CounselorWithdrawal(
            id=withdrawal_id,
            reference_id=f"EVA-PO-{suffix}",
            counselor_id=counselor_id,
            bank_account_id=bank_id,
            quote_id=quote_id,
            account_revision=1,
            idempotency_key=f"idem-po-{suffix}",
            request_hash="c" * 64,
            amount_idr=80000,
            fee_idr=5000,
            fee_bearer="counselor",
            net_amount_idr=75000,
            wallet_debit_idr=80000,
            status=PayoutStatus.COMPLETED.value,
            provider_reference=f"iris-audit-{suffix}",
            reconciliation_status=ReconciliationStatus.MATCHED.value,
            bank_snapshot_json={"bank_code": "bca", "account_number_masked": "****6655"},
            completed_at=now,
        )
        w_event = CounselorWithdrawalEvent(
            withdrawal_id=withdrawal_id,
            status=PayoutStatus.COMPLETED.value,
            source="iris_webhook",
            message="Selesai ditransfer.",
            occurred_at=now,
        )
        session = ConsultationSession(
            id=session_id,
            session_code=f"EVA-SES-AUD-{suffix}",
            patient_id=non_admin_id,
            counselor_id=counselor_id,
            scheduled_start_time=now - timedelta(hours=1),
            scheduled_end_time=now,
            duration_minutes=60,
            status=ConsultationSessionStatus.COMPLETED.value,
            total_price=Decimal("100000"),
            counselor_earning=Decimal("70000"),
            platform_fee=Decimal("30000"),
        )
        db.add_all(
            [
                admin_user,
                regular_user,
                counselor,
                pkg,
                paid_order,
                pending_order,
                admin_grant_tx,
                bank,
                quote,
                withdrawal,
                w_event,
                session,
            ]
        )
        await db.commit()

    gateway = MockPayoutGatewayAdapter()
    gateway.aggregator_balance_idr = None  # Simulate unknown provider balance
    app = _admin_app(gateway)
    admin_token = create_access_token(str(admin_id), f"admin-fin-{suffix}@eva.id", "Admin EVA")
    user_token = create_access_token(str(non_admin_id), f"patient-fin-{suffix}@eva.id", "Pasien")

    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app),
            base_url="http://testserver",
        ) as client:
            # 1. Non-admin strictly rejected with 403
            forbidden = await client.get(
                "/api/v1/admin/finance/summary",
                headers={"Authorization": f"Bearer {user_token}"},
            )
            assert forbidden.status_code == 403

            # 2. Admin summary separates real IDR inflows from admin grants & returns null when provider balance unknown
            sum_resp = await client.get(
                "/api/v1/admin/finance/summary",
                headers={"Authorization": f"Bearer {admin_token}"},
            )
            assert sum_resp.status_code == 200
            body = sum_resp.json()
            assert "from" in body and "to" in body
            assert body["money_in_paid_idr"] >= 50000
            assert body["money_in_pending_idr"] >= 25000
            assert body["money_out_completed_idr"] >= 75000
            assert body["provider_fees_known_idr"] >= 5000
            assert body["commission_earned_idr"] >= 30000
            assert body["provider_payout_available_idr"] is None
            assert body["provider_balance_as_of"] is None

            # Verify admin_grant never polluted money_in_paid_idr (grant was 100 coins, paid topup was 50,000 IDR)
            # Filter transactions by direction=in -> must NOT include admin_grant
            in_tx = await client.get(
                "/api/v1/admin/finance/transactions?direction=in",
                headers={"Authorization": f"Bearer {admin_token}"},
            )
            assert in_tx.status_code == 200
            in_sources = {item["source"] for item in in_tx.json()["items"]}
            assert "admin_grant" not in in_sources

            # Filter transactions by source=counselor_payout -> bank number masked & never exposes full 9988776655
            out_tx = await client.get(
                f"/api/v1/admin/finance/transactions?source=counselor_payout&q={suffix}",
                headers={"Authorization": f"Bearer {admin_token}"},
            )
            assert out_tx.status_code == 200
            assert out_tx.json()["total"] == 1
            out_item = out_tx.json()["items"][0]
            assert out_item["bank_account_masked"] == "****6655"
            assert "9988776655" not in out_tx.text

            # Detail endpoint returns sanitized timeline events
            det_resp = await client.get(
                f"/api/v1/admin/finance/transactions/{withdrawal_id}",
                headers={"Authorization": f"Bearer {admin_token}"},
            )
            assert det_resp.status_code == 200
            assert len(det_resp.json()["events"]) == 1
            assert det_resp.json()["bank_account_masked"] == "****6655"

        # 3. Daily reconciliation marks mismatch if remote shows settled while local still pending
        pay_mock = MockPaymentGatewayAdapter()
        await pay_mock.create_qris_charge(
            order_id=f"EVA-TOPUP-PEND-{suffix}",
            amount_idr=25000,
            item_id=str(pkg_id),
            item_name="Paket Audit",
            customer_name="Pasien",
            customer_email=f"patient-fin-{suffix}@eva.id",
        )
        pay_mock.orders[f"EVA-TOPUP-PEND-{suffix}"].transaction_status = "settlement"

        async with AsyncSessionLocal() as db:
            rec_service = ReconciliationService(db, payment_gateway=pay_mock, payout_gateway=gateway)
            report = await rec_service.run_daily_reconciliation(lookback_hours=48)
            assert report.mismatched_topups >= 1
    finally:
        async with AsyncSessionLocal() as db:
            await db.execute(delete(ConsultationSession).where(ConsultationSession.id == session_id))
            await db.execute(delete(CounselorWithdrawalEvent).where(CounselorWithdrawalEvent.withdrawal_id == withdrawal_id))
            await db.execute(delete(CounselorWithdrawal).where(CounselorWithdrawal.id == withdrawal_id))
            await db.execute(delete(PayoutQuote).where(PayoutQuote.id == quote_id))
            await db.execute(delete(CounselorBankAccount).where(CounselorBankAccount.id == bank_id))
            await db.execute(delete(CoinTransaction).where(CoinTransaction.id == grant_tx_id))
            await db.execute(delete(CoinTopupOrder).where(CoinTopupOrder.id.in_([topup_paid_id, topup_pending_id])))
            await db.execute(delete(CoinPackage).where(CoinPackage.id == pkg_id))
            await db.execute(delete(PsychologistProfile).where(PsychologistProfile.id == counselor_id))
            await db.execute(delete(User).where(User.id.in_([admin_id, non_admin_id])))
            await db.commit()
