extends Node2D
var entering_system := false

@onready var system_layer := $SystemLayer
@onready var lane_layer := $HyperlaneLayer
@onready var camera := $Camera2D

const ZOOM_MIN := 120.0
const ZOOM_SYSTEM := 220.0
const ZOOM_REGION := 600.0
const ZOOM_GALAXY := 1400.0
const ZOOM_MAX := 2200.0

const SYSTEM_ENTER_ZOOM := 160.0


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
	ViewTransition.register_map(self, $Camera2D)
	center_camera()
	
func _process(delta: float) -> void:
	_handle_keyboard_pan(delta)

	var z: float = camera.zoom.x

	_update_lane_style(z)
	_update_system_style(z)

	if z >= ZOOM_GALAXY:
		set_galaxy_overview()
	elif z >= ZOOM_REGION:
		set_region_view()
	else:
		set_system_focus_view()

	if z >= SYSTEM_ENTER_ZOOM and selected_star and not entering_system:
		entering_system = true
		ViewTransition.enter_system(selected_star)

func _update_lane_style(z: float) -> void:
	for lane in lane_layer.get_children():
		# Lanes are strongest at galaxy scale
		lane.modulate.a = clamp(1.4 - (z / 800.0), 0.1, 0.9)

		# Thicker when zoomed out
		lane.width = lerp(2.0, 4.0, clamp(z / ZOOM_GALAXY, 0.0, 1.0))

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

	var mid := (a + b) * 0.5
	var offset := (b - a).orthogonal().normalized() * randf_range(-80, 80)

	curve.add_point(a)
	curve.add_point(mid + offset)
	curve.add_point(b)

	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.5, 0.7, 1.0, 0.6)
	line.z_index = -10

	const SEGMENTS := 24
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		line.add_point(curve.sample_baked(t))

	lane_layer.add_child(line)


func center_camera():
	camera.position = Vector2.ZERO

func _on_system_selected(star_data: StarData):
	selected_star = star_data
	print("Selected:", star_data.id)

	for node in systems.values():
		node.set_selected(node.star_data == star_data)

func _handle_keyboard_pan(delta: float) -> void:
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
			camera.zoom *= 0.9
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom *= 1.1

	camera.zoom.x = clamp(camera.zoom.x, ZOOM_MIN, ZOOM_MAX)
	camera.zoom.y = camera.zoom.x
	
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			camera.position -= event.relative / camera.zoom
