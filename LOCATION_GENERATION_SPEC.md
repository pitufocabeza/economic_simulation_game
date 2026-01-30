# Location Generation Specification

## Overview
Each planet generates **3-8 locations** (down from 3-50), each with a **256×512 grid** for gameplay. These locations have different biomes and support seamless Wang tileset transitions.

## Biome Distribution (by probability)
Our system generates locations with these biomes:
- **Barren** (40%) - Rocky, ore-rich, gray/brown
- **Oceanic** (25%) - Water-heavy, blue
- **Ice** (20%) - Frozen, white/blue
- **Temperate** (10%) - Grassland, green vegetation
- **Volcanic** (5%) - Lava/magma, orange/red

### Resource Distribution by Biome
Each biome has specific resources and rarity distributions:

**Barren:**
- Common: Iron Ore, Copper Ore, Coal, Quartz, Hydrogen, Aluminum, Zinc
- Rare: Lead, Nickel, Gold, Plutonium, Titanium
- Exotic: None

**Oceanic:**
- Common: Iron, Copper, Coal, Quartz, Hydrogen, Biomass, Wood
- Rare: None
- Exotic: None

**Ice:**
- Common: Iron, Copper, Coal, Quartz, Hydrogen, Aluminum, Zinc, Nitrogen, Oxygen
- Rare: Titanium, Lead, Gold, Palladium
- Exotic: None

**Temperate:**
- Common: Iron, Copper, Coal, Quartz, Hydrogen, Biomass, Wood, Nitrogen, Oxygen
- Rare: Gold, Nickel
- Exotic: None

**Volcanic:**
- Common: Iron, Coal, Quartz, Hydrogen
- Rare: Copper, Titanium, Uranium, Plutonium
- Exotic: Platinum, Palladium, Helium-3

## Location Data Structure (Database)

Each Location stores:
```python
{
  "id": int,
  "name": "Planet Name Plot 1",
  "planet_id": int,
  "x": float,           # Position on planet surface
  "y": float,
  "z": float,
  "biome": str,         # "Barren", "Oceanic", "Ice", "Temperate", "Volcanic"
  
  # Grid system for tile placement
  "grid_width": int,    # 256-512 (depends on planet size)
  "grid_height": int,   # 256-512
  
  # Procedural generation
  "tilemap_seed": int,  # 0-2,147,483,647 (unique per location)
  "wang_tile_id": int,  # 0-15 (enables seamless tiling)
  
  # Seamless location transitions
  "edge_north_id": int|null,     # ID of adjacent location (or null)
  "edge_south_id": int|null,
  "edge_east_id": int|null,
  "edge_west_id": int|null,
  
  "adjacent_biome_north": str,   # Biome of adjacent location
  "adjacent_biome_south": str,
  "adjacent_biome_east": str,
  "adjacent_biome_west": str,
  
  # Ownership
  "claimed_by_company_id": int|null,
  "claimed_at": datetime|null
}
```

## Data For Godot Rendering

**Godot receives per-location:**
1. **Biome** (string) - Determines visual texture palette
2. **Grid dimensions** (256-512) - Size of the tilemap
3. **Tilemap seed** (int) - For procedural terrain generation
4. **Wang tile ID** (0-15) - For seamless edge transitions
5. **Edge neighbors** (location IDs) - For map scrolling/teleportation
6. **Resource deposits** - Via separate ResourceDeposit table

**Example Godot pseudocode:**
```gdscript
# Load location data from API
var location = api.get_location(location_id)

# Initialize tilemap
var terrain = TerrainGenerator.create(
  biome = location.biome,        # "Barren", "Temperate", etc
  width = location.grid_width,    # 256-512
  height = location.grid_height,
  seed = location.tilemap_seed,   # Procedural generation
  wang_tile = location.wang_tile_id  # Seamless tiling (0-15)
)

# Load resources
var resources = api.get_location_resources(location_id)
for resource in resources:
  terrain.add_deposit(resource.x, resource.y, resource.type)

# Setup seamless transitions
if location.edge_north_id:
  setup_seamless_edge(terrain, "north", location.edge_north_id)
```

## Key Improvements Over Previous System

| Aspect | Old | New |
|--------|-----|-----|
| Grid size | 16×16 | 256×512 |
| Locations per planet | 3-50 | 3-8 |
| Gameplay duration | Switching locations constantly | Extended sessions per location |
| Seamless tiling | Not supported | Wang tiling (0-15 variants) |
| Edge transitions | Abrupt teleport | Neighbor references for smooth travel |
| Building space | 16×16 grid = too small | 256×512 grid = extensive industry |

## Outlaw Region Bonus
Outlaw regions receive a **20% resource boost**:
- All resource quantities multiplied by 1.2x
- Encourages risk/reward gameplay

## Procedural Generation Strategy
1. **Tilemap seed** ensures same location always generates identical terrain
2. **Wang tile ID** encodes edge compatibility for seamless tiling
3. **Edge neighbors** link locations for player navigation
4. **Adjacent biomes** guide visual transitions at location edges
