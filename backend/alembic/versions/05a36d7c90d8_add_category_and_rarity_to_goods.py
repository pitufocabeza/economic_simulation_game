"""add category and rarity to goods

Revision ID: 05a36d7c90d8
Revises: eb50d98f11df
Create Date: 2026-01-26 07:16:13.733758

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '05a36d7c90d8'
down_revision: Union[str, Sequence[str], None] = 'eb50d98f11df'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Create the goodscategory enum type
    op.execute(
        "CREATE TYPE goodscategory AS ENUM ('energy', 'metal', 'organic', 'gaseous', 'chemical', 'exotic', 'biotech')"
    )

    # Create the goodsrarity enum type
    op.execute(
        "CREATE TYPE goodsrarity AS ENUM ('common', 'rare', 'exotic')"
    )

    # Add columns to the goods table with default values in correct PostgreSQL enum syntax
    op.add_column(
        'goods',
        sa.Column('category', sa.Enum('energy', 'metal', 'organic', 'gaseous', 'chemical', 'exotic', 'biotech', name='goodscategory'),
                  nullable=False, server_default="metal")
    )
    op.add_column(
        'goods',
        sa.Column('rarity', sa.Enum('common', 'rare', 'exotic', name='goodsrarity'),
                  nullable=False, server_default="common")
    )

    # Optional: Reset default values after migration
    op.alter_column('goods', 'category', server_default=None)
    op.alter_column('goods', 'rarity', server_default=None)


def downgrade() -> None:
    """Downgrade schema."""
    # Drop columns from the goods table
    op.drop_column('goods', 'rarity')
    op.drop_column('goods', 'category')

    # Drop the enum types
    op.execute("DROP TYPE goodsrarity")
    op.execute("DROP TYPE goodscategory")