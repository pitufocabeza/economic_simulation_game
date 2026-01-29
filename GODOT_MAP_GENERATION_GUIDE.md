# Godot Tilemap Generation System

## Overview

This system generates procedural 2D tilemaps for locations in your economic simulation game. Each location on a planet has a unique tilemap generated from a seed, ensuring consistent terrain every time a location is viewed.

## Files Created

### GDScript Files
- **scripts/location_tilemap_generator.gd**: Main generator that fetches location data from API and creates procedural tilemaps
- **scripts/tileset_generator.gd**: Generates tileset with colored tiles for different biomes
- **scripts/location_test.gd**: Test scene controller for trying different locations

### Scene Files
- **scenes/location.tscn**: Main location scene with TileMapLayers and camera
- **scenes/location_test.tscn**: Test scene for quickly loading different locations

## How It Works

### 1. Data Flow

```
Godot Scene → API Request → Backend Database → JSON Response → Tilemap Generation
```

1. Player opens a location (clicks location ID)
2. Godot calls `/tilemap/location/{id}` API endpoint
3. Backend returns location data:
   - `grid_width`, `grid_height` (16x16 or 32x32)
   - `tilemap_seed` (unique deterministic seed)
   - `biome` (Temperate, Ice, Volcanic, Barren, Oceanic)
   - `resources` (array of resource deposits)
4. Godot generates terrain using `FastNoiseLite` with the seed
5. Resources are placed deterministically based on seed + offset

### 2. Procedural Generation

The system uses `FastNoiseLite` with these parameters:
- **Seed**: Location's `tilemap_seed` from database
- **Noise Type**: Simplex
- **Frequency**: 0.15 (controls terrain feature size)
- **Octaves**: 3 (detail layers)

Each tile's elevation is calculated:
```gdscript
var elevation = noise.get_noise_2d(x, y)  # Returns -1.0 to 1.0
```

Then mapped to terrain types based on biome and elevation thresholds.

### 3. Biome Terrain Mapping

#### Temperate
- elevation < -0.3: **Water** (blue)
- -0.3 to 0.0: **Plains** (green)
- 0.0 to 0.3: **Forest** (dark green)
- 0.3 to 0.6: **Hills** (brown-green)
- elevation > 0.6: **Mountain** (gray)

#### Ice
- elevation < -0.3: **Frozen Sea** (dark blue-gray)
- -0.3 to 0.1: **Ice Plains** (white-blue)
- 0.1 to 0.5: **Glacier** (light blue)
- elevation > 0.5: **Ice Mountain** (gray-blue)

#### Volcanic
- elevation < -0.2: **Lava** (bright orange-red)
- -0.2 to 0.2: **Lava Rock** (dark red-brown)
- 0.2 to 0.5: **Ash Plains** (gray)
- elevation > 0.5: **Volcanic Mountain** (red-brown)

#### Barren
- elevation < -0.2: **Sand** (tan)
- -0.2 to 0.2: **Rocky Plains** (brown)
- 0.2 to 0.5: **Crater** (dark brown)
- elevation > 0.5: **Rocky Mountain** (red-brown)

#### Oceanic
- elevation < -0.1: **Deep Water** (dark blue)
- -0.1 to 0.3: **Shallow Water** (blue)
- 0.3 to 0.6: **Beach** (sand)
- elevation > 0.6: **Coral** (teal)

### 4. Resource Placement

Resources are placed on the resource layer using a separate noise seed:
```gdscript
resource_noise.seed = tilemap_seed + 999
```

Number of resource tiles = `quantity / 1000` (capped at 10 tiles per resource type)

Resource tiles:
- **Iron/Steel**: Rusty brown
- **Copper**: Orange-brown
- **Rare Minerals** (Gold, Uranium, REE): Purple
- **Organic** (Timber, Food, Water): Green

## Usage

### Running the Test Scene

1. **Start the backend server**:
   ```powershell
   cd backend
   docker-compose up
   ```

2. **Open Godot** and load `scenes/location_test.tscn`

3. **Run the scene** (F5)

4. **Test different locations**:
   - Press **1-9** to load location IDs 1-9
   - Each location will have a unique tilemap based on its seed

### Controls

- **WASD** or **Arrow Keys**: Pan camera
- **Q**: Zoom out
- **E**: Zoom in
- **1-9**: Load location ID 1-9 (in test scene)

### Integrating Into Your Game

To use this in your main game:

```gdscript
# In your planet/location selection code
var location_scene = preload("res://scenes/location.tscn")
var location_instance = location_scene.instantiate()
add_child(location_instance)

# Load the specific location
location_instance.load_location(location_id)
```

## Customization

### Adjusting Terrain Generation

Edit `location_tilemap_generator.gd`:

```gdscript
# Line ~118-122: Noise parameters
noise.frequency = 0.15  # Lower = larger terrain features
noise.fractal_octaves = 3  # Higher = more detail
```

### Changing Biome Thresholds

Edit `get_tile_for_biome()` function (lines ~149-195):

```gdscript
"Temperate":
    if elevation < -0.3:  # Adjust water level
        return TILE_WATER
    # ... etc
```

### Adding New Tile Types

1. **Edit tileset_generator.gd**: Add new color to `tile_colors` dictionary
2. **Edit location_tilemap_generator.gd**: Add new constant and use in biome mapping
3. Update row/column coordinates accordingly

### Using Custom Textures

To replace colored tiles with actual textures:

1. Place texture files in `assets/tilesets/`
2. Modify `tileset_generator.gd` to load textures instead of generating colors:
   ```gdscript
   var texture = load("res://assets/tilesets/grass.png")
   ```

## Database Structure

### Location Table Fields
- `id`: Unique location ID
- `name`: Location name
- `planet_id`: Parent planet
- `biome`: Temperate/Ice/Volcanic/Barren/Oceanic
- `grid_width`, `grid_height`: Tilemap dimensions (usually 16x16 or 32x32)
- `tilemap_seed`: Integer seed for procedural generation
- `x, y, z`: 3D coordinates on planet surface

### Resource Deposit Table
- `location_id`: Foreign key to location
- `resource_type`: Name of resource (e.g., "Iron Ore")
- `quantity`: Available units
- `rarity`: "common", "rare", "legendary"

## API Endpoints

### GET /tilemap/location/{location_id}

Returns location data for tilemap generation:

```json
{
  "location_id": 1,
  "location_name": "Sirius Major I Plot 5",
  "planet_id": 567,
  "biome": "Temperate",
  "grid_width": 16,
  "grid_height": 16,
  "tilemap_seed": 1829471829,
  "elevation": 125.4,
  "position": { "x": 1234.5, "y": 6789.2, "z": 125.4 },
  "resources": [
    {
      "good_name": "Iron Ore",
      "quantity": 5000,
      "rarity": "common"
    }
  ],
  "claimed": false,
  "claimed_by": null
}
```

## Performance Notes

- **Procedural generation is fast**: 16x16 grid generates in <1ms
- **No texture loading**: Uses programmatically generated colored tiles
- **Deterministic**: Same seed always produces same map
- **Scalable**: Can handle 150k-250k unique locations
- **Client-side**: No server load for terrain generation

## Future Enhancements

1. **Texture Atlas**: Replace colored tiles with actual terrain textures
2. **Tile Autotiling**: Use Godot's terrain system for smooth transitions
3. **Building Layer**: Add third TileMapLayer for player structures
4. **Terrain Modification**: Store player changes as delta from procedural base
5. **Minimap**: Add minimap widget showing full location
6. **Grid Overlay**: Optional grid for building placement
7. **Resource Animations**: Animate resource tiles (sparkles, etc.)
8. **Biome Blending**: Smooth transitions between adjacent biomes

## Troubleshooting

### "Location not found" Error
- Ensure backend is running and accessible at `http://localhost:8000`
- Check that location IDs exist in database
- Verify `api_base_url` in `location_tilemap_generator.gd`

### Blank/White Screen
- Check console for errors (View → Output)
- Verify TileMapLayer nodes exist in scene
- Ensure tileset is generated successfully

### All Tiles Same Color
- Check noise frequency isn't too high or too low
- Verify elevation thresholds in `get_tile_for_biome()`
- Inspect `tilemap_seed` value (shouldn't be 0)

### Resources Not Appearing
- Check that location has resource deposits in database
- Verify resource layer is visible and above terrain layer
- Increase quantity threshold in `place_resources()` function

## Development Tips

1. **Test with various seeds**: Try locations with different `tilemap_seed` values
2. **Adjust camera zoom**: Default is 2.0x, change in `generate_tilemap()`
3. **Debug with print statements**: All tile placements are logged to console
4. **Use Godot debugger**: Set breakpoints in `generate_tilemap()` to inspect values
5. **Visualize noise**: Comment out biome logic and just return elevation as grayscale

## Next Steps

1. ✅ Basic tilemap generation working
2. ✅ Procedural terrain with 5 biomes
3. ✅ Resource placement
4. ⏳ **Add custom textures** (replace colored tiles)
5. ⏳ **Implement building placement**
6. ⏳ **Add collision layers for pathfinding**
7. ⏳ **Create location selection UI** (connect to planet view)
8. ⏳ **Add player interaction** (mine resources, place buildings)
