class_name PlanetGenerator
extends Node3D

# Preload the planet shader
var planet_shader = preload("res://shaders/planet_shader.gdshader")

# API client reference
var api_client: Node

# Create a 1x1 ImageTexture of a solid color (fallback for missing tiles)
func create_color_tex(c: Color) -> Texture:
	var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)

func _ready():
	# Get reference to API client if it exists
	if has_node("/root/APIClient"):
		api_client = get_node("/root/APIClient")
	# Otherwise we'll use it only when needed

# Create a planet from data dictionary
func create_planet(planet_data: Dictionary) -> MeshInstance3D:
	print("Creating planet with data: ", planet_data)
	
	# Create sphere mesh
	var sphere = SphereMesh.new()
	var radius = planet_data.get("diameter", 10000.0) / 2.0
	sphere.radius = radius
	sphere.height = planet_data.get("diameter", 10000.0)
	sphere.radial_segments = get_lod_segments(planet_data.get("diameter", 10000.0))
	sphere.rings = get_lod_rings(planet_data.get("diameter", 10000.0))
	
	print("Sphere created - radius: ", radius, " segments: ", sphere.radial_segments)
	
	# Create mesh instance
	var planet_mesh = MeshInstance3D.new()
	planet_mesh.mesh = sphere
	planet_mesh.name = planet_data.get("name", "Planet")
	
	# --- Physics collider (required for raycasting) ---
	var body := StaticBody3D.new()
	body.name = "PlanetBody"

	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius

	shape.shape = sphere_shape

	body.add_child(shape)
	planet_mesh.add_child(body)
	
	# Apply procedural material
	var material = create_planet_material(planet_data)
	planet_mesh.material_override = material
	
	print("Material applied, type: ", material.get_class())
	
	# Optional: Add atmosphere
	if planet_data.has("atmosphere") and planet_data["atmosphere"] != "None":
		add_atmosphere(planet_mesh, planet_data)
	
	return planet_mesh

# Create shader material for the planet
func create_planet_material(planet_data: Dictionary):
	# Try shader first, but use fallback if it fails
	var use_shader = true  # Set to false to use simple material for testing
	
	if use_shader:
		var material = ShaderMaterial.new()
		material.shader = planet_shader
		
		if material.shader == null:
			push_error("Failed to load planet shader!")
			use_shader = false
		else:
			# Pass planet properties to shader
			var seed_val = planet_data.get("seed", 12345)
			var biome_id = get_biome_id(planet_data.get("biome", "Temperate"))
			
			print("Setting shader parameters - seed: ", seed_val, " biome: ", biome_id)
			material.set_shader_parameter("planet_seed", seed_val)
			material.set_shader_parameter("biome_type", biome_id)
			material.set_shader_parameter("noise_scale", 5.0)

			# Attempt to load tileset textures and bind to shader; create 1x1 fallbacks when missing
			var plains_path = "res://assets/tilesets/temperate/plains.png"
			var water_path = "res://assets/tilesets/temperate/water.png"
			var shallow_path = "res://assets/tilesets/oceanic/shallow_water.png"
			var deep_path = "res://assets/tilesets/oceanic/deep_water.png"
			var barren_path = "res://assets/tilesets/barren/rocky_plains.png"

			# (Using top-level create_color_tex fallback helper)

			# Plains texture or fallback green
			var plains_tex: Texture = null
			if ResourceLoader.exists(plains_path):
				plains_tex = load(plains_path)
			else:
				plains_tex = create_color_tex(Color(0.25, 0.38, 0.18))
			material.set_shader_parameter("tex_plains", plains_tex)

			# Temperate water or fallback blue
			var water_tex: Texture = null
			if ResourceLoader.exists(water_path):
				water_tex = load(water_path)
			else:
				water_tex = create_color_tex(Color(0.04, 0.10, 0.18))
			material.set_shader_parameter("tex_water", water_tex)

			# Shallow ocean or fallback turquoise
			var shallow_tex: Texture = null
			if ResourceLoader.exists(shallow_path):
				shallow_tex = load(shallow_path)
			else:
				shallow_tex = create_color_tex(Color(0.12, 0.46, 0.60))
			material.set_shader_parameter("tex_shallow_water", shallow_tex)

			# Deep ocean or fallback dark blue
			var deep_tex: Texture = null
			if ResourceLoader.exists(deep_path):
				deep_tex = load(deep_path)
			else:
				deep_tex = create_color_tex(Color(0.01, 0.04, 0.10))
			material.set_shader_parameter("tex_deep_water", deep_tex)

			# Barren plains texture or fallback sandy-brown
			var barren_tex: Texture = null
			if ResourceLoader.exists(barren_path):
				barren_tex = load(barren_path)
			else:
				barren_tex = create_color_tex(Color(0.60, 0.44, 0.28))
			material.set_shader_parameter("tex_barren_plains", barren_tex)

			return material
	
	# Fallback to standard material with biome colors
	print("Using fallback StandardMaterial3D")
	var fallback = StandardMaterial3D.new()
	fallback.albedo_color = get_fallback_biome_color(planet_data.get("biome", "Temperate"))
	fallback.metallic = 0.0
	fallback.roughness = 0.8
	return fallback

func get_fallback_biome_color(biome: String) -> Color:
	match biome:
		"Temperate":
			return Color(0.3, 0.6, 0.3)  # Green
		"Ice":
			return Color(0.8, 0.9, 1.0)  # Light blue
		"Volcanic":
			return Color(0.6, 0.2, 0.1)  # Dark red
		"Barren":
			return Color(0.6, 0.5, 0.4)  # Brown
		"Oceanic":
			return Color(0.2, 0.4, 0.8)  # Blue
		_:
			return Color(0.5, 0.5, 0.5)  # Gray

# Convert biome name to ID
func get_biome_id(biome_name: String) -> int:
	match biome_name:
		"Temperate":
			return 0
		"Ice":
			return 1
		"Volcanic":
			return 2
		"Barren":
			return 3
		"Oceanic":
			return 4
		_:
			return 0

func biome_id_to_name(biome_id: int) -> String:
	match biome_id:
		0: return "Temperate"
		1: return "Ice"
		2: return "Volcanic"
		3: return "Barren"
		4: return "Oceanic"
		_: return "Temperate"

# Get LOD segments based on planet size
func get_lod_segments(diameter: float) -> int:
	if diameter > 20000:
		return 1024  # Extreme detail - over 1 million triangles
	elif diameter > 10000:
		return 1024  # Extreme detail
	else:
		return 512   # Maximum detail

# Get LOD rings based on planet size
func get_lod_rings(diameter: float) -> int:
	return get_lod_segments(diameter) / 2

# Add atmospheric layer
func add_atmosphere(planet_mesh: MeshInstance3D, planet_data: Dictionary):
	# Create slightly larger transparent sphere
	var atmo_sphere = SphereMesh.new()
	var base_radius = planet_data.get("diameter", 10000.0) / 2.0
	atmo_sphere.radius = base_radius * 1.05
	atmo_sphere.height = planet_data.get("diameter", 10000.0) * 1.05
	atmo_sphere.radial_segments = 32
	atmo_sphere.rings = 16
	
	var atmo_mesh = MeshInstance3D.new()
	atmo_mesh.mesh = atmo_sphere
	atmo_mesh.name = "Atmosphere"
	
	# Transparent atmospheric material
	var atmo_material = StandardMaterial3D.new()
	atmo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	atmo_material.albedo_color = get_atmosphere_color(planet_data.get("atmosphere", "None"))
	atmo_material.cull_mode = BaseMaterial3D.CULL_FRONT  # Render from inside
	atmo_mesh.material_override = atmo_material
	
	planet_mesh.add_child(atmo_mesh)

# Get atmosphere color based on type
func get_atmosphere_color(atmosphere_type: String) -> Color:
	match atmosphere_type:
		"Breathable":
			return Color(0.5, 0.7, 1.0, 0.3)
		"Toxic":
			return Color(0.8, 1.0, 0.3, 0.4)
		"Thin":
			return Color(0.9, 0.9, 1.0, 0.1)
		_:
			return Color(1.0, 1.0, 1.0, 0.0)

# Load planet from API by ID
func load_planet(planet_id: int) -> MeshInstance3D:
	print("Loading planet with ID: ", planet_id)
	var planet_data = await get_planet_data(planet_id)
	
	if planet_data:
		return create_planet(planet_data)
	else:
		push_error("Failed to load planet data for ID: ", planet_id)
		return null

# Fetch planet data from API
func get_planet_data(planet_id: int) -> Dictionary:
	if not api_client:
		push_error("API client not initialized")
		return {}
	
	var url = api_client.BASE_URL + "/planets/" + str(planet_id)
	print("Requesting planet data from: ", url)
	
	var http = HTTPRequest.new()
	add_child(http)
	
	var error = http.request(url)
	if error != OK:
		push_error("HTTP Request failed with error: ", error)
		http.queue_free()
		return {}
	
	var result = await http.request_completed
	var response_code = result[1]
	var body = result[3]
	
	http.queue_free()
	
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		print("Planet data received: ", json)
		return json
	else:
		push_error("API returned status code: ", response_code)
		return {}

# Create a sample planet with test data (no API required)
func create_sample_planet(
	biome_id: int, 
	diameter: float, 
	seed_value: int,
	) -> MeshInstance3D:
	var biome_name: String = biome_id_to_name(biome_id)
	
	var test_data = {
		"name": "Sample Planet",
		"seed": seed_value,
		"biome": biome_name,
		"diameter": diameter,
		"atmosphere": "Breathable",
		"gravity": 1.0
	}
	
	print("Creating sample planet with data: ", test_data)
	var planet = create_planet(test_data)
	
	# Make it unshaded so it's always visible for testing
	
	return planet
