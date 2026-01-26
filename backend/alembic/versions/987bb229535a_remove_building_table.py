"""remove building table

Revision ID: 987bb229535a
Revises: 5e14b15b6694
Create Date: 2026-01-26 09:37:46.904223

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSON

# revision identifiers, used by Alembic.
revision: str = '987bb229535a'
down_revision: Union[str, Sequence[str], None] = '5e14b15b6694'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create building_blueprints and buildings tables."""
    # Create building_blueprints table
    op.create_table(
        "building_blueprints",
        sa.Column("id", sa.Integer, primary_key=True, index=True),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("role", sa.String(50), nullable=False),
        sa.Column("description", sa.String, nullable=True),
        sa.Column("category", sa.String(50), nullable=False),
        sa.Column("max_capacity", sa.Integer, default=0),
        sa.Column("base_efficiency", sa.Float, default=1.0),
        sa.Column("energy_production", sa.Integer, nullable=False, server_default="0"),
        sa.Column("energy_consumption", sa.Integer, nullable=False, server_default="0"),
        sa.Column("operating_cost", JSON, nullable=True),
        sa.Column("supported_goods", JSON, nullable=True),
        sa.Column("production_recipes", JSON, nullable=True),
        sa.Column("construction_cost", JSON, nullable=False),
        sa.Column("created_at", sa.TIMESTAMP, server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP, onupdate=sa.func.now(), nullable=True),
    )

    # Create buildings table
    op.create_table(
        "buildings",
        sa.Column("id", sa.Integer, primary_key=True, index=True),
        sa.Column("blueprint_id", sa.Integer, sa.ForeignKey("building_blueprints.id"), nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("owner_company_id", sa.Integer, sa.ForeignKey("companies.id"), nullable=False),
        sa.Column("location_id", sa.Integer, sa.ForeignKey("locations.id"), nullable=False),
        sa.Column("status", sa.String(50), nullable=False, server_default="constructing"),
        sa.Column("current_capacity", sa.Integer, server_default="0"),
        sa.Column("current_efficiency", sa.Float, server_default="1.0"),
        sa.Column("created_at", sa.TIMESTAMP, server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.TIMESTAMP, onupdate=sa.func.now(), nullable=True),
    )


def downgrade() -> None:
    """Drop buildings and building_blueprints tables."""
    op.drop_table("buildings")
    op.drop_table("building_blueprints")