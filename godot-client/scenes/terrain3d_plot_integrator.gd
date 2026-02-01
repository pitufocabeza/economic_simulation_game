extends Node3D

################################################################################
# TERRAIN3D PLOT INTEGRATOR (FIXED FOR REGION-BASED API)
################################################################################

var plot_generator: Node3D
var terrain3d: Node3D

var VERTICAL_SCALE: float = 50.0  # Increased from 8.0 for better visibility
var TERRAIN_SIZE: int = 16


func _ready() -> void:
	_setup_references()


################################################################################
# PUBLIC API
################################################################################

func generate_and_apply(seed: int) -> Dictionary:
	if not plot_generator:
		push_error("Plot generator not found")
		return {}

	if not terrain3d or not terrain3d.data:
		push_error("Terrain3D or Terrain3DData not available")
		return {}

	var plot_data: Dictionary = plot_generator.generate_plot(seed)

	var archetype: String = plot_data["archetype"]
	var height_map: Array = plot_data["height_map"]
	var buildable_map: Array = plot_data["buildable_map"]

	print("🌿 Applying archetype:", archetype)

	_apply_height_map(height_map)

	return {
		"archetype": archetype,
		"height_map": height_map,
		"buildable_map": buildable_map,
		"success": true,
	}


################################################################################
# TERRAIN APPLICATION (CORRECT)
################################################################################

func _apply_height_map(height_map: Array) -> void:
	if not terrain3d or not terrain3d.data:
		push_error("No terrain data available")
		return
	
	var size: int = height_map.size()
	var target_size: int = 64
	
	# Check all regions to see what exists
	var region_pos = Vector2i.ZERO
	var region = null
	
	# Try common region positions
	for test_pos in [Vector2i.ZERO, Vector2i(-1, -1), Vector2i(1, 1)]:
		region = terrain3d.data.get_region(test_pos)
		if region:
			region_pos = test_pos
			break
	
	if not region:
		print("No region found!")
		return
	
	print("✓ Found region at", region_pos)
	
	# Upscale heightmap
	var scaled_map = _upscale_heightmap(height_map, target_size)
	
	# Write heights using set_height
	print("Writing %d x %d heightmap..." % [target_size, target_size])
	var heights_written: int = 0
	
	for z in range(target_size):
		for x in range(target_size):
			var h_norm: float = scaled_map[z][x]
			var h_world: float = h_norm * VERTICAL_SCALE
			var world_x = float(x) + (region_pos.x * target_size)
			var world_z = float(z) + (region_pos.y * target_size)
			var pos := Vector3(world_x, h_world, world_z)
			terrain3d.data.set_height(pos, h_world)
			heights_written += 1
	
	print("✓ Wrote %d heights to region at %s" % [heights_written, region_pos])
	
	# Force save the region
	if region.has_method("save"):
		region.save()
		print("✓ Saved region")
	
	# Update terrain mesh
	if terrain3d.has_method("update_aabbs"):
		terrain3d.update_aabbs()
	
	# Notify that region changed
	var aabb = AABB(Vector3(region_pos.x * target_size, -100, region_pos.y * target_size), Vector3(target_size, 200, target_size))
	if terrain3d.data.has_method("notify_region_changed"):
		terrain3d.data.notify_region_changed(aabb)
		print("✓ Notified region changed")
	
	print("Camera should look at approximately (%.0f, y, %.0f)" % [region_pos.x * target_size + target_size * 0.5, region_pos.y * target_size + target_size * 0.5])

func _upscale_heightmap(height_map: Array, target_size: int) -> Array:
	var source_size: int = height_map.size()
	var scale: float = float(source_size) / float(target_size)
	var scaled = []
	
	for z in range(target_size):
		var row = []
		for x in range(target_size):
			# Simple nearest-neighbor upscaling
			var src_x: int = int(float(x) * scale)
			var src_z: int = int(float(z) * scale)
			src_x = clampi(src_x, 0, source_size - 1)
			src_z = clampi(src_z, 0, source_size - 1)
			row.append(height_map[src_z][src_x])
		scaled.append(row)
	
	return scaled


################################################################################
# REFERENCE SETUP
################################################################################

func _setup_references() -> void:
	if not plot_generator:
		plot_generator = _find_node_by_script("temperate_map_generator")

	if not terrain3d:
		terrain3d = _find_node_by_class("Terrain3D")

	if plot_generator:
		print("✓ Plot generator found:", plot_generator.name)

	if terrain3d:
		print("✓ Terrain3D found:", terrain3d.name)


func _find_node_by_script(script_name: String) -> Node3D:
	var parent := get_parent()
	if parent:
		for child in parent.get_children():
			if child.get_script() and child.get_script().resource_path.contains(script_name):
				return child as Node3D

	for child in get_children():
		if child.get_script() and child.get_script().resource_path.contains(script_name):
			return child as Node3D

	return null


func _find_node_by_class(type_name: String) -> Node3D:
	for child in get_children():
		if child.is_class(type_name):
			return child as Node3D
	return null
