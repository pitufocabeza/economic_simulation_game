# Water Edge Mask Generator Integration Guide

## Overview

`water_edge_mask_generator.gd` automatically generates shoreline masks for water tiles, enabling your water shader to render foam, algae, and shallow water effects near land.

## Architecture

### How It Works

1. **Biome Detection**: Iterates all water tiles in a biome grid
2. **Neighbor Analysis**: Checks 4 or 8 neighboring tiles for land
3. **Signature Computation**: Creates a bitmask showing which directions border land
4. **Texture Selection**: Maps signatures to appropriate edge mask textures
5. **Material Application**: Assigns masks to water tile shader materials

### Data Flow

```
TileMap (world grid)
       ↓
Biome Map (Dictionary of positions → biome types)
       ↓
Water Edge Mask Generator
       ├─ Detect shoreline water tiles
       ├─ Compute edge signatures (bitmask)
       ├─ Select mask textures from signature
       └─ Apply to ShaderMaterial uniforms
       ↓
Water Shader (uses water_edge_mask texture)
       ↓
Rendered foam, algae, shallow water effects
```

## Installation & Setup

### 1. Add the Script to Your Scene

```gdscript
# In your terrain generator or main scene
extends Node2D

var water_mask_gen: Node

func _ready():
	# Create water mask generator
	water_mask_gen = load("res://scripts/water_edge_mask_generator.gd").new()
	add_child(water_mask_gen)
	
	# Initialize with your tilemap and biome data
	water_mask_gen.initialize(tilemap, tileset, base_map)
	
	# Generate edge masks
	water_mask_gen.generate_all_water_edge_masks()
```

### 2. Integration with temperate_map_generator.gd

```gdscript
# In temperate_map_generator.gd _ready() or generate_map()

func generate_map():
	# ... existing code ...
	
	# After creating base_map and placing tiles:
	
	# Generate water edge masks
	var water_mask_gen = load("res://scripts/water_edge_mask_generator.gd").new()
	add_child(water_mask_gen)
	water_mask_gen.initialize(tilemap_base, tileset, base_map)
	water_mask_gen.generate_all_water_edge_masks()
```

### 3. Prepare Mask Textures

Create or export edge mask textures for all patterns:

```
assets/tilesets/temperate/
├── water_edge_north.png       # Land to north
├── water_edge_east.png        # Land to east
├── water_edge_south.png       # Land to south
├── water_edge_west.png        # Land to west
├── water_edge_ne.png          # Corner: northeast
├── water_edge_se.png          # Corner: southeast
├── water_edge_sw.png          # Corner: southwest
├── water_edge_nw.png          # Corner: northwest
├── water_edge_inner_ne.png    # Interior corner
├── water_edge_inner_se.png
├── water_edge_inner_sw.png
├── water_edge_inner_nw.png
└── water_edge_full.png        # All surrounded
```

**Texture Format:**
- Grayscale PNG with alpha channel
- Values: 0.0 (black) = deep water, 0.3-0.7 (gray) = shallow, 1.0 (white) = shoreline
- Size: 256×256 (matching your tile size)
- Seamlessly tileable

## API Reference

### Constants

```gdscript
const BIOME_WATER = 2
const BIOME_SAND = 1
const BIOME_GRASS = 0
```

### Initialization

```gdscript
initialize(p_tilemap: TileMap, p_tileset: TileSet, p_biome_map: Dictionary)
```

Initialize with your tilemap, tileset, and biome grid dictionary.

**Example:**
```gdscript
var base_map = {}  # Build this during map generation
for y in range(height):
    for x in range(width):
        var pos = Vector2i(x, y)
        base_map[pos] = biome_type  # 0=grass, 1=sand, 2=water

water_mask_gen.initialize(tilemap, tileset, base_map)
```

### Biome Detection

```gdscript
is_water(biome_type: int) -> bool
is_land(biome_type: int) -> bool
get_biome_at(pos: Vector2i) -> int
```

### Neighbor Checking

```gdscript
has_land_neighbor_cardinal(pos: Vector2i) -> bool  # 4-directional
has_land_neighbor_diagonal(pos: Vector2i) -> bool  # 8-directional
has_land_neighbor(pos: Vector2i) -> bool           # Any neighbor
```

### Edge Signature Computation

```gdscript
compute_edge_signature_4dir(pos: Vector2i) -> int
compute_edge_signature_8dir(pos: Vector2i) -> int
```

Returns a bitmask where each bit represents a direction:

**4-directional (cardinal):**
```
Bit 0: North
Bit 1: East
Bit 2: South
Bit 3: West
```

**8-directional:**
```
Bit 0: North
Bit 1: Northeast
Bit 2: East
Bit 3: Southeast
Bit 4: South
Bit 5: Southwest
Bit 6: West
Bit 7: Northwest
```

**Example:**
```gdscript
var sig = compute_edge_signature_4dir(Vector2i(5, 3))
# If water at (5,3) has land to North and East:
# sig = 0b0011 = 3

if (sig & (1 << 0)) != 0:  # Check North
    print("Has land to north")
```

### Texture Selection

```gdscript
get_edge_mask_texture(signature: int) -> String
```

Maps a signature to a texture name from the registry.

```gdscript
get_edge_rotation(signature: int) -> int      # 0, 1, 2, 3 (×90°)
get_edge_flip(signature: int) -> bool         # Horizontal flip
```

### Main Generation

```gdscript
generate_all_water_edge_masks()
```

Iterates all water tiles and generates masks. Prints statistics.

### Debug Functions

```gdscript
debug_signature_at(pos: Vector2i)
print_signature_stats()
```

**Example:**
```gdscript
water_mask_gen.debug_signature_at(Vector2i(10, 15))

# Output:
# Position (10, 15):
#   4-dir signature: 0011 (0x03)
#   8-dir signature: 00010011 (0x13)
#   Edge mask texture: water_edge_ne
#   Rotation: 0°
#   Flip H: false
```

### Configuration

```gdscript
set_simple_edges(enabled: bool)          # Use 4-directional vs 8-directional
set_rotation_enabled(enabled: bool)      # Support rotation of textures
register_custom_edge_variant(signature: int, textures: Array)
```

## Edge Signature Patterns

### 4-Directional Examples

| Pattern | Signature | Visual | Texture |
|---------|-----------|--------|---------|
| Land to North | `0b0001` | `▲` | water_edge_north |
| Land to East | `0b0010` | `▶` | water_edge_east |
| Land to South | `0b0100` | `▼` | water_edge_south |
| Land to West | `0b1000` | `◀` | water_edge_west |
| NE Corner | `0b0011` | `┐` | water_edge_ne |
| SE Corner | `0b0110` | `┌` | water_edge_se |
| SW Corner | `0b1100` | `┘` | water_edge_sw |
| NW Corner | `0b1001` | `└` | water_edge_nw |
| Full surround | `0b1111` | `◼` | water_edge_full |

## Rotation & Flipping

The generator can automatically rotate and flip edge textures to reduce the number of required texture variants.

**Example with rotation:**
```
Signature: 0b0010 (land to East)
Rotation: 90° → reuse "water_edge_north.png" rotated

This means you only need ONE directional texture:
water_edge_north.png → reused at 0°, 90°, 180°, 270°
```

**To enable/disable:**
```gdscript
water_mask_gen.set_rotation_enabled(true)   # Support rotation
water_mask_gen.set_rotation_enabled(false)  # No rotation
```

## Texture Registry

Customize which textures map to which signatures:

```gdscript
var edge_mask_variants = {
	0b00000001: ["water_edge_north"],
	0b00000100: ["water_edge_east"],
	# ... etc
}

# Or add variants:
water_mask_gen.register_custom_edge_variant(0b00000001, [
	"water_edge_north_v1",
	"water_edge_north_v2",
	"water_edge_north_v3",
])
```

Multiple variants per signature allows the generator to pick randomly, breaking repetition.

## Material Assignment

By default, the generator creates ShaderMaterial instances with `water_2_5d.gdshader`.

**To customize:**
```gdscript
func create_water_shader_material() -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = load("res://assets/shaders/custom_water.gdshader")
	material.set_shader_parameter("foam_threshold", 0.8)
	return material
```

## Performance Considerations

| Aspect | Cost | Notes |
|--------|------|-------|
| **BFS distance calc** | O(n) per tile | Not used here (faster approach) |
| **Neighbor checks** | O(1) | Simple array lookup |
| **Signature computation** | O(1) | 8 bits max |
| **Texture loading** | I/O | Cached by Godot |
| **Material creation** | GPU | One per unique material |

For a 32×32 map: ~100 shoreline tiles × ~50 operations = negligible cost.

## Troubleshooting

### Masks Not Appearing

**Symptoms:** Water looks flat, no edge effects visible

**Fixes:**
1. Verify textures exist:
   ```gdscript
   water_mask_gen.print_signature_stats()  # Shows which signatures appear
   debug_signature_at(Vector2i(10, 10))    # Check specific tile
   ```

2. Check material assignment:
   ```gdscript
   var cell_data = tilemap.get_cell_tile_data(0, pos)
   print(cell_data.material)  # Should not be null
   ```

3. Verify shader loads:
   ```gdscript
   var shader = load("res://assets/shaders/water_2_5d.gdshader")
   print(shader)  # Should not be null
   ```

### Incorrect Rotations/Flips

**Symptoms:** Edge masks appear upside-down or mirrored incorrectly

**Fixes:**
1. Disable rotation for debugging:
   ```gdscript
   water_mask_gen.set_rotation_enabled(false)
   ```

2. Use dedicated textures instead (16+ variants)

3. Adjust `get_edge_rotation()` logic if needed

### Hard Edges Visible

**Symptoms:** Clear seams between tiles

**Fixes:**
1. Ensure mask textures are **seamlessly tileable**
2. Use soft (gradient-based) transitions in masks, not hard cutoffs
3. Increase overlap in shader using `texture(water_edge_mask, UV * 1.2)`

## Advanced: Custom Edge Patterns

### Adding a New Pattern

```gdscript
# In water_edge_mask_generator.gd, extend edge_mask_simple:

var edge_mask_simple = {
	# ... existing patterns ...
	
	# New: T-shaped shoreline
	0b1110: ["water_edge_t_shaped"],
	
	# New: Custom island interior
	0b1010: ["water_edge_island_interior"],
}
```

Then create corresponding textures:
- `water_edge_t_shaped.png`
- `water_edge_island_interior.png`

### Random Variants Per Signature

```gdscript
var edge_mask_variants = {
	0b00000001: [
		"water_edge_north_v1",
		"water_edge_north_v2",
		"water_edge_north_v3",
		"water_edge_north_foam_heavy",
	],
	# When signature matches 0b00000001, randomly selects one
}
```

## Integration Checklist

- [ ] Script added to project (`scripts/water_edge_mask_generator.gd`)
- [ ] Edge mask textures created (at least 8 cardinal variants)
- [ ] Textures in `assets/tilesets/temperate/`
- [ ] Water shader loaded (`assets/shaders/water_2_5d.gdshader`)
- [ ] Biome map generated in terrain generator
- [ ] `initialize()` called with biome data
- [ ] `generate_all_water_edge_masks()` called after map generation
- [ ] Tested with `debug_signature_at()` on known shorelines
- [ ] Shader uniforms visible in material inspector

## Example Full Integration

```gdscript
# In temperate_map_generator.gd

func generate_map():
	# ... existing terrain generation ...
	
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			base_map[pos] = compute_biome_type(noise_values[pos])
	
	# NEW: Generate water edge masks
	var water_mask_gen = load("res://scripts/water_edge_mask_generator.gd").new()
	add_child(water_mask_gen)
	water_mask_gen.initialize(tilemap_base, tileset, base_map)
	water_mask_gen.set_simple_edges(true)      # Use 4-directional
	water_mask_gen.set_rotation_enabled(true)  # Support rotation
	water_mask_gen.generate_all_water_edge_masks()
	
	print("Water masks generated successfully")
```

## See Also

- [water_2_5d.gdshader](../assets/shaders/water_2_5d.gdshader) - Water shader implementation
- [WATER_SHADER_GUIDE.md](WATER_SHADER_GUIDE.md) - Shader documentation
- [temperate_map_generator.gd](../godot-client/scenes/temperate_map_generator.gd) - Terrain generation
