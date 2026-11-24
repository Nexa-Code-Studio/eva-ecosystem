"""add_coin_packages_economy

Revision ID: 0007_add_coin_packages_economy
Revises: 0006_add_psychologist_doc_fields
Create Date: 2026-11-23 19:40:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0007_add_coin_packages_economy"
down_revision: str | None = "0006_add_psychologist_doc_fields"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if not inspector.has_table("coin_packages"):
        op.create_table(
            "coin_packages",
            sa.Column(
                "id",
                postgresql.UUID(as_uuid=True),
                server_default=sa.text("gen_random_uuid()"),
                nullable=False,
            ),
            sa.Column("code", sa.String(length=40), nullable=False),
            sa.Column("name", sa.String(length=150), nullable=False),
            sa.Column("coins", sa.Integer(), nullable=False),
            sa.Column("bonus_coins", sa.Integer(), nullable=False, server_default=sa.text("0")),
            sa.Column("price_idr", sa.Integer(), nullable=False),
            sa.Column("description", sa.Text(), nullable=False, server_default=sa.text("''")),
            sa.Column("is_popular", sa.Boolean(), nullable=False, server_default=sa.text("false")),
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
            sa.UniqueConstraint("code"),
        )
        op.create_index("ix_coin_packages_code", "coin_packages", ["code"])
        op.create_index("ix_coin_packages_is_active", "coin_packages", ["is_active"])

    if not inspector.has_table("coin_economy_configs"):
        op.create_table(
            "coin_economy_configs",
            sa.Column(
                "id",
                postgresql.UUID(as_uuid=True),
                server_default=sa.text("gen_random_uuid()"),
                nullable=False,
            ),
            sa.Column(
                "base_price_per_coin_idr",
                sa.Integer(),
                nullable=False,
                server_default=sa.text("1000"),
            ),
            sa.Column(
                "free_trial_coins_new_user",
                sa.Integer(),
                nullable=False,
                server_default=sa.text("10"),
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
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if inspector.has_table("coin_economy_configs"):
        op.drop_table("coin_economy_configs")
    if inspector.has_table("coin_packages"):
        op.drop_index("ix_coin_packages_is_active", table_name="coin_packages")
        op.drop_index("ix_coin_packages_code", table_name="coin_packages")
        op.drop_table("coin_packages")
