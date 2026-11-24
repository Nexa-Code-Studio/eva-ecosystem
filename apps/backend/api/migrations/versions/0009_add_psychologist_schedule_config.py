"""add_psychologist_schedule_config

Revision ID: 0009_add_psychologist_schedule_config
Revises: 0008_add_crisis_config_and_faqs
Create Date: 2026-11-24 21:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0009_add_psychologist_schedule_config"
down_revision: str | None = "0008_add_crisis_config_and_faqs"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    cols = {col["name"] for col in inspector.get_columns("psychologist_profiles")}

    if "schedule_config" not in cols:
        op.add_column(
            "psychologist_profiles",
            sa.Column(
                "schedule_config",
                postgresql.JSONB(astext_type=sa.Text()),
                nullable=False,
                server_default=sa.text("'{}'::jsonb"),
            ),
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    cols = {col["name"] for col in inspector.get_columns("psychologist_profiles")}

    if "schedule_config" in cols:
        op.drop_column("psychologist_profiles", "schedule_config")
