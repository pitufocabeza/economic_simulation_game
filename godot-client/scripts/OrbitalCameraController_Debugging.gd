extends Camera3D

@export var orbit_speed := 0.15
@export var pan_speed := 400.0
@export var zoom_speed := 3000.0
@export var max_distance := 500000.0

@export var pan_smoothing := 10.0
@export var edge_scroll_enabled := true
@export var edge_scroll_margin := 24.0
@export var edge_scroll_speed := 600.0

@export var star_radius := 12000.0

@export var near_clip := 200.0
@export var far_clip := 300000.0

@export var min_vertical_angle := -85.0
@export var max_vertical_angle := 85.0

var focus_point := Vector3.ZERO
var orbit_radius := 0.0
var orbit_theta := 0.0
var orbit_phi := 35.0
var min_distance := 0.0
var pan_velocity := Vector3.ZERO

func _ready():
	near = near_clip
	far = far_clip

	min_distance = star_radius * 3.0
	max_distance = max(max_distance, min_distance + 1.0)
	orbit_radius = star_radius * 5.0

	update_camera_position()

func _process(delta):
	handle_input(delta)
	update_camera_position()

func handle_input(delta):
	var pan_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		pan_dir.z -= 1
	if Input.is_key_pressed(KEY_S):
		pan_dir.z += 1
	if Input.is_key_pressed(KEY_A):
		pan_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		pan_dir.x += 1

	if edge_scroll_enabled:
		var viewport := get_viewport()
		var mouse_pos := viewport.get_mouse_position()
		var size := viewport.get_visible_rect().size
		if mouse_pos.x <= edge_scroll_margin:
			pan_dir.x -= 1
		elif mouse_pos.x >= size.x - edge_scroll_margin:
			pan_dir.x += 1
		if mouse_pos.y <= edge_scroll_margin:
			pan_dir.z -= 1
		elif mouse_pos.y >= size.y - edge_scroll_margin:
			pan_dir.z += 1

	var target_speed := pan_speed
	if edge_scroll_enabled:
		if pan_dir != Vector3.ZERO:
			target_speed = max(pan_speed, edge_scroll_speed)

	var target_velocity := Vector3.ZERO
	if pan_dir != Vector3.ZERO:
		target_velocity = pan_dir.normalized() * target_speed

	var smoothing := 1.0 - exp(-pan_smoothing * delta)
	pan_velocity = pan_velocity.lerp(target_velocity, smoothing)
	focus_point += pan_velocity * delta

	if Input.is_action_just_pressed("ui_up"):
		orbit_radius = clamp(orbit_radius - zoom_speed, min_distance, max_distance)
	if Input.is_action_just_pressed("ui_down"):
		orbit_radius = clamp(orbit_radius + zoom_speed, min_distance, max_distance)

func _input(event):
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) \
		or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.is_key_pressed(KEY_ALT)):
			orbit_theta -= event.relative.x * orbit_speed
			orbit_phi = clamp(
				orbit_phi + event.relative.y * orbit_speed,
				min_vertical_angle,
				max_vertical_angle
			)

func update_camera_position():
	var theta := deg_to_rad(orbit_theta)
	var phi := deg_to_rad(orbit_phi)

	var x := orbit_radius * cos(phi) * sin(theta)
	var y := orbit_radius * sin(phi)
	var z := orbit_radius * cos(phi) * cos(theta)

	global_position = focus_point + Vector3(x, y, z)
	look_at(focus_point, Vector3.UP)
