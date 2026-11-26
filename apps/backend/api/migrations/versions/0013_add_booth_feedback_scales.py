"""add_booth_feedback_scales

Revision ID: 0013_add_booth_feedback_scales
Revises: 0012_add_midtrans_payment_ledger
Create Date: 2026-11-26 23:45:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0013_add_booth_feedback_scales"
down_revision: str | tuple[str, ...] | None = "0012_add_midtrans_payment_ledger"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str, ...] | None = None

DEFAULT_NEUTRAL_SCORE = 3
DEFAULT_VISITOR_ROLE = "user"
SCALE_COLUMNS = ("usage_likelihood", "recommendation_score")
CHECK_CONSTRAINTS = (
    (
        "ck_booth_feedbacks_usage_likelihood_range",
        "usage_likelihood >= 1 AND usage_likelihood <= 5",
    ),
    (
        "ck_booth_feedbacks_recommendation_score_range",
        "recommendation_score >= 1 AND recommendation_score <= 5",
    ),
    (
        "ck_booth_feedbacks_visitor_role",
        "visitor_role IN ('user', 'counselor')",
    ),
)
INDEX_NAMES = (
    ("ix_booth_feedbacks_usage_likelihood", ["usage_likelihood"]),
    ("ix_booth_feedbacks_recommendation_score", ["recommendation_score"]),
    ("ix_booth_feedbacks_visitor_role", ["visitor_role"]),
)


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if not inspector.has_table("booth_feedbacks"):
        return

    existing_cols = {col["name"] for col in inspector.get_columns("booth_feedbacks")}
    for col_name in SCALE_COLUMNS:
        if col_name not in existing_cols:
            op.add_column("booth_feedbacks", sa.Column(col_name, sa.Integer(), nullable=True))

    if "visitor_role" not in existing_cols:
        op.add_column(
            "booth_feedbacks",
            sa.Column("visitor_role", sa.String(length=30), nullable=True),
        )

    op.execute(
        sa.text(
            f"""
            UPDATE booth_feedbacks
            SET usage_likelihood = COALESCE(usage_likelihood, {DEFAULT_NEUTRAL_SCORE}),
                recommendation_score = COALESCE(recommendation_score, {DEFAULT_NEUTRAL_SCORE}),
                visitor_role = COALESCE(visitor_role, '{DEFAULT_VISITOR_ROLE}')
            WHERE usage_likelihood IS NULL
               OR recommendation_score IS NULL
               OR visitor_role IS NULL
            """
        )
    )

    for col_name in SCALE_COLUMNS:
        op.alter_column(
            "booth_feedbacks",
            col_name,
            existing_type=sa.Integer(),
            nullable=False,
        )

    op.alter_column(
        "booth_feedbacks",
        "visitor_role",
        existing_type=sa.String(length=30),
        server_default=DEFAULT_VISITOR_ROLE,
        nullable=False,
    )

    existing_checks = {
        ck["name"] for ck in inspector.get_check_constraints("booth_feedbacks") if ck.get("name")
    }
    for ck_name, condition in CHECK_CONSTRAINTS:
        if ck_name not in existing_checks:
            op.create_check_constraint(ck_name, "booth_feedbacks", condition)

    existing_indexes = {
        idx["name"] for idx in inspector.get_indexes("booth_feedbacks") if idx.get("name")
    }
    for idx_name, cols in INDEX_NAMES:
        if idx_name not in existing_indexes:
            op.create_index(idx_name, "booth_feedbacks", cols)


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if not inspector.has_table("booth_feedbacks"):
        return

    existing_indexes = {
        idx["name"] for idx in inspector.get_indexes("booth_feedbacks") if idx.get("name")
    }
    for idx_name, _ in INDEX_NAMES:
        if idx_name in existing_indexes:
            op.drop_index(idx_name, table_name="booth_feedbacks")

    existing_checks = {
        ck["name"] for ck in inspector.get_check_constraints("booth_feedbacks") if ck.get("name")
    }
    for ck_name, _ in CHECK_CONSTRAINTS:
        if ck_name in existing_checks:
            op.drop_constraint(ck_name, "booth_feedbacks", type_="check")

    existing_cols = {col["name"] for col in inspector.get_columns("booth_feedbacks")}
    for col_name in (*SCALE_COLUMNS, "visitor_role"):
        if col_name in existing_cols:
            op.drop_column("booth_feedbacks", col_name)
