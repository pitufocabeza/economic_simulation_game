# Isometric Wang Tile Setup Guide

## Overview
This document explains the isometric Wang tile approach for location map generation.

## What are Wang Tiles?
Wang tiles (also called corner tiles or blob tiles) are a tiling system where tiles are selected based on their neighbors. Each tile edge has a "color" or "type", and tiles automatically match their neighbors to create seamless terrain transitions.

### Advantages:
- **Seamless transitions** between terrain types (no manual tile placement)
- **Automatic variation** - the tileset handles all edge cases
- **Less code** - the tile selection is algorithmic
- **Natural-looking** terrain boundaries

## Isometric Setup

### Camera Configuration
The isometric camera is set to:
- **Angle**: 30° rotation (standard isometric)
- **Base zoom**: 1.5x
- **Controls**: WASD for pan, Q/E for zoom

### Files Created
1. `scripts/isometric_location_generator.gd` - Main generator script
2. `scenes/isometric_location.tscn` - Scene for isometric locations

## Creating Wang Tilesets

### Tileset Structure
For each biome, you'll need a Wang tileset with tiles for:
- **Center tiles**: Single terrain type (e.g., all grass)
- **Edge tiles**: Two terrain types meeting (e.g., grass-water edge)
- **Corner tiles**: Multiple terrain types meeting at corners

### Recommended Layout
For a 2-terrain Wang set (e.g., grass + water):
- 1 all-grass tile
- 1 all-water tile  
- 4 edge tiles (grass on N, S, E, W with water on opposite)
- 4 corner tiles (grass in corner with water on adjacent sides)
- Additional variations for visual diversity

### Godot TileSet Setup
1. Create a TileSet resource in Godot
2. Import your isometric tile sprites
3. Set the tile shape to **Isometric**
4. Configure Wang sets in the TileSet editor:
   - Right panel: "Terrains" tab
   - Create terrain sets (e.g., "Temperate")
   - Define terrain types (e.g., "Grass", "Water", "Forest")
   - Paint terrain bits on each tile

## Implementation Steps

### Phase 1: Basic Isometric View ✅
- [x] Create isometric camera setup
- [x] Add camera controls (pan, zoom, rotation)
- [x] Create placeholder grid

### Phase 2: Wang Tileset Creation (TODO)
- [ ] Design isometric tile sprites for each biome
- [ ] Create TileSet resources with terrain sets
- [ ] Configure Wang edge rules

### Phase 3: Terrain Generation (TODO)
- [ ] Implement `get_wang_tile_for_position()` 
- [ ] Use location biome data to select terrain types
- [ ] Apply noise-based terrain variation
- [ ] Handle biome-specific rules

### Phase 4: Visual Polish (TODO)
- [ ] Add decorative objects (trees, rocks, etc.)
- [ ] Implement lighting/shadows for isometric view
- [ ] Add particle effects for biomes

## Wang Tile Algorithm

```gdscript
func get_wang_tile_for_position(x: int, y: int) -> Vector2i:
	# Get terrain type at this position
	var center_terrain = get_terrain_type_at(x, y)
	
	# Check 4 cardinal neighbors
	var north = get_terrain_type_at(x, y - 1)
	var south = get_terrain_type_at(x, y + 1)
	var east = get_terrain_type_at(x + 1, y)
	var west = get_terrain_type_at(x - 1, y)
	
	# Godot's TileSet terrain system will automatically
	# select the correct tile based on these neighbors
	terrain_layer.set_cells_terrain_connect(
		[Vector2i(x, y)],
		terrain_set_id,
		terrain_id
	)
```

## Resources
- [Godot Terrain Documentation](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html#terrain-tiles)
- [Wang Tiles Overview](https://en.wikipedia.org/wiki/Wang_tile)
- Example isometric tile packs: Kenney.nl, OpenGameArt.org

## Next Steps
1. Design/source isometric tile sprites for your biomes
2. Set up TileSet with terrain definitions
3. Implement terrain generation using noise and biome data
4. Test with different location types
