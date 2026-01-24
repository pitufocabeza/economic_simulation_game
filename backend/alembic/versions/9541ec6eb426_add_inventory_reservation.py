"""add inventory reservation

Revision ID: 9541ec6eb426
Revises: 8055f82c9b78
Create Date: 2026-01-24 08:27:42.582166

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '9541ec6eb426'
down_revision: Union[str, Sequence[str], None] = '8055f82c9b78'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.add_column(
        "inventories",
        sa.Column(
            "reserved",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )



def downgrade():
    op.drop_column("inventories", "reserved")

