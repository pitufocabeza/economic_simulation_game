# Calm Water System Documentation

## Overview

A strategy-game-optimized water rendering system for use with HTerrain terrain. Provides calm, readable water with subtle animation suitable for top-down and angled camera views.

## Design Philosophy

**Water is SEPARATE from terrain:**
- HTerrain handles land collision and rendering
- Water is purely visual (no collision)
- Water never affects or deforms terrain
- Stable and performant at all scales

**Strategy-game aesthetics:**
- Calm, minimal wave motion
- High transparency (0.85) for map readability
- Slow normal map animation (no vertex displacement)
- Suitable for long play sessions

## Implementation

### Water Plane

Single `PlaneMesh` covering the terrain area:
- Size: 120% of terrain bounds
- Position: Constant Y at `current_water_level`
- No horizontal movement (static in X/Z)
- Minimal subdivisions (1x1) - no vertex displacement needed

### Shader: calm_water.gdshader

**Location:** `res://shaders/calm_water.gdshader`

**Features:**
- Two scrolling normal map layers
- Slow animation speeds (0.02 and 0.015)
- Subtle normal strength (0.25)
- High transparency (0.85)
- No vertex displacement

**Shader Parameters:**
```gdscript
water_color         # Base water color (default: blue-green)
water_transparency  # Alpha value (0.85 = mostly transparent)
water_normal        # First normal map texture
water_normal_2      # Second normal map texture
scroll_speed_1      # Speed of first normal layer (0.02)
scroll_speed_2      # Speed of second normal layer (0.015)
normal_strength     # Normal map intensity (0.25 = subtle)
normal_scale_1      # UV scale for first layer (2.0)
normal_scale_2      # UV scale for second layer (3.0)
metallic            # Surface metallic property (0.0)
roughness           # Surface roughness (0.15)
specular            # Specular reflection (0.5)
```

## API Reference

### Variables

#### `current_water_level: float`
Current water height in world coordinates (meters).
- Read this to check water level
- Modify via `update_water_level()` function

### Functions

#### `update_water_level(new_y_value: float) -> void`
Updates water level and repositions water plane.

**Args:**
- `new_y_value`: New water height in world units

**Example:**
```gdscript
terrain_integrator.update_water_level(75.0)  # Set water to 75 meters
```

#### `is_position_underwater(world_position: Vector3) -> bool`
Checks if a 3D position is below the water surface.

**Args:**
- `world_position`: Position in world coordinates

**Returns:**
- `true` if position Y < current_water_level
- `false` otherwise

**Example:**
```gdscript
var ship_pos = Vector3(100, 45, 200)
if terrain_integrator.is_position_underwater(ship_pos):
    print("Ship is submerged!")
```

#### `get_water_depth_at_position(world_position: Vector3) -> float`
Calculates water depth (or height above water) at a position.

**Args:**
- `world_position`: Position in world coordinates

**Returns:**
- **Positive value**: Depth below water surface (meters)
- **Negative value**: Height above water surface (meters)
- **Zero**: Exactly at water surface

**Example:**
```gdscript
var depth = terrain_integrator.get_water_depth_at_position(Vector3(100, 40, 200))
if depth > 0:
    print("Underwater by %.1f meters" % depth)
else:
    print("Above water by %.1f meters" % abs(depth))
```

## Integration Examples

### Check if Building Location is Dry

```gdscript
func can_place_dock(tile_x: int, tile_z: int) -> bool:
    # Convert tile to world position
    var world_pos = tile_to_world(tile_x, tile_z)
    
    # Check if land is above water (for dock placement)
    var depth = terrain_integrator.get_water_depth_at_position(world_pos)
    
    # Dock needs land above water but close to water level
    return depth < 0 and abs(depth) < 5.0  # Within 5m of water
```

### Dynamic Water Level (Tides/Flooding)

```gdscript
func simulate_tide(time: float) -> void:
    # Gentle sine wave tide
    var base_level = 50.0
    var tide_range = 2.0
    var tide_speed = 0.1
    
    var new_level = base_level + sin(time * tide_speed) * tide_range
    terrain_integrator.update_water_level(new_level)
```

### Ship/Boat Movement Validation

```gdscript
func update_ship_position(ship: Node3D, target_pos: Vector3) -> void:
    # Only allow ship to move in water
    var depth = terrain_integrator.get_water_depth_at_position(target_pos)
    
    if depth > 5.0:  # Need at least 5m of water
        ship.position = target_pos
    else:
        push_warning("Ship cannot enter shallow water!")
```

### Underwater Effects

```gdscript
func apply_camera_effects(camera: Camera3D) -> void:
    var cam_depth = terrain_integrator.get_water_depth_at_position(camera.global_position)
    
    if cam_depth > 0:
        # Camera is underwater
        apply_underwater_post_processing(cam_depth)
    else:
        # Camera is above water
        clear_underwater_effects()
```

## Visual Customization

### Changing Water Color

In `hterrain_plot_integrator.gd`, modify the water setup:

```gdscript
# Tropical blue water
material.set_shader_parameter("water_color", Color(0.08, 0.52, 0.72, 0.85))

# Murky swamp water
material.set_shader_parameter("water_color", Color(0.15, 0.25, 0.18, 0.90))

# Arctic ice water
material.set_shader_parameter("water_color", Color(0.18, 0.35, 0.45, 0.75))
```

### Adjusting Animation Speed

```gdscript
# Faster animation (still calm)
material.set_shader_parameter("scroll_speed_1", 0.04)
material.set_shader_parameter("scroll_speed_2", 0.03)

# Slower animation (nearly still)
material.set_shader_parameter("scroll_speed_1", 0.01)
material.set_shader_parameter("scroll_speed_2", 0.008)
```

### Changing Transparency

```gdscript
# More opaque (for deeper oceans)
material.set_shader_parameter("water_transparency", 0.70)

# More transparent (for shallow coastal water)
material.set_shader_parameter("water_transparency", 0.95)
```

## Performance

**Optimized for strategy games:**
- Single mesh (no expensive multi-layer setup)
- Minimal vertex count (1x1 subdivisions)
- Simple shader (normal maps only, no displacement)
- No CPU updates (pure GPU animation)

**Typical performance:**
- Draw calls: 1
- Vertices: 4 (quad)
- GPU cost: Negligible (<0.1ms per frame on mid-range hardware)

## Troubleshooting

### Water not visible
- Check that water level is below camera: `current_water_level < camera.position.y`
- Verify shader file exists: `res://shaders/calm_water.gdshader`
- Ensure normal map textures are assigned

### Water too opaque
- Increase `water_transparency` parameter (0.85-0.95 recommended)
- Check material transparency mode is set correctly

### Animation too fast/slow
- Adjust `scroll_speed_1` and `scroll_speed_2` parameters
- Keep values below 0.05 for strategy game aesthetics

### Water doesn't update when changing level
- Call `update_water_level()` instead of directly modifying `current_water_level`
- Ensure `_update_water_layer_positions()` is being called

## Technical Notes

### Coordinate System
- Water Y level is in **world space** (meters)
- Terrain uses **normalized heights** (0.0-1.0) which are scaled by `VERTICAL_SCALE`
- Conversion: `world_height = normalized_height * VERTICAL_SCALE`

### Water Level Calculation
The default water level is calculated during terrain generation:
```gdscript
current_water_level = WATER_LEVEL_NORM * VERTICAL_SCALE
# Example: 0.25 * 200 = 50 meters
```

### Collision
Water has **no collision shape**. It is purely visual. For gameplay:
- Use `is_position_underwater()` to check if entities can enter water
- Implement your own water logic (swimming, boats, etc.)
- HTerrain provides terrain collision independently

## Credits

Designed for Anno-style strategy city builders where clear, calm water enhances map readability without distracting from gameplay.
