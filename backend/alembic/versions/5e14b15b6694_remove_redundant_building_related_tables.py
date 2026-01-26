"""remove redundant building-related tables

Revision ID: 5e14b15b6694
Revises: 05a36d7c90d8
Create Date: 2026-01-26 08:56:29.991630

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '5e14b15b6694'
down_revision: Union[str, Sequence[str], None] = '05a36d7c90d8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Remove tables that are being unified under `buildings`."""
    # Use raw SQL to include the CASCADE keyword
    op.execute("DROP TABLE extractor_heads CASCADE;")
    op.execute("DROP TABLE ecus CASCADE;")
    op.execute("DROP TABLE command_centers CASCADE;")
    op.execute("DROP TABLE planetary_links CASCADE;")
    op.execute("DROP TABLE processors CASCADE;")
    op.execute("DROP TABLE spaceports CASCADE;")
    op.execute("DROP TABLE storages CASCADE;")


def downgrade() -> None:
    """Recreate the dropped tables in case of a rollback."""
    op.create_table(
        "command_centers",
        op.Column("id", op.Integer(), primary_key=True, index=True),
        op.Column("name", op.String(100), nullable=False),
        op.Column("owner_company_id", op.Integer(), nullable=False),
        op.Column("planet_name", op.String(100), nullable=False),
    )

    op.create_table(
        "ecus",
        op.Column("id", op.Integer(), primary_key=True),
        op.Column("extraction_capacity", op.Integer(), nullable=False),
    )

    op.create_table(
        "extractor_heads",
        op.Column("id", op.Integer(), primary_key=True, index=True),
        op.Column("ecu_id", op.Integer(), op.ForeignKey("ecus.id"), nullable=False),
        op.Column("extraction_rate", op.Float(), nullable=False),
    )

    op.create_table(
        "planetary_links",
        op.Column("id", op.Integer(), primary_key=True),
    )

    op.create_table(
        "processors",
        op.Column("id", op.Integer(), primary_key=True),
        op.Column("tier", op.String(50), nullable=False),
    )

    op.create_table(
        "spaceports",
        op.Column("id", op.Integer(), primary_key=True),
    )

    op.create_table(
        "storages",
        op.Column("id", op.Integer(), primary_key=True),
    )