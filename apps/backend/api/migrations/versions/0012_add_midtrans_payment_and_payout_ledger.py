"""add_midtrans_payment_and_payout_ledger

Revision ID: 0012_add_midtrans_payment_ledger
Revises: 0011_add_booth_feedbacks
Create Date: 2026-11-25 16:05:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0012_add_midtrans_payment_ledger"
down_revision: str | tuple[str, ...] | None = "0011_add_booth_feedbacks"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str, ...] | None = None


def _backfill_legacy_bank_accounts(bind: sa.Connection) -> None:
    """Migrate legacy plaintext psychologist bank fields into counselor_bank_accounts as unverified."""
    rows = bind.execute(
        sa.text(
            """
            SELECT id, bank_name, bank_account_number, bank_account_holder, full_name
            FROM psychologist_profiles
            WHERE bank_account_number IS NOT NULL
              AND BTRIM(bank_account_number) <> ''
            """
        )
    ).mappings().all()

    for row in rows:
        existing = bind.execute(
            sa.text(
                """
                SELECT 1 FROM counselor_bank_accounts
                WHERE counselor_id = :counselor_id
                LIMIT 1
                """
            ),
            {"counselor_id": row["id"]},
        ).first()
        if existing:
            continue

        raw_number = str(row["bank_account_number"] or "").strip()
        last4 = raw_number[-4:] if len(raw_number) >= 4 else raw_number
        masked = f"****{last4}" if last4 else "****"
        bank_name = str(row["bank_name"] or "Bank Tidak Diketahui").strip()
        bank_code = bank_name.lower().replace(" ", "_")[:50] or "legacy"
        holder = str(row["bank_account_holder"] or row["full_name"] or "").strip()

        bind.execute(
            sa.text(
                """
                INSERT INTO counselor_bank_accounts (
                    counselor_id, bank_code, bank_name, account_number_encrypted,
                    account_number_masked, account_holder_name, verification_status,
                    verified_at, account_revision, is_active
                ) VALUES (
                    :counselor_id, :bank_code, :bank_name, NULL,
                    :masked, :holder, 'unverified',
                    NULL, 1, true
                )
                """
            ),
            {
                "counselor_id": row["id"],
                "bank_code": bank_code,
                "bank_name": bank_name,
                "masked": masked,
                "holder": holder,
            },
        )


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    profile_cols = {col["name"] for col in inspector.get_columns("psychologist_profiles")}
    if "locked_withdrawal_balance" not in profile_cols:
        op.add_column(
            "psychologist_profiles",
            sa.Column(
                "locked_withdrawal_balance",
                sa.Numeric(precision=14, scale=2),
                server_default="0.00",
                nullable=False,
            ),
        )

    if not inspector.has_table("coin_topup_orders"):
        op.create_table(
            "coin_topup_orders",
            sa.Column(
                "id",
                postgresql.UUID(as_uuid=True),
                server_default=sa.text("gen_random_uuid()"),
                nullable=False,
            ),
            sa.Column("order_id", sa.String(length=64), nullable=False),
            sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("package_id", postgresql.UUID(as_uuid=True), nullable=True),
            sa.Column("package_code", sa.String(length=40), nullable=False),
            sa.Column("package_name", sa.String(length=150), nullable=False),
            sa.Column("coins_snapshot", sa.Integer(), nullable=False),
            sa.Column("bonus_coins_snapshot", sa.Integer(), server_default="0", nullable=False),
            sa.Column("total_coins_snapshot", sa.Integer(), nullable=False),
            sa.Column("amount_idr", sa.Integer(), nullable=False),
            sa.Column("currency", sa.String(length=10), server_default="IDR", nullable=False),
            sa.Column("payment_method", sa.String(length=30), server_default="qris", nullable=False),
            sa.Column("idempotency_key", sa.String(length=128), nullable=False),
            sa.Column("request_hash", sa.String(length=64), nullable=False),
            sa.Column("status", sa.String(length=30), server_default="creating", nullable=False),
            sa.Column("provider_transaction_id", sa.String(length=120), nullable=True),
            sa.Column("qr_image_url", sa.Text(), nullable=True),
            sa.Column("qr_image_v2_url", sa.Text(), nullable=True),
            sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("refunded_amount_idr", sa.Integer(), server_default="0", nullable=False),
            sa.Column("coin_transaction_id", postgresql.UUID(as_uuid=True), nullable=True),
            sa.Column("reconciliation_status", sa.String(length=30), server_default="pending", nullable=False),
            sa.Column("failure_code", sa.String(length=60), nullable=True),
            sa.Column("failure_message", sa.Text(), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.ForeignKeyConstraint(["coin_transaction_id"], ["coin_transactions.id"], ondelete="SET NULL"),
            sa.ForeignKeyConstraint(["package_id"], ["coin_packages.id"], ondelete="SET NULL"),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("coin_transaction_id"),
            sa.UniqueConstraint("order_id"),
            sa.UniqueConstraint("provider_transaction_id"),
            sa.UniqueConstraint("user_id", "idempotency_key", name="uq_coin_topup_orders_user_idem"),
        )
        op.create_index("ix_coin_topup_orders_order_id", "coin_topup_orders", ["order_id"])
        op.create_index("ix_coin_topup_orders_user_id", "coin_topup_orders", ["user_id"])
        op.create_index("ix_coin_topup_orders_package_id", "coin_topup_orders", ["package_id"])
        op.create_index("ix_coin_topup_orders_status", "coin_topup_orders", ["status"])
        op.create_index(
            "ix_coin_topup_orders_reconciliation_status",
            "coin_topup_orders",
            ["reconciliation_status"],
        )

    if not inspector.has_table("bank_account_validations"):
        op.create_table(
            "bank_account_validations",
            sa.Column(
                "id",
                postgresql.UUID(as_uuid=True),
                server_default=sa.text("gen_random_uuid()"),
                nullable=False,
            ),
            sa.Column("counselor_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("bank_code", sa.String(length=50), nullable=False),
            sa.Column("bank_name", sa.String(length=120), nullable=False),
            sa.Column("account_number_encrypted", sa.Text(), nullable=False),
            sa.Column("account_number_masked", sa.String(length=32), nullable=False),
            sa.Column("account_holder_name", sa.String(length=200), nullable=False),
            sa.Column("status", sa.String(length=30), nullable=False),
            sa.Column("name_match", sa.String(length=30), nullable=False),
            sa.Column("provider_payload_redacted", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
            sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.ForeignKeyConstraint(["counselor_id"], ["psychologist_profiles.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index("ix_bank_account_validations_counselor_id", "bank_account_validations", ["counselor_id"])
        op.create_index("ix_bank_account_validations_status", "bank_account_validations", ["status"])

    if not inspector.has_table("counselor_bank_accounts"):
        op.create_table(
            "counselor_bank_accounts",
            sa.Column(
                "id",
                postgresql.UUID(as_uuid=True),
                server_default=sa.text("gen_random_uuid()"),
                nullable=False,
            ),
            sa.Column("counselor_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("validation_id", postgresql.UUID(as_uuid=True), nullable=True),
            sa.Column("bank_code", sa.String(length=50), nullable=False),
            sa.Column("bank_name", sa.String(length=120), nullable=False),
            sa.Column("account_number_encrypted", sa.Text(), nullable=True),
            sa.Column("account_number_masked", sa.String(length=32), nullable=False),
            sa.Column("account_holder_name", sa.String(length=200), nullable=False),
            sa.Column("verification_status", sa.String(length=30), server_default="unverified", nullable=False),
            sa.Column("verified_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("account_revision", sa.Integer(), server_default="1", nullable=False),
            sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.ForeignKeyConstraint(["counselor_id"], ["psychologist_profiles.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["validation_id"], ["bank_account_validations.id"], ondelete="SET NULL"),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index("ix_counselor_bank_accounts_counselor_id", "counselor_bank_accounts", ["counselor_id"])
        op.create_index(
            "ix_counselor_bank_accounts_verification_status",
            "counselor_bank_accounts",
            ["verification_status"],
        )
        op.create_index(
            "uq_counselor_bank_accounts_active",
            "counselor_bank_accounts",
            ["counselor_id"],
            unique=True,
            postgresql_where=sa.text("is_active IS TRUE"),
        )
        _backfill_legacy_bank_accounts(bind)

    if not inspector.has_table("payout_quotes"):
        op.create_table(
            "payout_quotes",
            sa.Column(
                "id",
                postgresql.UUID(as_uuid=True),
                server_default=sa.text("gen_random_uuid()"),
                nullable=False,
            ),
            sa.Column("counselor_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("bank_account_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("account_revision", sa.Integer(), nullable=False),
            sa.Column("amount_idr", sa.Integer(), nullable=False),
            sa.Column("fee_idr", sa.Integer(), nullable=False),
            sa.Column("fee_bearer", sa.String(length=30), server_default="counselor", nullable=False),
            sa.Column("net_amount_idr", sa.Integer(), nullable=False),
            sa.Column("wallet_debit_idr", sa.Integer(), nullable=False),
            sa.Column("currency", sa.String(length=10), server_default="IDR", nullable=False),
            sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.ForeignKeyConstraint(["bank_account_id"], ["counselor_bank_accounts.id"], ondelete="RESTRICT"),
            sa.ForeignKeyConstraint(["counselor_id"], ["psychologist_profiles.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index("ix_payout_quotes_counselor_id", "payout_quotes", ["counselor_id"])
        op.create_index("ix_payout_quotes_bank_account_id", "payout_quotes", ["bank_account_id"])

    if not inspector.has_table("counselor_withdrawals"):
        op.create_table(
            "counselor_withdrawals",
            sa.Column(
                "id",
                postgresql.UUID(as_uuid=True),
                server_default=sa.text("gen_random_uuid()"),
                nullable=False,
            ),
            sa.Column("reference_id", sa.String(length=64), nullable=False),
            sa.Column("counselor_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("bank_account_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("quote_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("account_revision", sa.Integer(), nullable=False),
            sa.Column("idempotency_key", sa.String(length=128), nullable=False),
            sa.Column("request_hash", sa.String(length=64), nullable=False),
            sa.Column("amount_idr", sa.Integer(), nullable=False),
            sa.Column("fee_idr", sa.Integer(), nullable=False),
            sa.Column("fee_bearer", sa.String(length=30), server_default="counselor", nullable=False),
            sa.Column("net_amount_idr", sa.Integer(), nullable=False),
            sa.Column("wallet_debit_idr", sa.Integer(), nullable=False),
            sa.Column("currency", sa.String(length=10), server_default="IDR", nullable=False),
            sa.Column("status", sa.String(length=30), server_default="requested", nullable=False),
            sa.Column("provider_reference", sa.String(length=120), nullable=True),
            sa.Column("reconciliation_status", sa.String(length=30), server_default="pending", nullable=False),
            sa.Column("counselor_transaction_id", postgresql.UUID(as_uuid=True), nullable=True),
            sa.Column("bank_snapshot_json", postgresql.JSONB(astext_type=sa.Text()), server_default="{}", nullable=False),
            sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("failure_code", sa.String(length=60), nullable=True),
            sa.Column("failure_message", sa.Text(), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.ForeignKeyConstraint(["bank_account_id"], ["counselor_bank_accounts.id"], ondelete="RESTRICT"),
            sa.ForeignKeyConstraint(["counselor_id"], ["psychologist_profiles.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["counselor_transaction_id"], ["counselor_transactions.id"], ondelete="SET NULL"),
            sa.ForeignKeyConstraint(["quote_id"], ["payout_quotes.id"], ondelete="RESTRICT"),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("counselor_transaction_id"),
            sa.UniqueConstraint("quote_id"),
            sa.UniqueConstraint("reference_id"),
            sa.UniqueConstraint("counselor_id", "idempotency_key", name="uq_counselor_withdrawals_idem"),
        )
        op.create_index("ix_counselor_withdrawals_reference_id", "counselor_withdrawals", ["reference_id"])
        op.create_index("ix_counselor_withdrawals_counselor_id", "counselor_withdrawals", ["counselor_id"])
        op.create_index("ix_counselor_withdrawals_bank_account_id", "counselor_withdrawals", ["bank_account_id"])
        op.create_index("ix_counselor_withdrawals_status", "counselor_withdrawals", ["status"])
        op.create_index("ix_counselor_withdrawals_provider_reference", "counselor_withdrawals", ["provider_reference"])
        op.create_index(
            "ix_counselor_withdrawals_reconciliation_status",
            "counselor_withdrawals",
            ["reconciliation_status"],
        )

    if not inspector.has_table("counselor_withdrawal_events"):
        op.create_table(
            "counselor_withdrawal_events",
            sa.Column(
                "id",
                postgresql.UUID(as_uuid=True),
                server_default=sa.text("gen_random_uuid()"),
                nullable=False,
            ),
            sa.Column("withdrawal_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("status", sa.String(length=30), nullable=False),
            sa.Column("source", sa.String(length=30), nullable=False),
            sa.Column("message", sa.Text(), nullable=False),
            sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.ForeignKeyConstraint(["withdrawal_id"], ["counselor_withdrawals.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(
            "ix_counselor_withdrawal_events_withdrawal_id",
            "counselor_withdrawal_events",
            ["withdrawal_id"],
        )

    if not inspector.has_table("payment_webhook_inbox"):
        op.create_table(
            "payment_webhook_inbox",
            sa.Column(
                "id",
                postgresql.UUID(as_uuid=True),
                server_default=sa.text("gen_random_uuid()"),
                nullable=False,
            ),
            sa.Column("provider", sa.String(length=30), nullable=False),
            sa.Column("event_key", sa.String(length=128), nullable=False),
            sa.Column("order_or_ref_id", sa.String(length=120), nullable=False),
            sa.Column("payload_json", postgresql.JSONB(astext_type=sa.Text()), server_default="{}", nullable=False),
            sa.Column("signature_valid", sa.Boolean(), server_default="false", nullable=False),
            sa.Column("process_status", sa.String(length=30), server_default="pending", nullable=False),
            sa.Column("attempts", sa.Integer(), server_default="0", nullable=False),
            sa.Column("last_error", sa.Text(), nullable=True),
            sa.Column("processed_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("provider", "event_key", name="uq_payment_webhook_inbox_event"),
        )
        op.create_index("ix_payment_webhook_inbox_provider", "payment_webhook_inbox", ["provider"])
        op.create_index("ix_payment_webhook_inbox_order_or_ref_id", "payment_webhook_inbox", ["order_or_ref_id"])
        op.create_index("ix_payment_webhook_inbox_process_status", "payment_webhook_inbox", ["process_status"])

    if not inspector.has_table("payment_outbox_events"):
        op.create_table(
            "payment_outbox_events",
            sa.Column(
                "id",
                postgresql.UUID(as_uuid=True),
                server_default=sa.text("gen_random_uuid()"),
                nullable=False,
            ),
            sa.Column("aggregate_type", sa.String(length=40), nullable=False),
            sa.Column("aggregate_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("event_type", sa.String(length=60), nullable=False),
            sa.Column("payload_json", postgresql.JSONB(astext_type=sa.Text()), server_default="{}", nullable=False),
            sa.Column("status", sa.String(length=30), server_default="pending", nullable=False),
            sa.Column("attempts", sa.Integer(), server_default="0", nullable=False),
            sa.Column("next_retry_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("last_error", sa.Text(), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index("ix_payment_outbox_events_aggregate_type", "payment_outbox_events", ["aggregate_type"])
        op.create_index("ix_payment_outbox_events_aggregate_id", "payment_outbox_events", ["aggregate_id"])
        op.create_index("ix_payment_outbox_events_status", "payment_outbox_events", ["status"])
        op.create_index("ix_payment_outbox_events_next_retry_at", "payment_outbox_events", ["next_retry_at"])


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    for table_name in (
        "payment_outbox_events",
        "payment_webhook_inbox",
        "counselor_withdrawal_events",
        "counselor_withdrawals",
        "payout_quotes",
        "counselor_bank_accounts",
        "bank_account_validations",
        "coin_topup_orders",
    ):
        if inspector.has_table(table_name):
            op.drop_table(table_name)

    profile_cols = {col["name"] for col in inspector.get_columns("psychologist_profiles")}
    if "locked_withdrawal_balance" in profile_cols:
        op.drop_column("psychologist_profiles", "locked_withdrawal_balance")
