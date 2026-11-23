"""add_coin_wallet_admin

Revision ID: 0005_add_coin_wallet_admin
Revises: 0004_add_patient_consent
Create Date: 2026-11-23 15:10:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0005_add_coin_wallet_admin"
down_revision: str | None = "0004_add_patient_consent"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    user_cols = {col["name"] for col in inspector.get_columns("users")}

    if "is_admin" not in user_cols:
        op.add_column(
            "users",
            sa.Column("is_admin", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        )
    if "coin_balance" not in user_cols:
        op.add_column(
            "users",
            sa.Column("coin_balance", sa.Integer(), nullable=False, server_default=sa.text("10")),
        )

    if not inspector.has_table("coin_transactions"):
        op.create_table(
            "coin_transactions",
            sa.Column(
                "id",
                postgresql.UUID(as_uuid=True),
                server_default=sa.text("gen_random_uuid()"),
                nullable=False,
            ),
            sa.Column("invoice_code", sa.String(length=60), nullable=False),
            sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("performed_by_user_id", postgresql.UUID(as_uuid=True), nullable=True),
            sa.Column(
                "transaction_type",
                sa.String(length=40),
                nullable=False,
                server_default=sa.text("'topup_admin'"),
            ),
            sa.Column("coins_delta", sa.Integer(), nullable=False),
            sa.Column("balance_after", sa.Integer(), nullable=False),
            sa.Column("amount_idr", sa.Integer(), nullable=False, server_default=sa.text("0")),
            sa.Column(
                "payment_method",
                sa.String(length=50),
                nullable=False,
                server_default=sa.text("'Transfer Bank'"),
            ),
            sa.Column("package_name", sa.String(length=150), nullable=False),
            sa.Column(
                "status",
                sa.String(length=30),
                nullable=False,
                server_default=sa.text("'completed'"),
            ),
            sa.Column("admin_notes", sa.Text(), nullable=True),
            sa.Column("reference_session_id", postgresql.UUID(as_uuid=True), nullable=True),
            sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
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
            sa.ForeignKeyConstraint(["performed_by_user_id"], ["users.id"], ondelete="SET NULL"),
            sa.ForeignKeyConstraint(
                ["reference_session_id"], ["consultation_sessions.id"], ondelete="SET NULL"
            ),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("invoice_code"),
        )
        op.create_index("ix_coin_transactions_invoice_code", "coin_transactions", ["invoice_code"])
        op.create_index("ix_coin_transactions_user_id", "coin_transactions", ["user_id"])
        op.create_index(
            "ix_coin_transactions_performed_by_user_id",
            "coin_transactions",
            ["performed_by_user_id"],
        )
        op.create_index(
            "ix_coin_transactions_transaction_type", "coin_transactions", ["transaction_type"]
        )
        op.create_index("ix_coin_transactions_status", "coin_transactions", ["status"])
        op.create_index(
            "ix_coin_transactions_reference_session_id",
            "coin_transactions",
            ["reference_session_id"],
        )


def downgrade() -> None:
    op.drop_table("coin_transactions")
    op.drop_column("users", "coin_balance")
    op.drop_column("users", "is_admin")
