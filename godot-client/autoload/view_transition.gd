extends Node

# Scenes
const SYSTEM_SCENE := preload("res://system_view.tscn")

# References
var map_view: Node
var map_camera: Camera2D
var system_view: Node
var system_camera: Camera3D

# State
var active_star: StarData
var transitioning := false

# Tuning
const MAP_ZOOM_ENTER := 0.18
const MAP_ZOOM_EXIT  := 0.22

# Fade
var fade_layer: CanvasLayer
var fade_rect: ColorRect


func _ready():
	_create_fade_layer()


# ---------------------------------------------------
# PUBLIC API (called by MapView / SystemView)
# ---------------------------------------------------

func register_map(map: Node, camera: Camera2D) -> void:
	map_view = map
	map_camera = camera


func enter_system(star: StarData) -> void:
	if transitioning:
		return

	transitioning = true
	active_star = star

	await _fade_out()

	_load_system_view()

	await _fade_in()

	transitioning = false


func exit_system() -> void:
	if transitioning:
		return

	transitioning = true

	await _fade_out()

	if system_view:
		system_view.queue_free()
		system_view = null
		system_camera = null

	if map_view:
		map_view.visible = true
		map_camera.enabled = true

	await _fade_in()

	transitioning = false


# ---------------------------------------------------
# INTERNALS
# ---------------------------------------------------

func _load_system_view() -> void:
	# Disable map
	map_camera.enabled = false
	map_view.visible = false

	# Load system
	system_view = SYSTEM_SCENE.instantiate()
	get_tree().root.add_child(system_view)

	# Inject StarData
	system_view.setup_from_star(active_star)

	# Cache camera
	system_camera = system_view.get_node("orbital camera")

	# Align camera zoom
	_align_system_camera()


func _align_system_camera() -> void:
	var t := inverse_lerp(0.05, MAP_ZOOM_ENTER, map_camera.zoom.x)
	t = clamp(t, 0.0, 1.0)

	system_camera.zoom = lerp(
		system_camera.max_distance,
		system_camera.min_distance,
		t
	)


# ---------------------------------------------------
# Fade Layer
# ---------------------------------------------------
func _create_fade_layer():
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 100

	get_tree().root.call_deferred("add_child", fade_layer)

	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	fade_layer.add_child(fade_rect)

	# Defer resize until it's in the scene tree
	fade_rect.call_deferred("set_size", get_viewport().get_visible_rect().size)

func _fade_out():
	await _tween_fade(1.0)


func _fade_in():
	await _tween_fade(0.0)


func _tween_fade(target_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(
		fade_rect,
		"modulate:a",
		target_alpha,
		0.35
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished
