import logging
import uuid
from datetime import UTC, datetime
from decimal import Decimal

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.crypto import mask_account_number
from app.core.payment_errors import raise_contract_error
from app.models.counselor import ConsultationSession, CounselorTransaction, PsychologistProfile
from app.models.enums import TransactionStatus, TransactionType
from app.models.payment import CounselorWithdrawal
from app.schemas.finances.requests import PayoutRequest
from app.schemas.finances.responses import (
    FinancialSummaryResponse,
    PayoutResponse,
    TransactionResponse,
)

logger = logging.getLogger(__name__)


class FinanceService:
    """Domain service managing counselor earnings ledger, revenue splits, and payouts."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_summary(self, user_id: uuid.UUID) -> FinancialSummaryResponse:
        """Calculate available balance and total earnings/withdrawals for counselor."""
        stmt = select(PsychologistProfile).where(PsychologistProfile.user_id == user_id)
        res = await self.db.execute(stmt)
        profile = res.scalar_one_or_none()

        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan",
            )

        # 1. Total earnings this month
        now = datetime.now(UTC)
        first_day_month = datetime(now.year, now.month, 1, tzinfo=UTC)

        earnings_stmt = select(func.coalesce(func.sum(CounselorTransaction.amount), 0)).where(
            CounselorTransaction.counselor_id == profile.id,
            CounselorTransaction.transaction_type == TransactionType.EARNING.value,
            CounselorTransaction.status == TransactionStatus.COMPLETED.value,
            CounselorTransaction.created_at >= first_day_month,
        )
        earnings_res = await self.db.execute(earnings_stmt)
        total_earnings = int(earnings_res.scalar() or 0)

        # 2. Total withdrawn
        withdrawn_stmt = select(func.coalesce(func.sum(CounselorTransaction.amount), 0)).where(
            CounselorTransaction.counselor_id == profile.id,
            CounselorTransaction.transaction_type == TransactionType.WITHDRAWAL.value,
            CounselorTransaction.status == TransactionStatus.COMPLETED.value,
        )
        withdrawn_res = await self.db.execute(withdrawn_stmt)
        total_withdrawn = int(withdrawn_res.scalar() or 0)

        # 3. Pending clearing balance
        pending_stmt = select(func.coalesce(func.sum(CounselorTransaction.amount), 0)).where(
            CounselorTransaction.counselor_id == profile.id,
            CounselorTransaction.transaction_type == TransactionType.EARNING.value,
            CounselorTransaction.status == TransactionStatus.PENDING.value,
        )
        pending_res = await self.db.execute(pending_stmt)
        pending_clearing = int(pending_res.scalar() or 0)

        return FinancialSummaryResponse(
            available_balance=int(profile.wallet_balance),
            pending_clearing_balance=pending_clearing,
            locked_withdrawal_balance=int(profile.locked_withdrawal_balance),
            total_earnings_this_month=total_earnings,
            total_withdrawn=total_withdrawn,
            currency="IDR",
        )

    async def get_transactions(self, user_id: uuid.UUID) -> list[TransactionResponse]:
        """Fetch transaction history for authenticated counselor."""
        stmt = select(PsychologistProfile).where(PsychologistProfile.user_id == user_id)
        res = await self.db.execute(stmt)
        profile = res.scalar_one_or_none()

        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan",
            )

        trx_stmt = (
            select(CounselorTransaction)
            .where(CounselorTransaction.counselor_id == profile.id)
            .order_by(CounselorTransaction.created_at.desc())
            .options(
                selectinload(CounselorTransaction.session).selectinload(ConsultationSession.patient)
            )
        )
        trx_res = await self.db.execute(trx_stmt)
        transactions = trx_res.scalars().all()

        withdrawals_stmt = select(CounselorWithdrawal).where(
            CounselorWithdrawal.counselor_id == profile.id
        )
        withdrawals = (await self.db.execute(withdrawals_stmt)).scalars().all()
        withdrawal_by_tx = {
            w.counselor_transaction_id: w for w in withdrawals if w.counselor_transaction_id is not None
        }

        results: list[TransactionResponse] = []
        for t in transactions:
            is_withdrawal = t.transaction_type == TransactionType.WITHDRAWAL.value
            linked_withdrawal = withdrawal_by_tx.get(t.id)
            if is_withdrawal:
                snap = (linked_withdrawal.bank_snapshot_json or {}) if linked_withdrawal else {}
                snap_bank = snap.get("bank_name") or profile.bank_name or "Bank"
                snap_masked = snap.get("account_number_masked") or mask_account_number(
                    profile.bank_account_number or ""
                )
                patient_name = f"Penarikan Dana ({snap_bank} {snap_masked})"
                session_type = "Transfer Bank Pencairan Honorarium"
                amount = int(t.amount)
                admin_fee = int(linked_withdrawal.fee_idr) if linked_withdrawal else 0
                net_earnings = int(linked_withdrawal.net_amount_idr) if linked_withdrawal else (amount - admin_fee)
                payout_status = linked_withdrawal.status if linked_withdrawal else (
                    "payout_requested" if t.status == TransactionStatus.PENDING.value else t.status
                )
                status_str = payout_status
                bank_info = f"{snap_bank} • Rekening Terverifikasi • {snap_masked}"
                ref_id = linked_withdrawal.reference_id if linked_withdrawal else t.reference_number
            else:
                patient_user = t.session.patient if t.session and t.session.patient else None
                patient_name = patient_user.email.split("@")[0].capitalize() if patient_user else "Pasien"
                session_type = t.description or "Telekonsultasi Video (30 Menit)"
                net_earnings = int(t.amount)
                amount = int(Decimal(str(net_earnings)) * Decimal("1.25"))
                admin_fee = amount - net_earnings
                status_str = t.status
                payout_status = None
                bank_info = None
                ref_id = t.reference_number

            results.append(
                TransactionResponse(
                    id=ref_id or str(t.id),
                    patient_name=patient_name,
                    session_type=session_type,
                    date=t.created_at.isoformat() if t.created_at else datetime.now(UTC).isoformat(),
                    amount=amount,
                    admin_fee=admin_fee,
                    net_earnings=net_earnings,
                    status=status_str,
                    bank_account_info=bank_info,
                    transaction_type=t.transaction_type,
                    payout_status=payout_status,
                    reference_id=ref_id,
                )
            )

        return results

    async def request_payout(self, user_id: uuid.UUID, payload: PayoutRequest) -> PayoutResponse:
        """Legacy direct payout disabled; enforce quote + idempotent /finances/payouts workflow."""
        raise_contract_error(
            status.HTTP_400_BAD_REQUEST,
            "USE_QUOTED_PAYOUT",
            "Endpoint penarikan langsung dinonaktifkan. Gunakan POST /finances/payouts/quote lalu POST /finances/payouts.",
        )
