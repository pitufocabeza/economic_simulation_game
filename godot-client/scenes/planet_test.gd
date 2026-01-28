extends Node3D

@onready var planet_generator = PlanetGenerator.new()
@onready var biome_label = $UI/CurrentBiome
@onready var camera = $Camera3D
var current_planet: MeshInstance3D
var current_biome_index = 0
var current_seed = 12345
var biomes = ["Temperate", "Ice", "Volcanic", "Barren", "Oceanic"]

# Camera control variables
var camera_speed = 2000.0
var camera_rotate_speed = 1.5

func _ready():
	add_child(planet_generator)
	
	# Create the planet (no test sphere needed anymore)
	create_new_planet()
	update_ui()

func create_test_sphere():
	# Create a bright red test sphere
	var test_sphere = SphereMesh.new()
	test_sphere.radius = 500.0
	test_sphere.height = 1000.0
	
	var test_mesh = MeshInstance3D.new()
	test_mesh.mesh = test_sphere
	test_mesh.position = Vector3(0, 0, -2000)  # In front of camera
	
	var test_material = StandardMaterial3D.new()
	test_material.albedo_color = Color(1, 0, 0, 1)  # Bright red
	test_material.emission_enabled = true
	test_material.emission = Color(1, 0, 0, 1)
	test_material.emission_energy_multiplier = 5.0
	test_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # Always visible
	test_mesh.material_override = test_material
	
	add_child(test_mesh)
	print("Test sphere created at: ", test_mesh.global_position)
	print("Camera is at: ", $Camera3D.global_position)
	print("Distance: ", test_mesh.global_position.distance_to($Camera3D.global_position))

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			# Cycle through biomes
			current_biome_index = (current_biome_index + 1) % biomes.size()
			create_new_planet(current_seed)
		elif event.keycode == KEY_R:
			# Random seed
			current_seed = randi()
			create_new_planet(current_seed)

func update_ui():
	if biome_label:
		biome_label.text = "Biome: " + biomes[current_biome_index] + " | Seed: " + str(current_seed)

func create_new_planet(seed_value: int = 12345):
	# Remove old planet if it exists
	if current_planet:
		current_planet.queue_free()
	
	# Store current seed
	current_seed = seed_value
	
	# Create new planet with current biome
	var biome = biomes[current_biome_index]
	print("\n=== Creating Planet ===")
	print("Biome: ", biome, " | Seed: ", seed_value)
	current_planet = planet_generator.create_sample_planet(biome, 10000.0, seed_value)
	
	if current_planet:
		add_child(current_planet)
		print("Planet added to scene tree")
		print("Planet position: ", current_planet.global_position)
		print("Planet visible: ", current_planet.visible)
		print("Planet layers: ", current_planet.layers)
		print("Camera position: ", $Camera3D.global_position)
		
		# Check if mesh exists
		if current_planet.mesh:
			print("Mesh radius: ", current_planet.mesh.radius)
			print("Mesh segments: ", current_planet.mesh.radial_segments)
		
		# Check material
		if current_planet.material_override:
			print("Material type: ", current_planet.material_override.get_class())
			if current_planet.material_override is StandardMaterial3D:
				var mat = current_planet.material_override as StandardMaterial3D
				print("Material color: ", mat.albedo_color)
		
		print("======================\n")
		update_ui()

func _process(delta):
	if current_planet:
		# Auto-rotation - very slow spin
		current_planet.rotate_y(delta * 0.05)
	
	# Freeflight camera controls
	var move_dir = Vector3.ZERO
	
	# WASD for forward/back/strafe
	if Input.is_key_pressed(KEY_W):
		move_dir -= camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		move_dir += camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		move_dir -= camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		move_dir += camera.global_transform.basis.x
	
	# Q/E for up/down
	if Input.is_key_pressed(KEY_Q):
		move_dir.y -= 1.0
	if Input.is_key_pressed(KEY_E):
		move_dir.y += 1.0
	
	# Apply camera movement
	if move_dir != Vector3.ZERO:
		camera.global_position += move_dir.normalized() * camera_speed * delta
	
	# Arrow keys for camera rotation
	if Input.is_key_pressed(KEY_LEFT):
		camera.rotate_y(delta * camera_rotate_speed)
	if Input.is_key_pressed(KEY_RIGHT):
		camera.rotate_y(-delta * camera_rotate_speed)
	if Input.is_key_pressed(KEY_UP):
		camera.rotate_x(delta * camera_rotate_speed)
	if Input.is_key_pressed(KEY_DOWN):
		camera.rotate_x(-delta * camera_rotate_speed)
