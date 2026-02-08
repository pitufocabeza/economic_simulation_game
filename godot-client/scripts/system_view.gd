extends Node3D

@onready var camera: Camera3D = $"orbital camera"
@onready var planet_generator := PlanetGenerator.new()
const PlanetMotion := preload("res://scripts/PlanetMotion.gd")
@export var planet_count: int = 0
@export var seed: int = 12345
var generated_root: Node3D
var system_radius: float = 0.0
@export var biomes := ["Temperate", "Ice", "Volcanic", "Barren", "Oceanic"]
var planet_shader = preload("res://shaders/planet_shader.gdshader")

const SYSTEM_EXIT_DISTANCE_FACTOR := 1.15
const AU := 500.0
const ORBIT_CLEARANCE := 500.0
const ORBIT_SPACING_MULTIPLIER := 3.0
const SYSTEM_PAN_PADDING := 1.0

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
var baseline_zoom: float
var exit_zoom: float
var exit_armed := false
var exiting := false
const EXIT_FACTOR := 1.35

var corona: MeshInstance3D
var sun_light: OmniLight3D
var pan_limit_radius: float

var hovered_planet: MeshInstance3D = null
@onready var hover_material: Material = preload("res://assets/materials/planet_hover.tres")

func _ready():
	add_child(planet_generator)
	
	generated_root = Node3D.new()
	generated_root.name = "Generated"
	add_child(generated_root)

func _process(_delta):
	if exiting:
		return
	if ViewTransition.current_view != ViewTransition.ViewMode.SYSTEM:
		return
	if ViewTransition.transitioning:
		return
	if not is_instance_valid(camera):
		return
	
	_update_star_emission()
	# Arm exit only after zooming IN
	if not exit_armed:
		if camera.zoom < baseline_zoom * 0.9:
			exit_armed = true
		return

	# Exit when zoomed out as far as the camera allows
	if camera.zoom >= camera.max_distance:
		exit_armed = false
		ViewTransition.exit_system()

func _update_star_emission():
	if not is_instance_valid(camera) or not is_instance_valid(star):
		return

	var dist_t: float = clamp(
		inverse_lerp(baseline_zoom, camera.max_distance, camera.zoom),
		0.0,
		1.0
	)

	# Angle-based attenuation
	var view_dir: Vector3 = (camera.global_position - star.global_position).normalized()
	var normal_dir: Vector3 = (star.global_position - camera.global_position).normalized()
	var facing: float = abs(view_dir.dot(normal_dir))
	facing = pow(facing, 2.5)

	# Corona glow
	if corona and corona.material_override:
		corona.material_override.emission_energy_multiplier = lerp(
			0.04,
			0.004,
			dist_t
		) * facing

	# Star light
	if sun_light:
		sun_light.light_energy = lerp(3.0, 1.0, dist_t) * facing


# ----------------------------------------------------
# SYSTEM GENERATION
# ----------------------------------------------------
var star_data: StarData

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)

	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_select_planet(event.position)

func _update_hover(mouse_pos: Vector2) -> void:
	var cam: Camera3D = camera
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	var ray_origin: Vector3 = cam.project_ray_origin(mouse_pos)
	var ray_end: Vector3 = ray_origin + cam.project_ray_normal(mouse_pos) * 100000.0

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result := space.intersect_ray(query)

	var new_hover: MeshInstance3D = null

	if not result.is_empty():
		var node: Node = result["collider"]
		while node:
			if node is MeshInstance3D and node.has_meta("planet_data"):
				new_hover = node
				break
			node = node.get_parent()

	_set_hovered_planet(new_hover)
	
func _set_hovered_planet(planet: MeshInstance3D) -> void:
	if hovered_planet == planet:
		return

	# Remove old highlight
	if hovered_planet:
		hovered_planet.material_overlay = null

	hovered_planet = planet

	# Apply new highlight
	if hovered_planet:
		hovered_planet.material_overlay = hover_material



func _on_view_changed(new_view):
	if new_view == ViewTransition.ViewMode.MAP:
		queue_free() # or hide, depending on your setup
		camera.pan_limit_enabled = false

func _try_select_planet(mouse_pos: Vector2) -> void:
	var cam: Camera3D = camera
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	var ray_origin: Vector3 = cam.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = cam.project_ray_normal(mouse_pos)
	var ray_end: Vector3 = ray_origin + ray_dir * 100000.0

	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_end
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		return

	var node: Node = result["collider"]
	while node:
		if node.has_meta("planet_data"):
			var pdata: PlanetData = node.get_meta("planet_data")
			ViewTransition.enter_planet(pdata)
			return
		node = node.get_parent()

func setup_from_star(data: StarData) -> void:
	for c in generated_root.get_children():
		c.queue_free()
	
	star_data = data
	generate_system(data)
	system_radius *= 1.2 # padding
	
	pan_limit_radius = system_radius * SYSTEM_PAN_PADDING
	camera.frame_radius(system_radius)
	camera.pan_limit_enabled = true
	camera.pan_limit_radius = pan_limit_radius
	await get_tree().create_timer(0.95).timeout

	baseline_zoom = camera.zoom
	camera.max_distance = max(camera.max_distance, baseline_zoom * 2.0)
	exit_zoom =  baseline_zoom * SYSTEM_EXIT_DISTANCE_FACTOR
	exit_armed = false

func generate_system(data: StarData) -> void:
	print("Generating system with seed:", data.system_seed)
	star_data = data
	var rng := RandomNumberGenerator.new()
	rng.seed = data.system_seed
	
	planet_count = rng.randi_range(4,7)

	
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

func pick_orbit_au_for_biome(biome: String, rng: RandomNumberGenerator) -> float:
	match biome:
		"Temperate":
			return rng.randf_range(HZ_MIN_AU, HZ_MAX_AU)
		"Volcanic":
			return rng.randf_range(0.3, 0.8)
		"Ice":
			return rng.randf_range(ICE_MIN_AU, ICE_MAX_AU)
		"Oceanic":
			return rng.randf_range(0.8, 2.5)
		"Barren":
			return rng.randf_range(0.4, 3.5)
		_:
			return rng.randf_range(1.0, 3.0)

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
	var planet_index := 0
	
	for p in planets:
		# Orbit pivot
		var orbit_node := Node3D.new()
		orbit_node.name = "Orbit_%s" % p["biome"]
		add_child(orbit_node)

		var biome_id: int = planet_generator.get_biome_id(p["biome"])
		# Create planet body
		var planet := planet_generator.create_sample_planet(
			biome_id,
			p["radius"] * 2.0, # diameter if generator expects it
			p["seed"]
		)
		if planet == null:
			continue
			
		var planet_data := PlanetData.new()
		planet_data.planet_id = planet_index   # or i
		planet_data.system_id = star_data.system_id
		planet_data.seed = p["seed"]
		planet_data.biome = biome_id
		planet_data.radius = p["radius"]
		planet_data.plot_count = rng.randi_range(2, 10)

		planet.set_meta("planet_data", planet_data)
		print("Planet created with data:", planet.get_meta("planet_data"))
		planet_index += 1
		
		var desired_au := pick_orbit_au_for_biome(p["biome"], rng)
		var orbit := compute_safe_orbit(desired_au, p["radius"])

		# biome minimum AU (keeps ice worlds away from the star)
		if biome_id == 1:
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
		orbit_line.name = "OrbitLine_%s" % biome_id
		star.add_child(orbit_line)
		
		system_radius = max(system_radius, orbit_radius, p["radius"])

# ----------------------------------------------------
# STAR CREATION
# ----------------------------------------------------

func create_star():
	star = Node3D.new()
	star.name = "Sol"
	generated_root.add_child(star)
	
	var photosphere := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = star_radius
	mesh.height = star_radius * 2.0
	mesh.radial_segments = 64  # Lower = better perf/distance
	mesh.rings = 32
	photosphere.mesh = mesh
	
	var star_shader := load("res://assets/shaders/star.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = star_shader
	mat.set_shader_parameter("sun_texture", preload("res://assets/textures/8k_sun.jpg"))
	mat.set_shader_parameter("emission_strength", 0.15)
	mat.set_shader_parameter("speed", 0.02)
	mat.set_shader_parameter("distortion", 0.03)
	
	photosphere.material_override = mat  # Override, not surface
	photosphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	# KEY FIXES - REAL 3D SPHERE
	photosphere.lod_bias = 0.5  # Medium bias - keeps detail without perf hit
	star.add_child(photosphere)
	
	# Light
	sun_light = OmniLight3D.new()
	sun_light.light_energy = 24.0
	sun_light.omni_range = current_orbit + 5000000
	star.add_child(sun_light)

	print("STAR children:", star.get_child_count(), "Generated children:", generated_root.get_child_count())
