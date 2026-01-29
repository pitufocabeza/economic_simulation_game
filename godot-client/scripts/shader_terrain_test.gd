extends Node2D

# Test script for shader-based terrain
@onready var generator = $ShaderLocation

func _ready():
	print("Shader Terrain Test Scene Ready")
	
	await get_tree().process_frame
	
	# Load location ID 1 by default
	var test_location_id = 1
	generator.load_location(test_location_id)

func _input(event):
	# Press 1-9 to load different test locations
	if event is InputEventKey and event.pressed:
		var location_id = -1
		match event.keycode:
			KEY_1:
				location_id = 1
			KEY_2:
				location_id = 2
			KEY_3:
				location_id = 3
			KEY_4:
				location_id = 4
			KEY_5:
				location_id = 5
			KEY_6:
				location_id = 6
			KEY_7:
				location_id = 7
			KEY_8:
				location_id = 8
			KEY_9:
				location_id = 9
		
		if location_id > 0:
			print("Loading location ID: ", location_id)
			generator.load_location(location_id)
