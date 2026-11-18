"""add_patient_consent

Revision ID: 0004_add_patient_consent
Revises: 0003_add_counselor_and_pricing
Create Date: 2026-11-18 10:55:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0004_add_patient_consent"
down_revision: str | None = "0003_add_counselor_and_pricing"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "patient_consents",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("patient_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("counselor_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("status", sa.String(length=30), nullable=False, server_default=sa.text("'granted'")),
        sa.Column("granted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
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
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_patient_consents_patient_id", "patient_consents", ["patient_id"])
    op.create_index("ix_patient_consents_counselor_id", "patient_consents", ["counselor_id"])
    op.create_index("ix_patient_consents_status", "patient_consents", ["status"])


def downgrade() -> None:
    op.drop_table("patient_consents")
