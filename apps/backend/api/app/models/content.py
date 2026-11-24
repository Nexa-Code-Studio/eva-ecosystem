from sqlalchemy import Boolean, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import BaseModel


class CrisisConfig(BaseModel):
    """Singleton platform configuration for SafetyNet crisis intervention and DASS-21 thresholds."""

    __tablename__ = "crisis_configs"

    hotline_number: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        default="119 EXT 8",
        server_default="119 EXT 8",
    )
    hotline_label: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
        default="Layanan Darurat Kemenkes RI",
        server_default="Layanan Darurat Kemenkes RI",
    )
    extreme_depression_threshold: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=28,
        server_default="28",
    )
    extreme_anxiety_threshold: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=20,
        server_default="20",
    )
    auto_safety_net_modal: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
    )
    allow_direct_independent_referral: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
    )


class FaqEntry(BaseModel):
    """Public FAQ CMS entry managed by Admin Portal and displayed on the Landing Page."""

    __tablename__ = "faq_entries"

    category: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    question: Mapped[str] = mapped_column(String(500), nullable=False)
    answer: Mapped[str] = mapped_column(Text, nullable=False)
    is_published: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
        index=True,
    )
    sort_order: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
        index=True,
    )
