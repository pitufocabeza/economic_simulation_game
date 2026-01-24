"""add last_extracted_at to extraction_sites

Revision ID: be082146dc7b
Revises: 1ed5b1ba01d5
Create Date: 2026-01-24 16:23:20.842072

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "add_last_extracted_at"
down_revision = "1ed5b1ba01d5"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "extraction_sites",
        sa.Column(
            "last_extracted_at",
            sa.DateTime(),
            nullable=True,
        ),
    )


def downgrade():
    op.drop_column("extraction_sites", "last_extracted_at")
