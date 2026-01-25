"""add default to extraction_sites.created_at

Revision ID: 835a908925d8
Revises: ad98d0f3b061
Create Date: 2026-01-25 08:06:27.842924

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '835a908925d8'
down_revision: Union[str, Sequence[str], None] = 'ad98d0f3b061'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.alter_column(
        "extraction_sites",
        "created_at",
        server_default=sa.func.now(),
        nullable=False,
    )


def downgrade():
    op.alter_column(
        "extraction_sites",
        "created_at",
        server_default=None,
        nullable=False,
    )

