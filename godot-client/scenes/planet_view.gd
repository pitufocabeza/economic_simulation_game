extends Node3D

@onready var planet_root := $PlanetRoot
@onready var planet_mesh := $PlanetRoot/PlanetMesh
@onready var camera := $CameraRig/PlanetCamera
@onready var key_light: DirectionalLight3D = $KeyLight
@onready var rim_light: DirectionalLight3D = $RimLight
@onready var planet_generator := PlanetGenerator.new()

var planet_data: PlanetData
var plot_infos: Array[PlotInfo] = []

# UI overlays (instantiated in _ready)
var tooltip: PanelContainer = null
var detail_panel: PanelContainer = null
var hovered_plot: int = -1

# zoom state
var zoom_distance: float = 0.0
var zoom_min: float = 0.0
var zoom_max: float = 0.0
const ZOOM_STEP: float = 20.0
const ZOOM_MARGIN: float = 100.0
const PLOT_SURFACE_OFFSET_FACTOR: float = 0.005
const PLOT_HEX_SCALE_FACTOR: float = 0.05

var selected_plot: int = -1
var rotating: bool = false
var last_mouse: Vector2 = Vector2.ZERO
var drag_started: bool = false
const DRAG_THRESHOLD: float = 4.0

func _ready() -> void:
	camera.current = true
	set_process_unhandled_input(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_create_ui()


func setup(pdata: PlanetData) -> void:
	planet_data = pdata
	_generate_dummy_plot_infos()
	_build_planet()
	_position_camera()
	_tune_lights()
	_tune_planet_material()
	_spawn_plots()
	_sync_zoom_limits()
	_apply_zoom()

func _tune_lights() -> void:
	# Lower specular contribution so you don't get a huge hot spot.
	if key_light != null:
		key_light.light_energy = 1.0
		key_light.light_specular = 0.0
		key_light.light_indirect_energy = 0.0

	if rim_light != null:
		rim_light.light_energy = 0.25
		rim_light.light_specular = 0.0
		rim_light.light_indirect_energy = 0.0

func _tune_planet_material() -> void:
	if planet_mesh == null:
		return
	if planet_mesh.mesh == null:
		return

	var surface_count: int = planet_mesh.mesh.get_surface_count()
	for i: int in range(surface_count):
		var mat: Material = planet_mesh.get_active_material(i)
		if mat == null:
			continue

		# Duplicate so we don't edit a shared resource
		var mat_copy: Material = mat.duplicate(true) as Material
		planet_mesh.set_surface_override_material(i, mat_copy)

		if mat_copy is StandardMaterial3D:
			var smat: StandardMaterial3D = mat_copy as StandardMaterial3D
			smat.metallic = 0.0
			smat.roughness = 0.9
			smat.specular = 0.1
			smat.clearcoat = 0.0
			smat.clearcoat_roughness = 1.0
		elif mat_copy is ShaderMaterial:
			var shmat: ShaderMaterial = mat_copy as ShaderMaterial
			# Only sets parameters if the uniform exists in the shader.
			# Rename these to match the uniforms in your planet shader.
			_set_shader_param_if_present(shmat, &"specular_strength", 0.1)
			_set_shader_param_if_present(shmat, &"roughness", 0.9)
			_set_shader_param_if_present(shmat, &"metallic", 0.0)
			_set_shader_param_if_present(shmat, &"gloss", 0.0)

func _set_shader_param_if_present(mat: ShaderMaterial, uniform_name: StringName, value: Variant) -> void:
	if mat == null or mat.shader == null:
		return
	if _shader_has_uniform(mat.shader, uniform_name):
		mat.set_shader_parameter(uniform_name, value)

func _shader_has_uniform(shader: Shader, uniform_name: StringName) -> bool:
	var target: String = String(uniform_name)
	for u: Dictionary in shader.get_shader_uniform_list():
		if u.has("name") and String(u["name"]) == target:
			return true
	return false

func _sync_zoom_limits() -> void:
	var collider_radius: float = _get_planet_collider_radius()
	zoom_min = collider_radius + ZOOM_MARGIN
	zoom_max = maxf(zoom_min + 0.01, collider_radius * 6.0)
	zoom_distance = clampf(zoom_distance, zoom_min, zoom_max)

func _build_planet() -> void:
	var planet: MeshInstance3D = planet_generator.create_sample_planet(
		planet_data.biome,
		planet_data.radius * 2.0,
		planet_data.seed
	)

	planet.name = "Planet"
	planet_root.add_child(planet)
	planet_mesh = planet


func _spawn_plots() -> void:
	# Clear previous plots
	for c: Node in planet_root.get_children():
		if c.name.begins_with("Plot_"):
			c.queue_free()

	if planet_data == null:
		return

	var count: int = planet_data.plot_count
	if count <= 0:
		return

	var planet_radius: float = _get_visual_planet_radius()
	var surface_offset: float = planet_radius * PLOT_SURFACE_OFFSET_FACTOR
	var r: float = planet_radius + surface_offset
	var hex_size: float = planet_radius * PLOT_HEX_SCALE_FACTOR

	# Deterministic RNG from planet seed so layout is always the same
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = planet_data.seed + 999

	var plot_scene: PackedScene = preload("res://scenes/plot_node.tscn")

	for i: int in range(count):
		var dir: Vector3 = _random_sphere_point(rng)
		var is_claimed: bool = planet_data.claimed_plots.has(i)

		var plot: Node3D = plot_scene.instantiate()
		plot.name = "Plot_%d" % i
		plot.plot_id = i
		plot.hex_radius = hex_size
		plot.hex_thickness = hex_size * 0.12
		plot.set_state(is_claimed, i == selected_plot)
		plot.clicked.connect(_on_plot_clicked)

		# Position and orient as a single transform
		var up: Vector3 = dir.normalized()
		var arbitrary: Vector3 = Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.99 else Vector3.FORWARD
		var right_v: Vector3 = up.cross(arbitrary).normalized()
		var forward_v: Vector3 = right_v.cross(up).normalized()
		plot.transform = Transform3D(Basis(right_v, up, forward_v), dir * r)

		planet_root.add_child(plot)

func _random_sphere_point(rng: RandomNumberGenerator) -> Vector3:
	# Uniform distribution on a sphere
	var theta: float = rng.randf() * TAU
	var phi: float = acos(2.0 * rng.randf() - 1.0)
	return Vector3(
		sin(phi) * cos(theta),
		cos(phi),
		sin(phi) * sin(theta)
	).normalized()

func _get_visual_planet_radius() -> float:
	# Fallback if mesh isn't ready
	if planet_mesh == null:
		return max(planet_data.radius, 0.01)

	# Ensure we’re calling get_aabb() on a MeshInstance3D
	var mi: MeshInstance3D = planet_mesh as MeshInstance3D
	var aabb: AABB = mi.get_aabb()
	var s: Vector3 = aabb.size
	var r: float = 0.5 * max(s.x, max(s.y, s.z))
	return max(r, 0.01)

func _get_planet_collider_radius() -> float:
	var body: StaticBody3D = planet_root.get_node_or_null("PlanetCollider") as StaticBody3D
	if body != null:
		var cs: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if cs != null and cs.shape is SphereShape3D:
			var sphere: SphereShape3D = cs.shape as SphereShape3D
			return sphere.radius
	return _get_visual_planet_radius()
	
func _apply_zoom() -> void:
	if camera == null:
		return
	# keep camera on +Z axis looking at origin (matches your _position_camera)
	camera.global_position = Vector3(0, 0, zoom_distance)
	camera.look_at(Vector3.ZERO, Vector3.UP)

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		ViewTransition.exit_planet()
		return

	# Mouse wheel zoom
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_distance = max(zoom_min, zoom_distance - ZOOM_STEP)
			_apply_zoom()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_distance = min(zoom_max, zoom_distance + ZOOM_STEP)
			_apply_zoom()
			return

		# Left click: track for drag vs click
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				rotating = false
				drag_started = true
				last_mouse = mb.position
			else:
				if drag_started and not rotating:
					# It was a click, not a drag — try to pick a plot
					_try_pick_plot(mb.position)
				drag_started = false
				rotating = false
			return

	# Drag rotates planet (only after movement exceeds threshold)
	if event is InputEventMouseMotion and drag_started:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if not rotating:
			var dist: float = mm.position.distance_to(last_mouse)
			if dist > DRAG_THRESHOLD:
				rotating = true
		if rotating:
			var d: Vector2 = mm.relative
			planet_root.rotate_y(-d.x * 0.005)
			var new_x: float = planet_root.rotation.x - d.y * 0.005
			planet_root.rotation.x = clamp(new_x, -PI * 0.45, PI * 0.45)

func _try_pick_plot(screen_pos: Vector2) -> void:
	if camera == null:
		return

	# Cast a ray from the camera through the click position
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var ray_length: float = zoom_max * 3.0

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * ray_length)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		return

	var collider: Object = result.get("collider")
	if collider == null:
		return

	# The collider is the Area3D inside the plot node
	var plot_node: Node = (collider as Node).get_parent()
	if plot_node != null and plot_node.has_method("emit_signal"):
		var plot_name: String = plot_node.name
		if plot_name.begins_with("Plot_"):
			var id: int = plot_name.substr(5).to_int()
			_on_plot_clicked(id)

func _on_plot_clicked(id: int) -> void:
	var prev: int = selected_plot
	selected_plot = id
	print("Plot clicked: %d (claimed: %s)" % [id, planet_data.claimed_plots.has(id)])

	# Update visuals for old and new selection
	_update_plot_visual(prev)
	_update_plot_visual(id)

	# Show detail panel
	if id >= 0 and id < plot_infos.size() and detail_panel != null:
		detail_panel.show_for_plot(plot_infos[id])

func _update_plot_visual(id: int) -> void:
	if id < 0:
		return
	var node: Node = planet_root.get_node_or_null("Plot_%d" % id)
	if node == null:
		return
	var claimed: bool = planet_data.claimed_plots.has(id)
	node.set_state(claimed, id == selected_plot)

func _position_camera() -> void:
	if camera == null:
		push_error("PlanetView: Camera is null")
		return

	var radius: float = planet_data.radius
	var distance: float = radius * 2.5

	camera.global_position = Vector3(0, 0, distance)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	
	zoom_distance = distance

# ── UI creation ──────────────────────────────────────────────────────

func _create_ui() -> void:
	var hud: Control = get_node_or_null("UI/PlanetHUD")
	if hud == null:
		push_error("PlanetView: UI/PlanetHUD not found")
		return

	# Tooltip
	var tooltip_scene: PackedScene = preload("res://scenes/plot_tooltip.tscn")
	tooltip = tooltip_scene.instantiate() as PanelContainer
	hud.add_child(tooltip)

	# Detail panel — center-top of screen
	var panel_scene: PackedScene = preload("res://scenes/plot_detail_panel.tscn")
	detail_panel = panel_scene.instantiate() as PanelContainer
	detail_panel.anchors_preset = Control.PRESET_CENTER_TOP
	detail_panel.position = Vector2(0.0, 40.0)
	hud.add_child(detail_panel)

	detail_panel.claim_requested.connect(_on_claim_requested)
	detail_panel.enter_requested.connect(_on_enter_requested)
	detail_panel.closed.connect(_on_detail_closed)

# ── Dummy data generation ────────────────────────────────────────────

const ARCHETYPES: Array[String] = [
	"Flat Plains",
	"Coastal Shelf",
	"Gentle Hills",
	"River Basin",
	"Forest Edge",
	"Agricultural Plateau",
]

const RESOURCE_TYPES: Array[String] = [
	"Iron Ore",
	"Copper Ore",
	"Coal",
	"Quartz",
	"Biomass",
	"Wood",
	"Gold",
	"Uranium",
]

const PLOT_SIZES: Array[int] = [16, 18, 20]

func _generate_dummy_plot_infos() -> void:
	plot_infos.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = planet_data.seed + 7777

	for i: int in range(planet_data.plot_count):
		var info: PlotInfo = PlotInfo.new()
		info.plot_id = i
		info.archetype = ARCHETYPES[rng.randi() % ARCHETYPES.size()]
		info.plot_size = PLOT_SIZES[rng.randi() % PLOT_SIZES.size()]
		info.claimed = planet_data.claimed_plots.has(i)

		# Generate 2-4 random resource deposits
		var num_resources: int = rng.randi_range(2, 4)
		var used: Dictionary = {}
		for _j: int in range(num_resources):
			var res_name: String = RESOURCE_TYPES[rng.randi() % RESOURCE_TYPES.size()]
			if not used.has(res_name):
				used[res_name] = true
				info.resources[res_name] = rng.randi_range(200, 5000)

		plot_infos.append(info)

# ── Hover detection (runs every frame) ───────────────────────────────

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_hover()

func _update_hover() -> void:
	if camera == null or tooltip == null:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	# Don't hover while dragging
	if rotating:
		_clear_hover()
		return

	# Don't hover if detail panel is visible (blocks interaction)
	if detail_panel != null and detail_panel.visible:
		_clear_hover()
		return

	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var dir: Vector3 = camera.project_ray_normal(mouse_pos)
	var ray_length: float = zoom_max * 3.0

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * ray_length)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		_clear_hover()
		return

	var collider: Object = result.get("collider")
	if collider == null:
		_clear_hover()
		return

	var plot_node: Node = (collider as Node).get_parent()
	if plot_node == null:
		_clear_hover()
		return

	var plot_name: String = plot_node.name
	if not plot_name.begins_with("Plot_"):
		_clear_hover()
		return

	var id: int = plot_name.substr(5).to_int()
	if id < 0 or id >= plot_infos.size():
		_clear_hover()
		return

	# Show / update tooltip
	if hovered_plot != id:
		hovered_plot = id
		tooltip.show_for_plot(plot_infos[id])
	tooltip.follow_mouse(mouse_pos)

func _clear_hover() -> void:
	if hovered_plot >= 0:
		hovered_plot = -1
		if tooltip != null:
			tooltip.hide_tooltip()

# ── Claim handling ───────────────────────────────────────────────────

func _on_claim_requested(plot_id: int) -> void:
	print("Claiming plot %d — transitioning to plot view" % plot_id)

	# Locally mark as claimed (dummy)
	if not planet_data.claimed_plots.has(plot_id):
		planet_data.claimed_plots.append(plot_id)

	if plot_id >= 0 and plot_id < plot_infos.size():
		plot_infos[plot_id].claimed = true
		plot_infos[plot_id].claimed_by = GameState.current_company_id

	_update_plot_visual(plot_id)
	_enter_plot(plot_id)

func _on_enter_requested(plot_id: int) -> void:
	print("Entering owned plot %d" % plot_id)
	_enter_plot(plot_id)

func _enter_plot(plot_id: int) -> void:
	# Hide detail panel and transition to plot view
	if detail_panel != null:
		detail_panel.visible = false

	if plot_id >= 0 and plot_id < plot_infos.size():
		ViewTransition.enter_plot(plot_infos[plot_id])

func _on_detail_closed() -> void:
	var prev: int = selected_plot
	selected_plot = -1
	_update_plot_visual(prev)
