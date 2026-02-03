extends CharacterBody3D

# Collision-aware camera rig
# Node hierarchy:
# CameraRig (CharacterBody3D)
#   - CollisionShape3D (CapsuleShape3D)
#   - SpringArm3D
#       - Camera3D

@export var move_speed: float = 30.0
@export var acceleration: float = 12.0
@export var zoom_speed: float = 6.0
@export var min_zoom: float = 8.0
@export var max_zoom: float = 80.0
@export var rotate_speed: float = 0.25
@export var enable_middle_drag_rotate: bool = true

@export var terrain_collision_mask: int = 1

@onready var _spring_arm: SpringArm3D = $SpringArm3D

var _drag_rotate := false
var _last_mouse_pos := Vector2.ZERO

func _ready():
	# Ensure this rig only collides with terrain (layer 1)
	collision_mask = terrain_collision_mask

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_drag_rotate = event.pressed and enable_middle_drag_rotate
			_last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_spring_arm.spring_length = clamp(_spring_arm.spring_length - zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_spring_arm.spring_length = clamp(_spring_arm.spring_length + zoom_speed, min_zoom, max_zoom)
	elif event is InputEventMouseMotion and _drag_rotate:
		var delta = event.position - _last_mouse_pos
		rotation.y -= delta.x * rotate_speed
		_last_mouse_pos = event.position

func _physics_process(delta):
	var input_vec = Vector2.ZERO
	if Input.is_action_pressed("ui_left"):
		input_vec.x -= 1
	if Input.is_action_pressed("ui_right"):
		input_vec.x += 1
	if Input.is_action_pressed("ui_up"):
		input_vec.y -= 1
	if Input.is_action_pressed("ui_down"):
		input_vec.y += 1

	var dir = Vector3.ZERO
	if input_vec.length() > 0:
		input_vec = input_vec.normalized()
		var forward = -transform.basis.z
		forward.y = 0
		forward = forward.normalized()
		var right = transform.basis.x
		right.y = 0
		right = right.normalized()
		dir = (forward * input_vec.y + right * input_vec.x).normalized()

	var target_vel = dir * move_speed
	velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)
	velocity.y = 0.0

	move_and_slide()