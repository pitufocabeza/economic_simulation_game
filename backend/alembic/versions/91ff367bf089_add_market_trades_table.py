"""add market_trades table

Revision ID: 91ff367bf089
Revises: f3a224d24a2b
Create Date: 2026-01-24 17:22:37.828487

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '91ff367bf089'
down_revision: Union[str, Sequence[str], None] = 'f3a224d24a2b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
