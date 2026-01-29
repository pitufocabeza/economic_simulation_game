extends Node

# This script generates a TileSet that can use sprite textures or fallback to colored tiles
# Place your 256x256 PNG tiles in the appropriate folders:
# - assets/tilesets/temperate/
# - assets/tilesets/ice/
# - assets/tilesets/volcanic/
# - assets/tilesets/barren/
# - assets/tilesets/oceanic/
# - assets/tilesets/resources/

const TILE_SIZE = 256

# Tile file paths organized by biome
const TILE_PATHS = {
	# Temperate biome (row 0)
	Vector2i(0, 0): "res://assets/tilesets/temperate/water.png",
	Vector2i(1, 0): "res://assets/tilesets/temperate/plains.png",
	Vector2i(2, 0): "res://assets/tilesets/temperate/forest.png",
	Vector2i(3, 0): "res://assets/tilesets/temperate/hills.png",
	Vector2i(4, 0): "res://assets/tilesets/temperate/mountain.png",
	
	# Ice biome (row 1)
	Vector2i(0, 1): "res://assets/tilesets/ice/ice_sea.png",
	Vector2i(1, 1): "res://assets/tilesets/ice/ice_plains.png",
	Vector2i(2, 1): "res://assets/tilesets/ice/glacier.png",
	Vector2i(3, 1): "res://assets/tilesets/ice/ice_mountain.png",
	
	# Volcanic biome (row 2)
	Vector2i(0, 2): "res://assets/tilesets/volcanic/lava.png",
	Vector2i(1, 2): "res://assets/tilesets/volcanic/lava_rock.png",
	Vector2i(2, 2): "res://assets/tilesets/volcanic/ash_plains.png",
	Vector2i(3, 2): "res://assets/tilesets/volcanic/volcanic_mountain.png",
	
	# Barren biome (row 3)
	Vector2i(0, 3): "res://assets/tilesets/barren/sand.png",
	Vector2i(1, 3): "res://assets/tilesets/barren/rocky_plains.png",
	Vector2i(2, 3): "res://assets/tilesets/barren/crater.png",
	Vector2i(3, 3): "res://assets/tilesets/barren/rocky_mountain.png",
	
	# Oceanic biome (row 4)
	Vector2i(0, 4): "res://assets/tilesets/oceanic/deep_water.png",
	Vector2i(1, 4): "res://assets/tilesets/oceanic/shallow_water.png",
	Vector2i(2, 4): "res://assets/tilesets/oceanic/beach.png",
	Vector2i(3, 4): "res://assets/tilesets/oceanic/coral.png",
	
	# Resource tiles (row 5)
	Vector2i(0, 5): "res://assets/tilesets/resources/iron_ore.png",
	Vector2i(1, 5): "res://assets/tilesets/resources/copper_ore.png",
	Vector2i(2, 5): "res://assets/tilesets/resources/rare_minerals.png",
	Vector2i(3, 5): "res://assets/tilesets/resources/organic.png",
}

# Load texture from file or create fallback colored texture
static func load_or_create_texture(tile_coord: Vector2i, fallback_color: Color) -> Texture2D:
	var file_path = TILE_PATHS.get(tile_coord, "")
	
	# Try to load texture from file
	if file_path != "" and FileAccess.file_exists(file_path.replace("res://", "res://")):
		if ResourceLoader.exists(file_path):
			var texture = load(file_path)
			if texture:
				print("✓ Loaded texture: ", file_path)
				return texture
	
	# Fallback to generated colored texture
	print("✗ Using fallback color for tile ", tile_coord, " (expected: ", file_path, ")")
	return create_gradient_texture(fallback_color, 0.15)

# Create a simple colored texture
static func create_colored_texture(color: Color, size: int = TILE_SIZE) -> ImageTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

# Create a gradient texture (for terrain variation)
static func create_gradient_texture(base_color: Color, variation: float = 0.2, size: int = TILE_SIZE) -> ImageTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	var rng = RandomNumberGenerator.new()
	rng.seed = base_color.to_rgba32()
	
	for y in range(size):
		for x in range(size):
			var noise_val = rng.randf_range(-variation, variation)
			var varied_color = Color(
				clamp(base_color.r + noise_val, 0.0, 1.0),
				clamp(base_color.g + noise_val, 0.0, 1.0),
				clamp(base_color.b + noise_val, 0.0, 1.0),
				1.0
			)
			image.set_pixel(x, y, varied_color)
	
	return ImageTexture.create_from_image(image)

# Generate complete tileset
static func generate_tileset() -> TileSet:
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	
	# Create atlas source
	var atlas_source = TileSetAtlasSource.new()
	atlas_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	
	# Define biome colors
	var tile_colors = {
		# Temperate biome (row 0)
		Vector2i(0, 0): Color(0.2, 0.4, 0.8),    # Water - blue
		Vector2i(1, 0): Color(0.5, 0.7, 0.3),    # Plains - green
		Vector2i(2, 0): Color(0.2, 0.5, 0.2),    # Forest - dark green
		Vector2i(3, 0): Color(0.6, 0.5, 0.3),    # Hills - brown-green
		Vector2i(4, 0): Color(0.5, 0.5, 0.5),    # Mountain - gray
		
		# Ice biome (row 1)
		Vector2i(0, 1): Color(0.3, 0.4, 0.6),    # Frozen sea - dark blue-gray
		Vector2i(1, 1): Color(0.8, 0.9, 1.0),    # Ice plains - white-blue
		Vector2i(2, 1): Color(0.7, 0.8, 0.9),    # Glacier - light blue
		Vector2i(3, 1): Color(0.6, 0.7, 0.8),    # Ice mountain - gray-blue
		
		# Volcanic biome (row 2)
		Vector2i(0, 2): Color(1.0, 0.3, 0.0),    # Lava - bright orange-red
		Vector2i(1, 2): Color(0.3, 0.2, 0.2),    # Lava rock - dark red-brown
		Vector2i(2, 2): Color(0.4, 0.4, 0.4),    # Ash plains - gray
		Vector2i(3, 2): Color(0.5, 0.3, 0.2),    # Volcanic mountain - red-brown
		
		# Barren biome (row 3)
		Vector2i(0, 3): Color(0.8, 0.7, 0.5),    # Sand - tan
		Vector2i(1, 3): Color(0.6, 0.5, 0.4),    # Rocky plains - brown
		Vector2i(2, 3): Color(0.5, 0.4, 0.3),    # Crater - dark brown
		Vector2i(3, 3): Color(0.4, 0.3, 0.3),    # Rocky mountain - red-brown
		
		# Oceanic biome (row 4)
		Vector2i(0, 4): Color(0.1, 0.2, 0.5),    # Deep water - dark blue
		Vector2i(1, 4): Color(0.3, 0.5, 0.7),    # Shallow water - blue
		Vector2i(2, 4): Color(0.8, 0.8, 0.6),    # Beach - sand
		Vector2i(3, 4): Color(0.3, 0.6, 0.5),    # Coral - teal
		
		# Resource tiles (row 5)
		Vector2i(0, 5): Color(0.7, 0.5, 0.3),    # Iron ore - rusty brown
		Vector2i(1, 5): Color(0.8, 0.5, 0.2),    # Copper ore - orange-brown
		Vector2i(2, 5): Color(0.6, 0.3, 0.8),    # Rare minerals - purple
		Vector2i(3, 5): Color(0.4, 0.7, 0.3),    # Organic - green
	}
	
	# Create tiles with textures (load from files or use fallback colors)
	for coord in tile_colors.keys():
		var color = tile_colors[coord]
		
		# For the first tile, set the atlas texture
		if coord == Vector2i(0, 0):
			# Create a composite atlas texture with all tiles
			var atlas_width = 5  # 5 columns
			var atlas_height = 6  # 6 rows
			var atlas_image = Image.create(
				atlas_width * TILE_SIZE,
				atlas_height * TILE_SIZE,
				false,
				Image.FORMAT_RGBA8
			)
			
			# Fill the atlas with all tile textures (from files or colored fallbacks)
			for tile_coord in tile_colors.keys():
				var tile_color = tile_colors[tile_coord]
				var tile_tex = load_or_create_texture(tile_coord, tile_color)
				var tile_img = tile_tex.get_image()
				
				# Convert image to RGBA8 format to match atlas format
				if tile_img.get_format() != Image.FORMAT_RGBA8:
					tile_img.convert(Image.FORMAT_RGBA8)
				
				var paste_x = tile_coord.x * TILE_SIZE
				var paste_y = tile_coord.y * TILE_SIZE
				atlas_image.blit_rect(tile_img, Rect2i(0, 0, TILE_SIZE, TILE_SIZE), Vector2i(paste_x, paste_y))
			
			atlas_source.texture = ImageTexture.create_from_image(atlas_image)
		
		# Create tile at this coordinate
		atlas_source.create_tile(coord)
		var tile_data = atlas_source.get_tile_data(coord, 0)
		
		# Optional: Add physics, collision, etc. here if needed
		# tile_data.set_collision_polygons_count(0, 1)
		# ...
	
	# Add the atlas source to the tileset
	tileset.add_source(atlas_source, 0)
	
	return tileset

func _ready():
	print("Tileset generator ready. Call generate_tileset() to create tiles.")
