extends Node3D

## Example usage of the calm water system
##
## Shows how to query water level and check if positions are underwater

@export var terrain_integrator: Node3D

func _ready() -> void:
	# Find terrain integrator
	if not terrain_integrator:
		terrain_integrator = get_tree().root.find_child("HTerrainPlotIntegrator", true, false)
	
	if not terrain_integrator:
		push_error("Could not find HTerrainPlotIntegrator")
		return
	
	# Wait for terrain to generate
	await get_tree().create_timer(1.0).timeout
	
	_test_water_queries()


func _test_water_queries() -> void:
	"""Example water system queries."""
	if not terrain_integrator:
		return
	
	print("\n=== Water System Test ===")
	print("Current water level: %.2f" % terrain_integrator.current_water_level)
	
	# Test some positions
	var test_positions = [
		Vector3(512, 0, 512),    # Very low (underwater)
		Vector3(512, 50, 512),   # At water level
		Vector3(512, 100, 512),  # Above water
		Vector3(512, 200, 512),  # High ground
	]
	
	for pos in test_positions:
		var is_underwater = terrain_integrator.is_position_underwater(pos)
		var depth = terrain_integrator.get_water_depth_at_position(pos)
		
		print("Position Y=%.0f: underwater=%s, depth=%.2f" % [pos.y, is_underwater, depth])
	
	print("=========================\n")


func _input(event: InputEvent) -> void:
	"""Example: Change water level with keyboard."""
	if not terrain_integrator:
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				# Raise water level
				var new_level = terrain_integrator.current_water_level + 5.0
				terrain_integrator.update_water_level(new_level)
			
			KEY_DOWN:
				# Lower water level
				var new_level = terrain_integrator.current_water_level - 5.0
				terrain_integrator.update_water_level(new_level)


# Example: Check if a building location is safe from water
func is_building_location_dry(tile_x: int, tile_z: int, terrain_size: int) -> bool:
	"""Check if a gameplay tile is above water level."""
	if not terrain_integrator:
		return false
	
	# Convert tile coordinates to world position
	var tile_size = float(terrain_size) / 16.0  # Assuming 16x16 gameplay grid
	var world_x = tile_x * tile_size
	var world_z = tile_z * tile_size
	
	# Sample terrain height at this position (would need HTerrain API in real code)
	# For now, just check if ground level is above water
	var estimated_ground_height = terrain_integrator.current_water_level + 10.0  # Placeholder
	
	var ground_pos = Vector3(world_x, estimated_ground_height, world_z)
	return not terrain_integrator.is_position_underwater(ground_pos)
