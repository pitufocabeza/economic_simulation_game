extends Node2D
var entering_system := false

@onready var system_layer := $SystemLayer
@onready var lane_layer := $HyperlaneLayer
@onready var camera := $Camera2D

const ZOOM_MIN := 0.4
const ZOOM_SYSTEM := 1.2
const ZOOM_REGION := 0.8
const ZOOM_GALAXY := 0.4
const ZOOM_MAX := 2.0

const SYSTEM_ENTER_ZOOM := 1.8

var lane_pulse_time := 0
var selected_star: StarData
var last_click_time := 0.0
const DOUBLE_CLICK_TIME := 0.3

var systems := {}  # id → node

const DUMMY_GALAXY := {
	"systems": [
		{
			"id": "core-1",
			"name": "Aurelion",
			"pos": Vector2(0, 0),
			"region": "Faction",
			"owner": "Faction"
		},
		{
			"id": "outlaw-1",
			"name": "Rift-9",
			"pos": Vector2(600, 200),
			"region": "Outlaw",
			"owner": ""
		},
		{
			"id": "outlaw-2",
			"name": "Kharos",
			"pos": Vector2(-500, -300),
			"region": "Outlaw",
			"owner": ""
		}
	],
	"lanes": [
		{ "from": "core-1", "to": "outlaw-1" },
		{ "from": "core-1", "to": "outlaw-2" }
	]
}


func _ready():
	build_map(DUMMY_GALAXY)
	camera.zoom = Vector2.ONE * ZOOM_GALAXY
	ViewTransition.register_map(self, $Camera2D)
	center_camera()
	
	ViewTransition.view_changed.connect(_on_view_changed)

func _on_view_changed(new_view):
	if new_view == ViewTransition.ViewMode.MAP:
		entering_system = false

func _process(delta: float) -> void:
	if ViewTransition.current_view != ViewTransition.ViewMode.MAP:
		return
	if ViewTransition.transitioning:
		return
		
	_handle_keyboard_pan(delta)
	# print("VIEW:", ViewTransition.current_view, "TRANS:", ViewTransition.transitioning)
	# print(camera.zoom)
	lane_pulse_time += delta *0.6
	var z: float = camera.zoom.x

	_update_lane_style(z)
	_update_system_style(z)

	if z <= ZOOM_GALAXY:
		set_galaxy_overview()
	elif z <= ZOOM_REGION:
		set_region_view()
	else:
		set_system_focus_view()

	if z >= SYSTEM_ENTER_ZOOM and selected_star and not entering_system:
		entering_system = true
		ViewTransition.enter_system(selected_star)
		
	if entering_system:
		return

func _update_lane_style(z: float) -> void:
	var t: float = clamp((z - ZOOM_SYSTEM) / (ZOOM_GALAXY - ZOOM_SYSTEM), 0.0, 1.0)
	
	# Pulse goes from 0.85 to 1.15
	var pulse: float = 0.85 + sin(lane_pulse_time) * 0.15
	
	for lane in lane_layer.get_children():
		var lane_type: String = lane.get_meta("lane_type")

		if lane_type == "glow":
			lane.modulate.a = lerp(0.05, 0.35, t) * pulse
			lane.width = lerp(3.0, 7.0, t)

		elif lane_type == "core":
			lane.modulate.a = lerp(0.15, 0.9, t)
			lane.width = lerp(1.0, 2.5, t)


func _update_system_style(z: float) -> void:
	for node in systems.values():
		node.update_visuals(z)


func set_galaxy_overview():
	# later: show region labels, hide lanes
	pass

func set_region_view():
	# normal map
	pass

func set_system_focus_view():
	# enable system entry on double-click
	pass


func build_map(data: Dictionary):
	# Spawn systems
	for sys in data.systems:
		var node := preload("res://scenes/system_node.tscn").instantiate()
		node.system_id = sys.id
		node.system_name = sys.name
		node.position = sys.pos
		node.region_type = sys.region
		
		var star_data = StarData.new()
		star_data.id = sys.id.hash()
		star_data.galaxy_position = sys.pos
		star_data.system_seed = sys.id.hash() ^ 0xBEEFCAFE
		
		node.star_data = star_data
		
		node.connect("system_selected", _on_system_selected)
		system_layer.add_child(node)
		systems[sys.id] = node

	# Draw lanes
	for lane in data.lanes:
		draw_lane(
			systems[lane.from].position,
			systems[lane.to].position
		)


func draw_lane(a: Vector2, b: Vector2):
	var curve := Curve2D.new()
	var mat := CanvasItemMaterial.new()
	
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var mid := (a + b) * 0.5
	var offset := (b - a).orthogonal().normalized() * randf_range(-80, 80)

	curve.add_point(a)
	curve.add_point(mid + offset)
	curve.add_point(b)

	
	# --- GLOW LINE ----
	var glow := Line2D.new()
	glow.width = 6.0
	glow.default_color = Color(0.5, 0.7, 1.0, 0.25)
	glow.z_index = -20
	glow.antialiased = true

	# --- CORE LINE ---
	var core := Line2D.new()
	core.width = 2.0
	core.default_color = Color(0.7, 0.9, 1.0, 0.85)
	core.z_index = -10
	core.antialiased = true
	
	var hue_shift := randf_range(-0.03, 0.03)
	glow.default_color = Color.from_hsv(
		glow.default_color.h + hue_shift,
		glow.default_color.s,
		glow.default_color.v,
		glow.default_color.a
	)
	core.default_color = Color.from_hsv(
		core.default_color.h + hue_shift,
		core.default_color.s,
		core.default_color.v,
		core.default_color.a
	)

	for c in curve.get_baked_points():
		core.add_point(c)
		
	for g in curve.get_baked_points():
		glow.add_point(g)
		
	
	lane_layer.add_child(core)
	lane_layer.add_child(glow)

	glow.set_meta("lane_type", "glow")
	core.set_meta("lane_type", "core")

func center_camera():
	camera.position = Vector2.ZERO

func _on_system_selected(star_data: StarData):
	selected_star = star_data
	print("Selected:", star_data.id)

	for node in systems.values():
		node.set_selected(node.star_data == star_data)

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

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom *= 1.1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom *= 0.9

	camera.zoom.x = clamp(camera.zoom.x, ZOOM_MIN, ZOOM_MAX)
	camera.zoom.y = camera.zoom.x
	
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			camera.position -= event.relative / camera.zoom
