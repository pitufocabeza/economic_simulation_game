# Godot Tilemap Integration Guide

## Architecture Overview

### 3-Tier Map Structure

1. **Universe/Region/Star System Maps (3D)**
   - Navigate between star systems and planets in 3D space
   - Select planets to view their surface locations

2. **Planet Surface (2.5D Overview)**
   - Shows 3-50 claimable locations as markers/nodes
   - Players click on a location to claim or visit it

3. **Location Detail (2.5D Tilemap)**
   - Each location has a 16x16 or 32x32 tile grid
   - This is where players mine resources and build structures
   - Tilemap is procedurally generated client-side

## Database Structure

### Locations (Claimable Plots)
- Each planet has **3-50 locations** (based on planet size)
- Each location is a claimable plot that a player can own
- Total galaxy: **~150,000-250,000 claimable locations**

### Location Properties
```json
{
  "location_id": 1234,
  "location_name": "Sirius Major I Plot 5",
  "planet_id": 567,
  "biome": "Temperate",
  "grid_width": 16,
  "grid_height": 16,
  "tilemap_seed": 1829471829,
  "elevation": 125.4,
  "position": { "x": 1234.5, "y": 6789.2, "z": 125.4 },
  "resources": [...],
  "claimed": false
}
```

## Godot Implementation

### Step 1: Fetch Location Data

When a player clicks on a location, call the API:

```gdscript
GET /tilemap/location/{location_id}
```

This returns:
- `grid_width`, `grid_height` (16x16 or 32x32)
- `tilemap_seed` (unique seed for this location)
- `biome` (affects which tiles to use)
- `resources` (what can be mined here)

### Step 2: Generate Tilemap Procedurally

Use the seed to generate consistent terrain:

```gdscript
# In Godot
extends TileMap

var location_data: Dictionary
var noise: FastNoiseLite

func generate_tilemap():
    # Initialize noise with location's seed
    noise = FastNoiseLite.new()
    noise.seed = location_data["tilemap_seed"]
    noise.frequency = 0.1
    
    # Generate tiles
    for y in range(location_data["grid_height"]):
        for x in range(location_data["grid_width"]):
            var elevation = noise.get_noise_2d(x, y)
            var tile_type = get_tile_for_biome_and_elevation(
                location_data["biome"], 
                elevation
            )
            set_cell(0, Vector2i(x, y), tile_type)

func get_tile_for_biome_and_elevation(biome: String, elevation: float) -> int:
    match biome:
        "Temperate":
            if elevation > 0.3:
                return TILE_HILLS
            elif elevation < -0.2:
                return TILE_WATER
            else:
                return TILE_PLAINS
        "Volcanic":
            if elevation > 0.4:
                return TILE_VOLCANIC_MOUNTAIN
            else:
                return TILE_LAVA_ROCK
        # ... etc for other biomes
```

### Step 3: Place Resource Nodes

Use the resource data to place minable resource indicators:

```gdscript
func place_resources():
    for resource in location_data["resources"]:
        # Place resource node at random tile (or use seed-based placement)
        var pos = get_resource_position(resource["type"])
        spawn_resource_node(pos, resource)
```

## Biome Tile Mapping

Create TileSets for each biome with tiles for:

### Barren
- rocky_plains (low elevation)
- crater (medium)
- rocky_mountain (high)
- sand_dune (very low)

### Oceanic
- shallow_water (low)
- deep_water (very low)
- beach (medium)
- coral_reef (low, rare)

### Ice
- ice_plains (low)
- glacier (medium)
- ice_mountain (high)
- frozen_sea (very low)

### Temperate
- plains (medium)
- forest (medium-high)
- hills (high)
- lake (low)

### Volcanic
- lava_rock (low)
- volcanic_mountain (high)
- ash_plains (medium)
- lava_flow (very low)

## Example Workflow

1. **Player browses galaxy map (3D)**
   - Clicks on planet "Sirius Major I"

2. **Game loads planet surface view (2.5D overview)**
   - Shows 15 locations as markers
   - "Plot 1", "Plot 2", etc.

3. **Player clicks "Plot 5"**
   - Fetches: `GET /tilemap/location/1234`
   - Receives: 16x16 grid, seed 1829471829, biome "Temperate"

4. **Godot generates tilemap**
   - Uses seed to create terrain
   - Places grass, forests, lakes based on noise
   - Places resource nodes (iron ore, wood, etc.)

5. **Player can build and mine**
   - Places buildings on specific tiles
   - Mines resources from resource-rich tiles

## Performance Notes

- **No stored tile data**: Tiles are always generated procedurally
- **Same seed = same map**: Location looks identical every time
- **Lightweight**: Only 150k-250k location records in database
- **Scalable**: Can add more planets easily
- **Client-side generation**: Server doesn't need to store millions of tiles

## Future Enhancements

1. **Store player modifications**: When player builds, save building positions
2. **Terrain modifications**: Allow players to terraform (store changes as deltas)
3. **Multi-layer tilemaps**: Add layers for buildings, decorations, etc.
4. **Biome transitions**: Blend tiles at location boundaries
