from datetime import UTC, datetime
import uuid

from fastapi import HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.coin import CoinTransaction
from app.models.enums import CoinTransactionType, TransactionStatus
from app.models.user import User
from app.schemas.coin import (
    AdminCoinTopupRequest,
    AdminCoinTopupResultResponse,
    AdminUserSummaryResponse,
    CoinTopupTransactionResponse,
    UserCoinBalanceResponse,
)


def format_user_code(user_id: uuid.UUID | str) -> str:
    """Derive stable human-readable EVA user code from UUID."""
    raw = str(user_id).replace("-", "").upper()
    return f"EVA-USR-{raw[:4]}"


class CoinService:
    """Domain service managing user EVA Coin balances, admin top-ups, and ledger history."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_user_balance(self, user_id: uuid.UUID) -> UserCoinBalanceResponse:
        """Retrieve authenticated user's current EVA Coin balance."""
        res = await self.db.execute(select(User).where(User.id == user_id))
        user = res.scalar_one_or_none()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Pengguna tidak ditemukan.",
            )
        return UserCoinBalanceResponse(user_id=str(user.id), coin_balance=user.coin_balance)

    async def list_admin_users(self, search: str | None = None) -> list[AdminUserSummaryResponse]:
        """List non-admin mobile users along with their current EVA Coin balances."""
        query = select(User).where(User.is_admin.is_(False)).order_by(User.created_at.desc())
        if search and search.strip():
            term = f"%{search.strip()}%"
            query = query.where(
                or_(
                    User.email.ilike(term),
                    User.display_name.ilike(term),
                    User.username.ilike(term),
                )
            )
        res = await self.db.execute(query)
        users = res.scalars().all()
        return [self._to_user_summary(u) for u in users]

    async def list_transactions(
        self,
        include_usage: bool = False,
    ) -> list[CoinTopupTransactionResponse]:
        """List coin ledger transactions for Admin Portal (top-ups/grants/refunds by default)."""
        query = (
            select(CoinTransaction, User)
            .join(User, CoinTransaction.user_id == User.id)
            .order_by(CoinTransaction.created_at.desc())
        )
        if not include_usage:
            query = query.where(
                CoinTransaction.transaction_type.in_(
                    [
                        CoinTransactionType.TOPUP_ADMIN.value,
                        CoinTransactionType.GRANT_ADMIN.value,
                        CoinTransactionType.REFUND.value,
                    ]
                )
            )
        res = await self.db.execute(query)
        rows = res.all()
        return [self._to_transaction_response(tx, usr) for tx, usr in rows]

    async def topup_user_coins(
        self,
        admin_id: uuid.UUID,
        target_user_id: uuid.UUID,
        payload: AdminCoinTopupRequest,
    ) -> AdminCoinTopupResultResponse:
        """Atomically credit EVA Coins to a user's wallet and record an admin top-up transaction."""
        res = await self.db.execute(
            select(User).where(User.id == target_user_id).with_for_update()
        )
        user = res.scalar_one_or_none()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Akun pengguna tidak ditemukan.",
            )
        if user.is_admin:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Tidak dapat melakukan top-up ke akun admin.",
            )

        is_grant = payload.payment_method.strip() == "Grant Admin (Gratis)" or payload.amount_idr == 0
        effective_amount_idr = 0 if payload.payment_method.strip() == "Grant Admin (Gratis)" else payload.amount_idr
        tx_type = (
            CoinTransactionType.GRANT_ADMIN.value
            if is_grant
            else CoinTransactionType.TOPUP_ADMIN.value
        )

        now = datetime.now(UTC)
        date_stamp = now.strftime("%Y%m%d")
        invoice_code = f"EVA-ADM-{date_stamp}-{uuid.uuid4().hex[:6].upper()}"

        user.coin_balance += payload.coins_granted
        tx = CoinTransaction(
            invoice_code=invoice_code,
            user_id=user.id,
            performed_by_user_id=admin_id,
            transaction_type=tx_type,
            coins_delta=payload.coins_granted,
            balance_after=user.coin_balance,
            amount_idr=effective_amount_idr,
            payment_method=payload.payment_method.strip(),
            package_name=payload.package_name.strip(),
            status=TransactionStatus.COMPLETED.value,
            admin_notes=payload.admin_notes.strip() if payload.admin_notes else None,
            completed_at=now,
        )
        self.db.add(tx)
        await self.db.commit()
        await self.db.refresh(user)
        await self.db.refresh(tx)

        return AdminCoinTopupResultResponse(
            user=self._to_user_summary(user),
            transaction=self._to_transaction_response(tx, user),
        )

    @staticmethod
    def _to_user_summary(user: User) -> AdminUserSummaryResponse:
        display_name = user.display_name or user.username or user.email.split("@")[0]
        return AdminUserSummaryResponse(
            id=str(user.id),
            user_code=format_user_code(user.id),
            display_name=display_name,
            email=user.email,
            coin_balance=user.coin_balance,
            is_active=user.is_active,
            created_at=user.created_at,
        )

    @staticmethod
    def _to_transaction_response(
        tx: CoinTransaction,
        user: User,
    ) -> CoinTopupTransactionResponse:
        display_name = user.display_name or user.username or user.email.split("@")[0]
        return CoinTopupTransactionResponse(
            id=str(tx.id),
            invoice_code=tx.invoice_code,
            user_id=str(tx.user_id),
            user_code=format_user_code(user.id),
            user_display_name=display_name,
            package_name=tx.package_name,
            transaction_type=tx.transaction_type,
            coins_delta=tx.coins_delta,
            balance_after=tx.balance_after,
            amount_idr=tx.amount_idr,
            payment_method=tx.payment_method,
            status=tx.status,
            admin_notes=tx.admin_notes,
            created_at=tx.created_at,
            completed_at=tx.completed_at,
        )
