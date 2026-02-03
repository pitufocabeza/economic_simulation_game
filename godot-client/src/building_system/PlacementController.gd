extends Node3D

@export var hterrain_path: NodePath
@export var buildings_root_path: NodePath

@export var build_menu: NodePath
@onready var _build_menu: BuildMenu = get_node(build_menu)

@export var tile_size: float = 8.0
@export var grid_origin: Vector3 = Vector3.ZERO
@export var buildability_source_path: NodePath
@export var water_level_buffer: float = 0.1
@export var terrain_origin_is_centered: bool = true
@export var terrain_collision_mask: int = 1
@export var enable_raycast_debug: bool = false
@export var terrain_node_name: StringName = &"HTerrain"
@export var ray_length: float = 5000.0

var hterrain: Node3D
var buildings_root: Node3D
var buildability_source: Node = null
var _terrain_size: float = 0.0
var _gameplay_grid_size: int = 0
var _terrain_world_size: float = 0.0
var _raycast_exclude: Array = []
var _water_nodes: Array = []

var placing: bool = false
var current_definition: BuildingDefinition = null
var ghost_instance: Node3D = null
var current_rotation: int = 0 # 0..3 (90° steps)

# Tile occupancy map: Vector2i -> bool
var occupied_tiles: Dictionary = {}


# -------------------------------------------------
# LIFECYCLE
# -------------------------------------------------
func _ready():
	hterrain = get_node_or_null(hterrain_path)
	buildings_root = get_node_or_null(buildings_root_path)
	if buildability_source_path != NodePath(""):
		buildability_source = get_node_or_null(buildability_source_path)

	_sync_grid_from_buildability()
	_sync_grid_origin_from_terrain()
	_collect_raycast_excludes()

	_build_menu.building_selected.connect(_on_building_selected)

func _collect_raycast_excludes():
	_raycast_exclude.clear()
	_water_nodes.clear()
	for name in ["WaterShallow", "WaterBase", "WaterDeep"]:
		var n := get_tree().get_root().find_child(name, true, false)
		if n:
			_water_nodes.append(n)
			if n is CollisionObject3D:
				_raycast_exclude.append(n.get_rid())
	if ghost_instance and ghost_instance is CollisionObject3D:
		_raycast_exclude.append(ghost_instance.get_rid())

func _sync_grid_from_buildability():
	if buildability_source and buildability_source.has_method("get"):
		var ts = buildability_source.get("TERRAIN_SIZE")
		var world_size = buildability_source.get("SLOPE_WORLD_SIZE")
		if typeof(world_size) == TYPE_FLOAT and world_size > 0.0:
			_terrain_world_size = world_size
			if tile_size > 0.0:
				_gameplay_grid_size = int(floor(_terrain_world_size / tile_size))
			if enable_raycast_debug:
				print("Buildability sync: world_size=", _terrain_world_size, " tile_size=", tile_size, " grid_size=", _gameplay_grid_size)
		elif typeof(ts) == TYPE_INT or typeof(ts) == TYPE_FLOAT:
			_terrain_size = float(ts)
			_update_world_sizes()
			if tile_size > 0.0 and _terrain_world_size > 0.0:
				_gameplay_grid_size = int(floor(_terrain_world_size / tile_size))
			if enable_raycast_debug:
				print("Terrain size: ", _terrain_size)
				print("Terrain world size: ", _terrain_world_size)
				print("Calculated tile_size: ", tile_size)

func _update_world_sizes():
	var scale_x := 1.0
	if hterrain and hterrain.has_method("get"):
		var map_scale = hterrain.get("map_scale")
		if typeof(map_scale) == TYPE_VECTOR3:
			scale_x = map_scale.x
	if _terrain_size > 1.0:
		_terrain_world_size = (_terrain_size - 1.0) * scale_x
	else:
		_terrain_world_size = _terrain_size * scale_x

func _sync_grid_origin_from_terrain():
	if hterrain:
		_update_world_sizes()
		grid_origin = hterrain.global_position
		var centered := terrain_origin_is_centered
		if hterrain.has_method("get"):
			var c = hterrain.get("centered")
			if typeof(c) == TYPE_BOOL:
				centered = c
		if centered and _terrain_world_size > 0.0:
			grid_origin -= Vector3(_terrain_world_size * 0.5, 0.0, _terrain_world_size * 0.5)


# -------------------------------------------------
# PUBLIC API
# -------------------------------------------------
func start_placement(definition: BuildingDefinition):
	placing = true
	current_definition = definition
	current_rotation = 0
	_spawn_ghost()

func _on_building_selected(definition: BuildingDefinition):
	print("PlacementController: building selected ", definition.name)
	start_placement(definition)

# -------------------------------------------------
# MAIN LOOP
# -------------------------------------------------
func _process(_delta):
	if not placing or ghost_instance == null:
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var hit: Variant = get_mouse_world_hit(camera)
	if hit == null:
		return
	var world_pos: Vector3 = hit.position

	var tile_coords := Vector2i(
		floor((world_pos.x - grid_origin.x) / tile_size),
		floor((world_pos.z - grid_origin.z) / tile_size)
	)

	var snap_result := _validate_and_snap(tile_coords)
	var valid: bool = snap_result[0]
	var snap_pos: Vector3 = snap_result[1]
	if enable_raycast_debug:
		print("Mouse tile coords: ", tile_coords, " | World pos: ", snap_pos, " | Tile size: ", tile_size)

	ghost_instance.global_position = snap_pos
	ghost_instance.rotation.y = current_rotation * PI * 0.5
	_set_ghost_color(valid)

	# --- Input ---
	if Input.is_action_just_pressed("rotate_left"):
		current_rotation = (current_rotation + 3) % 4

	if Input.is_action_just_pressed("rotate_right"):
		current_rotation = (current_rotation + 1) % 4

	if Input.is_action_just_pressed("ui_cancel") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_cancel_placement()

	if (Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and valid:
		_place_building(tile_coords, snap_pos)


# -------------------------------------------------
# CORE LOGIC
# -------------------------------------------------
func _validate_and_snap(tile_coords: Vector2i) -> Array:
	var fp := current_definition.footprint
	var rot_fp := fp if current_rotation % 2 == 0 else Vector2i(fp.y, fp.x)

	# Bottom-left anchor placement
	var base_x := grid_origin.x + tile_coords.x * tile_size
	var base_z := grid_origin.z + tile_coords.y * tile_size
	var height := _get_height(base_x, base_z)
	var snap_pos := Vector3(base_x, height, base_z)

	print("=== VALIDATE_AND_SNAP DEBUG ===")
	print("Tile coords: ", tile_coords)
	print("Grid origin: ", grid_origin)
	print("Tile size: ", tile_size)
	print("Base world pos: (", base_x, ", ", base_z, ")")
	print("Footprint: ", rot_fp)
	print("Gameplay grid size: ", _gameplay_grid_size)
	print("Terrain world size: ", _terrain_world_size)

	# Bounds check
	if tile_coords.x < 0 or tile_coords.y < 0:
		print("FAIL: negative tile coords")
		return [false, snap_pos]
	
	if (tile_coords.x * tile_size) >= _terrain_world_size or (tile_coords.y * tile_size) >= _terrain_world_size:
		print("FAIL: exceeds world size. x*size=", tile_coords.x * tile_size, " >= ", _terrain_world_size)
		return [false, snap_pos]

	# Occupancy check
	for x in range(rot_fp.x):
		for z in range(rot_fp.y):
			var check_tile = tile_coords + Vector2i(x, z)
			if occupied_tiles.has(check_tile):
				print("FAIL: occupied at ", check_tile)
				return [false, snap_pos]
			if buildability_source and buildability_source.has_method("is_tile_buildable"):
				var tx = tile_coords.x + x
				var tz = tile_coords.y + z
				# Convert from building tile coords to plot coords
				# 128 building tiles / 16 plots = 8 building tiles per plot
				var plot_grid_res = buildability_source.GRID_RESOLUTION if "GRID_RESOLUTION" in buildability_source else 16
				if typeof(plot_grid_res) != TYPE_INT or plot_grid_res <= 0:
					print("FAIL: invalid GRID_RESOLUTION: ", plot_grid_res)
					return [false, snap_pos]

				var tiles_per_plot = _gameplay_grid_size / plot_grid_res
				if tiles_per_plot <= 0:
					print("FAIL: invalid tiles_per_plot. gameplay_grid=", _gameplay_grid_size, " plot_grid=", plot_grid_res)
					return [false, snap_pos]

				var plot_x = tx / tiles_per_plot
				var plot_z = tz / tiles_per_plot

				print("Building tile (", tx, ",", tz, ") -> plot (", plot_x, ",", plot_z, ") tiles_per_plot=", tiles_per_plot)

				if not buildability_source.is_tile_buildable(plot_x, plot_z):
					print("FAIL: not buildable at plot ", plot_x, ",", plot_z)
					return [false, snap_pos]

	if _is_underwater(height):
		print("FAIL: underwater (height=", height, ")")
		return [false, snap_pos]
	
	print("PASS: placement valid")
	return [true, snap_pos]


func _place_building(tile_coords: Vector2i, world_pos: Vector3):
	var inst := current_definition.scene.instantiate() as Node3D
	buildings_root.add_child(inst)
	inst.global_position = world_pos
	inst.rotation.y = current_rotation * PI * 0.5

	var fp := current_definition.footprint
	var rot_fp := fp if current_rotation % 2 == 0 else Vector2i(fp.y, fp.x)

	for x in range(rot_fp.x):
		for z in range(rot_fp.y):
			occupied_tiles[tile_coords + Vector2i(x, z)] = true

	_cancel_placement()


# -------------------------------------------------
# GHOST HANDLING
# -------------------------------------------------
func _spawn_ghost():
	if ghost_instance:
		ghost_instance.queue_free()

	ghost_instance = current_definition.scene.instantiate()
	add_child(ghost_instance)
	_disable_ghost_collision()
	_collect_raycast_excludes()
	_set_ghost_color(true)

func _disable_ghost_collision():
	if not ghost_instance:
		return
	for co in ghost_instance.find_children("*", "CollisionObject3D", true, false):
		co.collision_layer = 0
		co.collision_mask = 0
	for cs in ghost_instance.find_children("*", "CollisionShape3D", true, false):
		cs.disabled = true


func _set_ghost_color(valid: bool):
	if not ghost_instance:
		return

	var color := Color(0.2, 1.0, 0.2, 0.5) if valid else Color(1.0, 0.2, 0.2, 0.5)

	for mi in ghost_instance.find_children("*", "GeometryInstance3D", true, false):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _cancel_placement():
	placing = false
	current_definition = null

	if ghost_instance:
		ghost_instance.queue_free()
		ghost_instance = null


# -------------------------------------------------
# HTERRAIN HEIGHT SAMPLING
# -------------------------------------------------
func _get_height(x: float, z: float) -> float:
	if not hterrain:
		return 0.0
	if not hterrain.has_method("get_data"):
		return 0.0
	var hterrain_data = hterrain.get_data()
	if not hterrain_data:
		return 0.0
	var local_x = x - hterrain.global_position.x
	var local_z = z - hterrain.global_position.z
	var map_scale = hterrain.get("map_scale") if hterrain.has_method("get") else null
	var vertical_scale = map_scale.y if typeof(map_scale) == TYPE_VECTOR3 else 1.0
	return hterrain_data.get_height_at(local_x, local_z) * vertical_scale + hterrain.global_position.y

func get_mouse_world_hit(camera: Camera3D) -> Variant:
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + ray_dir * ray_length
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = terrain_collision_mask
	query.exclude = _raycast_exclude

	var result := space_state.intersect_ray(query)
	if result.is_empty():
		if enable_raycast_debug:
			print("PlacementController: raycast hit nothing")
		return null
	var collider = result.get("collider", null)
	if not _is_terrain_collider(collider):
		if enable_raycast_debug:
			var bad_name = collider.name if collider and collider is Node else "(unknown)"
			print("PlacementController: hit non-terrain ", bad_name)
		return null
	if enable_raycast_debug:
		var name = collider.name if collider and collider is Node else "(unknown)"
		print("PlacementController: raycast hit ", name)
	return result

func _is_terrain_collider(collider: Object) -> bool:
	if collider == null:
		return false
	if collider is Node:
		var n: Node = collider
		while n:
			if n.name == terrain_node_name:
				return true
			n = n.get_parent()
	return false

func _is_underwater(height: float) -> bool:
	if buildability_source and buildability_source.has_method("get"):
		var water_level = buildability_source.get("current_water_level")
		if typeof(water_level) == TYPE_FLOAT:
			return height <= water_level + water_level_buffer
	return false
