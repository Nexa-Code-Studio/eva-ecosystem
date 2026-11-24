"""add_crisis_config_and_faqs

Revision ID: 0008_add_crisis_config_and_faqs
Revises: 0007_add_coin_packages_economy
Create Date: 2026-11-23 22:45:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0008_add_crisis_config_and_faqs"
down_revision: str | None = "0007_add_coin_packages_economy"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if not inspector.has_table("crisis_configs"):
        op.create_table(
            "crisis_configs",
            sa.Column(
                "id",
                postgresql.UUID(as_uuid=True),
                server_default=sa.text("gen_random_uuid()"),
                nullable=False,
            ),
            sa.Column(
                "hotline_number",
                sa.String(length=50),
                nullable=False,
                server_default=sa.text("'119 EXT 8'"),
            ),
            sa.Column(
                "hotline_label",
                sa.String(length=150),
                nullable=False,
                server_default=sa.text("'Layanan Darurat Kemenkes RI'"),
            ),
            sa.Column(
                "extreme_depression_threshold",
                sa.Integer(),
                nullable=False,
                server_default=sa.text("28"),
            ),
            sa.Column(
                "extreme_anxiety_threshold",
                sa.Integer(),
                nullable=False,
                server_default=sa.text("20"),
            ),
            sa.Column(
                "auto_safety_net_modal",
                sa.Boolean(),
                nullable=False,
                server_default=sa.text("true"),
            ),
            sa.Column(
                "allow_direct_independent_referral",
                sa.Boolean(),
                nullable=False,
                server_default=sa.text("true"),
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

    if not inspector.has_table("faq_entries"):
        op.create_table(
            "faq_entries",
            sa.Column(
                "id",
                postgresql.UUID(as_uuid=True),
                server_default=sa.text("gen_random_uuid()"),
                nullable=False,
            ),
            sa.Column("category", sa.String(length=100), nullable=False),
            sa.Column("question", sa.String(length=500), nullable=False),
            sa.Column("answer", sa.Text(), nullable=False),
            sa.Column(
                "is_published",
                sa.Boolean(),
                nullable=False,
                server_default=sa.text("true"),
            ),
            sa.Column(
                "sort_order",
                sa.Integer(),
                nullable=False,
                server_default=sa.text("0"),
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
        op.create_index("ix_faq_entries_category", "faq_entries", ["category"])
        op.create_index("ix_faq_entries_is_published", "faq_entries", ["is_published"])
        op.create_index("ix_faq_entries_sort_order", "faq_entries", ["sort_order"])


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if inspector.has_table("faq_entries"):
        op.drop_index("ix_faq_entries_sort_order", table_name="faq_entries")
        op.drop_index("ix_faq_entries_is_published", table_name="faq_entries")
        op.drop_index("ix_faq_entries_category", table_name="faq_entries")
        op.drop_table("faq_entries")

    if inspector.has_table("crisis_configs"):
        op.drop_table("crisis_configs")
