# Tileset Sprite Guide

## Quick Start

Place your 16x16 PNG sprite files in the corresponding folders below. The system will automatically detect and use them. If a sprite is missing, it will use a colored fallback.

## Folder Structure

```
godot-client/assets/tilesets/
├── temperate/
│   ├── water.png
│   ├── plains.png
│   ├── forest.png
│   ├── hills.png
│   └── mountain.png
├── ice/
│   ├── frozen_sea.png
│   ├── ice_plains.png
│   ├── glacier.png
│   └── ice_mountain.png
├── volcanic/
│   ├── lava.png
│   ├── lava_rock.png
│   ├── ash_plains.png
│   └── volcanic_mountain.png
├── barren/
│   ├── sand.png
│   ├── rocky_plains.png
│   ├── crater.png
│   └── rocky_mountain.png
├── oceanic/
│   ├── deep_water.png
│   ├── shallow_water.png
│   ├── beach.png
│   └── coral.png
└── resources/
    ├── iron_ore.png
    ├── copper_ore.png
    ├── rare_minerals.png
    └── organic.png
```

## Sprite Specifications

### Size
- **All sprites must be 256x256 pixels**
- PNG format with transparency support

### Style Recommendations
- Top-down 2D view (bird's eye)
- Tileable edges (optional but recommended for seamless terrain)
- Consistent art style across all biomes
- Clear visual distinction between terrain types
- High detail possible with 256x256 resolution

## Tile Descriptions by Biome

### 🌳 Temperate Biome
Used for Earth-like planets with vegetation and water.

| File | Description | Elevation | Color Fallback |
|------|-------------|-----------|----------------|
| `water.png` | Lakes, rivers, ponds | < -0.3 | Blue |
| `plains.png` | Grassy plains | -0.3 to 0.0 | Light green |
| `forest.png` | Dense forests, trees | 0.0 to 0.3 | Dark green |
| `hills.png` | Rolling hills | 0.3 to 0.6 | Brown-green |
| `mountain.png` | Mountain peaks | > 0.6 | Gray |

### ❄️ Ice Biome
Used for frozen, arctic worlds.

| File | Description | Elevation | Color Fallback |
|------|-------------|-----------|----------------|
| `frozen_sea.png` | Frozen ocean | < -0.3 | Dark blue-gray |
| `ice_plains.png` | Flat ice sheets | -0.3 to 0.1 | White-blue |
| `glacier.png` | Glacial ice | 0.1 to 0.5 | Light blue |
| `ice_mountain.png` | Ice-covered peaks | > 0.5 | Gray-blue |

### 🌋 Volcanic Biome
Used for active volcanic planets.

| File | Description | Elevation | Color Fallback |
|------|-------------|-----------|----------------|
| `lava.png` | Active lava flows | < -0.2 | Bright orange-red |
| `lava_rock.png` | Cooled lava rock | -0.2 to 0.2 | Dark red-brown |
| `ash_plains.png` | Volcanic ash fields | 0.2 to 0.5 | Gray |
| `volcanic_mountain.png` | Volcanic peaks | > 0.5 | Red-brown |

### 🏜️ Barren Biome
Used for desert or Mars-like rocky planets.

| File | Description | Elevation | Color Fallback |
|------|-------------|-----------|----------------|
| `sand.png` | Sand dunes | < -0.2 | Tan |
| `rocky_plains.png` | Flat rocky terrain | -0.2 to 0.2 | Brown |
| `crater.png` | Impact craters | 0.2 to 0.5 | Dark brown |
| `rocky_mountain.png` | Rocky mountains | > 0.5 | Red-brown |

### 🌊 Oceanic Biome
Used for water-world planets.

| File | Description | Elevation | Color Fallback |
|------|-------------|-----------|----------------|
| `deep_water.png` | Deep ocean | < -0.1 | Dark blue |
| `shallow_water.png` | Shallow seas | -0.1 to 0.3 | Blue |
| `beach.png` | Sandy beaches | 0.3 to 0.6 | Sand |
| `coral.png` | Coral reefs | > 0.6 | Teal |

### ⛏️ Resources
Overlay tiles for minable resources.

| File | Description | Used For | Color Fallback |
|------|-------------|----------|----------------|
| `iron_ore.png` | Iron deposits | Iron Ore, Steel | Rusty brown |
| `copper_ore.png` | Copper deposits | Copper Ore | Orange-brown |
| `rare_minerals.png` | Precious materials | Gold, Uranium, REE | Purple |
| `organic.png` | Organic resources | Timber, Food, Water | Green |

## Art Style Examples

### Pixel Art Style
Classic 16x16 retro gaming aesthetic. Sharp pixels, limited color palette.

### Isometric Tiles
Slightly 3D appearance while remaining 2D. Popular for strategy games.

### Top-Down Realistic
Detailed terrain textures viewed from above, like satellite imagery.

### Flat Design
Minimalist, clean shapes with solid colors and simple patterns.

## Recommended Free Resources

### Tile Asset Packs
- **Kenney.nl** - Free game assets including tilesets
- **OpenGameArt.org** - Community-created free assets
- **itch.io** - Many free and paid tileset packs

### Creating Your Own
- **Aseprite** - Pixel art editor ($20, or compile from source for free)
- **Piskel** - Free online pixel art tool
- **GIMP** - Free image editor with pixel art plugins

## Testing Your Sprites

1. Place sprite files in the appropriate folders
2. Open Godot and run `scenes/location_test.tscn`
3. Press 1-9 to test different locations
4. Check the console output - it will print which tiles loaded successfully

Console messages:
- `"Loaded texture: res://assets/tilesets/..."` = Success
- `"Using fallback color for tile ..."` = File missing or not found

## Advanced: Creating Tileable Sprites

For seamless terrain, make edges tileable:

1. Create your 256x256 sprite
2. Ensure top edge matches bottom edge
3. Ensure left edge matches right edge
4. Test by placing 4 copies in a 2x2 grid - seams should be invisible

Tools with tileable texture features:
- Aseprite (Tiled Mode)
- Photoshop (Offset Filter)
- GIMP (Tile filter)
- Substance Designer (ideal for 256x256 tileable textures)

## Multiple Variations (Future Enhancement)

Currently the system uses one sprite per terrain type. In the future, you can add:
- Animated tiles (water ripples, lava bubbling)
- Terrain autotiling (smooth transitions between types)
- Multiple variations (random grass/forest patterns)

## Troubleshooting

### Sprite Not Loading
- Check filename exactly matches (case-sensitive on Linux)
- Verify sprite is exactly 256x256 pixels
- Ensure PNG format
- Check file is in correct folder
- Restart Godot to reimport assets

### Sprite Looks Wrong
- Verify transparency is correct
- Check colors haven't been inverted
- Ensure sprite is oriented correctly (top-down view)
- Try viewing sprite in Godot's FileSystem panel

### Performance Issues
- 256x256 PNG sprites are larger - ensure reasonable compression
- Consider using .webp format for better compression (Godot 4 supports it)
- All sprites should be same resolution (256x256)
- Avoid excessive transparency if not needed

## Next Steps

1. **Add sprites** to folders (start with one biome to test)
2. **Run location_test.tscn** in Godot
3. **Verify loading** in console output
4. **Iterate** until all biomes have sprites
5. **Share** your tileset with the community!
