extends Node2D
class_name LocationTilemapGenerator

# API configuration
@export var api_base_url: String = "http://localhost:8000"

# References to TileMapLayer nodes (set in scene)
@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var resource_layer: TileMapLayer = $ResourceLayer
@onready var camera: Camera2D = $Camera2D
@onready var info_label: Label = $UI/InfoLabel

# Location data
var location_data: Dictionary = {}
var noise: FastNoiseLite
var tileset: TileSet

# Tile atlas source IDs and coordinates
const TILE_SOURCE_ID = 0

# Terrain tile coordinates in atlas (y=0 row)
const TILE_WATER = Vector2i(0, 0)
const TILE_PLAINS = Vector2i(1, 0)
const TILE_FOREST = Vector2i(2, 0)
const TILE_HILLS = Vector2i(3, 0)
const TILE_MOUNTAIN = Vector2i(4, 0)

# Ice biome tiles (y=1 row)
const TILE_FROZEN_SEA = Vector2i(0, 1)
const TILE_ICE_PLAINS = Vector2i(1, 1)
const TILE_GLACIER = Vector2i(2, 1)
const TILE_ICE_MOUNTAIN = Vector2i(3, 1)

# Volcanic biome tiles (y=2 row)
const TILE_LAVA = Vector2i(0, 2)
const TILE_LAVA_ROCK = Vector2i(1, 2)
const TILE_ASH_PLAINS = Vector2i(2, 2)
const TILE_VOLCANIC_MOUNTAIN = Vector2i(3, 2)

# Barren biome tiles (y=3 row)
const TILE_SAND = Vector2i(0, 3)
const TILE_ROCKY_PLAINS = Vector2i(1, 3)
const TILE_CRATER = Vector2i(2, 3)
const TILE_ROCKY_MOUNTAIN = Vector2i(3, 3)

# Oceanic biome tiles (y=4 row)
const TILE_DEEP_WATER = Vector2i(0, 4)
const TILE_SHALLOW_WATER = Vector2i(1, 4)
const TILE_BEACH = Vector2i(2, 4)
const TILE_CORAL = Vector2i(3, 4)

# Resource tile coordinates (y=5 row)
const TILE_IRON_ORE = Vector2i(0, 5)
const TILE_COPPER_ORE = Vector2i(1, 5)
const TILE_RARE_MINERALS = Vector2i(2, 5)
const TILE_ORGANIC = Vector2i(3, 5)

func _ready():
	print("LocationTilemapGenerator ready")
	
	# Use terrain-based tileset for smooth transitions
	var TerrainGenerator = load("res://scripts/terrain_tileset_generator.gd")
	tileset = TerrainGenerator.generate_terrain_tileset()
	
	# Assign tileset to layers
	terrain_layer.tile_set = tileset
	terrain_layer.use_kinematic_bodies = false  # For performance
	
	# Resource layer uses simple tiles
	var ResourceTileset = load("res://scripts/tileset_generator.gd")
	resource_layer.tile_set = ResourceTileset.generate_tileset()
	
	print("Terrain tileset generated with autotiling support")

# Main entry point - load location by ID
func load_location(location_id: int):
	print("Loading location ID: ", location_id)
	
	# Fetch location data from API
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_location_data_received)
	
	var url = api_base_url + "/tilemap/location/" + str(location_id)
	var error = http_request.request(url)
	
	if error != OK:
		print("Error fetching location data: ", error)

# Callback when location data is received
func _on_location_data_received(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if response_code != 200:
		print("Failed to fetch location data. Response code: ", response_code)
		return
	
	# Parse JSON response
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		print("Failed to parse JSON response")
		return
	
	location_data = json.data
	print("Received location data: ", location_data)
	
	# Update info label
	update_info_label()
	
	# Generate the tilemap
	generate_tilemap()

# Generate tilemap procedurally based on location data
func generate_tilemap():
	if location_data.is_empty():
		print("No location data to generate from")
		return
	
	print("Generating tilemap for: ", location_data.get("location_name", "Unknown"))
	print("Grid size: ", location_data.get("grid_width", 16), "x", location_data.get("grid_height", 16))
	print("Biome: ", location_data.get("biome", "Unknown"))
	print("Seed: ", location_data.get("tilemap_seed", 0))
	
	# Initialize noise generator with location's unique seed
	noise = FastNoiseLite.new()
	noise.seed = location_data.get("tilemap_seed", 0)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.08  # Lower frequency = larger, smoother terrain features
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	
	var grid_width = location_data.get("grid_width", 16)
	var grid_height = location_data.get("grid_height", 16)
	var biome = location_data.get("biome", "Temperate")
	
	# Clear existing tiles
	terrain_layer.clear()
	resource_layer.clear()
	
	# Generate terrain tiles with smoothing
	for y in range(grid_height):
		for x in range(grid_width):
			# Sample multiple points for smoother transitions
			var elevation = noise.get_noise_2d(x, y)
			
			# Optional: Average with neighbors for smoother result
			var neighbor_avg = (
				noise.get_noise_2d(x + 0.3, y) +
				noise.get_noise_2d(x - 0.3, y) +
				noise.get_noise_2d(x, y + 0.3) +
				noise.get_noise_2d(x, y - 0.3)
			) / 4.0
			elevation = (elevation * 0.7 + neighbor_avg * 0.3)  # Blend 70% original, 30% neighbors
			
			# Use terrain system for auto-transitions
			var terrain_id = get_terrain_for_biome(biome, elevation)
			terrain_layer.set_cell(Vector2i(x, y), 0, Vector2i(terrain_id, 0), 0)
	
	# Place resource nodes
	place_resources()
	
	# Center camera on the tilemap
	var center_x = grid_width * 256.0 / 2.0  # Using 256x256 pixel tiles
	var center_y = grid_height * 256.0 / 2.0
	camera.position = Vector2(center_x, center_y)
	camera.zoom = Vector2(0.15, 0.15)  # Zoom out to see the whole map with larger tiles

# Get terrain ID for biome and elevation (simpler than tile coordinates)
func get_terrain_for_biome(biome: String, elevation: float) -> int:
	match biome:
		"Ice":
			if elevation < -0.2:
				return 0  # Ice Sea
			elif elevation < 0.15:
				return 1  # Ice Plains
			elif elevation < 0.45:
				return 2  # Glacier
			else:
				return 3  # Ice Mountain
		"Temperate":
			if elevation < -0.3:
				return 0  # Water
			elif elevation < 0.0:
				return 1  # Plains
			elif elevation < 0.3:
				return 2  # Forest
			else:
				return 3  # Hills
		_:
			return 1  # Default to middle terrain

# Get the appropriate tile for a biome and elevation value
func get_tile_for_biome(biome: String, elevation: float) -> Vector2i:
	match biome:
		"Temperate":
			if elevation < -0.3:
				return TILE_WATER
			elif elevation < 0.0:
				return TILE_PLAINS
			elif elevation < 0.3:
				return TILE_FOREST
			elif elevation < 0.6:
				return TILE_HILLS
			else:
				return TILE_MOUNTAIN
		
		"Ice":
			if elevation < -0.2:
				return TILE_FROZEN_SEA
			elif elevation < 0.15:
				return TILE_ICE_PLAINS
			elif elevation < 0.45:
				return TILE_GLACIER
			else:
				return TILE_ICE_MOUNTAIN
		
		"Volcanic":
			if elevation < -0.2:
				return TILE_LAVA
			elif elevation < 0.2:
				return TILE_LAVA_ROCK
			elif elevation < 0.5:
				return TILE_ASH_PLAINS
			else:
				return TILE_VOLCANIC_MOUNTAIN
		
		"Barren":
			if elevation < -0.2:
				return TILE_SAND
			elif elevation < 0.2:
				return TILE_ROCKY_PLAINS
			elif elevation < 0.5:
				return TILE_CRATER
			else:
				return TILE_ROCKY_MOUNTAIN
		
		"Oceanic":
			if elevation < -0.1:
				return TILE_DEEP_WATER
			elif elevation < 0.3:
				return TILE_SHALLOW_WATER
			elif elevation < 0.6:
				return TILE_BEACH
			else:
				return TILE_CORAL
	
	# Default fallback
	return TILE_PLAINS

# Place resource nodes on the resource layer
func place_resources():
	var resources = location_data.get("resources", [])
	print("Placing ", resources.size(), " resource deposits")
	
	# Create a separate noise for resource placement
	var resource_noise = FastNoiseLite.new()
	resource_noise.seed = location_data.get("tilemap_seed", 0) + 999  # Offset seed
	resource_noise.frequency = 0.3
	
	var grid_width = int(location_data.get("grid_width", 16))
	var grid_height = int(location_data.get("grid_height", 16))
	
	# For each resource type in the location
	for resource in resources:
		var resource_type = resource.get("good_name", "Unknown")
		var quantity = resource.get("quantity", 0)
		
		# Determine number of resource tiles based on quantity
		var num_tiles = max(1, int(quantity / 1000.0))  # 1 tile per 1000 units
		num_tiles = min(num_tiles, 10)  # Cap at 10 tiles per resource
		
		# Place resource tiles using deterministic noise-based positioning
		var placed = 0
		var attempt = 0
		while placed < num_tiles and attempt < 100:
			# Use noise to pick coordinates
			var seed_offset = attempt * 7.0
			var x = int(abs(resource_noise.get_noise_2d(seed_offset, 0.0)) * grid_width) % grid_width
			var y = int(abs(resource_noise.get_noise_2d(seed_offset, 1.0)) * grid_height) % grid_height
			
			# Check if this cell is already occupied
			if resource_layer.get_cell_source_id(Vector2i(x, y)) == -1:
				var tile_coord = get_resource_tile(resource_type)
				resource_layer.set_cell(Vector2i(x, y), TILE_SOURCE_ID, tile_coord)
				placed += 1
			
			attempt += 1

# Get resource tile based on good name
func get_resource_tile(good_name: String) -> Vector2i:
	match good_name:
		"Iron Ore", "Iron", "Steel":
			return TILE_IRON_ORE
		"Copper Ore", "Copper":
			return TILE_COPPER_ORE
		"Rare Earth Elements", "Uranium", "Gold":
			return TILE_RARE_MINERALS
		"Timber", "Food", "Water":
			return TILE_ORGANIC
		_:
			return TILE_IRON_ORE  # Default

# Camera controls
func _process(delta):
	if not camera:
		return
	
	var move_speed = 500.0 * delta / camera.zoom.x
	var zoom_speed = 0.5 * delta
	
	# WASD movement
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		camera.position.y -= move_speed
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		camera.position.y += move_speed
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		camera.position.x -= move_speed
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		camera.position.x += move_speed
	
	# Q/E zoom
	if Input.is_key_pressed(KEY_Q):
		camera.zoom -= Vector2.ONE * zoom_speed
		camera.zoom.x = max(0.05, camera.zoom.x)
		camera.zoom.y = max(0.05, camera.zoom.y)
	if Input.is_key_pressed(KEY_E):
		camera.zoom += Vector2.ONE * zoom_speed
		camera.zoom.x = min(1.0, camera.zoom.x)
		camera.zoom.y = min(1.0, camera.zoom.y)

# Update the info label with location details
func update_info_label():
	if not info_label or location_data.is_empty():
		return
	
	var location_name = location_data.get("location_name", "Unknown")
	var biome = location_data.get("biome", "Unknown")
	var grid_size = "%dx%d" % [location_data.get("grid_width", 0), location_data.get("grid_height", 0)]
	var seed = location_data.get("tilemap_seed", 0)
	var resources = location_data.get("resources", [])
	var resource_list = ""
	
	for i in range(min(3, resources.size())):  # Show first 3 resources
		var res = resources[i]
		resource_list += "\n  • %s (%d)" % [res.get("good_name", "?"), res.get("quantity", 0)]
	
	if resources.size() > 3:
		resource_list += "\n  • ... and %d more" % (resources.size() - 3)
	
	info_label.text = "Location: %s
Biome: %s | Grid: %s | Seed: %d
Resources:%s

WASD/Arrows - Move | Q/E - Zoom" % [location_name, biome, grid_size, seed, resource_list]
