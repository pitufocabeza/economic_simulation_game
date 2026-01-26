"""Add star attributes to star_systems

Revision ID: efbf48dabaf6
Revises: 5dffedf56aeb
Create Date: 2026-01-26 12:17:59.991363

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'efbf48dabaf6'
down_revision: Union[str, Sequence[str], None] = '5dffedf56aeb'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Apply the migration to add star attributes to the star_systems table."""
    op.add_column('star_systems', sa.Column('star_type', sa.String(), nullable=True))
    op.add_column('star_systems', sa.Column('star_size', sa.String(), nullable=True))
    op.add_column('star_systems', sa.Column('star_temperature', sa.Integer(), nullable=True))
    op.add_column('star_systems', sa.Column('star_luminosity', sa.String(), nullable=True))


def downgrade() -> None:
    """Rollback the migration to remove star attributes from the star_systems table."""
    op.drop_column('star_systems', 'star_type')
    op.drop_column('star_systems', 'star_size')
    op.drop_column('star_systems', 'star_temperature')
    op.drop_column('star_systems', 'star_luminosity')