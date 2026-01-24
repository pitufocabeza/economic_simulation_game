"""add production buffer to extraction sites

Revision ID: 61bd68e89f7a
Revises: add_last_extracted_at
Create Date: 2026-01-24 16:31:34.597187

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '61bd68e89f7a'
down_revision: Union[str, Sequence[str], None] = 'add_last_extracted_at'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.add_column(
        "extraction_sites",
        sa.Column(
            "production_buffer",
            sa.Float(),
            nullable=False,
            server_default="0",
        ),
    )

def downgrade():
    op.drop_column("extraction_sites", "production_buffer")



def downgrade() -> None:
    """Downgrade schema."""
    pass
