import logging
import uuid
from datetime import UTC, datetime
from decimal import Decimal

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.counselor import ConsultationSession, CounselorTransaction, PsychologistProfile
from app.models.enums import TransactionStatus, TransactionType
from app.models.user import User
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
            total_earnings_this_month=total_earnings,
            total_withdrawn=total_withdrawn,
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

        results: list[TransactionResponse] = []
        for t in transactions:
            is_withdrawal = t.transaction_type == TransactionType.WITHDRAWAL.value
            if is_withdrawal:
                patient_name = f"Penarikan Dana ({profile.bank_name or 'BCA'} ****{profile.bank_account_number[-4:] if profile.bank_account_number and len(profile.bank_account_number) >= 4 else '8192'})"
                session_type = "Transfer Bank Pencairan Honorarium"
                amount = int(t.amount)
                admin_fee = 0
                net_earnings = int(t.amount)
                status_str = "payout_requested" if t.status == TransactionStatus.PENDING.value else t.status
                bank_info = f"{profile.bank_name or 'BCA'} • Rekening Terverifikasi • {profile.bank_account_number or '1234567890'}"
            else:
                patient_user = t.session.patient if t.session and t.session.patient else None
                patient_name = patient_user.email.split("@")[0].capitalize() if patient_user else "Pasien"
                session_type = t.description or "Telekonsultasi Video (30 Menit)"
                net_earnings = int(t.amount)
                amount = int(Decimal(str(net_earnings)) * Decimal("1.25"))
                admin_fee = amount - net_earnings
                status_str = t.status
                bank_info = None

            results.append(
                TransactionResponse(
                    id=t.reference_number or str(t.id),
                    patient_name=patient_name,
                    session_type=session_type,
                    date=t.created_at.isoformat() if t.created_at else datetime.now(UTC).isoformat(),
                    amount=amount,
                    admin_fee=admin_fee,
                    net_earnings=net_earnings,
                    status=status_str,
                    bank_account_info=bank_info,
                )
            )

        return results

    async def request_payout(self, user_id: uuid.UUID, payload: PayoutRequest) -> PayoutResponse:
        """Submit a payout / withdrawal request, debiting the counselor's wallet balance."""
        stmt = select(PsychologistProfile).where(PsychologistProfile.user_id == user_id)
        res = await self.db.execute(stmt)
        profile = res.scalar_one_or_none()

        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profil psikolog tidak ditemukan",
            )

        withdraw_amount = Decimal(str(payload.amount))
        if profile.wallet_balance < withdraw_amount:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Saldo honorarium tidak mencukupi untuk melakukan penarikan.",
            )

        # Debit counselor wallet balance
        profile.wallet_balance -= withdraw_amount

        # Generate unique transaction reference
        ref_no = f"TRX-{datetime.now(UTC).year}-{uuid.uuid4().hex[:8].upper()}"

        transaction = CounselorTransaction(
            counselor_id=profile.id,
            transaction_type=TransactionType.WITHDRAWAL.value,
            status=TransactionStatus.PENDING.value,
            amount=withdraw_amount,
            description=f"Pencairan honorarium ke {payload.bank_name} {payload.account_number} a.n. {payload.account_holder or profile.bank_account_holder or profile.full_name}",
            reference_number=ref_no,
        )
        self.db.add(transaction)
        await self.db.commit()
        await self.db.refresh(transaction)

        logger.info(
            f"Payout requested for counselor {profile.id}: {withdraw_amount} IDR (Ref: {ref_no})"
        )

        return PayoutResponse(
            success=True,
            transaction_id=ref_no,
            message="Permintaan penarikan dana honorarium berhasil diajukan.",
        )
