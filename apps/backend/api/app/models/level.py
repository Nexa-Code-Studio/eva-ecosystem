import uuid
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship as orm_relationship

from app.models.base import BaseModel

if TYPE_CHECKING:
    from app.models.counselor import ConsultationSession, PsychologistProfile
    from app.models.user import User


class PsychologistLevel(BaseModel):
    """Dynamic master career tier and pricing configuration managed via Web Admin."""

    __tablename__ = "psychologist_levels"

    level_tier: Mapped[int] = mapped_column(Integer, nullable=False, unique=True, index=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    badge_icon: Mapped[str] = mapped_column(
        String(60),
        nullable=False,
        default="award",
        server_default="award",
    )

    # Quantitative qualification thresholds
    min_completed_sessions: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
    )
    min_average_rating: Mapped[Decimal] = mapped_column(
        Numeric(3, 2),
        nullable=False,
        default=Decimal("0.00"),
        server_default="0.00",
    )
    min_consultation_hours: Mapped[Decimal] = mapped_column(
        Numeric(10, 2),
        nullable=False,
        default=Decimal("0.00"),
        server_default="0.00",
    )
    min_review_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
    )

    # Tier pricing & platform revenue split (denominated in EVA Coins)
    default_session_price: Mapped[Decimal] = mapped_column(
        Numeric(14, 2),
        nullable=False,
        default=Decimal("150.00"),
        server_default="150.00",
    )
    platform_fee_percentage: Mapped[Decimal] = mapped_column(
        Numeric(5, 2),
        nullable=False,
        default=Decimal("20.00"),
        server_default="20.00",
    )
    allow_custom_price: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )
    min_custom_price: Mapped[Decimal | None] = mapped_column(Numeric(14, 2), nullable=True)
    max_custom_price: Mapped[Decimal | None] = mapped_column(Numeric(14, 2), nullable=True)
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
        index=True,
    )

    # Relationships
    counselors: Mapped[list["PsychologistProfile"]] = orm_relationship(
        "PsychologistProfile",
        back_populates="current_level",
    )


class CounselorReview(BaseModel):
    """Per-session patient rating and qualitative review (1 session = at most 1 review)."""

    __tablename__ = "counselor_reviews"
    __table_args__ = (
        UniqueConstraint("session_id", name="uq_counselor_reviews_session_id"),
        CheckConstraint("rating >= 1.0 AND rating <= 5.0", name="ck_counselor_reviews_rating_range"),
    )

    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("consultation_sessions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    counselor_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("psychologist_profiles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    patient_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    rating: Mapped[Decimal] = mapped_column(Numeric(3, 2), nullable=False)
    highlight_label: Mapped[str | None] = mapped_column(String(120), nullable=True)
    review_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_anonymous: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    # Relationships
    session: Mapped["ConsultationSession"] = orm_relationship("ConsultationSession")
    counselor: Mapped["PsychologistProfile"] = orm_relationship(
        "PsychologistProfile",
        back_populates="reviews",
    )
    patient: Mapped["User"] = orm_relationship("User", foreign_keys=[patient_id])
