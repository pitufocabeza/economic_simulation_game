extends Node2D
class_name IsometricLocationGenerator

# API configuration
@export var api_base_url: String = "http://localhost:8000"

# References
@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var camera: Camera2D = $Camera2D
@onready var info_label: Label = $UI/InfoLabel
@onready var minimap_camera: Camera2D = $UI/MinimapPanel/MinimapViewport/SubViewport/MinimapCamera

# Location data
var location_data: Dictionary = {}
var noise: FastNoiseLite
var moisture_noise: FastNoiseLite
var elevation_map: Array = []
var moisture_map: Array = []
var terrain_type_map: Array = []
var grid_width: int = 16
var grid_height: int = 16

# Resource nodes
var resource_nodes: Array = []

# Isometric camera settings
const ISOMETRIC_ANGLE: float = 30.0  # Standard isometric angle
const CAMERA_BASE_ZOOM: Vector2 = Vector2(1.5, 1.5)
const CAMERA_MIN_ZOOM: float = 0.5
const CAMERA_MAX_ZOOM: float = 3.0
const CAMERA_ZOOM_SPEED: float = 0.1
const CAMERA_PAN_SPEED: float = 500.0
var camera_target_position: Vector2 = Vector2.ZERO
var camera_velocity: Vector2 = Vector2.ZERO
const CAMERA_SMOOTHING: float = 0.15  # Lower = smoother

# Terrain generation settings
const TERRAIN_WATER_THRESHOLD: float = 0.3
const TERRAIN_PLAINS_THRESHOLD: float = 0.5
const TERRAIN_HILLS_THRESHOLD: float = 0.7
const TERRAIN_MOUNTAIN_THRESHOLD: float = 0.85

# Moisture thresholds
const MOISTURE_DRY_THRESHOLD: float = 0.35
const MOISTURE_NORMAL_THRESHOLD: float = 0.65

# Wang tile configuration
# Wang tiles use edge colors/patterns to automatically select correct tile variants
# This ensures seamless transitions between terrain types
var wang_tileset_ready: bool = false

func _ready():
	print("IsometricLocationGenerator ready")
	setup_noise_generators()
	setup_isometric_camera()
	
	# For now, use a placeholder grid
	# TODO: Load actual wang tileset when ready
	generate_test_grid()

func setup_noise_generators():
	"""Initialize noise generators for terrain"""
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.05
	nvar center_pos = Vector2(
			grid_width * 32,  # Center on grid
			grid_height * 32
		)
		camera.position = center_pos
		camera_target_position = center_posisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	moisture_noise.frequency = 0.08
	moisture_noise.fractal_octaves = 3
	moisture_noise.seed = 12345  # Different seed for variety

func setup_isometric_camera():
	"""Configure camera for isometric view"""
	if camera:
		camera.zoom = CAMERA_BASE_ZOOM
		# Rotate camera to isometric angle
		camera.rotation_degrees = ISOMETRIC_ANGLE
		camera.position = Vector2(
			grid_width * 32,  # Center on grid
			grid_height * 32
		)
		print("Isometric camera configured: angle=", ISOMETRIC_ANGLE, "°")

func _process(delta: float):
	handle_camera_input(delta)
	update_minimap()
 with smooth easing"""
	if not camera:
		return
	
	# Pan camera
	var move_vector = Vector2.ZERO
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		move_vector.x += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		move_vector.x -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		move_vector.y += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		move_vector.y -= 1
	
	if move_vector.length() > 0:
		# Account for camera rotation in movement
		var rotated_movement = move_vector.rotated(camera.rotation)
		camera_target_position += rotated_movement.normalized() * CAMERA_PAN_SPEED * delta / camera.zoom.x
		
		# Apply camera bounds
		var tile_size = 64  # Adjust based on your tile size
		var map_width = grid_width * tile_size
		var map_height = grid_height * tile_size
		var margin = 200.0  # Extra margin for edge visibility
		
		camera_target_position.x = clamp(camera_target_position.x, -margin, map_width + margin)
		camera_target_position.y = clamp(camera_target_position.y, -margin, map_height + margin)
	
	# Smooth camera movement
	camera.position = camera.position.lerp(camera_target_position, CAMERA_SMOOTHING)
		var rotated_movement = move_vector.rotated(camera.rotation)
		camera.position += rotated_movement.normalized() * CAMERA_PAN_SPEED * delta / camera.zoom.x
	
	# Zoom
	if Input.is_action_just_pressed("ui_page_up") or Input.is_key_pressed(KEY_E):
		var new_zoom = camera.zoom.x + CAMERA_ZOOM_SPEED
		if new_zoom <= CAMERA_MAX_ZOOM:
			camera.zoom = Vector2(new_zoom, new_zoom)
	
	if Input.is_action_just_pressed("ui_page_down") or Input.is_key_pressed(KEY_Q):
		var new_zoom = camera.zoom.x - CAMERA_ZOOM_SPEED
		if new_zoom >= CAMERA_MIN_ZOOM:
			camera.zoom = Vector2(new_zoom, new_zoom)

func load_location(location_id: int):
	"""Load location data from API"""
	print("Loading location ID: ", location_id)
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_location_data_received)
	
	var url = api_base_url + "/tilemap/location/" + str(location_id)
	var error = http_request.request(url)
	
	if error != OK:
		print("Error fetching location data: ", error)

func _on_location_data_received(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	"""Handle location data from API"""
	if response_code != 200:
		print("Failed to fetch location data. Response code: ", response_code)
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		print("Failed to parse JSON response")
		return
	
	location_data = json.data
	print("Received location data: ", location_data)
	
	# Update grid dimensions from API
	grid_width = location_data.get("grid_width", 16)
	grid_height = location_data.get("grid_height", 16)
	
	# Set noise seed from location data
	var seed_value = location_data.get("tilemap_seed", 0)
	noise.seed = seed_value
	moisture_noise.seed = seed_value + 999
	
	update_info_label()
	generate_terrain_maps()
	generate_wang_terrain()
	spawn_resources()

func generate_wang_terrain():
	"""Generate terrain using Wang tiles for seamless transitions"""
	if not terrain_layer:
		print("Error: TerrainLayer not found")
		return
	
	print("Generating Wang tile terrain...")
	
	# TODO: Implement Wang tile algorithm
	# For now, use the terrain type map to place tiles
	generate_terrain_preview()

func generate_terrain_maps():
	"""Generate elevation and moisture maps for terrain generation"""
	elevation_map.clear()
	moisture_map.clear()
	terrain_type_map.clear()
	
	for y in range(grid_height):
		var elevation_row = []
		var moisture_row = []
		var terrain_row = []
		
		for x in range(grid_width):
			# Generate elevation value
			var elev = noise.get_noise_2d(x, y)
			elev = (elev + 1.0) / 2.0  # Normalize to 0-1
			elevation_row.append(elev)
			
			# Generate moisture value
			var moist = moisture_noise.get_noise_2d(x, y)
			moist = (moist + 1.0) / 2.0  # Normalize to 0-1
			moisture_row.append(moist)
			
			# Classify terrain type
			var terrain_type = classify_terrain(elev, moist)
			terrain_row.append(terrain_type)
		
		elevation_map.append(elevation_row)
		moisture_map.append(moisture_row)
		terrain_type_map.append(terrain_row)
	
	print("Terrain maps generated: ", grid_width, "x", grid_height)

func classify_terrain(elevation: float, moisture: float) -> String:
	"""Classify terrain type based on elevation and moisture"""
	var biome = location_data.get("biome", "Temperate")
	
	# Water is universal
	if elevation < TERRAIN_WATER_THRESHOLD:
		return "water"
	
	# Biome-specific terrain
	match biome:
		"Temperate":
			if elevation < TERRAIN_PLAINS_THRESHOLD:
				if moisture > MOISTURE_NORMAL_THRESHOLD:
					return "forest"
				elif moisture < MOISTURE_DRY_THRESHOLD:
					return "plains_dry"
				else:
					return "plains"
			elif elevation < TERRAIN_HILLS_THRESHOLD:
				return "hills"
			elif elevation < TERRAIN_MOUNTAIN_THRESHOLD:
				return "mountain"
			else:
				return "mountain_peak"
		
		"Ice":
			if elevation < TERRAIN_PLAINS_THRESHOLD:
				return "ice_plains"
			elif elevation < TERRAIN_HILLS_THRESHOLD:
				return "glacier"
			else:
				return "ice_mountain"
		
		"Volcanic":
			if elevation < TERRAIN_PLAINS_THRESHOLD:
				return "lava_rock"
			elif elevation < TERRAIN_HILLS_THRESHOLD:
				return "ash_plains"
			else:
				return "volcanic_mountain"
		
		"Barren":
			if elevation < TERRAIN_PLAINS_THRESHOLD:
				if moisture > MOISTURE_NORMAL_THRESHOLD:
					return "rocky_plains"
				else:
					return "sand"
			elif elevation < TERRAIN_HILLS_THRESHOLD:
				return "rocky_hills"
			else:
				return "rocky_mountain"
		
		"Oceanic":
			if elevation < TERRAIN_PLAINS_THRESHOLD + 0.1:
				return "shallow_water"
			elif elevation < TERRAIN_HILLS_THRESHOLD:
				return "beach"
			else:
				return "coral"
	
	return "plains"  # Fallback

func generate_terrain_preview():
	"""Generate a preview using classified terrain (before Wang tiles are ready)"""
	if not terrain_layer:
		return
	
	terrain_layer.clear()
	
	# Color mapping for terrain types (for preview)
	var terrain_colors = {
		"water": Vector2i(0, 0),
		"shallow_water": Vector2i(0, 1),
		"plains": Vector2i(1, 0),
		"plains_dry": Vector2i(1, 1),
		"forest": Vector2i(2, 0),
		"hills": Vector2i(3, 0),
		"mountain": Vector2i(4, 0),
		"mountain_peak": Vector2i(4, 1),
		"ice_plains": Vector2i(1, 2),
		"glacier": Vector2i(2, 2),
		"ice_mountain": Vector2i(3, 2),
		"lava_rock": Vector2i(1, 3),
		"ash_plains": Vector2i(2, 3),
		"volcanic_mountain": Vector2i(3, 3),
		"sand": Vector2i(0, 4),
		"rocky_plains": Vector2i(1, 4),
		"rocky_hills": Vector2i(2, 4),
		"rocky_mountain": Vector2i(3, 4),
		"beach": Vector2i(0, 5),
		"coral": Vector2i(1, 5),
	}
	
	for y in range(grid_height):
		for x in range(grid_width):
			var terrain_type = terrain_type_map[y][x]
			var atlas_coords = terrain_colors.get(terrain_type, Vector2i(1, 0))
			terrain_layer.set_cell(Vector2i(x, y), 0, atlas_coords)
	
	print("Terrain preview generated")

func generate_test_grid():
	"""Generate a simple test grid for development"""
	if not terrain_layer:
		return
	
	terrain_layer.clear()
	
	# Create a checkerboard pattern as placeholder
	for y in range(grid_height):
		for x in range(grid_width):
			# Use alternating pattern
			var atlas_coords = Vector2i((x + y) % 2, 0)
			terrain_layer.set_cell(Vector2i(x, y), 0, atlas_coords)
	
	print("Test grid generated: ", grid_width, "x", grid_height)

func update_info_label():
	"""Update the info label with location data"""
	if not info_label:
		return
	
	var biome = location_data.get("biome", "Unknown")
	var location_id = location_data.get("id", 0)
	var coords = location_data.get("coordinates", [0, 0])
	
	info_label.text = "Isometric Wang Tile Generator\n"
	info_label.text += "Location ID: %d\n" % location_id
	info_label.text += "Biome: %s\n" % biome
	info_label.text += "Coordinates: [%d, %d]\n" % [coords[0], coords[1]]
	info_label.text += "\nWASD - Move | Q/E - Zoom"

# Wang tile helper functions

func get_wang_tile_for_position(x: int, y: int) -> Vector2i:
	"""
	Determine the correct Wang tile based on neighboring terrain types.
	
	Wang tiles use edge patterns to create seamless transitions.
	Each tile edge can match specific terrain types, and the tile
	variant is selected based on which neighbors are present.
	
	Returns: Atlas coordinates for the appropriate Wang tile
	"""
	# TODO: Implement Wang tile selection algorithm
	# This will check the 4 cardinal neighbors (or 8 with corners)
	# and select the tile variant that matches the edge requirements
	
	return Vector2i(0, 0)  # Placeholder

func get_terrain_type_at(x: int, y: int) -> String:
	"""Get the terrain type at a given grid position"""
	if y >= 0 and y < terrain_type_map.size():
		if x >= 0 and x < terrain_type_map[y].size():
			return terrain_type_map[y][x]
	return "plains"

func spawn_resources():
	"""Spawn resource nodes based on location data"""
	var resources = location_data.get("resources", [])
	
	if resources.is_empty():
		print("No resources to spawn")
		return
	
	# Clear existing resource nodes
	for node in resource_nodes:
		if is_instance_valid(node):
			node.queue_free()
	resource_nodes.clear()
	
	print("Spawning ", resources.size(), " resource types")
	
	# Spawn each resource type
	for resource_data in resources:
		var resource_name = resource_data.get("good_name", "unknown")
		var quantity = resource_data.get("quantity", 100)
		var rarity = resource_data.get("rarity", 0.5)
		
		# Number of nodes based on quantity and rarity
		# More quantity = more nodes, higher rarity = fewer but richer nodes
		var node_count = int(quantity / 100.0 * (2.0 - rarity))
		node_count = clamp(node_count, 1, 20)  # Limit nodes per resource
		
		for i in range(node_count):
			spawn_resource_node(resource_name, quantity / node_count, rarity)
	
	print("Resources spawned: ", resource_nodes.size(), " total nodes")

func spawn_resource_node(resource_type: String, amount: float, rarity: float):
	"""Spawn a single resource node at an appropriate location"""
	# Find suitable spawn location based on terrain
	var suitable_terrains = get_suitable_terrains_for_resource(resource_type)
	var max_attempts = 50
	var spawn_pos = Vector2i.ZERO
	var found_spot = false
	
	for attempt in range(max_attempts):
		var test_x = randi() % grid_width
		var test_y = randi() % grid_height
		var terrain_type = get_terrain_type_at(test_x, test_y)
		
		if terrain_type in suitable_terrains:
			spawn_pos = Vector2i(test_x, test_y)
			found_spot = true
			break
	
	if not found_spot:
		# Fallback: spawn anywhere that's not water
		for attempt in range(max_attempts):
			var test_x = randi() % grid_width
			var test_y = randi() % grid_height
			var terrain_type = get_terrain_type_at(test_x, test_y)
			
			if terrain_type != "water" and terrain_type != "shallow_water":
				spawn_pos = Vector2i(test_x, test_y)
				found_spot = true
				break
	
	if not found_spot:
		return  # Give up
	
	# Create resource node sprite
	# TODO: Replace with actual resource tile/sprite
	var resource_node = Sprite2D.new()
	resource_node.name = "Resource_" + resource_type + "_" + str(resource_nodes.size())
	
	# Position in isometric space
	var tile_size = 64  # Adjust based on your tileset
	resource_node.position = Vector2(
		spawn_pos.x * tile_size + tile_size / 2,
		spawn_pos.y * tile_size + tile_size / 2
	)
	
	# Visual representation (placeholder colored square)
	# TODO: Replace with actual resource sprites
	var texture = create_resource_placeholder(resource_type, rarity)
	resource_node.texture = texture
	resource_node.z_index = 10  # Above terrain
	
	# Store metadata
	resource_node.set_meta("resource_type", resource_type)
	resource_node.set_meta("amount", amount)
	resource_node.set_meta("rarity", rarity)
	resource_node.set_meta("grid_position", spawn_pos)
	
	add_child(resource_node)
	resource_nodes.append(resource_node)

func get_suitable_terrains_for_resource(resource_type: String) -> Array:
	"""Get terrain types suitable for spawning this resource"""
	match resource_type.to_lower():
		"iron", "iron_ore":
			return ["hills", "mountain", "rocky_hills", "rocky_mountain"]
		"coal":
			return ["hills", "mountain", "forest"]
		"copper", "copper_ore":
			return ["hills", "rocky_hills", "mountain"]
		"gold":
			return ["mountain", "mountain_peak", "rocky_mountain"]
		"uranium":
			return ["mountain", "volcanic_mountain", "rocky_mountain"]
		"oil", "petroleum":
			return ["plains", "sand", "rocky_plains"]
		"wood", "timber":
			return ["forest"]
		"stone":
			return ["hills", "mountain", "rocky_plains", "rocky_hills"]
		"water":
			return ["water", "shallow_water"]
		"fish":
			return ["water", "shallow_water", "coral"]
		"geothermal":
			return ["volcanic_mountain", "lava_rock"]
		"ice":
			return ["ice_plains", "glacier", "ice_mountain"]
		_:
			return ["plains", "hills"]  # Default for unknown resources

func create_resource_placeholder(resource_type: String, rarity: float) -> ImageTexture:
	"""Create a colored square placeholder for resources"""
	var size = 32 + int(rarity * 16)  # Rarer = larger
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	# Color based on resource type
	var color = Color.WHITE
	match resource_type.to_lower():
		"iron", "iron_ore":
			color = Color(0.7, 0.7, 0.7)  # Gray
		"coal":
			color = Color(0.2, 0.2, 0.2)  # Dark gray
		"copper", "copper_ore":
			color = Color(0.8, 0.5, 0.2)  # Orange-brown
		"gold":
			color = Color(1.0, 0.84, 0.0)  # Gold
		"uranium":
			color = Color(0.0, 1.0, 0.0)  # Green
		"oil", "petroleum":
			color = Color(0.1, 0.1, 0.1)  # Black
		"wood", "timber":
			color = Color(0.4, 0.25, 0.1)  # Brown
		"stone":
			color = Color(0.5, 0.5, 0.5)  # Gray
		"water":
			color = Color(0.0, 0.5, 1.0)  # Blue
		"fish":
			color = Color(0.2, 0.6, 0.8)  # Light blue
		_:
			color = Color(0.8, 0.8, 0.8)  # Default light gray
	
	image.fill(color)
	return ImageTexture.create_from_image(image)

func update_minimap():
	"""Update minimap camera to follow main camera"""
	if minimap_camera and camera:
		minimap_camera.position = camera.position
		# Minimap shows entire map - adjust zoom based on map size
		var tile_size = 64
		var map_width = grid_width * tile_size
		var map_height = grid_height * tile_size
		var zoom_x = 300.0 / map_width  # 300 is minimap width in pixels
		var zoom_y = 220.0 / map_height  # 220 is minimap height
		var zoom_level = min(zoom_x, zoom_y) * 0.9  # 0.9 for some padding
		minimap_camera.zoom = Vector2(zoom_level, zoom_level)
