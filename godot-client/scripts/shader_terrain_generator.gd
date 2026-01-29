extends Node2D
class_name ShaderTerrainGenerator

# API configuration
@export var api_base_url: String = "http://localhost:8000"

# References
@onready var terrain_mesh: MeshInstance2D = $TerrainMesh
@onready var resource_layer: TileMapLayer = $ResourceLayer
@onready var camera: Camera2D = $Camera2D
@onready var info_label: Label = $UI/InfoLabel

# Location data
var location_data: Dictionary = {}
var terrain_material: ShaderMaterial
var noise: FastNoiseLite

func _ready():
	print("ShaderTerrainGenerator ready")
	setup_terrain_material()

func setup_terrain_material():
	# Create shader material
	terrain_material = ShaderMaterial.new()
	var shader = load("res://assets/shaders/terrain_blend.gdshader")
	terrain_material.shader = shader
	
	# Load ice textures (or use placeholders)
	var ice_sea = load_texture_or_placeholder("res://assets/tilesets/ice/ice_sea.png", Color(0.3, 0.4, 0.6))
	var ice_plains = load_texture_or_placeholder("res://assets/tilesets/ice/ice_plains.png", Color(0.8, 0.9, 1.0))
	var glacier = load_texture_or_placeholder("res://assets/tilesets/ice/glacier.png", Color(0.7, 0.8, 0.9))
	var mountain = load_texture_or_placeholder("res://assets/tilesets/ice/ice_mountain.png", Color(0.6, 0.7, 0.8))
	
	# Assign textures to shader
	terrain_material.set_shader_parameter("terrain_1", ice_sea)
	terrain_material.set_shader_parameter("terrain_2", ice_plains)
	terrain_material.set_shader_parameter("terrain_3", glacier)
	terrain_material.set_shader_parameter("terrain_4", mountain)
	terrain_material.set_shader_parameter("blend_sharpness", 2.5)

func load_texture_or_placeholder(path: String, color: Color) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	
	# Create colored placeholder
	var img = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

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
	generate_terrain()

func generate_terrain():
	if location_data.is_empty():
		return
	
	var grid_width = int(location_data.get("grid_width", 16))
	var grid_height = int(location_data.get("grid_height", 16))
	var seed_value = location_data.get("tilemap_seed", 0)
	
	print("Generating shader terrain: ", grid_width, "x", grid_height, " seed: ", seed_value)
	
	# Set shader parameters
	terrain_material.set_shader_parameter("noise_seed", seed_value)
	terrain_material.set_shader_parameter("noise_frequency", 0.08)
	terrain_material.set_shader_parameter("noise_octaves", 4)
	
	# Create mesh quad covering the grid
	var mesh = QuadMesh.new()
	var mesh_width = grid_width * 256.0
	var mesh_height = grid_height * 256.0
	mesh.size = Vector2(mesh_width, mesh_height)
	
	terrain_mesh.mesh = mesh
	terrain_mesh.material = terrain_material
	terrain_mesh.position = Vector2(mesh_width / 2.0, mesh_height / 2.0)
	
	# Setup resource layer
	var ResourceTileset = load("res://scripts/tileset_generator.gd")
	resource_layer.tile_set = ResourceTileset.generate_tileset()
	
	# Initialize noise for resource placement
	noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.08
	noise.fractal_octaves = 4
	
	place_resources()
	
	# Center camera
	camera.position = Vector2(mesh_width / 2.0, mesh_height / 2.0)
	camera.zoom = Vector2(0.15, 0.15)

func place_resources():
	var resources = location_data.get("resources", [])
	print("Placing ", resources.size(), " resource deposits")
	
	if resources.is_empty():
		return
	
	var resource_noise = FastNoiseLite.new()
	resource_noise.seed = location_data.get("tilemap_seed", 0) + 999
	resource_noise.frequency = 0.3
	
	var grid_width = int(location_data.get("grid_width", 16))
	var grid_height = int(location_data.get("grid_height", 16))
	
	# Resource tile source and coordinates
	const TILE_SOURCE_ID = 0
	const TILE_IRON_ORE = Vector2i(0, 5)
	const TILE_COPPER_ORE = Vector2i(1, 5)
	const TILE_RARE_MINERALS = Vector2i(2, 5)
	const TILE_ORGANIC = Vector2i(3, 5)
	
	for resource in resources:
		var resource_type = resource.get("good_name", "Unknown")
		var quantity = resource.get("quantity", 0)
		
		var num_tiles = max(1, int(quantity / 1000.0))
		num_tiles = min(num_tiles, 10)
		
		var placed = 0
		var attempt = 0
		while placed < num_tiles and attempt < 100:
			var seed_offset = attempt * 7.0
			var x = int(abs(resource_noise.get_noise_2d(seed_offset, 0.0)) * float(grid_width)) % grid_width
			var y = int(abs(resource_noise.get_noise_2d(seed_offset, 1.0)) * float(grid_height)) % grid_height
			
			if resource_layer.get_cell_source_id(Vector2i(x, y)) == -1:
				var tile_coord = get_resource_tile(resource_type)
				resource_layer.set_cell(Vector2i(x, y), TILE_SOURCE_ID, tile_coord)
				placed += 1
			
			attempt += 1

func get_resource_tile(good_name: String) -> Vector2i:
	const TILE_IRON_ORE = Vector2i(0, 5)
	const TILE_COPPER_ORE = Vector2i(1, 5)
	const TILE_RARE_MINERALS = Vector2i(2, 5)
	const TILE_ORGANIC = Vector2i(3, 5)
	
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
			return TILE_IRON_ORE

func update_info_label():
	if not info_label or location_data.is_empty():
		return
	
	var location_name = location_data.get("location_name", "Unknown")
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
	
	info_label.text = "Location: %s
Biome: %s | Grid: %s | Seed: %d
Resources:%s

WASD/Arrows - Move | Q/E - Zoom
[Shader-based terrain blending]" % [location_name, biome, grid_size, seed, resource_list]

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
