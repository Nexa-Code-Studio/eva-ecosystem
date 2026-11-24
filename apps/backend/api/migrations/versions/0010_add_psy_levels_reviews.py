"""add_psy_levels_reviews

Revision ID: 0010_add_psy_levels_reviews
Revises: 0009_add_psy_certificates, 0009_counselor_schedule_config
Create Date: 2026-11-24 22:30:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0010_add_psy_levels_reviews"
down_revision: str | tuple[str, ...] | None = (
    "0009_add_psy_certificates",
    "0009_counselor_schedule_config",
)
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if not inspector.has_table("psychologist_levels"):
        op.create_table(
            "psychologist_levels",
            sa.Column(
                "id",
                postgresql.UUID(as_uuid=True),
                server_default=sa.text("gen_random_uuid()"),
                nullable=False,
            ),
            sa.Column("level_tier", sa.Integer(), nullable=False),
            sa.Column("name", sa.String(length=120), nullable=False),
            sa.Column(
                "badge_icon",
                sa.String(length=60),
                nullable=False,
                server_default=sa.text("'award'"),
            ),
            sa.Column("min_completed_sessions", sa.Integer(), nullable=False, server_default="0"),
            sa.Column(
                "min_average_rating",
                sa.Numeric(precision=3, scale=2),
                nullable=False,
                server_default=sa.text("0.00"),
            ),
            sa.Column(
                "min_consultation_hours",
                sa.Numeric(precision=10, scale=2),
                nullable=False,
                server_default=sa.text("0.00"),
            ),
            sa.Column("min_review_count", sa.Integer(), nullable=False, server_default="0"),
            sa.Column(
                "default_session_price",
                sa.Numeric(precision=14, scale=2),
                nullable=False,
                server_default=sa.text("150.00"),
            ),
            sa.Column(
                "platform_fee_percentage",
                sa.Numeric(precision=5, scale=2),
                nullable=False,
                server_default=sa.text("20.00"),
            ),
            sa.Column(
                "allow_custom_price",
                sa.Boolean(),
                nullable=False,
                server_default=sa.text("false"),
            ),
            sa.Column("min_custom_price", sa.Numeric(precision=14, scale=2), nullable=True),
            sa.Column("max_custom_price", sa.Numeric(precision=14, scale=2), nullable=True),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
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
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("level_tier", name="uq_psychologist_levels_level_tier"),
        )
        op.create_index(
            op.f("ix_psychologist_levels_level_tier"),
            "psychologist_levels",
            ["level_tier"],
            unique=True,
        )
        op.create_index(
            op.f("ix_psychologist_levels_is_active"),
            "psychologist_levels",
            ["is_active"],
            unique=False,
        )

    cols = {col["name"] for col in inspector.get_columns("psychologist_profiles")}
    if "current_level_id" not in cols:
        op.add_column(
            "psychologist_profiles",
            sa.Column("current_level_id", postgresql.UUID(as_uuid=True), nullable=True),
        )
        op.create_foreign_key(
            "fk_psychologist_profiles_current_level_id",
            "psychologist_profiles",
            "psychologist_levels",
            ["current_level_id"],
            ["id"],
            ondelete="SET NULL",
        )
        op.create_index(
            op.f("ix_psychologist_profiles_current_level_id"),
            "psychologist_profiles",
            ["current_level_id"],
            unique=False,
        )
    if "custom_price_per_session" not in cols:
        op.add_column(
            "psychologist_profiles",
            sa.Column("custom_price_per_session", sa.Numeric(precision=14, scale=2), nullable=True),
        )
    if "total_completed_sessions" not in cols:
        op.add_column(
            "psychologist_profiles",
            sa.Column(
                "total_completed_sessions",
                sa.Integer(),
                nullable=False,
                server_default="0",
            ),
        )
    if "total_consultation_hours" not in cols:
        op.add_column(
            "psychologist_profiles",
            sa.Column(
                "total_consultation_hours",
                sa.Numeric(precision=10, scale=2),
                nullable=False,
                server_default=sa.text("0.00"),
            ),
        )
    if "average_rating" not in cols:
        op.add_column(
            "psychologist_profiles",
            sa.Column(
                "average_rating",
                sa.Numeric(precision=3, scale=2),
                nullable=False,
                server_default=sa.text("0.00"),
            ),
        )
    if "rating_count" not in cols:
        op.add_column(
            "psychologist_profiles",
            sa.Column("rating_count", sa.Integer(), nullable=False, server_default="0"),
        )

    if not inspector.has_table("counselor_reviews"):
        op.create_table(
            "counselor_reviews",
            sa.Column(
                "id",
                postgresql.UUID(as_uuid=True),
                server_default=sa.text("gen_random_uuid()"),
                nullable=False,
            ),
            sa.Column("session_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("counselor_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("patient_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("rating", sa.Numeric(precision=3, scale=2), nullable=False),
            sa.Column("highlight_label", sa.String(length=120), nullable=True),
            sa.Column("review_text", sa.Text(), nullable=True),
            sa.Column(
                "is_anonymous",
                sa.Boolean(),
                nullable=False,
                server_default=sa.text("false"),
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
            sa.PrimaryKeyConstraint("id"),
            sa.ForeignKeyConstraint(
                ["session_id"],
                ["consultation_sessions.id"],
                ondelete="CASCADE",
            ),
            sa.ForeignKeyConstraint(
                ["counselor_id"],
                ["psychologist_profiles.id"],
                ondelete="CASCADE",
            ),
            sa.ForeignKeyConstraint(["patient_id"], ["users.id"], ondelete="CASCADE"),
            sa.UniqueConstraint("session_id", name="uq_counselor_reviews_session_id"),
            sa.CheckConstraint(
                "rating >= 1.0 AND rating <= 5.0",
                name="ck_counselor_reviews_rating_range",
            ),
        )
        op.create_index(
            op.f("ix_counselor_reviews_session_id"),
            "counselor_reviews",
            ["session_id"],
            unique=False,
        )
        op.create_index(
            op.f("ix_counselor_reviews_counselor_id"),
            "counselor_reviews",
            ["counselor_id"],
            unique=False,
        )
        op.create_index(
            op.f("ix_counselor_reviews_patient_id"),
            "counselor_reviews",
            ["patient_id"],
            unique=False,
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if inspector.has_table("counselor_reviews"):
        op.drop_index(op.f("ix_counselor_reviews_patient_id"), table_name="counselor_reviews")
        op.drop_index(op.f("ix_counselor_reviews_counselor_id"), table_name="counselor_reviews")
        op.drop_index(op.f("ix_counselor_reviews_session_id"), table_name="counselor_reviews")
        op.drop_table("counselor_reviews")

    cols = {col["name"] for col in inspector.get_columns("psychologist_profiles")}
    if "rating_count" in cols:
        op.drop_column("psychologist_profiles", "rating_count")
    if "average_rating" in cols:
        op.drop_column("psychologist_profiles", "average_rating")
    if "total_consultation_hours" in cols:
        op.drop_column("psychologist_profiles", "total_consultation_hours")
    if "total_completed_sessions" in cols:
        op.drop_column("psychologist_profiles", "total_completed_sessions")
    if "custom_price_per_session" in cols:
        op.drop_column("psychologist_profiles", "custom_price_per_session")
    if "current_level_id" in cols:
        op.drop_constraint(
            "fk_psychologist_profiles_current_level_id",
            "psychologist_profiles",
            type_="foreignkey",
        )
        op.drop_index(
            op.f("ix_psychologist_profiles_current_level_id"),
            table_name="psychologist_profiles",
        )
        op.drop_column("psychologist_profiles", "current_level_id")

    if inspector.has_table("psychologist_levels"):
        op.drop_index(op.f("ix_psychologist_levels_is_active"), table_name="psychologist_levels")
        op.drop_index(op.f("ix_psychologist_levels_level_tier"), table_name="psychologist_levels")
        op.drop_table("psychologist_levels")
