"""add market trades table

Revision ID: ad98d0f3b061
Revises: 91ff367bf089
Create Date: 2026-01-24 17:49:02.379560

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ad98d0f3b061'
down_revision: Union[str, Sequence[str], None] = '91ff367bf089'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.create_table(
        "market_trades",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("good_id", sa.Integer(), sa.ForeignKey("goods.id"), index=True),
        sa.Column("buyer_company_id", sa.Integer(), sa.ForeignKey("companies.id"), index=True),
        sa.Column("seller_company_id", sa.Integer(), sa.ForeignKey("companies.id"), index=True),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("price_per_unit", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )


def downgrade() -> None:
    """Downgrade schema."""
    pass
