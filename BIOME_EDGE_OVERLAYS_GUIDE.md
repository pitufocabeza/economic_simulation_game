# Biome Edge Overlays and Detail Masks Guide

## Overview

The `temperate_map_generator.gd` script implements a sophisticated biome edge overlay system for top-down 2.5D TileMap worlds. It uses probabilistic, distance-based rules to place visual detail masks at biome transitions (grass-water, sand-water, etc.).

## Architecture

### TileMap Layers

- **Layer 0 (Z=0)**: Base biome tiles (grass, sand, water)
- **Layer 1 (Z=1)**: Detail overlay tiles (variations of base colors)
- **Layer 2 (Z=2)**: Edge overlays and masks (foam, wet sand, algae, erosion, dirt stains)

### Biome Types

```gdscript
const BIOME_GRASS = 0
const BIOME_SAND = 1
const BIOME_WATER = 2
```

## Overlay Groups

Edge overlays are organized by visual/functional group:

### Grass Overlays
- `grass_dirt_small`
- `grass_dirt_medium`
- `grass_dirt_large`

**Placement Rules:**
- Base chance: 15% everywhere
- Near water: 35% (increased visibility of weathering)
- Near sand: 25% (transition zone)

### Sand Overlays

#### Wet Sand (`wet_sand_mask`)
- **Distance 0** (directly adjacent to water): 60% chance
- Represents freshly wet beach at shoreline
- High opacity to show water boundary

#### Erosion Edge (`erosion_edge_mask`)
- **Distance 1-2** (1-2 tiles away from water): 25% chance
- Subtle erosion patterns showing seasonal flooding zones
- Lower opacity for natural appearance

### Water Overlays

#### Foam (`water_foam_mask`)
- **Shoreline only** (adjacent to sand): 70% chance
- High probability for dramatic visual effect
- Represents wave action

#### Algae (`water_algae_mask`)
- **All water tiles**: 30% chance
- Lower probability to avoid over-saturation
- Works in all water areas, not just shoreline

## Helper Functions

### Biome Detection

```gdscript
is_water(biome_type: int) -> bool
is_sand(biome_type: int) -> bool
is_grass(biome_type: int) -> bool
```

### Neighbor Analysis

```gdscript
has_biome_neighbor(pos: Vector2i, target_biome: int, base_map: Dictionary) -> bool
```
Checks if a tile has a neighbor of the target biome type (4-directional).

```gdscript
get_neighbor_biomes(pos: Vector2i, base_map: Dictionary) -> Dictionary
```
Returns count of each biome type in neighbors: `{BIOME_GRASS: count, BIOME_SAND: count, BIOME_WATER: count}`

### Distance Calculation

```gdscript
get_distance_to_biome(pos: Vector2i, target_biome: int, base_map: Dictionary, max_distance: int = 3) -> int
```

Uses breadth-first search (BFS) to calculate minimum distance to target biome:
- Returns `0` if the tile **is** the target biome
- Returns distance `1..n` for neighboring tiles
- Returns `-1` if unreachable within `max_distance`

**Example Usage:**
```gdscript
var dist_to_water = get_distance_to_biome(pos, BIOME_WATER, base_map, 2)
if dist_to_water == 0:
    # Tile is on water
    pass
elif dist_to_water == 1:
    # 1 tile away from water
    pass
```

### Overlay Selection

```gdscript
get_random_overlay_from_group(group_key: String) -> String
```

Returns a random tile name from the `edge_overlays` dictionary.

**Example:**
```gdscript
var foam = get_random_overlay_from_group("water_foam")
# Returns one of: ["water_foam_mask"]

var dirt = get_random_overlay_from_group("grass_dirt")
# Returns one of: ["grass_dirt_small", "grass_dirt_medium", "grass_dirt_large"]
```

### Transform Application

```gdscript
apply_random_transform(tilemap: TileMap, pos: Vector2i, source_id: int)
```

Places a tile with optional random rotation and mirroring. Currently sets the tile directly; rotation/mirroring via TileData custom_data or alternative tiles can be enhanced.

## Configuration Parameters

All probabilities are tunable via script variables:

```gdscript
# Grass transitions
var GRASS_DIRT_BASE_CHANCE = 0.15       # 15%
var GRASS_DIRT_NEAR_WATER_CHANCE = 0.35 # 35%
var GRASS_DIRT_NEAR_SAND_CHANCE = 0.25  # 25%

# Sand transitions
var WET_SAND_NEAR_WATER_CHANCE = 0.60   # 60%
var EROSION_EDGE_CHANCE = 0.25          # 25%

# Water transitions
var WATER_FOAM_SHORELINE_CHANCE = 0.70  # 70%
var WATER_ALGAE_CHANCE = 0.30           # 30%

# Distance band settings
var MAX_DISTANCE_TO_WATER = 2            # Check up to 2 tiles away
```

## Texture/Atlas Setup

Ensure your tileset includes these overlay textures:

```
assets/tilesets/temperate/
├── grass_dirt_small.png
├── grass_dirt_medium.png
├── grass_dirt_large.png
├── water_algae_mask.png
├── water_foam_mask.png
├── water_edge_combined_mask.png (optional)
├── wet_sand_mask.png
└── erosion_edge_mask.png
```

**Important:** These are grayscale masks with alpha channels, rendered as tiles on top of base biomes.

## Debug Mode

Toggle debug mode with the **T** key:

```
Press T: Toggle debug overlay density
- Normal mode: 10% overlay density
- Debug mode: 45% overlay density (easier to see placement)
```

The configuration is printed on startup:

```
=== EDGE OVERLAY CONFIGURATION ===
Grass Dirt:
  - Base chance: 15.0%
  - Near water: 35.0%
  - Near sand: 25.0%
...
```

## Determinism and Seeding

The system is **deterministic** with seeded RNG:

```gdscript
var map_seed = randi()
noise.seed = map_seed
overlay_noise.seed = map_seed + 1000
```

Same seed = same map layout. Use `KEY_R` to regenerate with a new seed.

## Placement Algorithm

### Grass Tiles

```
FOR each grass tile:
  IF has water neighbor:
    IF randf() < 0.35: place grass_dirt (35% chance)
  ELSE IF has sand neighbor:
    IF randf() < 0.25: place grass_dirt (25% chance)
  ELSE:
    IF randf() < 0.15: place grass_dirt (15% chance)
```

### Sand Tiles

```
FOR each sand tile:
  distance_to_water = BFS(tile, BIOME_WATER)
  
  IF distance_to_water == 0:  (adjacent to water)
    IF randf() < 0.60: place wet_sand_mask
  ELSE IF distance_to_water IN [1, 2]:
    IF randf() < 0.25: place erosion_edge_mask
```

### Water Tiles

```
FOR each water tile:
  IF has sand neighbor:
    IF randf() < 0.70: place water_foam_mask
  
  IF randf() < 0.30:
    place water_algae_mask
```

## Examples: Custom Biome Rules

### Increase Sand Detail

```gdscript
# Make erosion more visible
var EROSION_EDGE_CHANCE = 0.40  # Up from 0.25
var WET_SAND_NEAR_WATER_CHANCE = 0.75  # Up from 0.60
```

### Make Water Busier

```gdscript
# More foam and algae
var WATER_FOAM_SHORELINE_CHANCE = 0.90  # Up from 0.70
var WATER_ALGAE_CHANCE = 0.50  # Up from 0.30
```

### Subtle Grass Weathering

```gdscript
# Only show dirt stains near water
var GRASS_DIRT_BASE_CHANCE = 0.05  # Down from 0.15
var GRASS_DIRT_NEAR_WATER_CHANCE = 0.40  # Emphasize water edges
```

## Performance Notes

- **BFS Distance Calculation**: O(n) per tile, capped at `MAX_DISTANCE_TO_WATER`
  - For 32x32 grid with max_distance=2, negligible impact
  - Optimize by caching distances if needed for larger maps
  
- **Neighbor Checks**: O(1) per lookup (hash table)

- **Total per-tile work**: ~20-50 operations at placement

## Future Enhancements

- [ ] TileSet alternative tiles for rotation/mirroring
- [ ] Directional overlays (foam flow direction)
- [ ] Seasonal overlay swapping (dry/wet seasons)
- [ ] Blended masks (layer multiple overlays with opacity)
- [ ] Performance optimization for large maps (quadtree distance caching)

## Troubleshooting

### Overlays Not Appearing

1. **Check tile names**: Verify `grass_dirt_small`, `water_foam_mask`, etc. match filenames
2. **Verify `tile_to_source`**: Print debug info:
   ```gdscript
   print("Available tiles:", tile_to_source.keys())
   ```
3. **Check layer visibility**: Ensure TileMap layers aren't hidden in Godot editor

### Too Much/Too Little Detail

Adjust `*_CHANCE` variables:
- Increase for more overlays
- Decrease for subtler transitions

### Seeded RNG Not Working

Ensure `setup_noise()` and `place_edges()` use the same seed:
```gdscript
noise.seed = map_seed
overlay_noise.seed = map_seed + 1000
# RNG uses Godot's built-in seeded rand generators
```

## API Reference

See [temperate_map_generator.gd](temperate_map_generator.gd) for full function signatures and inline documentation.
