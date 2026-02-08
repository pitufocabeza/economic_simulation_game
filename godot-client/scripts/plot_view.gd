extends Node3D

## Root script for the plot view scene.
## Handles returning to planet view on Escape and plot-state persistence.

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		ViewTransition.exit_plot()


# ── State persistence ───────────────────────────────────────────────

## Collect all placed buildings + occupancy so they can be cached in GameState.
func collect_state() -> Dictionary:
	var state: Dictionary = { "buildings": [], "occupied_tiles": {} }

	# Gather placed buildings from Buildings node
	var buildings_root: Node3D = get_node_or_null("Buildings")
	var placement: Node = get_node_or_null("PlacementController")

	if buildings_root:
		for child: Node in buildings_root.get_children():
			if child is Node3D:
				var entry: Dictionary = {
					"scene_path": child.scene_file_path,
					"position": child.global_position,
					"rotation_y": child.rotation.y,
				}
				state["buildings"].append(entry)

	# Gather occupancy grid
	if placement and "occupied_tiles" in placement:
		# Convert Vector2i keys to string keys for serialization safety
		for tile_key: Vector2i in placement.occupied_tiles:
			state["occupied_tiles"][var_to_str(tile_key)] = true

	state["visited"] = true
	return state


## Restore previously saved buildings after terrain is ready.
func restore_state(state: Dictionary) -> void:
	if state.is_empty():
		return

	var buildings_root: Node3D = get_node_or_null("Buildings")
	var placement: Node = get_node_or_null("PlacementController")

	# Restore placed buildings
	var building_list: Array = state.get("buildings", [])
	for entry: Dictionary in building_list:
		var scene_path: String = entry.get("scene_path", "")
		if scene_path.is_empty():
			continue
		if not ResourceLoader.exists(scene_path):
			push_warning("PlotView: cached building scene not found: %s" % scene_path)
			continue

		var scene: PackedScene = load(scene_path) as PackedScene
		if scene == null:
			continue

		var inst: Node3D = scene.instantiate() as Node3D
		if buildings_root:
			buildings_root.add_child(inst)
		inst.global_position = entry.get("position", Vector3.ZERO)
		inst.rotation.y = entry.get("rotation_y", 0.0)

	# Restore occupancy grid
	if placement and "occupied_tiles" in placement:
		var cached_tiles: Dictionary = state.get("occupied_tiles", {})
		for key_str: String in cached_tiles:
			var tile: Vector2i = str_to_var(key_str) as Vector2i
			placement.occupied_tiles[tile] = true

	print("PlotView: restored %d buildings from cache" % building_list.size())
