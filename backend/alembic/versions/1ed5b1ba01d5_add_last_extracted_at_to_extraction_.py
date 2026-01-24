"""add last_extracted_at to extraction_sites

Revision ID: 1ed5b1ba01d5
Revises: 76b5019a459c
Create Date: 2026-01-24 16:07:11.787617

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '1ed5b1ba01d5'
down_revision: Union[str, Sequence[str], None] = '76b5019a459c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
