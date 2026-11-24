"""counselor_levels_and_reviews

Revision ID: 0010_counselor_levels_and_reviews
Revises: 0009_counselor_schedule_config
Create Date: 2026-11-24 22:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0010_counselor_levels_and_reviews"
down_revision: str | None = "0009_counselor_schedule_config"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = inspector.get_table_names()

    # 1. Create psychologist_levels table
    if "psychologist_levels" not in tables:
        op.create_table(
            "psychologist_levels",
            sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("level_tier", sa.Integer(), nullable=False, unique=True, index=True),
            sa.Column("name", sa.String(length=100), nullable=False),
            sa.Column("badge_icon", sa.String(length=100), nullable=False, server_default="verified"),
            sa.Column("min_completed_sessions", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("min_average_rating", sa.Numeric(precision=3, scale=2), nullable=False, server_default="0.00"),
            sa.Column("min_consultation_hours", sa.Numeric(precision=6, scale=1), nullable=False, server_default="0.0"),
            sa.Column("min_review_count", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("default_session_price", sa.Numeric(precision=14, scale=2), nullable=False, server_default="50000.00"),
            sa.Column("platform_fee_percentage", sa.Numeric(precision=5, scale=2), nullable=False, server_default="20.00"),
            sa.Column("allow_custom_price", sa.Boolean(), nullable=False, server_default=sa.text("false")),
            sa.Column("min_custom_price", sa.Numeric(precision=14, scale=2), nullable=True),
            sa.Column("max_custom_price", sa.Numeric(precision=14, scale=2), nullable=True),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        )

        # Seed initial 4 dynamic levels
        op.execute(
            """
            INSERT INTO psychologist_levels (
                level_tier, name, badge_icon, min_completed_sessions, min_average_rating,
                min_consultation_hours, min_review_count, default_session_price, platform_fee_percentage,
                allow_custom_price, min_custom_price, max_custom_price, is_active
            ) VALUES
            (1, 'Junior Practitioner', 'shield', 0, 0.00, 0.0, 0, 50000.00, 20.00, false, null, null, true),
            (2, 'Advanced Counselor', 'star', 10, 4.50, 5.0, 5, 75000.00, 20.00, false, null, null, true),
            (3, 'Senior Specialist', 'military_tech', 30, 4.70, 15.0, 15, 100000.00, 20.00, false, null, null, true),
            (4, 'Master Expert', 'workspace_premium', 60, 4.85, 30.0, 30, 150000.00, 20.00, true, 100000.00, 500000.00, true)
            ON CONFLICT (level_tier) DO NOTHING;
            """
        )

    # 2. Add columns to psychologist_profiles
    profile_cols = {col["name"] for col in inspector.get_columns("psychologist_profiles")}

    if "current_level_id" not in profile_cols:
        op.add_column(
            "psychologist_profiles",
            sa.Column("current_level_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("psychologist_levels.id", ondelete="SET NULL"), nullable=True, index=True),
        )
    if "custom_price_per_session" not in profile_cols:
        op.add_column(
            "psychologist_profiles",
            sa.Column("custom_price_per_session", sa.Numeric(precision=14, scale=2), nullable=True),
        )
    if "total_completed_sessions" not in profile_cols:
        op.add_column(
            "psychologist_profiles",
            sa.Column("total_completed_sessions", sa.Integer(), nullable=False, server_default="0"),
        )
    if "total_consultation_hours" not in profile_cols:
        op.add_column(
            "psychologist_profiles",
            sa.Column("total_consultation_hours", sa.Numeric(precision=6, scale=1), nullable=False, server_default="0.0"),
        )
    if "average_rating" not in profile_cols:
        op.add_column(
            "psychologist_profiles",
            sa.Column("average_rating", sa.Numeric(precision=3, scale=2), nullable=False, server_default="5.00"),
        )
    if "rating_count" not in profile_cols:
        op.add_column(
            "psychologist_profiles",
            sa.Column("rating_count", sa.Integer(), nullable=False, server_default="0"),
        )

    # 3. Create counselor_reviews table
    if "counselor_reviews" not in tables:
        op.create_table(
            "counselor_reviews",
            sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("session_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("consultation_sessions.id", ondelete="CASCADE"), nullable=False, unique=True, index=True),
            sa.Column("counselor_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("psychologist_profiles.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("patient_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("rating", sa.Numeric(precision=2, scale=1), nullable=False),
            sa.Column("label", sa.String(length=150), nullable=True),
            sa.Column("review_text", sa.Text(), nullable=True),
            sa.Column("is_anonymous", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = inspector.get_table_names()

    if "counselor_reviews" in tables:
        op.drop_table("counselor_reviews")

    profile_cols = {col["name"] for col in inspector.get_columns("psychologist_profiles")}
    for col in [
        "rating_count",
        "average_rating",
        "total_consultation_hours",
        "total_completed_sessions",
        "custom_price_per_session",
        "current_level_id",
    ]:
        if col in profile_cols:
            op.drop_column("psychologist_profiles", col)

    if "psychologist_levels" in tables:
        op.drop_table("psychologist_levels")
