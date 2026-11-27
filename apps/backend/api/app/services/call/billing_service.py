from dataclasses import dataclass
from datetime import UTC, datetime
import logging
import uuid

from sqlalchemy import select

from app.core.security import decode_access_token
from app.db.session import AsyncSessionLocal
from app.models.coin import CoinTransaction
from app.models.enums import CoinTransactionType, TransactionStatus
from app.models.user import User

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class AuthenticatedCallUser:
    """Minimal authenticated user identity resolved for a WebSocket call session."""

    user_id: uuid.UUID
    display_name: str | None
    coin_balance: int


@dataclass(frozen=True)
class CallChargeResult:
    """Outcome of an atomic per-minute EVA Coin debit for an AI phone call."""

    success: bool
    coin_balance: int
    coins_debited: int
    minute_index: int
    invoice_code: str | None = None
    reason: str | None = None


class CallBillingService:
    """Handles JWT auth resolution and atomic per-minute EVA Coin debits for AI voice calls."""

    @staticmethod
    async def resolve_authenticated_user(token: str | None) -> AuthenticatedCallUser | None:
        """Verify access token and return active user identity regardless of privacy_mode."""
        if not token or not token.strip():
            return None
        decoded = decode_access_token(token.strip())
        if not decoded or "sub" not in decoded:
            return None
        try:
            user_uuid = uuid.UUID(str(decoded["sub"]))
        except (ValueError, TypeError):
            return None

        async with AsyncSessionLocal() as db:
            res = await db.execute(
                select(User).where(User.id == user_uuid, User.is_active.is_(True))
            )
            user = res.scalar_one_or_none()
            if not user:
                return None
            return AuthenticatedCallUser(
                user_id=user.id,
                display_name=user.display_name or user.username or None,
                coin_balance=int(user.coin_balance),
            )

    @staticmethod
    async def get_user_coin_balance(user_id: uuid.UUID) -> int | None:
        """Read current user EVA Coin balance without locking."""
        async with AsyncSessionLocal() as db:
            res = await db.execute(select(User.coin_balance).where(User.id == user_id))
            bal = res.scalar_one_or_none()
            return int(bal) if bal is not None else None

    @staticmethod
    async def charge_call_minute(
        user_id: uuid.UUID,
        session_id: str,
        minute_index: int,
        coins_cost: int,
    ) -> CallChargeResult:
        """Atomically lock user row, deduct EVA Coins, and append an AI_CALL_DEBIT ledger entry."""
        if minute_index < 1:
            raise ValueError("minute_index must be >= 1")

        async with AsyncSessionLocal() as db:
            res = await db.execute(
                select(User).where(User.id == user_id).with_for_update()
            )
            user = res.scalar_one_or_none()
            if not user or not user.is_active:
                return CallChargeResult(
                    success=False,
                    coin_balance=0,
                    coins_debited=0,
                    minute_index=minute_index,
                    reason="user_not_found",
                )

            if coins_cost <= 0:
                return CallChargeResult(
                    success=True,
                    coin_balance=int(user.coin_balance),
                    coins_debited=0,
                    minute_index=minute_index,
                )

            if user.coin_balance < coins_cost:
                return CallChargeResult(
                    success=False,
                    coin_balance=int(user.coin_balance),
                    coins_debited=0,
                    minute_index=minute_index,
                    reason="insufficient_coins",
                )

            now_utc = datetime.now(UTC)
            invoice_code = f"EVA-CALL-{now_utc.strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}"
            user.coin_balance -= coins_cost
            tx = CoinTransaction(
                invoice_code=invoice_code,
                user_id=user.id,
                transaction_type=CoinTransactionType.AI_CALL_DEBIT.value,
                coins_delta=-coins_cost,
                balance_after=int(user.coin_balance),
                amount_idr=0,
                payment_method="EVA Wallet",
                package_name=f"Telepon AI EVA (Menit ke-{minute_index})",
                status=TransactionStatus.COMPLETED.value,
                admin_notes=f"ai_call_session={session_id};minute={minute_index}",
                reference_session_id=None,
                completed_at=now_utc,
            )
            db.add(tx)
            await db.commit()
            logger.info(
                f"🪙 [AI CALL DEBIT] Session {session_id} | User {user.id} | "
                f"Minute {minute_index} | -{coins_cost} coin | Balance={user.coin_balance}"
            )
            return CallChargeResult(
                success=True,
                coin_balance=int(user.coin_balance),
                coins_debited=coins_cost,
                minute_index=minute_index,
                invoice_code=invoice_code,
            )
