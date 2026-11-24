"""add_psy_certificates

Revision ID: 0009_add_psy_certificates
Revises: 0008_add_crisis_config_and_faqs
Create Date: 2026-11-24 11:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "0009_add_psy_certificates"
down_revision: str | None = "0008_add_crisis_config_and_faqs"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if not inspector.has_table("certificate_templates"):
        op.create_table(
            "certificate_templates",
            sa.Column(
                "id",
                postgresql.UUID(as_uuid=True),
                server_default=sa.text("gen_random_uuid()"),
                nullable=False,
            ),
            sa.Column("code", sa.String(length=40), nullable=False),
            sa.Column("title", sa.String(length=200), nullable=False),
            sa.Column("subtitle", sa.String(length=250), nullable=False),
            sa.Column(
                "category_code",
                sa.String(length=20),
                nullable=False,
                server_default=sa.text("'PRO'"),
            ),
            sa.Column(
                "category_label",
                sa.String(length=100),
                nullable=False,
                server_default=sa.text("'Psikolog Mandiri'"),
            ),
            sa.Column("milestone_criteria", sa.String(length=250), nullable=False),
            sa.Column("description", sa.Text(), nullable=False),
            sa.Column(
                "badge_color",
                sa.String(length=20),
                nullable=False,
                server_default=sa.text("'#2563EB'"),
            ),
            sa.Column(
                "trigger_type",
                sa.String(length=30),
                nullable=False,
                server_default=sa.text("'sessions_milestone'"),
            ),
            sa.Column(
                "min_completed_sessions",
                sa.Integer(),
                nullable=False,
                server_default=sa.text("25"),
            ),
            sa.Column("min_average_rating", sa.Numeric(precision=3, scale=2), nullable=True),
            sa.Column(
                "auto_issue_enabled",
                sa.Boolean(),
                nullable=False,
                server_default=sa.text("true"),
            ),
            sa.Column(
                "is_active",
                sa.Boolean(),
                nullable=False,
                server_default=sa.text("true"),
            ),
            sa.Column("svg_body_template", sa.Text(), nullable=True),
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
        op.create_index("ix_certificate_templates_code", "certificate_templates", ["code"])
        op.create_index(
            "ix_certificate_templates_trigger_type",
            "certificate_templates",
            ["trigger_type"],
        )
        op.create_index(
            "ix_certificate_templates_is_active",
            "certificate_templates",
            ["is_active"],
        )

    if not inspector.has_table("psychologist_certificates"):
        op.create_table(
            "psychologist_certificates",
            sa.Column(
                "id",
                postgresql.UUID(as_uuid=True),
                server_default=sa.text("gen_random_uuid()"),
                nullable=False,
            ),
            sa.Column("certificate_number", sa.String(length=80), nullable=False),
            sa.Column("sequence_number", sa.Integer(), nullable=False),
            sa.Column("issue_year", sa.Integer(), nullable=False),
            sa.Column("category_code", sa.String(length=20), nullable=False),
            sa.Column("counselor_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("template_id", postgresql.UUID(as_uuid=True), nullable=True),
            sa.Column("issued_by_user_id", postgresql.UUID(as_uuid=True), nullable=True),
            sa.Column("title", sa.String(length=200), nullable=False),
            sa.Column("subtitle", sa.String(length=250), nullable=False),
            sa.Column("recipient_name", sa.String(length=200), nullable=False),
            sa.Column("str_number", sa.String(length=100), nullable=False),
            sa.Column("milestone_criteria", sa.String(length=250), nullable=False),
            sa.Column("category_label", sa.String(length=100), nullable=False),
            sa.Column("description", sa.Text(), nullable=False),
            sa.Column("badge_color", sa.String(length=20), nullable=False),
            sa.Column(
                "trigger_source",
                sa.String(length=30),
                nullable=False,
                server_default=sa.text("'manual'"),
            ),
            sa.Column(
                "status",
                sa.String(length=20),
                nullable=False,
                server_default=sa.text("'active'"),
            ),
            sa.Column(
                "issued_at",
                sa.DateTime(timezone=True),
                server_default=sa.text("now()"),
                nullable=False,
            ),
            sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("revocation_reason", sa.Text(), nullable=True),
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
            sa.ForeignKeyConstraint(
                ["counselor_id"],
                ["psychologist_profiles.id"],
                ondelete="CASCADE",
            ),
            sa.ForeignKeyConstraint(
                ["template_id"],
                ["certificate_templates.id"],
                ondelete="SET NULL",
            ),
            sa.ForeignKeyConstraint(
                ["issued_by_user_id"],
                ["users.id"],
                ondelete="SET NULL",
            ),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("certificate_number"),
        )
        op.create_index(
            "ix_psychologist_certificates_certificate_number",
            "psychologist_certificates",
            ["certificate_number"],
        )
        op.create_index(
            "ix_psychologist_certificates_issue_year",
            "psychologist_certificates",
            ["issue_year"],
        )
        op.create_index(
            "ix_psychologist_certificates_category_code",
            "psychologist_certificates",
            ["category_code"],
        )
        op.create_index(
            "ix_psychologist_certificates_counselor_id",
            "psychologist_certificates",
            ["counselor_id"],
        )
        op.create_index(
            "ix_psychologist_certificates_template_id",
            "psychologist_certificates",
            ["template_id"],
        )
        op.create_index(
            "ix_psychologist_certificates_status",
            "psychologist_certificates",
            ["status"],
        )

    session_cols = {
        col["name"] for col in inspector.get_columns("consultation_sessions")
    }
    if "patient_rating" not in session_cols:
        op.add_column(
            "consultation_sessions",
            sa.Column("patient_rating", sa.Numeric(precision=3, scale=2), nullable=True),
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    session_cols = {
        col["name"] for col in inspector.get_columns("consultation_sessions")
    }
    if "patient_rating" in session_cols:
        op.drop_column("consultation_sessions", "patient_rating")

    if inspector.has_table("psychologist_certificates"):
        op.drop_table("psychologist_certificates")

    if inspector.has_table("certificate_templates"):
        op.drop_table("certificate_templates")
