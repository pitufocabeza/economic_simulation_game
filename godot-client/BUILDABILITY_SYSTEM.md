# Buildability System Documentation

## Overview

The buildability system provides Anno 1800-style grid-based building placement for the HTerrain terrain generator. It computes slope-based constraints at the gameplay grid resolution (12–20 tiles), ensuring fair and readable placement rules.

## Architecture

### Design Principles

1. **Terrain Never Fights the Grid**: Terrain is visual flavor; gameplay uses strict grid snapping
2. **False Negatives Preferred**: Better to block a marginally steep tile than allow unfair placement
3. **Conservative Evaluation**: Each tile uses max slope within its footprint
4. **Determinism**: Results depend only on seed, archetype, and terrain parameters
5. **Clean Separation**: Buildability is a separate layer from terrain generation

### Components

- **Slope Computation** (`_compute_slope_map`): Converts heightmap to world-space slopes in degrees
- **Grid Sampling** (`_sample_slopes_at_gameplay_grid`): Downsamples to gameplay resolution
- **Public API**: Clean query functions for gameplay code
- **Debug Visualization**: Optional colored overlay (Green/Yellow/Red)

## Usage

### Basic Queries

```gdscript
# Get slope for a specific tile
var slope = terrain_integrator.get_tile_slope(tile_x, tile_z)  # Returns degrees

# Check if fully buildable (houses, industry)
var can_build = terrain_integrator.is_tile_buildable(tile_x, tile_z)

# Check if conditionally buildable (roads, farms)
var can_build_road = terrain_integrator.is_tile_conditionally_buildable(tile_x, tile_z)

# Get human-readable status
var status = terrain_integrator.get_buildability_status(tile_x, tile_z)
# Returns: "buildable", "conditional", "blocked", or "invalid"
```

### Multi-Tile Buildings

```gdscript
# Check if a 3x3 building can be placed
func can_place_building(start_x: int, start_z: int, size: Vector2i) -> bool:
    for z in range(size.y):
        for x in range(size.x):
            if not terrain_integrator.is_tile_buildable(start_x + x, start_z + z):
                return false
    return true
```

### Debug Visualization

Press **B** in-game to toggle the buildability overlay:
- **Green**: Fully buildable (slope ≤ 5°)
- **Yellow**: Conditional (slope ≤ 8°, roads/farms only)
- **Red**: Blocked (slope > 8°, cliffs/mountains)

Or toggle programmatically:
```gdscript
terrain_integrator.show_buildability_debug = true
terrain_integrator.toggle_buildability_debug()
```

## Configuration

Adjust thresholds in the Inspector or via code:

```gdscript
# In hterrain_plot_integrator.gd
@export var BUILDABLE_SLOPE_MAX: float = 5.0      # Fully buildable threshold
@export var CONDITIONAL_SLOPE_MAX: float = 8.0    # Conditional threshold
```

### Recommended Thresholds

| Building Type | Max Slope | Setting |
|--------------|-----------|---------|
| Houses, Factories | 5° | `BUILDABLE_SLOPE_MAX` |
| Roads, Farms | 8° | `CONDITIONAL_SLOPE_MAX` |
| Everything Else | — | Blocked |

Real-world context:
- 5° ≈ 8.7% grade (gentle hill)
- 8° ≈ 14% grade (noticeable slope)
- 15° ≈ 27% grade (steep hill)

## Implementation Details

### Slope Calculation

Slopes are computed in **world space** using central differences:

1. Sample neighboring heights (in meters, scaled by `VERTICAL_SCALE`)
2. Compute gradients: `∂h/∂x` and `∂h/∂z`
3. Calculate slope magnitude: `√(gradient_x² + gradient_z²)`
4. Convert to degrees: `atan(slope) * 180/π`

### Grid Sampling

The system maps the high-resolution terrain (e.g., 1025×1025) to the gameplay grid (12–20 tiles):

1. Divide terrain into tile regions
2. Sample all slopes within each region
3. Use **maximum slope** (conservative evaluation)
4. Store in `slope_grid[tile_z][tile_x]`

### Performance

- Slope map computed once per terrain generation
- Lookups are O(1) array access
- No runtime raycast or physics queries needed
- Minimal memory overhead (~16×16 floats)

## Integration Examples

### Building Placement System

```gdscript
func attempt_place_building(tile_pos: Vector2i, building_type: String) -> bool:
    var size = BUILDING_SIZES[building_type]  # e.g., Vector2i(3, 3)
    
    # Check all tiles in footprint
    for z in range(size.y):
        for x in range(size.x):
            var check_pos = tile_pos + Vector2i(x, z)
            
            # Check buildability
            if not terrain_integrator.is_tile_buildable(check_pos.x, check_pos.y):
                show_error_message("Terrain too steep!")
                return false
            
            # Check for existing buildings, etc.
            # ...
    
    # Place building
    create_building(tile_pos, building_type)
    return true
```

### Road Pathfinding

```gdscript
func is_tile_traversable(tile_x: int, tile_z: int) -> bool:
    # Roads can go on conditional slopes
    return terrain_integrator.is_tile_conditionally_buildable(tile_x, tile_z)

func find_road_path(start: Vector2i, end: Vector2i) -> Array:
    # Use A* with is_tile_traversable as walkability check
    return astar_pathfind(start, end, is_tile_traversable)
```

### UI Feedback

```gdscript
func show_building_ghost(tile_pos: Vector2i, building_size: Vector2i) -> void:
    for z in range(building_size.y):
        for x in range(building_size.x):
            var check_pos = tile_pos + Vector2i(x, z)
            var status = terrain_integrator.get_buildability_status(check_pos.x, check_pos.y)
            
            # Color ghost tiles based on buildability
            match status:
                "buildable":
                    set_tile_color(check_pos, Color.GREEN)
                "conditional":
                    set_tile_color(check_pos, Color.YELLOW)
                "blocked":
                    set_tile_color(check_pos, Color.RED)
```

## Testing

A test script is provided at `scripts/buildability_test.gd`:

```bash
# Add to your scene to test queries
var test = preload("res://scripts/buildability_test.gd").new()
add_child(test)
```

Press **Q** to query a sample tile with detailed output.

## Keyboard Controls

| Key | Action |
|-----|--------|
| **R** | Regenerate terrain (new seed) |
| **T** | Cycle plot size (12/16/20) |
| **C** | Cycle archetype (Plains/Coast/Hills/etc.) |
| **B** | Toggle buildability debug overlay |

## API Reference

### Query Functions

#### `get_tile_slope(tile_x: int, tile_z: int) -> float`
Returns maximum slope in degrees for the tile, or -1.0 if invalid.

#### `is_tile_buildable(tile_x: int, tile_z: int) -> bool`
Returns true if slope ≤ BUILDABLE_SLOPE_MAX (suitable for buildings).

#### `is_tile_conditionally_buildable(tile_x: int, tile_z: int) -> bool`
Returns true if slope ≤ CONDITIONAL_SLOPE_MAX (suitable for roads/farms).

#### `get_buildability_status(tile_x: int, tile_z: int) -> String`
Returns "buildable", "conditional", "blocked", or "invalid".

### Debug Functions

#### `toggle_buildability_debug() -> void`
Toggles the colored overlay visualization.

### Variables

#### `gameplay_grid_size: int`
Current grid resolution (12, 16, or 20). Updated automatically when terrain generates.

#### `slope_grid: Array`
2D array of slopes at gameplay grid resolution. Format: `slope_grid[tile_z][tile_x]` → float (degrees).

## Troubleshooting

### "Buildability layer not computed yet"
Wait for terrain generation to complete before querying. Use signals or await:
```gdscript
await get_tree().process_frame
var slope = terrain_integrator.get_tile_slope(5, 5)
```

### Tiles look flat but marked as steep
Check `VERTICAL_SCALE` setting. If too high, minor height variations become steep slopes.

### All tiles blocked
- Verify `BUILDABLE_SLOPE_MAX` isn't too low (recommended: 5°)
- Check archetype isn't generating excessive cliffs (e.g., "Ring" archetype)
- Enable debug overlay (press B) to visualize slope distribution

### Debug overlay not visible
- Ensure camera is positioned above terrain
- Check `show_buildability_debug` is true
- Verify overlay height in `_create_buildability_debug_overlay()`

## Future Enhancements

Possible extensions to the system:

1. **Water Avoidance**: Mark tiles below water level as unbuildable
2. **Proximity Rules**: Reduce buildability near cliffs/edges
3. **Building-Specific Rules**: Different thresholds per building type
4. **Fertility Layer**: Combine slope with soil quality for farms
5. **Aesthetic Scoring**: Prefer flatter areas but don't hard-block marginal slopes

## Credits

Inspired by Anno 1800's grid-based city building system, where terrain provides visual interest without compromising fair gameplay.
