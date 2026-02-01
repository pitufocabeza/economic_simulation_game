# Texture Setup Guide

## Required Textures

The game needs the following textures. If they don't exist, the map will still generate but will be invisible.

Place these files in: `godot-client/assets/tilesets/temperate/`

### Base Biome Tiles (REQUIRED for map to display)

```
temperate_grass_base.png      (256×256) - Default grass tile
temperate_beach_base.png      (256×256) - Default sand tile  
temperate_water_base.png      (256×256) - Default water tile
```

### Detail Variants (used for color variation)

**Grass:**
```
temperate_grass_dry.png       (256×256) - Dry grass
temperate_grass_lush.png      (256×256) - Lush green grass
temperate_grass_patchy.png    (256×256) - Patchy/worn grass
temperate_grass_worn.png      (256×256) - Very worn grass
```

**Beach/Sand:**
```
temperate_beach_dry.png       (256×256) - Dry sand
temperate_beach_wet.png       (256×256) - Wet sand
```

**Water:**
```
temperate_water_deep.png      (256×256) - Deep water
temperate_water_shallow.png   (256×256) - Shallow water
```

### Water Shader Textures (optional but recommended)

Place in `godot-client/assets/shaders/temperate/`:

```
water_base_color.png          (256×256) - Base water color
water_normal.png              (256×256) - Normal map for animation
water_edge_combined_mask.png  (256×256) - Shoreline/depth mask
water_foam.png                (256×256) - Foam noise pattern
```

*Note: If these don't exist, the shader will generate procedural fallbacks automatically.*

## Quick Fix

If you don't have textures, the simplest solution is:

1. Create placeholder PNG files using any image editor
2. Make them 256×256 pixels
3. Save with the exact names above in the correct directory

OR

Use solid color images:
- Grass tiles: Green (#669933)
- Sand tiles: Tan (#CCCC99)
- Water tiles: Blue (#334466)
- Water variations: Different blue shades

## Godot Integration

Once textures are in place:

1. **No code changes needed** - the loader handles everything
2. Run the scene in Godot
3. Press R to regenerate with new seed
4. Water should animate and show color gradients
5. Overlays should appear at biome transitions

## Checking What Loaded

The console will show:
```
Creating TileSet...
ERROR: Could not load res://assets/tilesets/temperate/[filename].png
```

This tells you which files are missing.

## Minimum Viable Setup

If you only want to test, create these 3 files:
```
temperate_grass_base.png
temperate_beach_base.png
temperate_water_base.png
```

The game will:
- ✅ Generate the map
- ✅ Show terrain with basic colors
- ⚠️ Won't show detail variations
- ⚠️ Won't show water animation (without normal.png)
- ⚠️ Won't show foam/shoreline effects (without edge_mask.png)

## File Format

- **Format**: PNG (8-bit or 24-bit RGB)
- **Size**: 256×256 pixels (matching `tile_size = 256`)
- **Transparency**: Optional (alpha channel supported)
- **Compression**: PNG compression OK

All textures should be square and the same size for consistency.
