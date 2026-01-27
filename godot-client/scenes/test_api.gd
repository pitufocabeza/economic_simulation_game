extends Node2D

func _ready():
	print("=== Testing API Connection ===")
	
	# Test 1: Fetch a location
	print("Fetching location ID 1...")
	var location = await API.get_location(1)
	
	if location:
		print("✓ Location found: ", location.name)
		print("  Planet: ", location.planet_id)
		print("  Grid size: ", location.grid_width, "x", location.grid_height)
		print("  Tilemap seed: ", location.tilemap_seed)
	else:
		print("✗ Failed to fetch location")
	
	print("=== Test Complete ===")
