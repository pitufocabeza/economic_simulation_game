# Terrain Generator Buildability Integration

## Overview

The terrain generator now includes **post-processing passes** that shape terrain to naturally support grid-based building placement. These run after all existing generation (noise, macro shapes, rivers) and ensure the output works well with the slope-based buildability system.

## Design Philosophy

**Terrain must support gameplay, not fight it.**

- **Interior regions**: Calm, readable, and buildable
- **Edge regions**: Steep cliffs that clearly block expansion
- **Rivers**: Accessible, not surrounded by accidental cliffs

## Implementation

### Three Post-Processing Functions

#### 1. `_flatten_buildable_core(height_map, archetype)`

**Purpose**: Dampen micro-slopes in the interior region to prevent accidental steep tiles.

**How it works**:
- Uses archetype's `buildable_ratio` to determine core radius
- Applies distance-based smoothing from center outward
- Blends each point toward its 3x3 neighborhood average
- Stronger smoothing in center (60% max), fading to edges
- Preserves overall height variation, only removes sharp bumps

**Result**: Interior feels intentionally flat and usable.

#### 2. `_force_edge_mountains(height_map, archetype)`

**Purpose**: Create steep, clearly non-buildable cliffs at region boundaries.

**How it works**:
- Calculates distance to nearest edge for each point
- Applies height boost within edge band (~18% of region size)
- Uses power curve (2.5 exponent) for steep falloff
- Ensures minimum height (sea_level + 0.25) at edges
- Skips Coastal Shelf archetype (has natural water boundary)

**Result**: Clear visual and gameplay boundaries. No ambiguous slopes.

#### 3. `_soften_river_banks(height_map)` [Conditional]

**Purpose**: Smooth transitions near rivers to prevent accidental steep banks.

**How it works**:
- Identifies low-elevation areas (< 0.30 normalized height)
- Marks water/river tiles
- Smooths tiles within 2-tile radius of water
- Applies 40% blend toward 3x3 neighborhood average
- Only runs for archetypes with `has_river: true`

**Result**: Rivers are accessible and readable.

## Integration into Generation Pipeline

The post-processing runs at the **end** of `_generate_height_map()`:

```gdscript
# 1. Existing generation (noise, macro shapes)
# ...

# 2. River carving (if applicable)
if archetype_data.has("has_river") and archetype_data["has_river"]:
    height_map = _carve_river(height_map, archetype, coast_mask, rng)

# 3. POST-PROCESSING (NEW)
height_map = _flatten_buildable_core(height_map, archetype)
height_map = _force_edge_mountains(height_map, archetype)

if archetype_data.has("has_river") and archetype_data["has_river"]:
    height_map = _soften_river_banks(height_map)

return height_map
```

## Archetype Behavior

Each archetype already defines a `buildable_ratio` that influences the core smoothing:

| Archetype | Buildable Ratio | Core Treatment |
|-----------|----------------|----------------|
| Flat Plains | 0.80 | Large calm interior |
| Agricultural Plateau | 0.75 | Large calm interior |
| Gentle Hills | 0.70 | Moderate interior |
| Coastal Shelf | 0.65 | Moderate interior, no edge mountains |
| Forest Edge | 0.65 | Moderate interior |
| River Basin | 0.60 | Smaller calm zone |

## Expected Buildability Results

After these post-processing passes:

### Interior (Buildable Core)
- **Target**: 60-80% fully buildable tiles (≤ 5° slope)
- Micro-slopes dampened
- Smooth height transitions
- Clear, readable terrain

### Transition Zone
- **Target**: Mix of buildable and conditional tiles
- Gentle slopes for roads/farms
- Natural gradient from flat to steep

### Edge Mountains
- **Target**: 100% non-buildable (> 8° slope)
- Steep cliffs
- Visual expansion blockers
- Clear gameplay boundaries

## Technical Details

### Determinism
- All functions use only the heightmap and archetype data
- No randomness introduced in post-processing
- Same seed + archetype = identical results

### Performance
- Runs once per terrain generation (not per frame)
- Simple neighborhood sampling (3x3 kernels)
- O(n²) complexity where n = GRID_RESOLUTION (12-20)
- Negligible performance impact

### Preservation of Existing Features
- **Does NOT modify**: Noise generation, macro shapes, river carving
- **Does NOT add**: New randomness or noise layers
- **Only smooths**: High-frequency bumps that create accidental slopes

## Testing

Generate different archetypes and press **B** to view buildability overlay:

1. **Flat Plains**: Should show mostly green (buildable) interior
2. **Gentle Hills**: Should show green valleys, yellow hills, red edges
3. **River Basin**: Should show buildable banks, clear river, steep edges
4. **Coastal Shelf**: Should show clear coast/land transition, buildable interior

Expected improvements:
- More consistent buildability in center regions
- Fewer "surprise" steep tiles in flat-looking areas
- Clear non-buildable boundaries at edges

## Future Tuning

If buildability results need adjustment, modify these parameters:

### In `_flatten_buildable_core()`:
```gdscript
var core_radius = (buildable_ratio * 0.45) * float(size)  # Increase 0.45 for larger calm zone
var smoothing_strength = influence * 0.6  # Increase 0.6 for stronger smoothing
```

### In `_force_edge_mountains()`:
```gdscript
var edge_depth = float(size) * 0.18  # Increase for deeper mountain band
var mountain_height_boost = 0.35  # Increase for steeper cliffs
```

### In `_soften_river_banks()`:
```gdscript
var smooth_radius = 2  # Increase for wider smooth corridor
processed_map[z][x] = lerp(original, local_avg, 0.4)  # Increase 0.4 for more smoothing
```

## Credits

Designed to complement the slope-based buildability system in `hterrain_plot_integrator.gd`, creating an end-to-end terrain generation pipeline optimized for Anno-style city building gameplay.
