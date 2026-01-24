"""add market trades

Revision ID: 70c22751ddf7
Revises: 9541ec6eb426
Create Date: 2026-01-24 13:08:30.403001

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '70c22751ddf7'
down_revision: Union[str, Sequence[str], None] = '9541ec6eb426'
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
