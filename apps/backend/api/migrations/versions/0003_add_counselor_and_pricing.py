"""add_counselor_and_pricing

Revision ID: 0003_add_counselor_and_pricing
Revises: 0002_add_dass_assessments
Create Date: 2026-11-18 10:40:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0003_add_counselor_and_pricing"
down_revision: str | None = "0002_add_dass_assessments"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 1. Table: psychologist_profiles
    op.create_table(
        "psychologist_profiles",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("full_name", sa.String(length=200), nullable=False),
        sa.Column("title_degree", sa.String(length=100), nullable=False, server_default=sa.text("'M.Psi., Psikolog'")),
        sa.Column("str_number", sa.String(length=100), nullable=False),
        sa.Column("sip_number", sa.String(length=100), nullable=True),
        sa.Column(
            "association",
            sa.String(length=150),
            nullable=False,
            server_default=sa.text("'Himpunan Psikologi Indonesia (HIMPSI)'"),
        ),
        sa.Column("specializations", postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default=sa.text("'[]'::jsonb")),
        sa.Column("years_of_experience", sa.Integer(), nullable=False, server_default=sa.text("1")),
        sa.Column("bio", sa.Text(), nullable=True),
        sa.Column("profile_photo_url", sa.Text(), nullable=True),
        sa.Column("certificate_doc_url", sa.Text(), nullable=True),
        sa.Column("verification_status", sa.String(length=30), nullable=False, server_default=sa.text("'pending'")),
        sa.Column("verification_notes", sa.Text(), nullable=True),
        sa.Column("verified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("verified_by_user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("is_online", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("buffer_time_minutes", sa.Integer(), nullable=False, server_default=sa.text("10")),
        sa.Column("bank_name", sa.String(length=100), nullable=True),
        sa.Column("bank_account_number", sa.String(length=50), nullable=True),
        sa.Column("bank_account_holder", sa.String(length=200), nullable=True),
        sa.Column("wallet_balance", sa.Numeric(precision=14, scale=2), nullable=False, server_default=sa.text("0.00")),
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
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["verified_by_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id"),
    )
    op.create_index("ix_psychologist_profiles_user_id", "psychologist_profiles", ["user_id"])
    op.create_index("ix_psychologist_profiles_str_number", "psychologist_profiles", ["str_number"])
    op.create_index("ix_psychologist_profiles_sip_number", "psychologist_profiles", ["sip_number"])
    op.create_index("ix_psychologist_profiles_verification_status", "psychologist_profiles", ["verification_status"])

    # 2. Table: platform_pricing_configs
    op.create_table(
        "platform_pricing_configs",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("session_duration_minutes", sa.Integer(), nullable=False, server_default=sa.text("30")),
        sa.Column("price_per_session", sa.Numeric(precision=14, scale=2), nullable=False, server_default=sa.text("0.00")),
        sa.Column("counselor_share_percentage", sa.Numeric(precision=5, scale=2), nullable=False, server_default=sa.text("0.00")),
        sa.Column("platform_fee_percentage", sa.Numeric(precision=5, scale=2), nullable=False, server_default=sa.text("0.00")),
        sa.Column("extension_price_per_session", sa.Numeric(precision=14, scale=2), nullable=False, server_default=sa.text("0.00")),
        sa.Column("status", sa.String(length=30), nullable=False, server_default=sa.text("'active'")),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column(
            "effective_from",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("effective_until", sa.DateTime(timezone=True), nullable=True),
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
    )
    op.create_index("ix_platform_pricing_configs_status", "platform_pricing_configs", ["status"])

    # 3. Table: consultation_sessions
    op.create_table(
        "consultation_sessions",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("session_code", sa.String(length=50), nullable=False),
        sa.Column("patient_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("counselor_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("pricing_config_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("scheduled_start_time", sa.DateTime(timezone=True), nullable=False),
        sa.Column("scheduled_end_time", sa.DateTime(timezone=True), nullable=False),
        sa.Column("actual_start_time", sa.DateTime(timezone=True), nullable=True),
        sa.Column("actual_end_time", sa.DateTime(timezone=True), nullable=True),
        sa.Column("duration_minutes", sa.Integer(), nullable=False, server_default=sa.text("30")),
        sa.Column("status", sa.String(length=30), nullable=False, server_default=sa.text("'scheduled'")),
        sa.Column("is_extended", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("extension_requested_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("extension_granted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("total_price", sa.Numeric(precision=14, scale=2), nullable=False, server_default=sa.text("0.00")),
        sa.Column("counselor_earning", sa.Numeric(precision=14, scale=2), nullable=False, server_default=sa.text("0.00")),
        sa.Column("platform_fee", sa.Numeric(precision=14, scale=2), nullable=False, server_default=sa.text("0.00")),
        sa.Column("video_room_id", sa.String(length=100), nullable=True),
        sa.Column("soap_notes", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("cancellation_reason", sa.Text(), nullable=True),
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
        sa.ForeignKeyConstraint(["patient_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["counselor_id"], ["psychologist_profiles.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["pricing_config_id"], ["platform_pricing_configs.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("session_code"),
    )
    op.create_index("ix_consultation_sessions_session_code", "consultation_sessions", ["session_code"])
    op.create_index("ix_consultation_sessions_patient_id", "consultation_sessions", ["patient_id"])
    op.create_index("ix_consultation_sessions_counselor_id", "consultation_sessions", ["counselor_id"])
    op.create_index("ix_consultation_sessions_scheduled_start_time", "consultation_sessions", ["scheduled_start_time"])
    op.create_index("ix_consultation_sessions_scheduled_end_time", "consultation_sessions", ["scheduled_end_time"])
    op.create_index("ix_consultation_sessions_status", "consultation_sessions", ["status"])

    # 4. Table: counselor_transactions
    op.create_table(
        "counselor_transactions",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("counselor_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("session_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("transaction_type", sa.String(length=30), nullable=False, server_default=sa.text("'earning'")),
        sa.Column("status", sa.String(length=30), nullable=False, server_default=sa.text("'completed'")),
        sa.Column("amount", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("reference_number", sa.String(length=100), nullable=True),
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
        sa.ForeignKeyConstraint(["counselor_id"], ["psychologist_profiles.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["session_id"], ["consultation_sessions.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_counselor_transactions_counselor_id", "counselor_transactions", ["counselor_id"])
    op.create_index("ix_counselor_transactions_session_id", "counselor_transactions", ["session_id"])
    op.create_index("ix_counselor_transactions_transaction_type", "counselor_transactions", ["transaction_type"])
    op.create_index("ix_counselor_transactions_status", "counselor_transactions", ["status"])
    op.create_index("ix_counselor_transactions_reference_number", "counselor_transactions", ["reference_number"])


def downgrade() -> None:
    op.drop_table("counselor_transactions")
    op.drop_table("consultation_sessions")
    op.drop_table("platform_pricing_configs")
    op.drop_table("psychologist_profiles")
