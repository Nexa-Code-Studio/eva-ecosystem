from datetime import UTC, datetime
from typing import TYPE_CHECKING, Any
import uuid

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship as orm_relationship

from app.models.base import BaseModel
from app.models.enums import (
    BankNameMatchStatus,
    BankValidationStatus,
    BankVerificationStatus,
    OutboxEventStatus,
    PayoutStatus,
    ReconciliationStatus,
    TopupOrderStatus,
    WebhookProcessStatus,
)

if TYPE_CHECKING:
    from app.models.coin import CoinPackage, CoinTransaction
    from app.models.counselor import CounselorTransaction, PsychologistProfile
    from app.models.user import User


class CoinTopupOrder(BaseModel):
    """Server-authoritative Midtrans QRIS top-up order with immutable package snapshot."""

    __tablename__ = "coin_topup_orders"
    __table_args__ = (
        UniqueConstraint("user_id", "idempotency_key", name="uq_coin_topup_orders_user_idem"),
    )

    order_id: Mapped[str] = mapped_column(String(64), unique=True, nullable=False, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    package_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("coin_packages.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    package_code: Mapped[str] = mapped_column(String(40), nullable=False)
    package_name: Mapped[str] = mapped_column(String(150), nullable=False)
    coins_snapshot: Mapped[int] = mapped_column(Integer, nullable=False)
    bonus_coins_snapshot: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    total_coins_snapshot: Mapped[int] = mapped_column(Integer, nullable=False)
    amount_idr: Mapped[int] = mapped_column(Integer, nullable=False)
    currency: Mapped[str] = mapped_column(String(10), nullable=False, default="IDR", server_default="IDR")
    payment_method: Mapped[str] = mapped_column(String(30), nullable=False, default="qris", server_default="qris")
    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False)
    request_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default=TopupOrderStatus.CREATING.value,
        index=True,
    )
    provider_transaction_id: Mapped[str | None] = mapped_column(String(120), unique=True, nullable=True)
    qr_image_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    qr_image_v2_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    refunded_amount_idr: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    coin_transaction_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("coin_transactions.id", ondelete="SET NULL"),
        unique=True,
        nullable=True,
    )
    reconciliation_status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default=ReconciliationStatus.PENDING.value,
        server_default=ReconciliationStatus.PENDING.value,
        index=True,
    )
    failure_code: Mapped[str | None] = mapped_column(String(60), nullable=True)
    failure_message: Mapped[str | None] = mapped_column(Text, nullable=True)

    user: Mapped["User"] = orm_relationship("User", foreign_keys=[user_id])
    package: Mapped["CoinPackage | None"] = orm_relationship("CoinPackage", foreign_keys=[package_id])
    coin_transaction: Mapped["CoinTransaction | None"] = orm_relationship(
        "CoinTransaction", foreign_keys=[coin_transaction_id]
    )


class BankAccountValidation(BaseModel):
    """Short-lived, single-use provider bank account inquiry validation token."""

    __tablename__ = "bank_account_validations"

    counselor_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("psychologist_profiles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    bank_code: Mapped[str] = mapped_column(String(50), nullable=False)
    bank_name: Mapped[str] = mapped_column(String(120), nullable=False)
    account_number_encrypted: Mapped[str] = mapped_column(Text, nullable=False)
    account_number_masked: Mapped[str] = mapped_column(String(32), nullable=False)
    account_holder_name: Mapped[str] = mapped_column(String(200), nullable=False)
    status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default=BankValidationStatus.UNAVAILABLE.value,
        index=True,
    )
    name_match: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default=BankNameMatchStatus.UNKNOWN.value,
    )
    provider_payload_redacted: Mapped[dict[str, Any] | None] = mapped_column(JSONB, nullable=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    counselor: Mapped["PsychologistProfile"] = orm_relationship("PsychologistProfile", foreign_keys=[counselor_id])


class CounselorBankAccount(BaseModel):
    """Verified or migrated counselor payout bank account with single active constraint."""

    __tablename__ = "counselor_bank_accounts"
    __table_args__ = (
        Index(
            "uq_counselor_bank_accounts_active",
            "counselor_id",
            unique=True,
            postgresql_where=text("is_active IS TRUE"),
        ),
    )

    counselor_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("psychologist_profiles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    validation_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("bank_account_validations.id", ondelete="SET NULL"),
        nullable=True,
    )
    bank_code: Mapped[str] = mapped_column(String(50), nullable=False)
    bank_name: Mapped[str] = mapped_column(String(120), nullable=False)
    account_number_encrypted: Mapped[str | None] = mapped_column(Text, nullable=True)
    account_number_masked: Mapped[str] = mapped_column(String(32), nullable=False)
    account_holder_name: Mapped[str] = mapped_column(String(200), nullable=False)
    verification_status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default=BankVerificationStatus.UNVERIFIED.value,
        server_default=BankVerificationStatus.UNVERIFIED.value,
        index=True,
    )
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    account_revision: Mapped[int] = mapped_column(Integer, nullable=False, default=1, server_default="1")
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")

    counselor: Mapped["PsychologistProfile"] = orm_relationship("PsychologistProfile", foreign_keys=[counselor_id])
    validation: Mapped["BankAccountValidation | None"] = orm_relationship(
        "BankAccountValidation", foreign_keys=[validation_id]
    )


class PayoutQuote(BaseModel):
    """Server-computed fee and net disbursement quote prior to locking counselor balance."""

    __tablename__ = "payout_quotes"

    counselor_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("psychologist_profiles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    bank_account_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("counselor_bank_accounts.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    account_revision: Mapped[int] = mapped_column(Integer, nullable=False)
    amount_idr: Mapped[int] = mapped_column(Integer, nullable=False)
    fee_idr: Mapped[int] = mapped_column(Integer, nullable=False)
    fee_bearer: Mapped[str] = mapped_column(String(30), nullable=False, default="counselor", server_default="counselor")
    net_amount_idr: Mapped[int] = mapped_column(Integer, nullable=False)
    wallet_debit_idr: Mapped[int] = mapped_column(Integer, nullable=False)
    currency: Mapped[str] = mapped_column(String(10), nullable=False, default="IDR", server_default="IDR")
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    counselor: Mapped["PsychologistProfile"] = orm_relationship("PsychologistProfile", foreign_keys=[counselor_id])
    bank_account: Mapped["CounselorBankAccount"] = orm_relationship(
        "CounselorBankAccount", foreign_keys=[bank_account_id]
    )


class CounselorWithdrawal(BaseModel):
    """Idempotent counselor payout request backed by locked wallet funds and Iris lifecycle."""

    __tablename__ = "counselor_withdrawals"
    __table_args__ = (
        UniqueConstraint("counselor_id", "idempotency_key", name="uq_counselor_withdrawals_idem"),
    )

    reference_id: Mapped[str] = mapped_column(String(64), unique=True, nullable=False, index=True)
    counselor_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("psychologist_profiles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    bank_account_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("counselor_bank_accounts.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    quote_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("payout_quotes.id", ondelete="RESTRICT"),
        unique=True,
        nullable=False,
    )
    account_revision: Mapped[int] = mapped_column(Integer, nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False)
    request_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    amount_idr: Mapped[int] = mapped_column(Integer, nullable=False)
    fee_idr: Mapped[int] = mapped_column(Integer, nullable=False)
    fee_bearer: Mapped[str] = mapped_column(String(30), nullable=False, default="counselor", server_default="counselor")
    net_amount_idr: Mapped[int] = mapped_column(Integer, nullable=False)
    wallet_debit_idr: Mapped[int] = mapped_column(Integer, nullable=False)
    currency: Mapped[str] = mapped_column(String(10), nullable=False, default="IDR", server_default="IDR")
    status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default=PayoutStatus.REQUESTED.value,
        index=True,
    )
    provider_reference: Mapped[str | None] = mapped_column(String(120), nullable=True, index=True)
    reconciliation_status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default=ReconciliationStatus.PENDING.value,
        server_default=ReconciliationStatus.PENDING.value,
        index=True,
    )
    counselor_transaction_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("counselor_transactions.id", ondelete="SET NULL"),
        unique=True,
        nullable=True,
    )
    bank_snapshot_json: Mapped[dict[str, Any]] = mapped_column(JSONB, nullable=False, default=dict, server_default="{}")
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    failure_code: Mapped[str | None] = mapped_column(String(60), nullable=True)
    failure_message: Mapped[str | None] = mapped_column(Text, nullable=True)

    counselor: Mapped["PsychologistProfile"] = orm_relationship("PsychologistProfile", foreign_keys=[counselor_id])
    bank_account: Mapped["CounselorBankAccount"] = orm_relationship(
        "CounselorBankAccount", foreign_keys=[bank_account_id]
    )
    quote: Mapped["PayoutQuote"] = orm_relationship("PayoutQuote", foreign_keys=[quote_id])
    counselor_transaction: Mapped["CounselorTransaction | None"] = orm_relationship(
        "CounselorTransaction", foreign_keys=[counselor_transaction_id]
    )
    events: Mapped[list["CounselorWithdrawalEvent"]] = orm_relationship(
        "CounselorWithdrawalEvent",
        back_populates="withdrawal",
        cascade="all, delete-orphan",
        order_by="CounselorWithdrawalEvent.occurred_at.asc()",
    )


class CounselorWithdrawalEvent(BaseModel):
    """Sanitized status timeline entries for payout auditability and admin inspection."""

    __tablename__ = "counselor_withdrawal_events"

    withdrawal_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("counselor_withdrawals.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    status: Mapped[str] = mapped_column(String(30), nullable=False)
    source: Mapped[str] = mapped_column(String(30), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )

    withdrawal: Mapped["CounselorWithdrawal"] = orm_relationship("CounselorWithdrawal", back_populates="events")


class PaymentWebhookInbox(BaseModel):
    """Durable deduplicated inbox for Midtrans payment and Iris payout webhooks."""

    __tablename__ = "payment_webhook_inbox"
    __table_args__ = (
        UniqueConstraint("provider", "event_key", name="uq_payment_webhook_inbox_event"),
    )

    provider: Mapped[str] = mapped_column(String(30), nullable=False, index=True)
    event_key: Mapped[str] = mapped_column(String(128), nullable=False)
    order_or_ref_id: Mapped[str] = mapped_column(String(120), nullable=False, index=True)
    payload_json: Mapped[dict[str, Any]] = mapped_column(JSONB, nullable=False, default=dict, server_default="{}")
    signature_valid: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default="false")
    process_status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default=WebhookProcessStatus.PENDING.value,
        index=True,
    )
    attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    last_error: Mapped[str | None] = mapped_column(Text, nullable=True)
    processed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class PaymentOutboxEvent(BaseModel):
    """Transactional outbox for reliable provider dispatch and status reconciliation."""

    __tablename__ = "payment_outbox_events"

    aggregate_type: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    aggregate_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    event_type: Mapped[str] = mapped_column(String(60), nullable=False)
    payload_json: Mapped[dict[str, Any]] = mapped_column(JSONB, nullable=False, default=dict, server_default="{}")
    status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default=OutboxEventStatus.PENDING.value,
        index=True,
    )
    attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    next_retry_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    last_error: Mapped[str | None] = mapped_column(Text, nullable=True)
