"""Create companies table

Revision ID: 5089f6fc8f1d
Revises: 987bb229535a
Create Date: 2026-01-26 10:55:35.625487

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '5089f6fc8f1d'
down_revision: Union[str, Sequence[str], None] = '987bb229535a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "companies",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("cash", sa.Integer(), nullable=False, server_default="0"),
        sa.PrimaryKeyConstraint("id")
    )

def downgrade() -> None:
    op.drop_table("companies")
