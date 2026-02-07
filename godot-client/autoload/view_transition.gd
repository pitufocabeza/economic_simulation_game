extends Node
@export var nebula_layer: Control = null

# Scenes
const SYSTEM_SCENE := preload("res://system_view.tscn")

# References
var map_view: Node
var map_camera: Camera2D
var system_view: Node
var system_camera: Camera3D

# State
var active_star: StarData
var active_star_id: int = -1
var transitioning := false

# Tuning
const MAP_ZOOM_ENTER := 0.18
const MAP_ZOOM_EXIT  := 0.22
const MAP_RETURN_ZOOM := 0.25

# Fade
var fade_layer: CanvasLayer
var fade_rect: ColorRect

enum ViewMode {
	MAP,
	SYSTEM
}

var current_view: ViewMode = ViewMode.MAP

signal view_changed(new_view: ViewMode)

func _ready():
	_create_fade_layer()
	ViewTransition.view_changed.connect(_on_view_changed)

func _on_view_changed(new_view):
	if new_view == ViewTransition.ViewMode.MAP:
		_show_map_view()

func _show_map_view():
	pass
	# enable input, camera, etc

# ---------------------------------------------------
# PUBLIC API (called by MapView / SystemView)
# ---------------------------------------------------
func register_nebula(layer: Control) -> void:
	nebula_layer = layer
	
	# Ensure correct visibility based on current view
		
func clear_nebula(layer: Control) -> void:
	if nebula_layer == layer:
		nebula_layer = null
		
func _emit_view_changed() -> void:
	view_changed.emit(current_view)

func register_map(map: Node, camera: Camera2D) -> void:
	map_view = map
	map_camera = camera


func enter_system(star: StarData) -> void:
	if transitioning:
		return
	if system_view != null:
		return
	
	if current_view == ViewMode.SYSTEM and active_star_id == star.id:
		return
		
	transitioning = true
	current_view = ViewMode.SYSTEM
	active_star = star
	active_star_id = star.id

	await _fade_out()

	_load_system_view()

	await _fade_in()

	transitioning = false


func exit_system() -> void:
	if transitioning:
		return

	transitioning = true
	
	await _fade_out()

	# Tear down system view
	if system_view:
		system_view.set_process(false)
		system_view.queue_free()
		system_view = null
		system_camera = null

	active_star_id = -1
	current_view = ViewMode.MAP
	
	# Restore map view
	if map_view:
		map_view.visible = true

	if map_camera:
		map_camera.enabled = true
		# IMPORTANT: reset zoom WHILE transitioning is true
		map_camera.zoom = Vector2.ONE * (MAP_ZOOM_EXIT + 0.10)

	_emit_view_changed()

	await _fade_in()

	# ONLY NOW re-enable logic
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
