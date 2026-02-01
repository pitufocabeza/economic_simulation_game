# Water Shader & Overlay Debugging Guide

## What Changed

1. **Procedural Texture Generation**: Water shader now generates fallback textures if files don't exist
   - Normal texture (for animation)
   - Edge mask (for foam/shoreline effects)
   - These are created on-the-fly in memory

2. **Better Material Assignment**: Applied material to the entire TileMap layer instead of individual tiles
   - More efficient
   - Better compatibility with Godot 4.x

3. **Improved Error Logging**: Script now tells you exactly what's missing

## Expected Behavior

### Water Animation (Should See)
- Water surface should shimmer/ripple
- Colors should change smoothly from deep blue to shallow green
- Animation speed controlled by `water_scroll_speed` (0.3 = subtle)

### Edge Overlays (Should See)
- Slight texture variation at grass → sand → water transitions
- Layer 2 shows detail overlays

### Foam (Optional - Only with proper textures)
- White highlights at shorelines
- Fades inland based on mask

## Troubleshooting

### Water Not Animating
1. Check Godot console for shader errors:
   - Godot Editor → Output Console
   - Look for "shader compilation error"

2. Verify shader file exists:
   - `res://assets/shaders/water_2_5d.gdshader`

3. Check shader syntax:
   - Shader must be valid GLSL

### Water Not Changing Color
1. Procedural edge mask is being generated automatically
2. Colors controlled by uniforms:
   ```
   deep_water_color = (0.1, 0.2, 0.4)  // Dark blue
   shallow_water_color = (0.3, 0.6, 0.4)  // Light green
   ```

### Overlays Not Visible
1. Layer 2 (tilemap_edges) needs tiles assigned
2. Overlays use existing tileset tiles (not custom masks)
3. Probability-based placement:
   - Grass dirt: 15-35% chance
   - Wet sand: 60% at shoreline
   - Foam: 70% in water

## Manual Texture Creation (Optional)

If you want to create proper mask textures:

### water_normal.png (256×256)
- Format: Normal map (Red=X, Green=Y, Blue=Z)
- Should show wave/ripple patterns
- Tool: Substance Designer, Marmoset Toolbag, or online generators

### water_edge_combined_mask.png (256×256)
- Format: Grayscale (single channel)
- White (1.0) = shoreline/shallow
- Black (0.0) = deep water
- Tool: Grayscale gradient, can blur for smooth transitions

### water_base_color.png (256×256)
- Optional detail texture
- Any water-themed pattern works

## Checking Status

Run this in Godot console:

```gdscript
# Check if shader loads
var shader = load("res://assets/shaders/water_2_5d.gdshader")
print(shader)  # Should print "GDShader" object

# Check TileMap material
var tilemap = get_node("TileMap_Base")
print(tilemap.material)  # Should print "ShaderMaterial"
```

## Performance Notes

- Procedural texture generation is O(1) - very fast
- Textures created once and reused
- Memory: ~256KB per texture
- No disk I/O if textures exist

## Integration Complete

The system now:
✅ Loads or generates water textures
✅ Applies shader to water tiles
✅ Places edge overlays
✅ Animates water automatically
✅ Generates edge masks on-the-fly

If water still doesn't show effects, check shader compilation in Godot console.
