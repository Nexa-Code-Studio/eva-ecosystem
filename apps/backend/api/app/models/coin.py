from datetime import datetime
from typing import TYPE_CHECKING
import uuid

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship as orm_relationship

from app.models.base import BaseModel
from app.models.enums import CoinTransactionType, TransactionStatus

if TYPE_CHECKING:
    from app.models.user import User


class CoinTransaction(BaseModel):
    """Auditable ledger of user EVA Coin credits, top-ups, and consultation debits."""

    __tablename__ = "coin_transactions"

    invoice_code: Mapped[str] = mapped_column(String(60), unique=True, nullable=False, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    performed_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    transaction_type: Mapped[str] = mapped_column(
        String(40),
        nullable=False,
        default=CoinTransactionType.TOPUP_ADMIN.value,
        index=True,
    )
    coins_delta: Mapped[int] = mapped_column(Integer, nullable=False)
    balance_after: Mapped[int] = mapped_column(Integer, nullable=False)
    amount_idr: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    payment_method: Mapped[str] = mapped_column(String(50), nullable=False, default="Transfer Bank")
    package_name: Mapped[str] = mapped_column(String(150), nullable=False)
    status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default=TransactionStatus.COMPLETED.value,
        index=True,
    )
    admin_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    reference_session_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("consultation_sessions.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Relationships
    user: Mapped["User"] = orm_relationship(
        "User",
        foreign_keys=[user_id],
        back_populates="coin_transactions",
    )
    performed_by: Mapped["User | None"] = orm_relationship(
        "User",
        foreign_keys=[performed_by_user_id],
    )


class CoinPackage(BaseModel):
    """Configurable EVA Coin top-up bundle catalog displayed in mobile & admin portal."""

    __tablename__ = "coin_packages"

    code: Mapped[str] = mapped_column(String(40), unique=True, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    coins: Mapped[int] = mapped_column(Integer, nullable=False)
    bonus_coins: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    price_idr: Mapped[int] = mapped_column(Integer, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    is_popular: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default="false")
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
        index=True,
    )


class CoinEconomyConfig(BaseModel):
    """Global EVA Coin base rate and new-user free trial allocation."""

    __tablename__ = "coin_economy_configs"

    base_price_per_coin_idr: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=1000,
        server_default="1000",
    )
    free_trial_coins_new_user: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=10,
        server_default="10",
    )
