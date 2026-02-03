extends Node3D

## Example script showing how to query the buildability layer from gameplay code.
##
## This demonstrates the grid-based building placement system:
## - Query individual tiles before placing buildings
## - Respect terrain constraints (slopes, cliffs)
## - Provide clear feedback to players

# Reference to the terrain integrator (set in _ready or via export)
@export var terrain_integrator: Node3D

func _ready() -> void:
	# Find terrain integrator if not set
	if not terrain_integrator:
		terrain_integrator = get_tree().root.find_child("HTerrainPlotIntegrator", true, false)
	
	if not terrain_integrator:
		push_error("Could not find HTerrainPlotIntegrator in scene")
		return
	
	# Wait a frame for terrain to generate
	await get_tree().process_frame
	
	# Run example queries
	_test_buildability_queries()


func _test_buildability_queries() -> void:
	"""Example usage of buildability API."""
	if not terrain_integrator:
		return
	
	print("\n=== Buildability Test Queries ===")
	
	# Query a few random tiles
	var test_tiles = [
		Vector2i(5, 5),   # Center-left area
		Vector2i(8, 8),   # Center
		Vector2i(12, 12), # Outer area
		Vector2i(2, 2),   # Edge
	]
	
	for tile in test_tiles:
		var slope = terrain_integrator.get_tile_slope(tile.x, tile.y)
		var status = terrain_integrator.get_buildability_status(tile.x, tile.y)
		var is_buildable = terrain_integrator.is_tile_buildable(tile.x, tile.y)
		var is_conditional = terrain_integrator.is_tile_conditionally_buildable(tile.x, tile.y)
		
		print("Tile (%d, %d): slope=%.2f° | status=%s | buildable=%s | conditional=%s" % [
			tile.x, tile.y, slope, status, is_buildable, is_conditional
		])
	
	print("=================================\n")


func can_place_building(tile_x: int, tile_z: int, building_size: Vector2i) -> bool:
	"""Check if a building of given size can be placed at tile position.
	
	Args:
		tile_x: Top-left tile X coordinate
		tile_z: Top-left tile Z coordinate
		building_size: Building size in tiles (e.g. Vector2i(3, 3) for 3x3)
	
	Returns:
		true if all tiles under the building footprint are buildable
	"""
	if not terrain_integrator:
		return false
	
	# Check all tiles in building footprint
	for z in range(building_size.y):
		for x in range(building_size.x):
			var check_x = tile_x + x
			var check_z = tile_z + z
			
			if not terrain_integrator.is_tile_buildable(check_x, check_z):
				return false
	
	return true


func can_place_road(tile_x: int, tile_z: int) -> bool:
	"""Check if a road can be placed on a tile.
	
	Roads can be placed on conditionally buildable tiles (gentle slopes).
	"""
	if not terrain_integrator:
		return false
	
	return terrain_integrator.is_tile_conditionally_buildable(tile_x, tile_z)


func get_placement_feedback(tile_x: int, tile_z: int, building_size: Vector2i) -> String:
	"""Get human-readable feedback for building placement attempt.
	
	Returns a string explaining why placement failed, or "OK" if allowed.
	"""
	if not terrain_integrator:
		return "Terrain system not initialized"
	
	# Check each tile and collect issues
	var blocked_tiles = []
	var steep_tiles = []
	
	for z in range(building_size.y):
		for x in range(building_size.x):
			var check_x = tile_x + x
			var check_z = tile_z + z
			
			var status = terrain_integrator.get_buildability_status(check_x, check_z)
			
			if status == "invalid":
				return "Out of bounds"
			elif status == "blocked":
				blocked_tiles.append(Vector2i(check_x, check_z))
			elif status == "conditional":
				steep_tiles.append(Vector2i(check_x, check_z))
	
	if blocked_tiles.size() > 0:
		return "Terrain too steep (cliffs/mountains)"
	elif steep_tiles.size() > 0:
		return "Slope too steep for this building type"
	else:
		return "OK"


func _input(event: InputEvent) -> void:
	"""Example: Query tile under mouse cursor."""
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		# This is just an example - you'd normally raycast to find the tile
		var sample_tile = Vector2i(8, 8)
		
		print("\nQuerying tile (%d, %d):" % [sample_tile.x, sample_tile.y])
		
		var slope = terrain_integrator.get_tile_slope(sample_tile.x, sample_tile.y)
		print("  Slope: %.2f°" % slope)
		
		var can_build_house = can_place_building(sample_tile.x, sample_tile.y, Vector2i(2, 2))
		print("  Can place 2x2 house: %s" % can_build_house)
		
		var can_build_farm = can_place_building(sample_tile.x, sample_tile.y, Vector2i(4, 4))
		print("  Can place 4x4 farm: %s" % can_build_farm)
		
		var can_build_road_here = can_place_road(sample_tile.x, sample_tile.y)
		print("  Can place road: %s" % can_build_road_here)
		
		var feedback = get_placement_feedback(sample_tile.x, sample_tile.y, Vector2i(3, 3))
		print("  Placement feedback (3x3): %s" % feedback)
