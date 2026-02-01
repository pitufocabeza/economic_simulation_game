extends Camera3D

@export var move_speed: float = 15.0
@export var mouse_sensitivity: float = 0.002

var _rotation := Vector2.ZERO

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_rotation = Vector2(rotation.y, rotation.x)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_rotation.x -= event.relative.x * mouse_sensitivity
		_rotation.y -= event.relative.y * mouse_sensitivity
		_rotation.y = clamp(_rotation.y, -PI * 0.49, PI * 0.49)

		rotation = Vector3(_rotation.y, _rotation.x, 0)

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float) -> void:
	var dir := Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		dir += transform.basis.x
	if Input.is_key_pressed(KEY_Q):
		dir -= transform.basis.y
	if Input.is_key_pressed(KEY_E):
		dir += transform.basis.y

	if dir != Vector3.ZERO:
		global_position += dir.normalized() * move_speed * delta
