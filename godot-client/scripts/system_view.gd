extends Node3D

@onready var camera := $"orbital camera"
@onready var planet_generator := PlanetGenerator.new()
const PlanetMotion := preload("res://scripts/PlanetMotion.gd")
@export var planet_count: int = 0
@export var seed: int = 12345
var system_radius: float = 0.0
@export var biomes := ["Temperate", "Ice", "Volcanic", "Barren", "Oceanic"]
var planet_shader = preload("res://shaders/planet_shader.gdshader")

const AU := 500.0
const ORBIT_CLEARANCE := 500.0
const ORBIT_SPACING_MULTIPLIER := 3.0

const PLANET_RADIUS_MIN := 300.0
const PLANET_RADIUS_MAX := 700.0

const MIN_ORBIT_AU := 10.0
const HZ_MIN_AU := 0.95
const HZ_MAX_AU := 1.4
const ICE_MIN_AU := HZ_MAX_AU + 0.6
const ICE_MAX_AU := 6.0

var star_radius: float
var current_orbit: float = 0.0
var largest_planet_radius: float = 0.0
var star: Node3D

func _ready():
	randomize()
	add_child(planet_generator)

# ----------------------------------------------------
# SYSTEM GENERATION
# ----------------------------------------------------
var star_data: StarData

func setup_from_star(data: StarData) -> void:
	star_data = data
	seed = data.system_seed
	generate_system(data)
	system_radius *= 1.2 # padding
	
	camera.frame_radius(system_radius)

func generate_system(data: StarData) -> void:
	print("Generating system with seed:", data.system_seed)
	star_data = data
	var rng := RandomNumberGenerator.new()
	planet_count = rng.randi_range(4,7)
	rng.seed = data.system_seed
	
	# --- Pre-roll planet sizes to determine star radius
	var planet_defs := []
	for i in planet_count:
		var radius = rng.randf_range(PLANET_RADIUS_MIN, PLANET_RADIUS_MAX)
		largest_planet_radius = max(largest_planet_radius, radius)

		var biome = biomes[rng.randi_range(0, biomes.size() - 1)]
		planet_defs.append({
			"radius": radius,
			"biome": biome,
			"seed": rng.randi()
		})

	# --- Compute star radius
	star_radius = clamp(largest_planet_radius * 12.0, 800.0, 2000.0)

	create_star()
	create_planets(planet_defs, rng)

# ----------------------------------------------------
# ORBIT LOGIC
# ----------------------------------------------------

func pick_orbit_au_for_biome(biome: String) -> float:
	match biome:
		"Temperate":
			return randf_range(HZ_MIN_AU, HZ_MAX_AU)
		"Volcanic":
			return randf_range(0.3, 0.8)
		"Ice":
			return randf_range(ICE_MIN_AU, ICE_MAX_AU)
		"Oceanic":
			return randf_range(0.8, 2.5)
		"Barren":
			return randf_range(0.4, 3.5)
		_:
			return randf_range(1.0, 3.0)

func compute_safe_orbit(desired_au: float, planet_radius: float) -> float:
	var desired_units = desired_au * AU
	# Minimum distance from the star's surface
	var min_orbit_units = star_radius + (MIN_ORBIT_AU * AU)
	var min_safe = star_radius + planet_radius + ORBIT_CLEARANCE
	return max(desired_units, min_safe, min_orbit_units)

# ----------------------------------------------------
# PLANET CREATION
# ----------------------------------------------------

func create_planets(planets: Array, rng):
	for p in planets:
		# Orbit pivot
		var orbit_node := Node3D.new()
		orbit_node.name = "Orbit_%s" % p["biome"]
		add_child(orbit_node)

		# Create planet body
		var planet := planet_generator.create_sample_planet(
			p["biome"],
			p["radius"] * 2.0, # diameter if generator expects it
			p["seed"]
		)
		if planet == null:
			continue
		
		var desired_au := pick_orbit_au_for_biome(p["biome"])
		var orbit := compute_safe_orbit(desired_au, p["radius"])

		# biome minimum AU (keeps ice worlds away from the star)
		if p["biome"] == "Ice":
			orbit = max(orbit, ICE_MIN_AU * AU)

		# enforce spacing
		orbit = max(orbit, current_orbit + (p["radius"] + ORBIT_CLEARANCE) * ORBIT_SPACING_MULTIPLIER)

		p["orbit_units"] = orbit
		current_orbit = orbit
		
		orbit_node.add_child(planet)

		# Place planet at orbit distance
		var orbit_radius: float = p["orbit_units"]
		var angle: float = rng.randf_range(0.0, TAU)

		var x: float = cos(angle) * orbit_radius
		var z: float = sin(angle) * orbit_radius
		var y: float = rng.randf_range(-50.0, 50.0) # tiny inclination

		planet.position = Vector3(x, y, z)

		# Add motion controller
		var motion: Node3D = PlanetMotion.new()
		motion.orbit_speed = rng.randf_range(0.02, 0.15)
		motion.spin_speed  = rng.randf_range(0.2, 1.2)
		
		motion.setup(orbit_node, planet)
		
		orbit_node.add_child(motion)
		
		var orbit_line := preload("res://scripts/orbit_line.gd").new()
		orbit_line.radius = p["orbit_units"]
		orbit_line.name = "OrbitLine_%s" % p["biome"]
		star.add_child(orbit_line)
		
		system_radius = max(system_radius, orbit_radius, p["radius"])


# ----------------------------------------------------
# STAR CREATION
# ----------------------------------------------------

func create_star():
	star = Node3D.new()
	star.name = "Sol"
	add_child(star)
	
	var photosphere := MeshInstance3D.new()

	var mesh := SphereMesh.new()
	mesh.radius = star_radius
	mesh.height = star_radius * 2.0
	mesh.radial_segments = 256
	mesh.rings = 128
	photosphere.mesh = mesh

	var star_shader := load("res://assets/shaders/star.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = star_shader
	mat.set_shader_parameter("sun_texture", preload("res://assets/textures/8k_sun.jpg"))
	mat.set_shader_parameter("emission_strength", 1.2)
	mat.set_shader_parameter("speed", 0.02)
	mat.set_shader_parameter("distortion", 0.03)

	photosphere.set_surface_override_material(0, mat)
	photosphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(photosphere)

	# Chromosphere
	var chromo := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = star_radius * 1.01
	cm.height = star_radius * 2.02
	chromo.mesh = cm

	var chromo_mat := StandardMaterial3D.new()
	chromo_mat.emission_enabled = true
	chromo_mat.emission = Color(1.0, 0.3, 0.15)
	chromo_mat.emission_energy_multiplier = 2.0
	chromo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	chromo_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	chromo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	chromo.material_override = chromo_mat
	star.add_child(chromo)

	# Corona
	var corona := MeshInstance3D.new()
	var com := SphereMesh.new()
	com.radius = star_radius * 1.5
	com.height = star_radius * 2.6
	corona.mesh = com

	var corona_mat := StandardMaterial3D.new()
	corona_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	corona_mat.emission_enabled = true
	corona_mat.emission = Color(1,1,1)
	corona_mat.emission_energy_multiplier = 0.03
	corona_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	corona_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	corona_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	corona_mat.albedo_color = Color(0, 0, 0, 0)

	corona.material_override = corona_mat
	star.add_child(corona)

	# Light
	var sun_light := OmniLight3D.new()
	sun_light.light_energy = 8.0
	sun_light.omni_range = current_orbit + 5000000
	sun_light.shadow_enabled = true
	sun_light.position = Vector3(0, 0, 0)
	sun_light.omni_attenuation = 0.2
	star.add_child(sun_light)
