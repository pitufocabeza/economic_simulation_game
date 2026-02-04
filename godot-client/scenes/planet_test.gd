extends Node3D

@onready var planet_generator = PlanetGenerator.new()
var current_planet: MeshInstance3D
@export var current_biome_index = 0
@export var current_seed = 12345
@export var radius = 500
# @export var selected_biome: String = "Temperate"
@export var biomes = ["Temperate", "Ice", "Volcanic", "Barren", "Oceanic"]

func _ready():
	add_child(planet_generator)
	
	# Create the planet (no test sphere needed anymore)
	create_new_planet()

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
	test_mesh.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED

	
	add_child(test_mesh)

func create_new_planet(seed_value = current_seed):
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
	
	
func _process(delta):
	if current_planet:
		# Auto-rotation - very slow spin
		current_planet.rotate_y(delta * 0.05)
	
