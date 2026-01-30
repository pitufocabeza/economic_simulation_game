"""enhance_location_with_wang_tiles

Revision ID: 84e9c2f3b5e1
Revises: 79695facf709
Create Date: 2026-01-30 09:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '84e9c2f3b5e1'
down_revision: Union[str, Sequence[str], None] = '79695facf709'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema - add Wang tile and edge neighbor support to locations."""
    # Update grid dimensions from 16/16 default to 256/256 for larger locations
    op.alter_column('locations', 'grid_width',
                    existing_type=sa.Integer(),
                    server_default='256',
                    existing_server_default='16')
    op.alter_column('locations', 'grid_height',
                    existing_type=sa.Integer(),
                    server_default='256',
                    existing_server_default='16')
    
    # Add Wang tile support for seamless tiling
    op.add_column('locations', sa.Column('wang_tile_id', sa.Integer(), nullable=False, server_default='0'))
    
    # Add edge neighbor tracking for seamless transitions
    op.add_column('locations', sa.Column('edge_north_id', sa.Integer(), nullable=True))
    op.add_column('locations', sa.Column('edge_south_id', sa.Integer(), nullable=True))
    op.add_column('locations', sa.Column('edge_east_id', sa.Integer(), nullable=True))
    op.add_column('locations', sa.Column('edge_west_id', sa.Integer(), nullable=True))
    
    # Add adjacent biome information
    op.add_column('locations', sa.Column('adjacent_biome_north', sa.String(), nullable=False, server_default='none'))
    op.add_column('locations', sa.Column('adjacent_biome_south', sa.String(), nullable=False, server_default='none'))
    op.add_column('locations', sa.Column('adjacent_biome_east', sa.String(), nullable=False, server_default='none'))
    op.add_column('locations', sa.Column('adjacent_biome_west', sa.String(), nullable=False, server_default='none'))
    
    # Create foreign key constraints for edge neighbors
    op.create_foreign_key('fk_edge_north', 'locations', 'locations',
                          ['edge_north_id'], ['id'], ondelete='SET NULL')
    op.create_foreign_key('fk_edge_south', 'locations', 'locations',
                          ['edge_south_id'], ['id'], ondelete='SET NULL')
    op.create_foreign_key('fk_edge_east', 'locations', 'locations',
                          ['edge_east_id'], ['id'], ondelete='SET NULL')
    op.create_foreign_key('fk_edge_west', 'locations', 'locations',
                          ['edge_west_id'], ['id'], ondelete='SET NULL')


def downgrade() -> None:
    """Downgrade schema - remove Wang tile and edge neighbor support."""
    # Drop foreign key constraints
    op.drop_constraint('fk_edge_west', 'locations', type_='foreignkey')
    op.drop_constraint('fk_edge_east', 'locations', type_='foreignkey')
    op.drop_constraint('fk_edge_south', 'locations', type_='foreignkey')
    op.drop_constraint('fk_edge_north', 'locations', type_='foreignkey')
    
    # Remove adjacent biome columns
    op.drop_column('locations', 'adjacent_biome_west')
    op.drop_column('locations', 'adjacent_biome_east')
    op.drop_column('locations', 'adjacent_biome_south')
    op.drop_column('locations', 'adjacent_biome_north')
    
    # Remove edge neighbor columns
    op.drop_column('locations', 'edge_west_id')
    op.drop_column('locations', 'edge_east_id')
    op.drop_column('locations', 'edge_south_id')
    op.drop_column('locations', 'edge_north_id')
    
    # Remove Wang tile column
    op.drop_column('locations', 'wang_tile_id')
    
    # Revert grid dimensions
    op.alter_column('locations', 'grid_height',
                    existing_type=sa.Integer(),
                    server_default='16',
                    existing_server_default='256')
    op.alter_column('locations', 'grid_width',
                    existing_type=sa.Integer(),
                    server_default='16',
                    existing_server_default='256')
