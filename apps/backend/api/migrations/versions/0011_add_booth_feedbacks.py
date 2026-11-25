"""add_booth_feedbacks

Revision ID: 0011_add_booth_feedbacks
Revises: 0010_add_psy_levels_reviews
Create Date: 2026-11-25 10:40:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0011_add_booth_feedbacks"
down_revision: str | tuple[str, ...] | None = "0010_add_psy_levels_reviews"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str, ...] | None = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if not inspector.has_table("booth_feedbacks"):
        op.create_table(
            "booth_feedbacks",
            sa.Column(
                "id",
                postgresql.UUID(as_uuid=True),
                server_default=sa.text("gen_random_uuid()"),
                nullable=False,
            ),
            sa.Column("rating", sa.Integer(), nullable=False),
            sa.Column("message", sa.Text(), nullable=False),
            sa.Column("visitor_name", sa.String(length=120), nullable=True),
            sa.Column("visitor_contact", sa.String(length=150), nullable=True),
            sa.Column(
                "event_label",
                sa.String(length=120),
                server_default="Event Booth EVA",
                nullable=False,
            ),
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                server_default=sa.text("now()"),
                nullable=False,
            ),
            sa.Column(
                "updated_at",
                sa.DateTime(timezone=True),
                server_default=sa.text("now()"),
                nullable=False,
            ),
            sa.CheckConstraint("rating >= 1 AND rating <= 5", name="ck_booth_feedbacks_rating_range"),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index("ix_booth_feedbacks_rating", "booth_feedbacks", ["rating"])

    if not inspector.has_table("booth_feedback_photos"):
        op.create_table(
            "booth_feedback_photos",
            sa.Column(
                "id",
                postgresql.UUID(as_uuid=True),
                server_default=sa.text("gen_random_uuid()"),
                nullable=False,
            ),
            sa.Column("feedback_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("storage_rel_path", sa.String(length=255), nullable=False),
            sa.Column("original_filename", sa.String(length=180), nullable=False),
            sa.Column("mime_type", sa.String(length=50), nullable=False),
            sa.Column("file_size_bytes", sa.Integer(), nullable=False),
            sa.Column("sort_order", sa.Integer(), server_default="0", nullable=False),
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                server_default=sa.text("now()"),
                nullable=False,
            ),
            sa.Column(
                "updated_at",
                sa.DateTime(timezone=True),
                server_default=sa.text("now()"),
                nullable=False,
            ),
            sa.ForeignKeyConstraint(["feedback_id"], ["booth_feedbacks.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index("ix_booth_feedback_photos_feedback_id", "booth_feedback_photos", ["feedback_id"])


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if inspector.has_table("booth_feedback_photos"):
        op.drop_index("ix_booth_feedback_photos_feedback_id", table_name="booth_feedback_photos")
        op.drop_table("booth_feedback_photos")

    if inspector.has_table("booth_feedbacks"):
        op.drop_index("ix_booth_feedbacks_rating", table_name="booth_feedbacks")
        op.drop_table("booth_feedbacks")
