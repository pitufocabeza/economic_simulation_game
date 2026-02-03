
extends Camera3D

@export var target: Vector3 = Vector3(0, 0, 0)
@export var zoom: float = 40.0
@export var min_zoom: float = 180.0
@export var max_zoom: float = 600.0
@export var start_zoom: float = 260.0
@export var yaw: float = 45.0 # Horizontal angle (degrees)
@export var pitch: float = 35.0 # Vertical angle (degrees)
@export var min_pitch: float = 20.0
@export var max_pitch: float = 75.0
@export var zoom_speed: float = 8.0
@export var rotate_speed: float = 0.3
@export var pitch_speed: float = 0.2
@export var move_speed: float = 150.0
@export var terrain_integrator_path: NodePath
@export var auto_center_on_ready: bool = true
@export var follow_terrain_height: bool = true
@export var min_height_offset: float = 5.0

var _hterrain: Node = null
var _terrain_integrator: Node = null

var dragging_yaw := false
var dragging_pitch := false
var last_mouse_pos := Vector2.ZERO

func _ready():
	_setup_terrain_refs()
	if auto_center_on_ready:
		_center_on_terrain()
	zoom = clamp(start_zoom, min_zoom, max_zoom)
	_update_camera_transform()

func _setup_terrain_refs():
	if terrain_integrator_path != NodePath(""):
		_terrain_integrator = get_node_or_null(terrain_integrator_path)
	if _terrain_integrator:
		_hterrain = _terrain_integrator.find_child("HTerrain", true, false)
	else:
		_hterrain = find_child("HTerrain", true, false)

func _center_on_terrain():
	var terrain_size := _get_terrain_size()
	if terrain_size > 0.0:
		var origin = _terrain_integrator.global_position if _terrain_integrator else Vector3.ZERO
		target.x = origin.x + terrain_size * 0.5
		target.z = origin.z + terrain_size * 0.5
	if follow_terrain_height:
		target.y = _get_height_at(target.x, target.z)

func _get_terrain_size() -> float:
	if _terrain_integrator and "TERRAIN_SIZE" in _terrain_integrator:
		return float(_terrain_integrator.TERRAIN_SIZE)
	if _hterrain and _hterrain.has_method("get_data"):
		var data = _hterrain.get_data()
		if data and data.has_method("get_resolution"):
			return float(data.get_resolution())
	return 0.0

func _get_height_at(x: float, z: float) -> float:
	if _hterrain:
		if _hterrain.has_method("get_height_at_world_position"):
			return _hterrain.get_height_at_world_position(Vector3(x, 0.0, z))
		if _hterrain.has_method("get_height_at"):
			return _hterrain.get_height_at(x, z)
	return target.y

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging_yaw = event.pressed and not Input.is_key_pressed(KEY_ALT)
			dragging_pitch = event.pressed and Input.is_key_pressed(KEY_ALT)
			last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging_pitch = event.pressed
			last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom = clamp(zoom - zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = clamp(zoom + zoom_speed, min_zoom, max_zoom)
	elif event is InputEventMouseMotion:
		var delta = event.position - last_mouse_pos
		if dragging_yaw:
			yaw -= delta.x * rotate_speed
		if dragging_pitch:
			pitch = clamp(pitch - delta.y * pitch_speed, min_pitch, max_pitch)
		last_mouse_pos = event.position

func _process(delta):
	_handle_movement(delta)
	_update_camera_transform()

# Handles WASD movement relative to camera yaw
func _handle_movement(delta):
	var input_vec = Vector2.ZERO
	if Input.is_action_pressed("ui_left"):
		input_vec.x -= 1
	if Input.is_action_pressed("ui_right"):
		input_vec.x += 1
	if Input.is_action_pressed("ui_up"):
		input_vec.y -= 1
	if Input.is_action_pressed("ui_down"):
		input_vec.y += 1
	if input_vec.length() > 0:
		input_vec = input_vec.normalized()
		# Move relative to yaw (XZ plane)
		var yaw_rad = deg_to_rad(yaw)
		var forward = Vector3(sin(yaw_rad), 0, cos(yaw_rad))
		var right = Vector3(forward.z, 0, -forward.x)
		var move = (forward * input_vec.y + right * input_vec.x) * move_speed * delta * zoom * 0.05
		target += move

func _update_camera_transform():
	var rad_yaw = deg_to_rad(yaw)
	var rad_pitch = deg_to_rad(pitch)
	if follow_terrain_height:
		target.y = _get_height_at(target.x, target.z)
	if min_height_offset > 0.0 and rad_pitch > 0.001:
		var min_zoom_for_height = min_height_offset / sin(rad_pitch)
		var min_allowed = max(min_zoom, min_zoom_for_height)
		zoom = clamp(zoom, min_allowed, max_zoom)
	var offset = Vector3(
		zoom * sin(rad_yaw) * cos(rad_pitch),
		zoom * sin(rad_pitch),
		zoom * cos(rad_yaw) * cos(rad_pitch)
	)
	global_position = target + offset
	look_at(target, Vector3.UP)
