extends Node2D
class_name MeshTerrainGenerator

# API configuration
@export var api_base_url: String = "http://localhost:8000"

# References
@onready var terrain_container: Node2D = $TerrainContainer
@onready var resource_container: Node2D = $ResourceContainer
@onready var camera: Camera2D = $Camera2D
@onready var info_label: Label = $UI/InfoLabel
@onready var resources_label: Label = $UI/ResourcesLabel

# Additional containers for visual effects
var particles_container: Node2D
var vegetation_container: Node2D
var ambient_container: Node2D
var lighting_modulate: CanvasModulate

# Location data
var location_data: Dictionary = {}
var noise: FastNoiseLite
var moisture_noise: FastNoiseLite  # For biome transitions
var grid_width: int = 16
var grid_height: int = 16

# Day/night cycle
var time_of_day: float = 0.5  # 0.0 = midnight, 0.5 = noon, 1.0 = midnight
var day_night_speed: float = 0.02  # Speed of day/night cycle

# Terrain mesh settings
const TILE_SIZE = 64.0  # Smaller tiles for seamless appearance
const HEIGHT_SCALE = 30.0  # Visual height difference between elevation levels (increased for drama)
const MESH_SUBDIVISIONS = 8  # Smoothness of terrain mesh
const CLIFF_THRESHOLD = 0.35  # Elevation difference for cliff rendering (was 0.3)

func _ready():
	print("MeshTerrainGenerator ready")
	setup_visual_containers()

func setup_visual_containers():
	# Create containers for different visual layers
	particles_container = Node2D.new()
	particles_container.name = "ParticlesContainer"
	particles_container.z_index = 200
	add_child(particles_container)
	
	vegetation_container = Node2D.new()
	vegetation_container.name = "VegetationContainer"
	vegetation_container.z_index = 50
	vegetation_container.y_sort_enabled = true
	add_child(vegetation_container)
	
	ambient_container = Node2D.new()
	ambient_container.name = "AmbientContainer"
	ambient_container.z_index = 150
	add_child(ambient_container)
	
	# Setup lighting modulation for day/night cycle
	lighting_modulate = CanvasModulate.new()
	lighting_modulate.name = "LightingModulate"
	add_child(lighting_modulate)

func load_location(location_id: int):
	print("Loading location ID: ", location_id)
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_location_data_received)
	
	var url = api_base_url + "/tilemap/location/" + str(location_id)
	var error = http_request.request(url)
	
	if error != OK:
		print("Error fetching location data: ", error)

func _on_location_data_received(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
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
	
	update_info_label()
	update_resources_display()
	generate_mesh_terrain()
	
	# Add visual enhancements
	add_biome_particles()
	add_ambient_details()

func generate_mesh_terrain():
	if location_data.is_empty():
		return
	
	# Clear existing terrain and effects
	for child in terrain_container.get_children():
		child.queue_free()
	for child in vegetation_container.get_children():
		child.queue_free()
	for child in ambient_container.get_children():
		child.queue_free()
	for child in particles_container.get_children():
		child.queue_free()
	for child in terrain_container.get_children():
		child.queue_free()
	
	grid_width = int(location_data.get("grid_width", 16))
	grid_height = int(location_data.get("grid_height", 16))
	var seed_value = location_data.get("tilemap_seed", 0)
	var biome = location_data.get("biome", "Ice")
	
	print("Generating mesh terrain: ", grid_width, "x", grid_height, " seed: ", seed_value)
	
	# Initialize noise
	noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.08
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	
	# Initialize moisture noise for biome transitions
	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = seed_value + 1000
	moisture_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	moisture_noise.frequency = 0.05
	
	# Generate terrain tiles with height-based rendering
	for y in range(grid_height):
		for x in range(grid_width):
			generate_terrain_tile(x, y, biome)
	
	# Add rivers and waterfalls
	generate_rivers(biome)
	
	# Place resources using sprites instead of tiles
	place_resources()
	
	# Generate terrain tiles with height-based rendering
	for y in range(grid_height):
		for x in range(grid_width):
			generate_terrain_tile(x, y, biome)
	
	# Place resources using sprites instead of tiles
	place_resources()
	
	# Center camera
	var center_x = grid_width * TILE_SIZE / 2.0
	var center_y = grid_height * TILE_SIZE / 2.0
	camera.position = Vector2(center_x, center_y)
	camera.zoom = Vector2(0.15, 0.15)

func update_resources_display():
	var resources = location_data.get("resources", [])
	if resources.is_empty():
		resources_label.text = "Resources: None"
		return
	
	var text = "Available Resources:\n"
	for resource in resources:
		var resource_type = resource.get("good_name", "Unknown")
		var quantity = resource.get("quantity", 0)
		text += "  • %s: %s units\n" % [resource_type, format_number(quantity)]
	
	resources_label.text = text

func format_number(num: int) -> String:
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	else:
		return str(num)

func generate_terrain_tile(grid_x: int, grid_y: int, biome: String):
	# Sample elevation at tile center
	var elevation = get_smoothed_elevation(grid_x, grid_y)
	
	# Determine terrain type and texture
	var terrain_info = get_terrain_for_elevation(elevation, biome)
	
	# Create sprite for this tile
	var sprite = Sprite2D.new()
	
	# Use animated water shader for water tiles
	if terrain_info.type.contains("sea") or terrain_info.type.contains("water"):
		sprite.texture = create_water_texture(biome)
		# Apply water shader
		var water_shader = load("res://assets/shaders/water.gdshader")
		if water_shader:
			var shader_material = ShaderMaterial.new()
			shader_material.shader = water_shader
			# Set shader parameters based on biome
			if biome == "Ice":
				shader_material.set_shader_parameter("water_color", Color(0.2, 0.3, 0.5, 1.0))
				shader_material.set_shader_parameter("deep_water_color", Color(0.1, 0.2, 0.4, 1.0))
			else:  # Temperate or other
				shader_material.set_shader_parameter("water_color", Color(0.2, 0.4, 0.6, 1.0))
				shader_material.set_shader_parameter("deep_water_color", Color(0.1, 0.25, 0.45, 1.0))
			sprite.material = shader_material
	elif terrain_info.type == "lava":
		# Glowing lava with animated shader
		sprite.texture = create_water_texture(biome)
		var lava_shader = load("res://assets/shaders/water.gdshader")
		if lava_shader:
			var shader_material = ShaderMaterial.new()
			shader_material.shader = lava_shader
			shader_material.set_shader_parameter("water_color", Color(1.0, 0.4, 0.1, 1.0))
			shader_material.set_shader_parameter("deep_water_color", Color(0.8, 0.2, 0.05, 1.0))
			shader_material.set_shader_parameter("wave_speed", 1.5)
			sprite.material = shader_material
		
		# Add light glow effect
		sprite.modulate = Color(1.3, 1.1, 1.0)
		
		# Add point light for nearby illumination
		var light = PointLight2D.new()
		light.enabled = true
		light.energy = 0.8
		light.color = Color(1.0, 0.5, 0.2)
		light.texture_scale = 2.0
		sprite.add_child(light)
	else:
		sprite.texture = load_texture_for_terrain(terrain_info.type, biome)
	
	sprite.position = Vector2(grid_x * TILE_SIZE + TILE_SIZE / 2.0, grid_y * TILE_SIZE + TILE_SIZE / 2.0)
	
	# Apply height offset for 2.5D effect
	var height_offset = terrain_info.height_level * HEIGHT_SCALE
	sprite.position.y -= height_offset
	sprite.z_index = terrain_info.height_level
	
	# Add cliff rendering for dramatic height transitions
	var cliff_data = check_for_cliff(grid_x, grid_y, elevation)
	if cliff_data.has_cliff:
		add_enhanced_cliff(sprite, terrain_info.height_level, cliff_data)
	
	terrain_container.add_child(sprite)

func get_smoothed_elevation(grid_x: int, grid_y: int) -> float:
	var elevation = noise.get_noise_2d(grid_x, grid_y)
	
	# Average with neighbors for smoother result
	var neighbor_avg = (
		noise.get_noise_2d(grid_x + 0.3, grid_y) +
		noise.get_noise_2d(grid_x - 0.3, grid_y) +
		noise.get_noise_2d(grid_x, grid_y + 0.3) +
		noise.get_noise_2d(grid_x, grid_y - 0.3)
	) / 4.0
	
	return elevation * 0.7 + neighbor_avg * 0.3

func get_terrain_for_elevation(elevation: float, biome: String) -> Dictionary:
	# Map elevation to terrain type and height level
	match biome:
		"Ice":
			if elevation < -0.2:
				return {"type": "ice_sea", "height_level": 0}
			elif elevation < 0.15:
				return {"type": "ice_plains", "height_level": 1}
			elif elevation < 0.45:
				return {"type": "glacier", "height_level": 2}
			else:
				return {"type": "ice_mountain", "height_level": 3}
		"Temperate":
			if elevation < -0.15:
				return {"type": "water", "height_level": 0}
			elif elevation < 0.0:
				return {"type": "beach", "height_level": 1}
			elif elevation < 0.3:
				return {"type": "grassland", "height_level": 1}
			elif elevation < 0.5:
				return {"type": "forest", "height_level": 2}
			else:
				return {"type": "mountain", "height_level": 3}
		"Volcanic":
			if elevation < -0.1:
				return {"type": "lava", "height_level": 0}
			elif elevation < 0.2:
				return {"type": "volcanic_rock", "height_level": 1}
			elif elevation < 0.5:
				return {"type": "volcanic_highlands", "height_level": 2}
			else:
				return {"type": "volcanic_peak", "height_level": 3}
		_:
			# Default fallback
			if elevation < -0.2:
				return {"type": "low", "height_level": 0}
			elif elevation < 0.2:
				return {"type": "medium", "height_level": 1}
			else:
				return {"type": "high", "height_level": 2}
	
	return {"type": "default", "height_level": 1}

func load_texture_for_terrain(terrain_type: String, biome: String) -> Texture2D:
	# Enhanced color palette for different terrain types
	var colors = {
		# Ice biome
		"ice_sea": Color(0.15, 0.25, 0.45),
		"ice_plains": Color(0.88, 0.94, 0.98),
		"glacier": Color(0.60, 0.75, 0.88),
		"ice_mountain": Color(0.78, 0.85, 0.92),
		
		# Temperate biome
		"water": Color(0.2, 0.4, 0.65),
		"beach": Color(0.85, 0.80, 0.65),
		"grassland": Color(0.35, 0.65, 0.30),
		"forest": Color(0.20, 0.45, 0.20),
		"mountain": Color(0.55, 0.55, 0.50),
		
		# Volcanic biome
		"lava": Color(0.95, 0.35, 0.15),
		"volcanic_rock": Color(0.25, 0.20, 0.20),
		"volcanic_highlands": Color(0.40, 0.30, 0.25),
		"volcanic_peak": Color(0.50, 0.45, 0.40),
	}
	
	var base_color = colors.get(terrain_type, Color(0.5, 0.5, 0.5))
	
	# Generate procedural texture with more detail
	var size = int(TILE_SIZE)
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(terrain_type + biome)
	
	for y in range(size):
		for x in range(size):
			# Multi-octave noise for more interesting textures
			var noise_val = (
				noise.get_noise_2d(x * 0.2, y * 0.2) * 0.5 +
				noise.get_noise_2d(x * 0.5, y * 0.5) * 0.3 +
				noise.get_noise_2d(x * 1.0, y * 1.0) * 0.2
			)
			
			var variation = noise_val * 0.15
			var color = Color(
				clamp(base_color.r + variation, 0, 1),
				clamp(base_color.g + variation, 0, 1),
				clamp(base_color.b + variation, 0, 1),
				1.0
			)
			img.set_pixel(x, y, color)
	
	return ImageTexture.create_from_image(img)

func create_water_texture(biome: String) -> Texture2D:
	# Create a simple base texture for water (shader will animate it)
	var size = int(TILE_SIZE)
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	var base_color = Color(0.2, 0.4, 0.65) if biome == "Temperate" else Color(0.15, 0.25, 0.45)
	
	for y in range(size):
		for x in range(size):
			img.set_pixel(x, y, base_color)
	
	return ImageTexture.create_from_image(img)

func check_for_cliff(grid_x: int, grid_y: int, elevation: float) -> Dictionary:
	# Check all directions for cliff edges
	var result = {"has_cliff": false, "directions": []}
	
	if grid_y < grid_height - 1:
		var south_elevation = get_smoothed_elevation(grid_x, grid_y + 1)
		if elevation - south_elevation > CLIFF_THRESHOLD:
			result.has_cliff = true
			result.directions.append("south")
	
	if grid_x < grid_width - 1:
		var east_elevation = get_smoothed_elevation(grid_x + 1, grid_y)
		if elevation - east_elevation > CLIFF_THRESHOLD:
			result.has_cliff = true
			result.directions.append("east")
	
	if grid_x > 0:
		var west_elevation = get_smoothed_elevation(grid_x - 1, grid_y)
		if elevation - west_elevation > CLIFF_THRESHOLD:
			result.has_cliff = true
			result.directions.append("west")
	
	return result

func add_enhanced_cliff(sprite: Sprite2D, height_level: int, cliff_data: Dictionary):
	# Add dramatic cliff face rendering
	for direction in cliff_data.directions:
		var cliff_face = ColorRect.new()
		cliff_face.color = Color(0.15, 0.12, 0.10, 0.8)  # Dark brown/black
		
		match direction:
			"south":
				cliff_face.size = Vector2(TILE_SIZE, HEIGHT_SCALE * 1.2)
				cliff_face.position = Vector2(-TILE_SIZE / 2.0, TILE_SIZE / 2.0)
			"east":
				cliff_face.size = Vector2(HEIGHT_SCALE * 0.8, TILE_SIZE)
				cliff_face.position = Vector2(TILE_SIZE / 2.0, -TILE_SIZE / 2.0)
			"west":
				cliff_face.size = Vector2(HEIGHT_SCALE * 0.8, TILE_SIZE)
				cliff_face.position = Vector2(-TILE_SIZE / 2.0 - HEIGHT_SCALE * 0.8, -TILE_SIZE / 2.0)
		
		cliff_face.z_index = height_level - 1
		sprite.add_child(cliff_face)
	
	# Add darker shadow at base
	var shadow = ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.4)
	shadow.size = Vector2(TILE_SIZE * 1.1, 15)
	shadow.position = Vector2(-TILE_SIZE * 0.55, TILE_SIZE / 2.0)
	shadow.z_index = height_level - 1
	sprite.add_child(shadow)

func should_draw_cliff(grid_x: int, grid_y: int, elevation: float) -> bool:
	# Check if there's a significant elevation drop to the south (for cliff rendering)
	if grid_y + 1 >= grid_height:
		return false
	
	var south_elevation = get_smoothed_elevation(grid_x, grid_y + 1)
	return elevation - south_elevation > 0.3  # Cliff threshold

func add_cliff_shadow(sprite: Sprite2D, height_level: int):
	# Add a simple shadow effect below high terrain
	var shadow = ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.3)
	shadow.size = Vector2(TILE_SIZE, 20)
	shadow.position = Vector2(-TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	shadow.z_index = height_level - 1
	sprite.add_child(shadow)

func place_resources():
	var resources = location_data.get("resources", [])
	print("Placing ", resources.size(), " resource deposits")
	
	if resources.is_empty():
		return
	
	# Clear existing resources
	for child in resource_container.get_children():
		child.queue_free()
	
	var placed_positions = []  # Track all occupied positions
	
	# Place individual resource nodes (not patches)
	for i in range(resources.size()):
		var resource = resources[i]
		var resource_type = resource.get("good_name", "Unknown")
		var total_quantity = resource.get("quantity", 0)
		
		# Calculate how many nodes to place
		var num_nodes = 1
		if total_quantity >= 2000:
			num_nodes = max(1, int(total_quantity / 2000.0))
		
		var quantity_per_node = int(total_quantity / float(num_nodes))
		
		print("  ", resource_type, ": ", num_nodes, " nodes x ", quantity_per_node, " units")
		
		# Place each node
		for node_index in range(num_nodes):
			var position = find_resource_position(i, node_index, placed_positions)
			if position != Vector2i(-1, -1):
				create_resource_sprite(position.x, position.y, resource_type, quantity_per_node)
				placed_positions.append(position)

func find_resource_position(resource_index: int, node_index: int, existing_positions: Array) -> Vector2i:
	# Find a suitable position for a single resource node
	var rng = RandomNumberGenerator.new()
	rng.seed = location_data.get("tilemap_seed", 0) + resource_index * 137 + node_index * 73
	
	for attempt in range(100):
		var x = rng.randi_range(1, grid_width - 2)
		var y = rng.randi_range(1, grid_height - 2)
		var pos = Vector2i(x, y)
		
		# Check terrain suitability
		if not is_suitable_for_resources(x, y):
			continue
		
		# Check if position is not occupied
		if existing_positions.has(pos):
			continue
		
		# Check distance from other resources (at least 2 tiles apart)
		var too_close = false
		for existing_pos in existing_positions:
			if pos.distance_to(existing_pos) < 2.0:
				too_close = true
				break
		
		if not too_close:
			return pos
	
	return Vector2i(-1, -1)  # No space found

func is_suitable_for_resources(x: int, y: int) -> bool:
	# Check if this position is flat and not water/cliff
	var elevation = get_smoothed_elevation(x, y)
	
	# Not in water (too low elevation)
	if elevation < -0.1:
		return false
	
	# Not on mountain peaks (too high elevation)
	if elevation > 0.5:
		return false
	
	# Check for cliffs (steep elevation changes with neighbors)
	var max_elevation_diff = 0.0
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
				var neighbor_elevation = get_smoothed_elevation(nx, ny)
				var diff = abs(elevation - neighbor_elevation)
				max_elevation_diff = max(max_elevation_diff, diff)
	
	# Reject if near a cliff (steep elevation change)
	if max_elevation_diff > 0.25:
		return false
	
	return true

func create_resource_sprite(grid_x: int, grid_y: int, resource_type: String, quantity: int):
	# Create a colored sprite for resources with fissure effect
	var sprite = Sprite2D.new()
	sprite.texture = create_resource_texture(resource_type)
	sprite.position = Vector2(grid_x * TILE_SIZE + TILE_SIZE / 2.0, grid_y * TILE_SIZE + TILE_SIZE / 2.0)
	sprite.z_index = 100  # Always on top
	
	# Add a slight glow/outline effect
	sprite.modulate = Color(1.2, 1.2, 1.2)  # Slightly brighter
	
	# Add fissure/crack effect around the resource
	add_resource_fissure(sprite, resource_type)
	
	# Add label showing quantity
	var label = Label.new()
	label.text = str(quantity)
	label.position = Vector2(-15, -30)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	sprite.add_child(label)
	
	resource_container.add_child(sprite)

func add_resource_fissure(sprite: Sprite2D, resource_type: String):
	# Add crack/fissure visual around resource node
	var fissure = Line2D.new()
	fissure.width = 3
	fissure.default_color = Color(0.1, 0.05, 0.0, 0.6)
	
	# Create jagged crack pattern
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(resource_type)
	
	# Multiple crack lines radiating outward
	for crack_index in range(3):
		var angle = (crack_index * TAU / 3.0) + rng.randf() * 0.5
		var length = 25 + rng.randf() * 15
		
		fissure.add_point(Vector2.ZERO)
		var segments = 4
		for i in range(1, segments + 1):
			var t = float(i) / segments
			var dist = length * t
			var offset = Vector2(
				cos(angle) * dist + rng.randf() * 5 - 2.5,
				sin(angle) * dist + rng.randf() * 5 - 2.5
			)
			fissure.add_point(offset)
		
		if crack_index < 2:  # Start new crack line
			fissure.add_point(Vector2.ZERO)
	
	fissure.z_index = 99
	sprite.add_child(fissure)

func create_resource_texture(resource_type: String) -> Texture2D:
	# Resource colors
	var colors = {
		"Iron Ore": Color(0.7, 0.4, 0.2),      # Rusty brown
		"Iron": Color(0.7, 0.4, 0.2),
		"Steel": Color(0.7, 0.4, 0.2),
		"Copper Ore": Color(0.8, 0.5, 0.2),    # Orange-brown
		"Copper": Color(0.8, 0.5, 0.2),
		"Coal": Color(0.2, 0.2, 0.2),          # Dark gray/black
		"Rare Earth Elements": Color(0.6, 0.3, 0.8),  # Purple
		"Uranium": Color(0.6, 0.3, 0.8),
		"Gold": Color(0.6, 0.3, 0.8),
		"Timber": Color(0.3, 0.6, 0.2),        # Green
		"Food": Color(0.3, 0.6, 0.2),
		"Water": Color(0.3, 0.6, 0.2)
	}
	
	var base_color = colors.get(resource_type, Color(0.5, 0.5, 0.5))
	
	# Create smaller resource icon to match tile size
	var size = 48
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(resource_type)
	
	# Create a circle/blob shape for resources
	var center = Vector2(size / 2.0, size / 2.0)
	var radius = size / 2.5
	
	for y in range(size):
		for x in range(size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			
			if dist < radius:
				# Inside resource blob - use color with slight variation
				var edge_factor = 1.0 - (dist / radius) * 0.3  # Brighter in center
				var noise_val = (rng.randf() - 0.5) * 0.15
				var varied_color = Color(
					clamp(base_color.r * edge_factor + noise_val, 0.0, 1.0),
					clamp(base_color.g * edge_factor + noise_val, 0.0, 1.0),
					clamp(base_color.b * edge_factor + noise_val, 0.0, 1.0),
					1.0
				)
				img.set_pixel(x, y, varied_color)
			else:
				# Outside - transparent
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	
	return ImageTexture.create_from_image(img)

func get_resource_tile(good_name: String) -> Vector2i:
	# This function is no longer needed but kept for compatibility
	return Vector2i(0, 0)

func update_info_label():
	if not info_label or location_data.is_empty():
		return
	
	var location_name = location_data.get("location_name", "Unknown Location")
	var planet_name = location_data.get("planet_name", "Unknown Planet")
	var biome = location_data.get("biome", "Unknown")
	var grid_size = "%dx%d" % [location_data.get("grid_width", 0), location_data.get("grid_height", 0)]
	var seed = location_data.get("tilemap_seed", 0)
	var resources = location_data.get("resources", [])
	var resource_list = ""
	
	for i in range(min(3, resources.size())):
		var res = resources[i]
		resource_list += "\n  • %s (%d)" % [res.get("good_name", "?"), res.get("quantity", 0)]
	
	if resources.size() > 3:
		resource_list += "\n  • ... and %d more" % (resources.size() - 3)
	
	info_label.text = "Planet: %s
Location: %s
Biome: %s | Grid: %s | Seed: %d
Resources:%s

WASD - Move | Q/E - Zoom" % [planet_name, location_name, biome, grid_size, seed, resource_list]

func _process(delta):
	if not camera:
		return
	
	var move_speed = 500.0 * delta / camera.zoom.x
	var zoom_speed = 0.5 * delta
	
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		camera.position.y -= move_speed
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		camera.position.y += move_speed
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		camera.position.x -= move_speed
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		camera.position.x += move_speed
	
	if Input.is_key_pressed(KEY_Q):
		camera.zoom -= Vector2.ONE * zoom_speed
		camera.zoom.x = max(0.10, camera.zoom.x)
		camera.zoom.y = max(0.10, camera.zoom.y)
	if Input.is_key_pressed(KEY_E):
		camera.zoom += Vector2.ONE * zoom_speed
		camera.zoom.x = min(1.0, camera.zoom.x)
		camera.zoom.y = min(1.0, camera.zoom.y)
	
	# Update day/night cycle
	update_day_night_cycle(delta)

# ===== VISUAL ENHANCEMENT FUNCTIONS =====

func update_day_night_cycle(delta: float):
	time_of_day += day_night_speed * delta
	if time_of_day > 1.0:
		time_of_day = 0.0
	
	# Calculate lighting based on time
	var light_intensity = abs(sin(time_of_day * PI))  # 0 at midnight, 1 at noon
	var ambient_color = Color(
		0.3 + light_intensity * 0.7,
		0.35 + light_intensity * 0.65,
		0.5 + light_intensity * 0.5
	)
	
	if lighting_modulate:
		lighting_modulate.color = ambient_color

func add_biome_particles():
	var biome = location_data.get("biome", "Ice")
	
	match biome:
		"Ice":
			add_snow_particles()
		"Temperate":
			add_pollen_particles()
		"Volcanic":
			add_steam_vents()
	
	# Add water edge foam/bubbles
	add_water_edge_effects()

func add_snow_particles():
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 100
	particles.lifetime = 8.0
	particles.preprocess = 2.0
	
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(grid_width * TILE_SIZE, 50)
	
	particles.direction = Vector2(0, 1)
	particles.spread = 20.0
	particles.gravity = Vector2(10, 50)
	
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 60.0
	
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.5
	
	particles.color = Color(1, 1, 1, 0.8)
	
	particles.position = Vector2(grid_width * TILE_SIZE / 2.0, -50)
	particles_container.add_child(particles)

func add_pollen_particles():
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 50
	particles.lifetime = 10.0
	
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(grid_width * TILE_SIZE, grid_height * TILE_SIZE)
	
	particles.direction = Vector2(1, 0.2)
	particles.spread = 30.0
	particles.gravity = Vector2(5, 5)
	
	particles.initial_velocity_min = 15.0
	particles.initial_velocity_max = 30.0
	
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.8
	
	particles.color = Color(1.0, 0.95, 0.7, 0.4)
	
	particles.position = Vector2(grid_width * TILE_SIZE / 2.0, grid_height * TILE_SIZE / 2.0)
	particles_container.add_child(particles)

func add_steam_vents():
	# Add steam vents on low-elevation volcanic tiles
	for y in range(grid_height):
		for x in range(grid_width):
			var elevation = get_smoothed_elevation(x, y)
			
			# Add steam vents on volcanic rock areas
			if elevation > -0.1 and elevation < 0.3:
				if randf() < 0.05:  # 5% chance per tile
					var particles = CPUParticles2D.new()
					particles.emitting = true
					particles.amount = 20
					particles.lifetime = 3.0
					
					particles.direction = Vector2(0, -1)
					particles.spread = 15.0
					
					particles.initial_velocity_min = 40.0
					particles.initial_velocity_max = 80.0
					
					particles.scale_amount_min = 1.0
					particles.scale_amount_max = 2.5
					particles.scale_amount_curve = Curve.new()
					
					particles.color = Color(0.9, 0.9, 0.8, 0.6)
					particles.color_ramp = Gradient.new()
					particles.color_ramp.set_color(0, Color(0.9, 0.9, 0.8, 0.6))
					particles.color_ramp.set_color(1, Color(0.9, 0.9, 0.8, 0.0))
					
					particles.position = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE)
					particles_container.add_child(particles)

func add_water_edge_effects():
	# Add foam/bubbles at water edges
	for y in range(grid_height):
		for x in range(grid_width):
			var elevation = get_smoothed_elevation(x, y)
			
			# Check if this is water near land
			if elevation < -0.15:
				var has_land_neighbor = false
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var nx = x + dx
						var ny = y + dy
						if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
							var neighbor_elev = get_smoothed_elevation(nx, ny)
							if neighbor_elev > -0.1:
								has_land_neighbor = true
								break
					if has_land_neighbor:
						break
				
				if has_land_neighbor and randf() < 0.3:
					var particles = CPUParticles2D.new()
					particles.emitting = true
					particles.amount = 8
					particles.lifetime = 2.0
					
					particles.direction = Vector2(0, -1)
					particles.spread = 45.0
					
					particles.initial_velocity_min = 10.0
					particles.initial_velocity_max = 25.0
					
					particles.scale_amount_min = 0.5
					particles.scale_amount_max = 1.2
					
					particles.color = Color(0.9, 0.95, 1.0, 0.5)
					
					particles.position = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
					particles_container.add_child(particles)

func generate_rivers(biome: String):
	# Simple river generation - flows from high to low elevation
	if biome == "Volcanic":
		return  # Skip rivers on volcanic planets
	
	# Find high points (potential river sources)
	for attempt in range(3):  # Try to generate 3 rivers
		var start_x = randi() % grid_width
		var start_y = randi() % grid_height
		var start_elevation = get_smoothed_elevation(start_x, start_y)
		
		if start_elevation > 0.3:  # Start from high elevation
			trace_river(start_x, start_y, biome)

func trace_river(start_x: int, start_y: int, biome: String):
	var current_x = start_x
	var current_y = start_y
	var river_path = []
	var max_length = 30
	
	for i in range(max_length):
		river_path.append(Vector2i(current_x, current_y))
		
		var current_elevation = get_smoothed_elevation(current_x, current_y)
		
		# Find lowest neighbor
		var lowest_elevation = current_elevation
		var next_x = current_x
		var next_y = current_y
		
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var nx = current_x + dx
				var ny = current_y + dy
				if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
					var neighbor_elevation = get_smoothed_elevation(nx, ny)
					if neighbor_elevation < lowest_elevation:
						lowest_elevation = neighbor_elevation
						next_x = nx
						next_y = ny
		
		# Stop if we reached water or can't go lower
		if lowest_elevation >= current_elevation or lowest_elevation < -0.1:
			break
		
		# Check for cliff - create waterfall
		if current_elevation - lowest_elevation > CLIFF_THRESHOLD:
			add_waterfall(current_x, current_y, next_x, next_y)
		
		current_x = next_x
		current_y = next_y
	
	# Draw river
	if river_path.size() > 3:
		draw_river_path(river_path, biome)

func draw_river_path(path: Array, biome: String):
	var line = Line2D.new()
	line.width = 8.0
	line.default_color = Color(0.2, 0.4, 0.7, 0.8) if biome == "Temperate" else Color(0.15, 0.3, 0.6, 0.8)
	line.z_index = 10
	
	for point in path:
		line.add_point(Vector2(point.x * TILE_SIZE + TILE_SIZE / 2.0, point.y * TILE_SIZE + TILE_SIZE / 2.0))
	
	terrain_container.add_child(line)

func add_waterfall(x1: int, y1: int, x2: int, y2: int):
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 30
	particles.lifetime = 1.5
	
	particles.direction = Vector2(0, 1)
	particles.spread = 20.0
	particles.gravity = Vector2(0, 200)
	
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 150.0
	
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	
	particles.color = Color(0.9, 0.95, 1.0, 0.7)
	
	particles.position = Vector2(x1 * TILE_SIZE + TILE_SIZE / 2.0, y1 * TILE_SIZE + TILE_SIZE / 2.0)
	particles_container.add_child(particles)

func add_ambient_details():
	var biome = location_data.get("biome", "Ice")
	
	match biome:
		"Temperate":
			pass # add_birds() and add_vegetation() removed for new approach
		"Ice":
			add_rock_formations()
		"Volcanic":
			add_rock_formations()
			add_craters()
		"Oceanic":
			add_coral_kelp()

func add_rock_formations():
	for y in range(grid_height):
		for x in range(grid_width):
			var elevation = get_smoothed_elevation(x, y)
			
			# Add rocks on mountains
			if elevation > 0.4 and randf() < 0.08:
				var rock = Sprite2D.new()
				
				var size = 16
				var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
				img.fill(Color.TRANSPARENT)
				
				# Simple rock shape
				for ry in range(6, 16):
					for rx in range(4, 12):
						if (rx - 8) * (rx - 8) + (ry - 11) * (ry - 11) < 25:
							img.set_pixel(rx, ry, Color(0.4, 0.4, 0.35))
				
				rock.texture = ImageTexture.create_from_image(img)
				rock.position = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
				rock.z_index = int(elevation * 10) + 40
				
				ambient_container.add_child(rock)

func add_craters():
	for attempt in range(3):
		var x = randi() % grid_width
		var y = randi() % grid_height
		var elevation = get_smoothed_elevation(x, y)
		
		if elevation < 0.3:  # Lower areas
			var crater = Sprite2D.new()
			
			var size = 32
			var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
			img.fill(Color.TRANSPARENT)
			
			# Crater rim
			for cy in range(size):
				for cx in range(size):
					var dist = sqrt(float((cx - 16) * (cx - 16) + (cy - 16) * (cy - 16)))
					if dist > 10 and dist < 14:
						img.set_pixel(cx, cy, Color(0.25, 0.2, 0.18, 0.8))
					elif dist < 10:
						img.set_pixel(cx, cy, Color(0.15, 0.12, 0.10, 0.5))
			
			crater.texture = ImageTexture.create_from_image(img)
			crater.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
			crater.z_index = 5
			
			ambient_container.add_child(crater)

func add_coral_kelp():
	for y in range(grid_height):
		for x in range(grid_width):
			var elevation = get_smoothed_elevation(x, y)
			
			# Shallow water
			if elevation > -0.2 and elevation < -0.05 and randf() < 0.1:
				var kelp = Sprite2D.new()
				
				var size = 12
				var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
				img.fill(Color.TRANSPARENT)
				
				# Kelp strands
				for ky in range(4, 12):
					for kx in range(5, 7):
						img.set_pixel(kx, ky, Color(0.1, 0.4, 0.3, 0.7))
				
				kelp.texture = ImageTexture.create_from_image(img)
				kelp.position = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
				kelp.z_index = 3
				
				ambient_container.add_child(kelp)
