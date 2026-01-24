"""make extraction timestamps timezone aware

Revision ID: f3a224d24a2b
Revises: 61bd68e89f7a
Create Date: 2026-01-24 16:45:23.334982

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f3a224d24a2b'
down_revision: Union[str, Sequence[str], None] = '61bd68e89f7a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.alter_column(
        "extraction_sites",
        "last_extracted_at",
        type_=sa.DateTime(timezone=True),
        existing_type=sa.DateTime(),
    )

    op.alter_column(
        "extraction_sites",
        "created_at",
        type_=sa.DateTime(timezone=True),
        existing_type=sa.DateTime(),
    )


def downgrade():
    op.alter_column(
        "extraction_sites",
        "last_extracted_at",
        type_=sa.DateTime(),
        existing_type=sa.DateTime(timezone=True),
    )

    op.alter_column(
        "extraction_sites",
        "created_at",
        type_=sa.DateTime(),
        existing_type=sa.DateTime(timezone=True),
    )



def downgrade() -> None:
    """Downgrade schema."""
    pass
