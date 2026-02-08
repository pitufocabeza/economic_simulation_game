extends Node

# Scenes
const SYSTEM_SCENE := preload("res://system_view.tscn")
const PLANET_SCENE := preload("res://scenes/planet_view.tscn")
const PLOT_SCENE := preload("res://plot_view.tscn")

# Shared environments
var map_env: Environment = preload("res://environments/map_environment.tres")
var system_env: Environment = preload("res://environments/system_environment.tres")
var planet_env: Environment = preload("res://environments/planet_environment.tres")
var plot_env: Environment = preload("res://environments/plot_environment.tres")

# Global WorldEnvironment (owned by this autoload)
var world_env: WorldEnvironment = null

# References
var map_view: Node
var map_camera: Camera3D
var system_view: Node
var system_camera: Camera3D
var planet_view: Node
var plot_view: Node

# State
var active_star: StarData
var active_star_id: int = -1
var active_plot_info: PlotInfo = null
var transitioning := false

# Fade
var fade_layer: CanvasLayer
var fade_rect: ColorRect

# Loading screen
var loading_layer: CanvasLayer
var loading_panel: PanelContainer
var loading_label: Label
var loading_stage: Label
var loading_bar: ProgressBar

enum ViewMode {
	MAP,
	SYSTEM
}

var current_view: ViewMode = ViewMode.MAP

signal view_changed(new_view: ViewMode)

func _ready():
	_create_fade_layer()
	_create_loading_screen()
	_create_world_environment()
	ViewTransition.view_changed.connect(_on_view_changed)

func _create_world_environment() -> void:
	world_env = WorldEnvironment.new()
	world_env.name = "GlobalWorldEnvironment"
	world_env.environment = map_env
	add_child(world_env)

func set_environment(env: Environment) -> void:
	if world_env != null:
		world_env.environment = env

func _on_view_changed(new_view):
	if new_view == ViewTransition.ViewMode.MAP:
		_show_map_view()

func _show_map_view():
	pass
	# enable input, camera, etc

# ---------------------------------------------------
# PUBLIC API (called by MapView / SystemView)
# ---------------------------------------------------

func _emit_view_changed() -> void:
	view_changed.emit(current_view)

func register_map(map: Node, camera: Camera3D) -> void:
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
	set_environment(system_env)

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
		map_camera.current = true

	set_environment(map_env)

	_emit_view_changed()

	await _fade_in()

	# ONLY NOW re-enable logic
	transitioning = false

func enter_planet(pdata: PlanetData) -> void:
	if transitioning:
		return
	
	system_camera.set_input_enabled(false)
	transitioning = true
	await _fade_out()

	if system_view:
		system_view.visible = false

	set_environment(planet_env)

	planet_view = PLANET_SCENE.instantiate()
	get_tree().root.add_child(planet_view)
	planet_view.setup(pdata)

	await _fade_in()
	transitioning = false
	
func exit_planet() -> void:
	if transitioning:
		return
	system_camera.set_input_enabled(true)
	transitioning = true
	await _fade_out()

	if planet_view:
		planet_view.queue_free()
		planet_view = null

	if system_view:
		system_view.visible = true

	if system_camera:
		system_camera.current = true

	set_environment(system_env)

	await _fade_in()
	transitioning = false

func enter_plot(info: PlotInfo) -> void:
	if transitioning:
		return
	transitioning = true
	active_plot_info = info
	await _fade_out()

	# Hide planet view but keep it alive so we can return
	if planet_view:
		planet_view.visible = false

	set_environment(plot_env)

	# Show loading screen
	_show_loading_screen(info.archetype)
	await _fade_in()

	# Instantiate the plot scene (hidden while terrain generates)
	plot_view = PLOT_SCENE.instantiate()

	# Lock seed BEFORE add_child so the deferred _setup_references won't override it
	var terrain: Node = plot_view.get_node_or_null("Terrain")
	var plot_seed: int = info.plot_id + (active_star_id * 1000)
	if terrain:
		terrain.seed_locked = true
		terrain.current_seed = plot_seed

		# Connect progress updates before adding to tree
		if terrain.has_signal("generation_progress"):
			terrain.generation_progress.connect(_on_terrain_progress)

	get_tree().root.add_child(plot_view)

	# If cached state exists, restore buildings once terrain finishes generating
	var cache_key: String = GameState.plot_key(active_star_id, info.plot_id)
	if GameState.has_plot_state(cache_key):
		if terrain and terrain.has_signal("terrain_ready"):
			var cached_state: Dictionary = GameState.get_plot_state(cache_key)
			terrain.terrain_ready.connect(
				func() -> void:
					if plot_view and plot_view.has_method("restore_state"):
						plot_view.restore_state(cached_state),
				CONNECT_ONE_SHOT
			)

	# Wait for the terrain to finish generating
	if terrain and terrain.has_signal("terrain_ready"):
		await terrain.terrain_ready

	# Disconnect progress now that we're done
	if terrain and terrain.has_signal("generation_progress"):
		if terrain.generation_progress.is_connected(_on_terrain_progress):
			terrain.generation_progress.disconnect(_on_terrain_progress)

	# Fade out the loading screen, reveal the plot
	await _fade_out()
	_hide_loading_screen()
	await _fade_in()
	transitioning = false

func exit_plot() -> void:
	if transitioning:
		return
	transitioning = true
	await _fade_out()

	# Cache plot state before destroying
	if plot_view and active_plot_info:
		var cache_key: String = GameState.plot_key(active_star_id, active_plot_info.plot_id)
		if plot_view.has_method("collect_state"):
			var state: Dictionary = plot_view.collect_state()
			GameState.set_plot_state(cache_key, state)
			print("ViewTransition: cached state for plot %s (%d buildings)" % [
				cache_key, state.get("buildings", []).size()])

	if plot_view:
		plot_view.queue_free()
		plot_view = null

	active_plot_info = null

	# Restore planet view
	if planet_view:
		planet_view.visible = true
		# Re-activate planet camera
		var pcam: Camera3D = planet_view.get_node_or_null("CameraRig/PlanetCamera")
		if pcam:
			pcam.current = true
		# Reset camera to initial position
		if planet_view.has_method("_position_camera"):
			planet_view._position_camera()
			planet_view._apply_zoom()

	set_environment(planet_env)

	await _fade_in()
	transitioning = false


# ---------------------------------------------------
# INTERNALS
# ---------------------------------------------------

func _load_system_view() -> void:
	# Disable map
	if map_camera:
		map_camera.current = false
	if map_view:
		map_view.visible = false
	
	# Load system
	system_view = SYSTEM_SCENE.instantiate()
	get_tree().root.add_child(system_view)

	# Inject StarData
	system_view.setup_from_star(active_star)

	# Cache camera
	system_camera = system_view.get_node("orbital camera")
	if system_camera:
		system_camera.current = true


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


# ---------------------------------------------------
# Loading screen
# ---------------------------------------------------
func _create_loading_screen() -> void:
	loading_layer = CanvasLayer.new()
	loading_layer.layer = 99  # Below fade (100)
	loading_layer.visible = false
	get_tree().root.call_deferred("add_child", loading_layer)

	# Dark background that fills the viewport
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.1, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_layer.add_child(bg)
	bg.call_deferred("set_anchors_and_offsets_preset", Control.PRESET_FULL_RECT)

	# Centre container
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_layer.add_child(center)
	center.call_deferred("set_anchors_and_offsets_preset", Control.PRESET_FULL_RECT)

	# Vertical box
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	# Title label
	loading_label = Label.new()
	loading_label.text = "Generating Terrain…"
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 28)
	loading_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	vbox.add_child(loading_label)

	# Progress bar
	loading_bar = ProgressBar.new()
	loading_bar.min_value = 0.0
	loading_bar.max_value = 1.0
	loading_bar.value = 0.0
	loading_bar.show_percentage = false
	loading_bar.custom_minimum_size = Vector2(400, 24)

	# Style the bar fill
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.6, 1.0)
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	loading_bar.add_theme_stylebox_override("fill", fill_style)

	# Style the bar background
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.2)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	loading_bar.add_theme_stylebox_override("background", bg_style)

	vbox.add_child(loading_bar)

	# Stage label
	loading_stage = Label.new()
	loading_stage.text = ""
	loading_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_stage.add_theme_font_size_override("font_size", 16)
	loading_stage.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	vbox.add_child(loading_stage)

func _show_loading_screen(archetype: String) -> void:
	if loading_layer == null:
		return
	loading_label.text = "Generating %s…" % archetype if archetype != "" else "Generating Terrain…"
	loading_stage.text = "Initializing…"
	loading_bar.value = 0.0
	loading_layer.visible = true

func _hide_loading_screen() -> void:
	if loading_layer == null:
		return
	loading_layer.visible = false

func _on_terrain_progress(percent: float, stage: String) -> void:
	if loading_bar:
		loading_bar.value = percent
	if loading_stage:
		loading_stage.text = stage

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
