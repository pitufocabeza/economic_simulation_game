# Water Shader for 2.5D Top-Down TileMap

## Overview

`water_2_5d.gdshader` is a CanvasItem shader designed for Godot 4.x orthographic top-down worlds (like Factorio style). It implements:

- **Color Gradients**: Deep water (dark blue) → Shallow water (light green)
- **Animated Normals**: Two scrolling normal samples for non-repeating water movement
- **Shoreline Foam**: High-density white foam near shore, fading inland
- **Depth Fake**: Subtle darkening to simulate depth without 3D
- **Smooth Transitions**: No hard edges, all blending uses smoothstep

## Installation

### 1. Place Textures in Assets

```
godot-client/assets/tilesets/temperate/
├── water_base_color.png
├── water_normal.png
├── water_edge_combined_mask.png
└── water_foam.png (optional)
```

### 2. Create ShaderMaterial

1. In Godot editor, create a new **ShaderMaterial**
2. Set its **Shader** property to `res://assets/shaders/water_2_5d.gdshader`
3. Assign the ShaderMaterial to your water TileMap layer

### 3. Assign to TileMap

```gdscript
# In your scene or script
var water_tilemap: TileMap = $TileMap_Water
var shader_material = ShaderMaterial.new()
shader_material.shader = load("res://assets/shaders/water_2_5d.gdshader")
water_tilemap.material = shader_material
```

## Texture Requirements

### water_edge_combined_mask.png (CRITICAL)

This mask defines water depth zones:

```
Value Range   | Meaning              | Visual Effect
============================================
1.0 (white)   | Directly at shoreline| Maximum foam, bright highlight
0.3–0.7       | Shallow water        | Algae tint, medium foam
0.0 (black)   | Deep water           | Dark, no foam
```

**Generation Notes:**
- Use your biome edge generator to create this mask
- Should be tileable and aligned to TileMap grid
- Smooth transitions (use Gaussian blur in image editor if needed)
- Size: 256×256 or matching your tile size

### water_base_color.png

- Base water texture (optional detail)
- Can be a subtle pattern or solid color
- Blended at 30% with computed color gradient

### water_normal.png

- Standard normal map format (Red=X, Green=Y, Blue=Z)
- Should be seamlessly tileable
- Used for specular/ripple effects
- Two copies scroll at different speeds for animation

### water_foam.png (Optional)

- Grayscale noise texture for foam breakup
- Prevents uniform foam appearance
- Examples: Perlin noise, cloud texture
- Falls back to white if not provided

## Shader Uniforms

### Texture Uniforms

| Uniform | Type | Purpose |
|---------|------|---------|
| `water_color_tex` | Sampler2D | Base water texture |
| `water_normal_tex` | Sampler2D | Normal map for animation |
| `water_edge_mask` | Sampler2D | Shoreline/depth mask (WHITE=shore, BLACK=deep) |
| `foam_noise_tex` | Sampler2D | Foam detail/breakup noise |

### Color Uniforms

| Uniform | Default | Purpose |
|---------|---------|---------|
| `deep_water_color` | (0.1, 0.2, 0.4, 1.0) | Deep water RGB (dark blue) |
| `shallow_water_color` | (0.3, 0.6, 0.4, 1.0) | Shallow water RGB (light green) |
| `foam_color` | (0.95, 0.95, 1.0, 1.0) | Foam RGB (bright white) |

### Foam Parameters

| Uniform | Range | Default | Purpose |
|---------|-------|---------|---------|
| `foam_threshold` | 0.0–1.0 | 0.7 | Where foam starts (0.7 = foam above 70% mask value) |
| `foam_strength` | 0.0–2.0 | 1.5 | Intensity multiplier for foam opacity |
| `foam_fade_distance` | 0.0–1.0 | 0.4 | How far inland foam fades (0.4 = fades over 40% of shallow zone) |

### Animation Parameters

| Uniform | Range | Default | Purpose |
|---------|-------|---------|---------|
| `water_scroll_speed` | 0.0–2.0 | 0.3 | Speed of normal map animation (0.3 = subtle) |
| `normal_strength` | 0.0–3.0 | 1.5 | Amplitude of normal perturbation |
| `time_scale` | 0.1–5.0 | 1.0 | Global time multiplier (1.0 = normal speed) |

### Color Gradient Parameters

| Uniform | Range | Default | Purpose |
|---------|-------|---------|---------|
| `shallow_transition` | 0.0–1.0 | 0.4 | Zone width for deep→shallow transition |
| `subtle_noise_strength` | 0.0–0.3 | 0.1 | Color variation to break up flat areas |

## Configuration Examples

### Calm Lake (Minimal Animation)

```gdscript
water_scroll_speed = 0.1
normal_strength = 0.8
foam_strength = 0.8
foam_fade_distance = 0.2
```

### Choppy Ocean (High Energy)

```gdscript
water_scroll_speed = 0.8
normal_strength = 2.5
foam_strength = 2.0
foam_fade_distance = 0.6
deep_water_color = vec4(0.0, 0.1, 0.3, 1.0)  # Even darker
```

### Shallow Swamp (Algae-Heavy)

```gdscript
shallow_water_color = vec4(0.2, 0.5, 0.2, 1.0)  # Greenish
foam_strength = 0.5  # Less foam
shallow_transition = 0.6  # Wider shallow zone
subtle_noise_strength = 0.2  # More color variation
```

### Crystal Clear (Alpine Lake)

```gdscript
deep_water_color = vec4(0.2, 0.4, 0.6, 1.0)  # Lighter
shallow_water_color = vec4(0.5, 0.8, 0.7, 1.0)  # Very light
foam_threshold = 0.8  # Only foam at very edge
foam_strength = 1.0  # Moderate
```

## Shader Breakdown

### 1. Edge Mask Sampling

```glsl
float edge_mask = texture(water_edge_mask, UV).r;
// 0.0 = deep water, 1.0 = shoreline
```

The mask is the **core** of the shader. All depth-based effects depend on this value.

### 2. Normal Animation

```glsl
vec2 uv_scroll_1 = UV + vec2(TIME * water_scroll_speed, TIME * water_scroll_speed * 0.5) * time_scale;
vec2 uv_scroll_2 = UV + vec2(TIME * water_scroll_speed * -0.7, TIME * water_scroll_speed * 0.8) * time_scale;

vec3 normal_1 = normalize(texture(water_normal_tex, uv_scroll_1).rgb * 2.0 - 1.0);
vec3 normal_2 = normalize(texture(water_normal_tex, uv_scroll_2).rgb * 2.0 - 1.0);

vec3 combined_normal = normalize(normal_1 + normal_2);
```

Two normal samples scroll at different rates:
- Sample 1: (speed, speed×0.5)
- Sample 2: (speed×-0.7, speed×0.8)

This creates non-repeating motion. The negative and fractional factors prevent aliasing.

### 3. Color Gradient

```glsl
float depth_factor = smoothstep(0.0, shallow_transition, edge_mask);
vec4 water_color = mix(deep_water_color, shallow_water_color, depth_factor);
```

Uses `smoothstep` to interpolate smoothly from deep (factor=0) to shallow (factor=1).

### 4. Foam Calculation

```glsl
float foam_base = smoothstep(foam_threshold - 0.1, foam_threshold + foam_fade_distance, edge_mask);
```

Foam appears only when:
- `edge_mask > foam_threshold` (default: 0.7)
- Fades smoothly from `foam_threshold - 0.1` to `foam_threshold + foam_fade_distance`

```glsl
float foam_modulation = foam_noise * foam_noise;
foam_modulation += sin(TIME * 2.0 + UV.x * 10.0) * 0.3;  // Pulsing
```

Foam strength modulates with:
- **Foam noise texture** (squared for brightness)
- **Sine wave** based on TIME for subtle pulsing

### 5. Depth Darkening

```glsl
float depth_darkening = 1.0 - (1.0 - edge_mask) * 0.3;
water_color.rgb *= depth_darkening;
```

As `edge_mask` decreases (deeper water), color darkens by up to 30%.

## Texture Alignment

**CRITICAL:** The shader assumes `water_edge_combined_mask` is **TileMap-aligned**.

```
TileMap Grid         Mask Alignment
┌────┬────┬────┐    ┌────┬────┬────┐
│ T0 │ T1 │ T2 │    │ M0 │ M1 │ M2 │
├────┼────┼────┤    ├────┼────┼────┤
│ T3 │ T4 │ T5 │ = │ M3 │ M4 │ M5 │
└────┴────┴────┘    └────┴────┴────┘

Each tile (T) uses its corresponding mask region (M)
```

If tiles are 256×256 and your atlas is 2048×2048, each mask section should be 256×256.

## Performance Notes

- **Cost**: ~5 texture samples per fragment (normal_tex ×2, edge_mask, color_tex, foam_noise)
- **Suitable for**: 32×32 to 128×128 TileMaps on mid-range hardware
- **Optimization**: Reduce `time_scale` or disable `subtle_noise_strength` if needed

## Troubleshooting

### Foam Appears Everywhere
- **Cause**: `foam_threshold` too low
- **Fix**: Increase `foam_threshold` to 0.8 or higher
- **Also check**: Is `water_edge_combined_mask` correctly generated? (White at shore only)

### Water Looks Flat / No Animation
- **Cause**: `water_scroll_speed` too low
- **Fix**: Increase to 0.5–1.0
- **Also check**: Is `water_normal_tex` a valid normal map?

### Hard Edges Between Deep and Shallow
- **Cause**: `shallow_transition` too small
- **Fix**: Increase to 0.5–0.8
- **Also check**: Is `water_edge_combined_mask` smooth? (Use Gaussian blur)

### Tiling Visible / Repeating Patterns
- **Cause**: Normal map or mask not seamlessly tileable
- **Fix**: Regenerate textures with seamless algorithms
- **Also**: Increase `water_scroll_speed` to hide patterns faster

### Material Not Updating
- **Cause**: Material not assigned to correct layer
- **Fix**: Ensure `tilemap.material = shader_material`
- **Also**: Check layer Z-order (water should be Z=2 or lower)

## Integration with Biome Generator

Your [temperate_map_generator.gd](../scenes/temperate_map_generator.gd) creates `water_edge_combined_mask` for edge overlays. This same mask feeds directly into the water shader:

```gdscript
# In temperate_map_generator.gd
var edge_overlays = {
    "water_foam": ["water_foam_mask"],
    "water_algae": ["water_algae_mask"],
    # ... etc
}

# In water shader
uniform sampler2D water_edge_mask;  // <-- Uses the same mask generated here
```

## Advanced Techniques

### Adding Depth Buffer Interaction

If you later add parallax or depth effects:

```glsl
// Pseudo-code (not in base shader)
float screen_depth = texture(screen_depth_tex, SCREEN_UV).r;
float foam_from_depth = 1.0 - screen_depth;  // Foam only at surface
```

### Directional Wave Animation

To align waves with wind direction:

```glsl
// Replace uv_scroll_1/2 calculation
vec2 wind_dir = normalize(vec2(1.0, 0.5));  // Diagonal
vec2 uv_scroll_1 = UV + wind_dir * TIME * water_scroll_speed;
```

### Season-Based Color Swapping

```glsl
uniform float season;  // 0.0 = summer, 1.0 = winter
vec4 summer_color = vec4(0.3, 0.6, 0.4, 1.0);
vec4 winter_color = vec4(0.2, 0.3, 0.5, 1.0);
shallow_water_color = mix(summer_color, winter_color, season);
```

## References

- Godot Shader Documentation: https://docs.godotengine.org/en/stable/tutorials/shaders/
- Normal Map Format: Red=X, Green=Y, Blue=Z (standard)
- CanvasItem Shaders: Built-in variables: `TIME`, `UV`, `COLOR`, `TEXTURE`

## License

Part of the Economic Simulation Game project. Use freely within project scope.
