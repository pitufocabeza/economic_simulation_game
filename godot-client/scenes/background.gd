extends TextureRect

@export var drift_speed := 0.2
@export var breathe_amount := 0.02
@export var breathe_speed := 0.0001

func _process(delta: float) -> void:
	position.x += drift_speed * delta

	var t := Time.get_ticks_msec()
	var s := 1.0 + sin(t * breathe_speed) * breathe_amount
	scale = Vector2.ONE * s
