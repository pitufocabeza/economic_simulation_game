extends Node3D
class_name PlanetMotion

@export var orbit_speed: int = 0
@export var spin_speed: float = 0.05

var orbit_node: Node3D
var planet_body: Node3D

func setup(_orbit_node: Node3D, _planet_body: Node3D) -> void:
	orbit_node = _orbit_node
	planet_body = _planet_body

func _process(delta: float) -> void:
	if orbit_node == null or planet_body == null:
		return

	# Orbit around star
	orbit_node.rotate_y(orbit_speed * delta)

	# Spin around own axis
	planet_body.rotate_y(spin_speed * delta)
