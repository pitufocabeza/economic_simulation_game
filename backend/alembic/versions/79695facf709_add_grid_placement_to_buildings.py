"""add_grid_placement_to_buildings

Revision ID: 79695facf709
Revises: 13b8d6bf1310
Create Date: 2026-01-29 13:45:29.437346

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '79695facf709'
down_revision: Union[str, Sequence[str], None] = '13b8d6bf1310'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Create building_blueprints table if it doesn't exist
    op.create_table(
        'building_blueprints',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('role', sa.String(50), nullable=False),
        sa.Column('description', sa.String(), nullable=True),
        sa.Column('category', sa.String(50), nullable=False),
        sa.Column('max_capacity', sa.Integer(), server_default='0'),
        sa.Column('base_efficiency', sa.Float(), server_default='1.0'),
        sa.Column('energy_production', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('energy_consumption', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('operating_cost', sa.JSON(), nullable=True),
        sa.Column('supported_goods', sa.JSON(), nullable=True),
        sa.Column('production_recipes', sa.JSON(), nullable=True),
        sa.Column('construction_cost', sa.JSON(), nullable=False),
        sa.Column('grid_width', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('grid_height', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('sprite_path', sa.String(), nullable=True),
        sa.Column('created_at', sa.TIMESTAMP(), server_default=sa.text('now()')),
        sa.Column('updated_at', sa.TIMESTAMP(), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    
    # Create buildings table
    op.create_table(
        'buildings',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('blueprint_id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('owner_company_id', sa.Integer(), nullable=False),
        sa.Column('location_id', sa.Integer(), nullable=False),
        sa.Column('grid_x', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('grid_y', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('rotation', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('status', sa.String(50), nullable=False, server_default='constructing'),
        sa.Column('current_capacity', sa.Integer(), server_default='0'),
        sa.Column('current_efficiency', sa.Float(), server_default='1.0'),
        sa.Column('created_at', sa.TIMESTAMP(), server_default=sa.text('now()')),
        sa.Column('updated_at', sa.TIMESTAMP(), nullable=True),
        sa.PrimaryKeyConstraint('id'),
        sa.ForeignKeyConstraint(['blueprint_id'], ['building_blueprints.id']),
        sa.ForeignKeyConstraint(['owner_company_id'], ['companies.id']),
        sa.ForeignKeyConstraint(['location_id'], ['locations.id'])
    )
    
    # Create indexes
    op.create_index('ix_buildings_id', 'buildings', ['id'])
    op.create_index('ix_buildings_location_id', 'buildings', ['location_id'])
    op.create_index('ix_buildings_owner_company_id', 'buildings', ['owner_company_id'])


def downgrade() -> None:
    """Downgrade schema."""
    # Drop indexes
    op.drop_index('ix_buildings_owner_company_id')
    op.drop_index('ix_buildings_location_id')
    op.drop_index('ix_buildings_id')
    
    # Drop tables
    op.drop_table('buildings')
    op.drop_table('building_blueprints')
