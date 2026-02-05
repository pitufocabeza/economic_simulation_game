extends Camera3D

@export var target: Vector3 = Vector3.ZERO

@export var min_distance: float = 3000.0
@export var max_distance: float = 25000.0
@export var zoom: float = 18000.0
@export var zoom_speed: float = 1.15 # exponential zoom

@export var yaw: float = 45.0
@export var pitch: float = 40.0
@export var min_pitch: float = 20.0
@export var max_pitch: float = 75.0

@export var rotate_speed: float = 0.25
@export var pan_speed: float = 20.0
@export var key_rotate_speed: float = 90.0 # degrees/sec

@export var near_clip: float = 200.0
@export var far_clip: float = 300000.0

var dragging_rotate: bool = false
var dragging_pan: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	near = near_clip
	far = far_clip


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_RIGHT:
			dragging_rotate = mb.pressed
			last_mouse_pos = mb.position

		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			dragging_pan = mb.pressed
			last_mouse_pos = mb.position

		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom /= zoom_speed
			zoom = clamp(zoom, min_distance, max_distance)

		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom *= zoom_speed
			zoom = clamp(zoom, min_distance, max_distance)

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var mouse_delta: Vector2 = mm.position - last_mouse_pos

		if dragging_rotate:
			yaw -= mouse_delta.x * rotate_speed
			pitch = clamp(pitch - mouse_delta.y * rotate_speed, min_pitch, max_pitch)

		elif dragging_pan:
			_pan(mouse_delta)

		last_mouse_pos = mm.position


func _process(delta: float) -> void:
	_handle_keyboard_pan(delta)
	_handle_keyboard_rotation(delta)
	_update_camera_transform()


# -----------------------------
# Keyboard controls
# -----------------------------

func _handle_keyboard_rotation(delta: float) -> void:
	if Input.is_key_pressed(KEY_Q):
		yaw += key_rotate_speed * delta
	if Input.is_key_pressed(KEY_E):
		yaw -= key_rotate_speed * delta
	yaw = fmod(yaw, 360.0)


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

	if input == Vector2.ZERO:
		return

	input = input.normalized()

	var pan_strength: float = zoom * pan_speed * delta * 0.02
	var yaw_rad: float = deg_to_rad(yaw)

	var right: Vector3 = Vector3(cos(yaw_rad), 0.0, -sin(yaw_rad))
	var forward: Vector3 = Vector3(sin(yaw_rad), 0.0, cos(yaw_rad))

	target += (right * input.x + forward * input.y) * pan_strength


# -----------------------------
# Mouse panning
# -----------------------------

func _pan(mouse_delta: Vector2) -> void:
	var pan_strength: float = zoom * pan_speed * 0.002
	var yaw_rad: float = deg_to_rad(yaw)

	var right: Vector3 = Vector3(cos(yaw_rad), 0.0, -sin(yaw_rad))
	var forward: Vector3 = Vector3(sin(yaw_rad), 0.0, cos(yaw_rad))

	target -= right * mouse_delta.x * pan_strength
	target += forward * mouse_delta.y * pan_strength


# -----------------------------
# Camera transform
# -----------------------------

func _update_camera_transform() -> void:
	var yaw_rad: float = deg_to_rad(yaw)
	var pitch_rad: float = deg_to_rad(pitch)

	var offset: Vector3 = Vector3(
		zoom * sin(yaw_rad) * cos(pitch_rad),
		zoom * sin(pitch_rad),
		zoom * cos(yaw_rad) * cos(pitch_rad)
	)

	global_position = target + offset
	look_at(target, Vector3.UP)

func frame_radius(
	radius: float,
	padding: float = 1.25,
	animate: bool = true
) -> void:
	# Convert angles
	var fov_rad := deg_to_rad(fov)
	var pitch_rad := deg_to_rad(pitch)

	# Account for camera tilt
	var vertical_factor := tan(fov_rad * 0.5) * cos(pitch_rad)
	if vertical_factor <= 0.001:
		vertical_factor = 0.001

	var required_zoom := (radius * padding) / vertical_factor

	required_zoom = clamp(
		required_zoom,
		min_distance,
		max_distance
	)

	target = Vector3.ZERO

	if animate:
		var tween := create_tween()
		tween.tween_property(
			self,
			"zoom",
			required_zoom,
			0.9
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		zoom = required_zoom
