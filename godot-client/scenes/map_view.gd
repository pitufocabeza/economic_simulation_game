extends Node3D

## 3-D galaxy map with angled camera, hyperlanes, territory borders,
## and clickable star systems — styled after Stellaris.

var entering_system := false

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/MapCamera
@onready var system_layer: Node3D = $SystemLayer
@onready var lane_layer: Node3D = $LaneLayer
@onready var territory_layer: Node3D = $TerritoryLayer

# ── Camera ────────────────────────────────────────────────────────────

const CAM_PITCH_DEG: float = -55.0
const CAM_PAN_SPEED: float = 1.5
const CAM_ZOOM_STEP: float = 30.0
const CAM_ZOOM_MIN: float = 80.0
const CAM_ZOOM_MAX: float = 900.0

var cam_zoom: float = 400.0
var panning: bool = false
var last_pan_pos: Vector2 = Vector2.ZERO

# ── Selection state ──────────────────────────────────────────────────

var selected_star: StarData = null
var systems: Dictionary = {}           # id (String) → star_map_node (Node3D)
var lane_pulse_time: float = 0.0

# ── Region colours ───────────────────────────────────────────────────

const REGION_COLORS: Dictionary = {
	"Core Worlds": Color(0.25, 0.65, 1.0),
	"Outer Rim": Color(0.9, 0.35, 0.2),
	"Fringe Sector": Color(0.6, 0.2, 0.85),
	"Neutral": Color(0.45, 0.45, 0.45),
}

# ── Dummy galaxy data ───────────────────────────────────────────────

const DUMMY_GALAXY: Dictionary = {
	"regions": [
		{ "name": "Core Worlds",    "owner": "Terran Federation", "center": Vector2(0.0, 0.0) },
		{ "name": "Outer Rim",      "owner": "",                  "center": Vector2(500.0, 180.0) },
		{ "name": "Fringe Sector",  "owner": "",                  "center": Vector2(-420.0, -280.0) },
	],
	"systems": [
		# ── Core Worlds (6) ──
		{ "id": "core-1", "name": "Aurelion",        "pos": Vector2(0, 0),        "region": "Core Worlds" },
		{ "id": "core-2", "name": "Sol Prime",       "pos": Vector2(-120, 80),    "region": "Core Worlds" },
		{ "id": "core-3", "name": "Nova Helios",     "pos": Vector2(100, -70),    "region": "Core Worlds" },
		{ "id": "core-4", "name": "Cygnus Gate",     "pos": Vector2(-60, -130),   "region": "Core Worlds" },
		{ "id": "core-5", "name": "Arcturus Hub",    "pos": Vector2(150, 100),    "region": "Core Worlds" },
		{ "id": "core-6", "name": "Lyra Station",    "pos": Vector2(-160, -40),   "region": "Core Worlds" },
		# ── Outer Rim (5) ──
		{ "id": "rim-1",  "name": "Rift-9",          "pos": Vector2(420, 120),    "region": "Outer Rim" },
		{ "id": "rim-2",  "name": "Kharos",          "pos": Vector2(550, 250),    "region": "Outer Rim" },
		{ "id": "rim-3",  "name": "Ashfall",         "pos": Vector2(380, 280),    "region": "Outer Rim" },
		{ "id": "rim-4",  "name": "Dead Reach",      "pos": Vector2(600, 80),     "region": "Outer Rim" },
		{ "id": "rim-5",  "name": "Ember Gate",      "pos": Vector2(480, 0),      "region": "Outer Rim" },
		# ── Fringe Sector (4) ──
		{ "id": "fringe-1", "name": "Verdant Abyss",   "pos": Vector2(-380, -200), "region": "Fringe Sector" },
		{ "id": "fringe-2", "name": "Echo Nebula",     "pos": Vector2(-500, -320), "region": "Fringe Sector" },
		{ "id": "fringe-3", "name": "Oblivion's Edge", "pos": Vector2(-340, -380), "region": "Fringe Sector" },
		{ "id": "fringe-4", "name": "Phantom Shroud",  "pos": Vector2(-480, -180), "region": "Fringe Sector" },
	],
	"lanes": [
		# Core internal
		{ "from": "core-1", "to": "core-2" },
		{ "from": "core-1", "to": "core-3" },
		{ "from": "core-1", "to": "core-4" },
		{ "from": "core-2", "to": "core-6" },
		{ "from": "core-3", "to": "core-5" },
		{ "from": "core-4", "to": "core-6" },
		{ "from": "core-5", "to": "core-1" },
		# Outer Rim internal
		{ "from": "rim-1", "to": "rim-2" },
		{ "from": "rim-1", "to": "rim-5" },
		{ "from": "rim-2", "to": "rim-3" },
		{ "from": "rim-3", "to": "rim-1" },
		{ "from": "rim-4", "to": "rim-5" },
		{ "from": "rim-4", "to": "rim-1" },
		# Fringe internal
		{ "from": "fringe-1", "to": "fringe-2" },
		{ "from": "fringe-1", "to": "fringe-3" },
		{ "from": "fringe-2", "to": "fringe-3" },
		{ "from": "fringe-4", "to": "fringe-1" },
		{ "from": "fringe-4", "to": "fringe-2" },
		# Cross-region lanes
		{ "from": "core-3", "to": "rim-5" },
		{ "from": "core-5", "to": "rim-1" },
		{ "from": "core-4", "to": "fringe-1" },
		{ "from": "core-6", "to": "fringe-4" },
	],
}

# ── Lifecycle ────────────────────────────────────────────────────────

func _ready() -> void:
	camera.current = true
	_apply_camera()
	_build_map(DUMMY_GALAXY)
	ViewTransition.register_map(self, camera)
	ViewTransition.view_changed.connect(_on_view_changed)

func _on_view_changed(new_view) -> void:
	if new_view == ViewTransition.ViewMode.MAP:
		entering_system = false
		camera.current = true

# ── Camera helpers ───────────────────────────────────────────────────

func _apply_camera() -> void:
	camera.rotation_degrees = Vector3(CAM_PITCH_DEG, 0.0, 0.0)
	var pitch_rad: float = deg_to_rad(-CAM_PITCH_DEG)
	camera.position = Vector3(0.0, cam_zoom * sin(pitch_rad), cam_zoom * cos(pitch_rad))

# ── Input ────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if ViewTransition.transitioning:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			cam_zoom = maxf(CAM_ZOOM_MIN, cam_zoom - CAM_ZOOM_STEP)
			_apply_camera()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			cam_zoom = minf(CAM_ZOOM_MAX, cam_zoom + CAM_ZOOM_STEP)
			_apply_camera()
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			panning = mb.pressed
			last_pan_pos = mb.position
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_try_pick_star(mb.position)
			return

	if event is InputEventMouseMotion and panning:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var scale: float = cam_zoom * 0.002 * CAM_PAN_SPEED
		camera_rig.position.x -= mm.relative.x * scale
		camera_rig.position.z -= mm.relative.y * scale

# ── Process ──────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not visible:
		return
	if ViewTransition.current_view != ViewTransition.ViewMode.MAP:
		return
	if ViewTransition.transitioning:
		return

	_handle_keyboard_pan(delta)
	lane_pulse_time += delta * 0.6
	_update_lane_pulse()
	_update_label_visibility()

func _handle_keyboard_pan(_delta: float) -> void:
	var input: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("ui_left"):
		input.x -= 1.0
	if Input.is_action_pressed("ui_right"):
		input.x += 1.0
	if Input.is_action_pressed("ui_up"):
		input.y -= 1.0
	if Input.is_action_pressed("ui_down"):
		input.y += 1.0
	if input.length_squared() > 0.0:
		var speed: float = cam_zoom * 0.005
		camera_rig.position.x += input.x * speed
		camera_rig.position.z += input.y * speed

# ── Star picking (raycast) ──────────────────────────────────────────

func _try_pick_star(screen_pos: Vector2) -> void:
	if camera == null:
		return

	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var ray_len: float = cam_zoom * 4.0

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, from + dir * ray_len
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		return

	var collider: Object = result.get("collider")
	if collider == null:
		return

	var node: Node = (collider as Node).get_parent()
	if node == null or not node.has_method("get_star_data"):
		return

	var sdata: StarData = node.get_star_data()
	_on_system_selected(sdata)

func _on_system_selected(sdata: StarData) -> void:
	selected_star = sdata
	print("Selected star: %d" % sdata.id)

	for node in systems.values():
		node.set_selected(node.get_star_data() == sdata)

	# Double-click → enter system
	if _last_selected_id == sdata.id and (Time.get_ticks_msec() - _last_click_ms) < 400:
		_enter_selected_system()
	_last_selected_id = sdata.id
	_last_click_ms = Time.get_ticks_msec()

var _last_selected_id: int = -1
var _last_click_ms: int = 0

func _enter_selected_system() -> void:
	if entering_system or selected_star == null:
		return
	entering_system = true
	ViewTransition.enter_system(selected_star)

# ── Map building ─────────────────────────────────────────────────────

func _build_map(data: Dictionary) -> void:
	var sys_by_id: Dictionary = {}
	for sys: Dictionary in data["systems"]:
		sys_by_id[sys["id"]] = sys

	_build_territories(data)
	_build_hyperlanes(data, sys_by_id)
	_spawn_star_nodes(data)

# ── Star nodes ───────────────────────────────────────────────────────

func _spawn_star_nodes(data: Dictionary) -> void:
	var star_scene: PackedScene = preload("res://scenes/star_map_node.tscn")

	for sys: Dictionary in data["systems"]:
		var sid: String = sys["id"]
		var pos2: Vector2 = sys["pos"]
		var region_name: String = sys["region"]

		var node: Node3D = star_scene.instantiate()
		node.name = "Star_%s" % sid
		node.position = Vector3(pos2.x, 0.0, pos2.y)

		var sd: StarData = StarData.new()
		sd.id = sid.hash()
		sd.galaxy_position = pos2
		sd.system_seed = sid.hash() ^ 0xBEEFCAFE

		system_layer.add_child(node)
		node.setup(sys["name"], region_name, _get_region_color(region_name), sd)
		node.system_selected.connect(_on_system_selected)
		systems[sid] = node

func _get_region_color(region_name: String) -> Color:
	if REGION_COLORS.has(region_name):
		return REGION_COLORS[region_name]
	return REGION_COLORS["Neutral"]

# ── Hyperlanes ───────────────────────────────────────────────────────

var _lane_glow_meshes: Array[MeshInstance3D] = []

func _build_hyperlanes(data: Dictionary, sys_map: Dictionary) -> void:
	var drawn: Dictionary = {}

	for lane: Dictionary in data["lanes"]:
		var id_a: String = lane["from"]
		var id_b: String = lane["to"]
		var key: String
		if id_a < id_b:
			key = id_a + "_" + id_b
		else:
			key = id_b + "_" + id_a
		if drawn.has(key):
			continue
		drawn[key] = true

		var pos_a: Vector2 = sys_map[id_a]["pos"]
		var pos_b: Vector2 = sys_map[id_b]["pos"]

		var cross: bool = sys_map[id_a]["region"] != sys_map[id_b]["region"]
		_add_lane_line(pos_a, pos_b, false, cross)
		_add_lane_line(pos_a, pos_b, true, cross)

func _add_lane_line(a: Vector2, b: Vector2, is_glow: bool, cross_region: bool) -> void:
	var im: ImmediateMesh = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)

	var base_color: Color
	if cross_region:
		base_color = Color(0.9, 0.7, 0.3)
	else:
		base_color = Color(0.3, 0.75, 1.0)

	if is_glow:
		base_color.a = 0.18
	else:
		base_color.a = 0.7

	var y: float = 0.2 if is_glow else 0.3

	im.surface_set_color(base_color)
	im.surface_add_vertex(Vector3(a.x, y, a.y))
	im.surface_set_color(base_color)
	im.surface_add_vertex(Vector3(b.x, y, b.y))
	im.surface_end()

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = im

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat

	if is_glow:
		mi.set_meta("lane_type", "glow")
		_lane_glow_meshes.append(mi)
	else:
		mi.set_meta("lane_type", "core")

	lane_layer.add_child(mi)

func _update_lane_pulse() -> void:
	var pulse: float = 0.85 + sin(lane_pulse_time) * 0.15
	for mi: MeshInstance3D in _lane_glow_meshes:
		if mi == null or not is_instance_valid(mi):
			continue
		var mat: StandardMaterial3D = mi.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color.a = 0.18 * pulse

func _update_label_visibility() -> void:
	var t: float = clampf(inverse_lerp(CAM_ZOOM_MAX * 0.7, CAM_ZOOM_MAX, cam_zoom), 0.0, 1.0)
	for node in systems.values():
		if node.has_method("set_label_alpha"):
			node.set_label_alpha(1.0 - t)

# ── Territories (filled polygons + border outlines) ──────────────────

func _build_territories(data: Dictionary) -> void:
	var region_points: Dictionary = {}
	for sys: Dictionary in data["systems"]:
		var rname: String = sys["region"]
		if not region_points.has(rname):
			region_points[rname] = []
		region_points[rname].append(sys["pos"])

	for rname: String in region_points.keys():
		var points: Array = region_points[rname]
		if points.size() < 3:
			continue

		var pv: PackedVector2Array = PackedVector2Array()
		for p: Variant in points:
			pv.append(p as Vector2)

		var hull: PackedVector2Array = Geometry2D.convex_hull(pv)
		if hull.size() < 3:
			continue

		var color: Color = _get_region_color(rname)
		var expanded: PackedVector2Array = _expand_polygon(hull, 120.0)
		expanded = _smooth_polygon(expanded, 2)

		_add_territory_fill(expanded, color, -0.1)
		_add_territory_border(expanded, color, 0.05)
		_add_region_label(rname, _polygon_centroid(expanded))

func _expand_polygon(poly: PackedVector2Array, amount: float) -> PackedVector2Array:
	# Use Godot's proper polygon offset (Minkowski sum) for uniform expansion
	var result_polys: Array[PackedVector2Array] = Geometry2D.offset_polygon(poly, amount)
	if result_polys.size() > 0:
		return result_polys[0]
	# Fallback: manual centroid-based expansion
	var center: Vector2 = Vector2.ZERO
	for p: Vector2 in poly:
		center += p
	center /= float(poly.size())
	var result: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in poly:
		var dir: Vector2 = (p - center).normalized()
		result.append(p + dir * amount)
	return result

func _smooth_polygon(poly: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var pts: PackedVector2Array = poly
	for _iter: int in range(iterations):
		var smoothed: PackedVector2Array = PackedVector2Array()
		var n: int = pts.size()
		for i: int in range(n):
			var prev_pt: Vector2 = pts[(i - 1 + n) % n]
			var curr: Vector2 = pts[i]
			var next_pt: Vector2 = pts[(i + 1) % n]
			smoothed.append(prev_pt * 0.2 + curr * 0.6 + next_pt * 0.2)
		pts = smoothed
	return pts

func _polygon_centroid(poly: PackedVector2Array) -> Vector2:
	var c: Vector2 = Vector2.ZERO
	for p: Vector2 in poly:
		c += p
	return c / float(poly.size())

func _add_territory_fill(poly: PackedVector2Array, color: Color, y: float) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var fill: Color = Color(color.r, color.g, color.b, 0.08)

	for i: int in range(1, poly.size() - 1):
		st.set_color(fill)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(poly[0].x, y, poly[0].y))
		st.set_color(fill)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(poly[i].x, y, poly[i].y))
		st.set_color(fill)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(poly[i + 1].x, y, poly[i + 1].y))

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "TerritoryFill"
	mi.mesh = st.commit()

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat

	territory_layer.add_child(mi)

func _add_territory_border(poly: PackedVector2Array, color: Color, y: float) -> void:
	var border_color: Color = Color(color.r, color.g, color.b, 0.5)
	var width: float = 3.0

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	var n: int = poly.size()
	for i: int in range(n + 1):
		var idx: int = i % n
		var next_idx: int = (i + 1) % n
		var curr: Vector2 = poly[idx]
		var next_pt: Vector2 = poly[next_idx]
		var tangent: Vector2 = (next_pt - curr).normalized()
		var normal_2d: Vector2 = Vector2(-tangent.y, tangent.x)

		st.set_color(border_color)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(curr.x + normal_2d.x * width, y, curr.y + normal_2d.y * width))
		st.set_color(border_color)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(curr.x - normal_2d.x * width, y, curr.y - normal_2d.y * width))

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "TerritoryBorder"
	mi.mesh = st.commit()

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat

	territory_layer.add_child(mi)

func _add_region_label(region_name: String, center: Vector2) -> void:
	var label: Label3D = Label3D.new()
	label.text = region_name.to_upper()
	label.font_size = 64
	label.pixel_size = 0.4
	label.position = Vector3(center.x, 1.0, center.y)
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	label.modulate = Color(1.0, 1.0, 1.0, 0.15)
	label.outline_modulate = Color(0, 0, 0, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.shaded = false
	territory_layer.add_child(label)
