import uuid
from datetime import UTC, datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship as orm_relationship

from app.models.base import BaseModel
from app.models.enums import (
    ConsultationSessionStatus,
    PricingConfigStatus,
    PsychologistVerificationStatus,
    TransactionStatus,
    TransactionType,
)


class PsychologistProfile(BaseModel):
    """Profile and professional credentials for verified individual psychologists."""

    __tablename__ = "psychologist_profiles"

    def __init__(self, **kwargs: Any) -> None:
        kwargs.setdefault("verification_status", PsychologistVerificationStatus.PENDING.value)
        kwargs.setdefault("str_verified", False)
        kwargs.setdefault("sip_verified", False)
        kwargs.setdefault("is_online", True)
        kwargs.setdefault("buffer_time_minutes", 10)
        kwargs.setdefault("schedule_config", {})
        kwargs.setdefault("wallet_balance", Decimal("0.00"))
        kwargs.setdefault("total_completed_sessions", 0)
        kwargs.setdefault("total_consultation_hours", Decimal("0.00"))
        kwargs.setdefault("average_rating", Decimal("0.00"))
        kwargs.setdefault("rating_count", 0)
        super().__init__(**kwargs)

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    full_name: Mapped[str] = mapped_column(String(200), nullable=False)
    title_degree: Mapped[str] = mapped_column(String(100), nullable=False, default="M.Psi., Psikolog")
    str_number: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    sip_number: Mapped[str | None] = mapped_column(String(100), nullable=True, index=True)
    association: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
        default="Himpunan Psikologi Indonesia (HIMPSI)",
    )
    specializations: Mapped[list[str]] = mapped_column(
        JSONB,
        nullable=False,
        default=list,
        server_default="[]",
    )
    years_of_experience: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    bio: Mapped[str | None] = mapped_column(Text, nullable=True)
    education: Mapped[str | None] = mapped_column(String(200), nullable=True)
    profile_photo_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    certificate_doc_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Separate STR / SIP Document Metadata & Admin Verification Flags
    str_doc_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    str_issuing_institution: Mapped[str | None] = mapped_column(String(150), nullable=True)
    str_expiry_date: Mapped[str | None] = mapped_column(String(50), nullable=True)
    str_verified: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )
    sip_doc_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    sip_issuing_institution: Mapped[str | None] = mapped_column(String(150), nullable=True)
    sip_expiry_date: Mapped[str | None] = mapped_column(String(50), nullable=True)
    sip_verified: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    # Verification Gate Fields
    verification_status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default=PsychologistVerificationStatus.PENDING.value,
        index=True,
    )
    verification_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    verified_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    # Practice & Availability Settings (100% Digital Teleconsultation)
    is_online: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    buffer_time_minutes: Mapped[int] = mapped_column(Integer, nullable=False, default=10)
    schedule_config: Mapped[dict[str, Any]] = mapped_column(
        JSONB,
        nullable=False,
        default=dict,
        server_default="{}",
    )

    # Bank Account & Financial Details
    bank_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    bank_account_number: Mapped[str | None] = mapped_column(String(50), nullable=True)
    bank_account_holder: Mapped[str | None] = mapped_column(String(200), nullable=True)
    wallet_balance: Mapped[Decimal] = mapped_column(
        Numeric(14, 2),
        nullable=False,
        default=Decimal("0.00"),
        server_default="0.00",
    )

    # Career Level & Quantitative Metrics
    current_level_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("psychologist_levels.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    custom_price_per_session: Mapped[Decimal | None] = mapped_column(Numeric(14, 2), nullable=True)
    total_completed_sessions: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
    )
    total_consultation_hours: Mapped[Decimal] = mapped_column(
        Numeric(10, 2),
        nullable=False,
        default=Decimal("0.00"),
        server_default="0.00",
    )
    average_rating: Mapped[Decimal] = mapped_column(
        Numeric(3, 2),
        nullable=False,
        default=Decimal("0.00"),
        server_default="0.00",
    )
    rating_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
    )

    # Relationships
    user: Mapped["User"] = orm_relationship("User", foreign_keys=[user_id])
    verified_by: Mapped["User | None"] = orm_relationship("User", foreign_keys=[verified_by_user_id])
    current_level: Mapped["PsychologistLevel | None"] = orm_relationship(
        "PsychologistLevel",
        back_populates="counselors",
    )
    reviews: Mapped[list["CounselorReview"]] = orm_relationship(
        "CounselorReview",
        back_populates="counselor",
        cascade="all, delete-orphan",
    )
    sessions: Mapped[list["ConsultationSession"]] = orm_relationship(
        "ConsultationSession",
        back_populates="counselor",
        cascade="all, delete-orphan",
    )
    transactions: Mapped[list["CounselorTransaction"]] = orm_relationship(
        "CounselorTransaction",
        back_populates="counselor",
        cascade="all, delete-orphan",
    )


class PlatformPricingConfig(BaseModel):
    """Centralized platform pricing and revenue share configuration managed via Web Portal."""

    __tablename__ = "platform_pricing_configs"

    session_duration_minutes: Mapped[int] = mapped_column(Integer, nullable=False, default=30)
    price_per_session: Mapped[Decimal] = mapped_column(
        Numeric(14, 2),
        nullable=False,
        default=Decimal("0.00"),
        server_default="0.00",
    )
    counselor_share_percentage: Mapped[Decimal] = mapped_column(
        Numeric(5, 2),
        nullable=False,
        default=Decimal("0.00"),
        server_default="0.00",
    )
    platform_fee_percentage: Mapped[Decimal] = mapped_column(
        Numeric(5, 2),
        nullable=False,
        default=Decimal("0.00"),
        server_default="0.00",
    )
    extension_price_per_session: Mapped[Decimal] = mapped_column(
        Numeric(14, 2),
        nullable=False,
        default=Decimal("0.00"),
        server_default="0.00",
    )
    status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default=PricingConfigStatus.ACTIVE.value,
        index=True,
    )
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    effective_from: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )
    effective_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Relationships
    sessions: Mapped[list["ConsultationSession"]] = orm_relationship(
        "ConsultationSession",
        back_populates="pricing_config",
    )


class ConsultationSession(BaseModel):
    """Consultation session entity adhering to 30-minute blocks and in-call extension."""

    __tablename__ = "consultation_sessions"

    session_code: Mapped[str] = mapped_column(String(50), nullable=False, unique=True, index=True)
    patient_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    counselor_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("psychologist_profiles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    pricing_config_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("platform_pricing_configs.id", ondelete="SET NULL"),
        nullable=True,
    )

    scheduled_start_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    scheduled_end_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    actual_start_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    actual_end_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    duration_minutes: Mapped[int] = mapped_column(Integer, nullable=False, default=30)
    status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default=ConsultationSessionStatus.SCHEDULED.value,
        index=True,
    )

    # In-Call Extension (+30 Minutes) Tracking
    is_extended: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    extension_requested_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    extension_granted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Financial Snapshot
    total_price: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False, default=Decimal("0.00"))
    counselor_earning: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False, default=Decimal("0.00"))
    platform_fee: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False, default=Decimal("0.00"))

    # Session Artifacts
    video_room_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    soap_notes: Mapped[dict[str, Any] | None] = mapped_column(JSONB, nullable=True)
    patient_rating: Mapped[Decimal | None] = mapped_column(Numeric(3, 2), nullable=True)
    cancellation_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Relationships
    patient: Mapped["User"] = orm_relationship("User", foreign_keys=[patient_id])
    counselor: Mapped["PsychologistProfile"] = orm_relationship("PsychologistProfile", back_populates="sessions")
    pricing_config: Mapped["PlatformPricingConfig | None"] = orm_relationship(
        "PlatformPricingConfig",
        back_populates="sessions",
    )
    transactions: Mapped[list["CounselorTransaction"]] = orm_relationship(
        "CounselorTransaction",
        back_populates="session",
        cascade="all, delete-orphan",
    )


class CounselorTransaction(BaseModel):
    """Financial ledger for psychologist earnings, platform fee distribution, and payouts."""

    __tablename__ = "counselor_transactions"

    counselor_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("psychologist_profiles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    session_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("consultation_sessions.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    transaction_type: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default=TransactionType.EARNING.value,
        index=True,
    )
    status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default=TransactionStatus.COMPLETED.value,
        index=True,
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    reference_number: Mapped[str | None] = mapped_column(String(100), nullable=True, index=True)

    # Relationships
    counselor: Mapped["PsychologistProfile"] = orm_relationship("PsychologistProfile", back_populates="transactions")
    session: Mapped["ConsultationSession | None"] = orm_relationship(
        "ConsultationSession",
        back_populates="transactions",
    )


class PatientConsent(BaseModel):
    """Patient consent allowing a psychologist to view screening DASS-21 and journal records."""

    __tablename__ = "patient_consents"

    patient_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    counselor_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("psychologist_profiles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    status: Mapped[str] = mapped_column(String(30), nullable=False, default="granted", index=True)
    granted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    patient: Mapped["User"] = orm_relationship("User", foreign_keys=[patient_id])
    counselor: Mapped["PsychologistProfile"] = orm_relationship("PsychologistProfile")

