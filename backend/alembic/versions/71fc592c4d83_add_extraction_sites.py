"""add extraction sites

Revision ID: 71fc592c4d83
Revises: 1ac9d284b10f
Create Date: 2026-01-24 15:36:50.626520
"""

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = "71fc592c4d83"
down_revision = "1ac9d284b10f"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "extraction_sites",
        sa.Column("id", sa.Integer(), primary_key=True),

        sa.Column(
            "company_id",
            sa.Integer(),
            sa.ForeignKey("companies.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),

        sa.Column(
            "location_id",
            sa.Integer(),
            sa.ForeignKey("locations.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),

        sa.Column(
            "good_id",
            sa.Integer(),
            sa.ForeignKey("goods.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),

        sa.Column("rate_per_hour", sa.Integer(), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(), nullable=False),

        sa.UniqueConstraint(
            "location_id",
            "good_id",
            name="uq_location_good_extraction",
        ),
    )


def downgrade():
    op.drop_table("extraction_sites")
