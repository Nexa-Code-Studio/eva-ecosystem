"""add_psychologist_doc_fields

Revision ID: 0006_add_psychologist_doc_fields
Revises: 0005_add_coin_wallet_admin
Create Date: 2026-11-23 19:02:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0006_add_psychologist_doc_fields"
down_revision: str | None = "0005_add_coin_wallet_admin"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    cols = {col["name"] for col in inspector.get_columns("psychologist_profiles")}

    columns_to_add = [
        ("education", sa.Column("education", sa.String(length=200), nullable=True)),
        ("str_doc_url", sa.Column("str_doc_url", sa.Text(), nullable=True)),
        ("str_issuing_institution", sa.Column("str_issuing_institution", sa.String(length=150), nullable=True)),
        ("str_expiry_date", sa.Column("str_expiry_date", sa.String(length=50), nullable=True)),
        ("str_verified", sa.Column("str_verified", sa.Boolean(), nullable=False, server_default=sa.text("false"))),
        ("sip_doc_url", sa.Column("sip_doc_url", sa.Text(), nullable=True)),
        ("sip_issuing_institution", sa.Column("sip_issuing_institution", sa.String(length=150), nullable=True)),
        ("sip_expiry_date", sa.Column("sip_expiry_date", sa.String(length=50), nullable=True)),
        ("sip_verified", sa.Column("sip_verified", sa.Boolean(), nullable=False, server_default=sa.text("false"))),
    ]

    for col_name, column in columns_to_add:
        if col_name not in cols:
            op.add_column("psychologist_profiles", column)

    # Ensure pre-existing verified psychologists remain eligible after enforcing doc verification
    op.execute(
        sa.text(
            "UPDATE psychologist_profiles SET str_verified = true "
            "WHERE verification_status = 'verified' AND str_verified = false AND sip_verified = false"
        )
    )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    cols = {col["name"] for col in inspector.get_columns("psychologist_profiles")}

    for col_name in [
        "sip_verified",
        "sip_expiry_date",
        "sip_issuing_institution",
        "sip_doc_url",
        "str_verified",
        "str_expiry_date",
        "str_issuing_institution",
        "str_doc_url",
        "education",
    ]:
        if col_name in cols:
            op.drop_column("psychologist_profiles", col_name)
