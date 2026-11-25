import uuid

from sqlalchemy import CheckConstraint, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import BaseModel


class BoothFeedback(BaseModel):
    """Visitor feedback submitted from the Mobile-First event booth /feedback route."""

    __tablename__ = "booth_feedbacks"
    __table_args__ = (
        CheckConstraint("rating >= 1 AND rating <= 5", name="ck_booth_feedbacks_rating_range"),
    )

    rating: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    visitor_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    visitor_contact: Mapped[str | None] = mapped_column(String(150), nullable=True)
    event_label: Mapped[str] = mapped_column(
        String(120),
        nullable=False,
        default="Event Booth EVA",
        server_default="Event Booth EVA",
    )

    photos: Mapped[list["BoothFeedbackPhoto"]] = relationship(
        "BoothFeedbackPhoto",
        back_populates="feedback",
        cascade="all, delete-orphan",
        order_by="BoothFeedbackPhoto.sort_order",
    )


class BoothFeedbackPhoto(BaseModel):
    """Uploaded booth selfie/photo metadata linked to a BoothFeedback entry."""

    __tablename__ = "booth_feedback_photos"

    feedback_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("booth_feedbacks.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    storage_rel_path: Mapped[str] = mapped_column(String(255), nullable=False)
    original_filename: Mapped[str] = mapped_column(String(180), nullable=False)
    mime_type: Mapped[str] = mapped_column(String(50), nullable=False)
    file_size_bytes: Mapped[int] = mapped_column(Integer, nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")

    feedback: Mapped[BoothFeedback] = relationship("BoothFeedback", back_populates="photos")
