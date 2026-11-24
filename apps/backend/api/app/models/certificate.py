from datetime import UTC, datetime
from decimal import Decimal
import uuid

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, Numeric, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship as orm_relationship

from app.models.base import BaseModel


class CertificateTemplate(BaseModel):
    """Configurable official certificate template and automated milestone/rating trigger rules."""

    __tablename__ = "certificate_templates"

    code: Mapped[str] = mapped_column(String(40), unique=True, nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    subtitle: Mapped[str] = mapped_column(String(250), nullable=False)
    category_code: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="PRO",
        server_default="PRO",
    )
    category_label: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        default="Psikolog Mandiri",
        server_default="Psikolog Mandiri",
    )
    milestone_criteria: Mapped[str] = mapped_column(String(250), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    badge_color: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="#2563EB",
        server_default="#2563EB",
    )
    trigger_type: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="sessions_milestone",
        server_default="sessions_milestone",
        index=True,
    )
    min_completed_sessions: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=25,
        server_default="25",
    )
    min_average_rating: Mapped[Decimal | None] = mapped_column(Numeric(3, 2), nullable=True)
    auto_issue_enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
        index=True,
    )
    svg_body_template: Mapped[str | None] = mapped_column(Text, nullable=True)

    certificates: Mapped[list["PsychologistCertificate"]] = orm_relationship(
        "PsychologistCertificate",
        back_populates="template",
    )


class PsychologistCertificate(BaseModel):
    """Officially issued psychologist certificate with EVA/CERT/{YEAR}/{CATEGORY}/{SEQ} numbering."""

    __tablename__ = "psychologist_certificates"

    certificate_number: Mapped[str] = mapped_column(
        String(80),
        unique=True,
        nullable=False,
        index=True,
    )
    sequence_number: Mapped[int] = mapped_column(Integer, nullable=False)
    issue_year: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    category_code: Mapped[str] = mapped_column(String(20), nullable=False, index=True)

    counselor_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("psychologist_profiles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    template_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("certificate_templates.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    issued_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    title: Mapped[str] = mapped_column(String(200), nullable=False)
    subtitle: Mapped[str] = mapped_column(String(250), nullable=False)
    recipient_name: Mapped[str] = mapped_column(String(200), nullable=False)
    str_number: Mapped[str] = mapped_column(String(100), nullable=False)
    milestone_criteria: Mapped[str] = mapped_column(String(250), nullable=False)
    category_label: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        default="Psikolog Mandiri",
    )
    description: Mapped[str] = mapped_column(Text, nullable=False)
    badge_color: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="#2563EB",
    )
    trigger_source: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="manual",
        server_default="manual",
    )
    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="active",
        server_default="active",
        index=True,
    )
    issued_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    revocation_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    template: Mapped["CertificateTemplate | None"] = orm_relationship(
        "CertificateTemplate",
        back_populates="certificates",
    )
