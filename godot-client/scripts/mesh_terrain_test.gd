extends Node2D

@onready var generator = $MeshLocation

var current_location_id = 1
var all_planets = []  # List of all planet IDs
var current_planet_index = 0
@export var api_base_url: String = "http://localhost:8000"

func _ready():
	print("Mesh Terrain Test Scene Ready")
	await get_tree().process_frame
	fetch_all_planets()
	load_location(current_location_id)

func load_location(location_id: int):
	current_location_id = location_id
	print("Loading location ID: ", location_id)
	generator.load_location(location_id)

func fetch_all_planets():
	var url = api_base_url + "/tilemap/planets"
	print("Fetching all planets from: ", url)

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_planets_received)

	var error = http.request(url)
	if error != OK:
		print("Failed to fetch planets: HTTP request error")

func _on_planets_received(result, response_code, headers, body):
	if response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())
		if parse_result == OK:
			var data = json.data
			var planets = data.get("planets", [])
			
			# Store planets and find current planet
			all_planets = planets
			print("Loaded ", all_planets.size(), " planets with locations")
			
			# Find which planet we're currently on
			for i in range(all_planets.size()):
				if all_planets[i].get("first_location_id") == current_location_id:
					current_planet_index = i
					break
	else:
		print("Failed to fetch planets: ", response_code)

func load_planet_by_index(index: int):
	if all_planets.size() == 0:
		print("No planets loaded yet")
		return
	
	# Wrap around
	current_planet_index = index % all_planets.size()
	if current_planet_index < 0:
		current_planet_index = all_planets.size() + current_planet_index
	
	var planet = all_planets[current_planet_index]
	var first_location = planet.get("first_location_id", 1)
	print("Loading planet: ", planet.get("planet_name"), " (location ", first_location, ")")
	load_location(first_location)

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_PAGEUP:
				# Next planet
				load_planet_by_index(current_planet_index + 1)
			
			KEY_PAGEDOWN:
				# Previous planet
				load_planet_by_index(current_planet_index - 1)
			
			KEY_TAB:
				# Next/Previous location (fine-grained within same planet)
				if event.shift_pressed:
					# Shift+Tab = Previous location
					current_location_id = max(1, current_location_id - 1)
				else:
					# Tab = Next location
					current_location_id += 1
				load_location(current_location_id)
			
			KEY_BRACKETLEFT:  # [ key
				# Previous location
				current_location_id = max(1, current_location_id - 1)
				load_location(current_location_id)
			
			KEY_BRACKETRIGHT:  # ] key
				# Next location
				current_location_id += 1
				load_location(current_location_id)
			
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				# Quick jump to planet by index
				var planet_index = event.keycode - KEY_1
				load_planet_by_index(planet_index)
