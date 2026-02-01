extends Node2D

var tiles_dir = "res://assets/tilesets/isometric/temperate/"
var tiles = {}
var grid_width = 16
var grid_height = 16
var tile_scale = 0.25
var camera: Camera2D
var camera_speed = 2000.0
var zoom_speed = 0.1

func _ready():
	print("=== Isometric Flat Map Generator ===")
	
	# Create camera
	camera = Camera2D.new()
	camera.zoom = Vector2(1.5, 1.5)
	add_child(camera)
	
	load_tiles()
	generate_flat_map()
	
	print("Controls: WASD/Arrows=Move, MouseWheel/PageUp/PageDown=Zoom, R=Regenerate, ESC=Quit")

func load_tiles():
	"""Load tile images"""
	var dir = DirAccess.open(tiles_dir)
	if dir == null:
		print("ERROR: Could not open directory")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".png"):
			var image = Image.new()
			image.load(tiles_dir + file_name)
			
			# Scale down
			var w = int(image.get_width() * tile_scale)
			var h = int(image.get_height() * tile_scale)
			image.resize(w, h)
			
			var texture = ImageTexture.create_from_image(image)
			tiles[file_name.trim_suffix(".png")] = {
				"texture": texture,
				"width": w,
				"height": h
			}
			print("Loaded: ", file_name)
		file_name = dir.get_next()

func generate_flat_map():
	"""Generate map by manually positioning tiles with weighted distribution"""
	print("Generating flat map...")
	
	var tile_names = tiles.keys()
	if tile_names.is_empty():
		print("ERROR: No tiles loaded!")
		return
	
	# Categorize tiles by type
	var base_tiles = []
	var obstacle_tiles = []
	var iron_tiles = []
	var copper_tiles = []
	var titanium_tiles = []
	
	for tile_name in tile_names:
		if "base" in tile_name:
			base_tiles.append(tile_name)
		elif "obstacle" in tile_name:
			obstacle_tiles.append(tile_name)
		elif "iron" in tile_name:
			iron_tiles.append(tile_name)
		elif "copper" in tile_name:
			copper_tiles.append(tile_name)
		elif "titanium" in tile_name:
			titanium_tiles.append(tile_name)
	
	print("Tile distribution: base=%d, obstacle=%d, iron=%d, copper=%d, titanium=%d" % [
		base_tiles.size(), obstacle_tiles.size(), iron_tiles.size(), 
		copper_tiles.size(), titanium_tiles.size()
	])
	
	# Get tile dimensions for positioning
	var first_tile = tiles[tile_names[0]]
	var tile_width = first_tile["width"]
	var tile_height = first_tile["height"]
	
	print("Tile size: %dx%d" % [tile_width, tile_height])
	print("Grid: %dx%d" % [grid_width, grid_height])
	
	# Store placed tiles to check for same obstacles adjacent
	var placed_grid = []
	for y in range(grid_height):
		placed_grid.append([])
		for x in range(grid_width):
			placed_grid[y].append("")
	
	for y in range(grid_height):
		for x in range(grid_width):
			# Staggered grid with tiles fitting like puzzle pieces
			var screen_x = x * tile_width * 0.860
			if y % 2 == 1:
				screen_x += tile_width * 0.375
			var screen_y = y * tile_height * 0.180
			
			# Pick tile with weighted distribution
			var tile_name = pick_weighted_tile(base_tiles, obstacle_tiles, iron_tiles, copper_tiles, titanium_tiles, placed_grid, x, y, obstacle_tiles)
			placed_grid[y][x] = tile_name
			
			var tile_data = tiles[tile_name]
			
			# Create sprite
			var sprite = Sprite2D.new()
			sprite.texture = tile_data["texture"]
			sprite.position = Vector2(screen_x, screen_y)
			sprite.centered = true
			add_child(sprite)
	
	print("Map generated with %d tiles" % (grid_width * grid_height))

func pick_weighted_tile(base: Array, obstacle: Array, iron: Array, copper: Array, titanium: Array, placed_grid: Array, x: int, y: int, obstacle_tiles: Array) -> String:
	"""Pick a tile based on weighted probability distribution"""
	var roll = randf() * 100.0
	
	# Weights: base 55%, obstacle 25%, iron 10%, copper 7%, titanium 3%
	if roll < 55 and base.size() > 0:
		return base[randi() % base.size()]
	elif roll < 80 and obstacle.size() > 0:
		# For obstacles, make sure not same as adjacent tiles
		return pick_unique_obstacle(obstacle, placed_grid, x, y)
	elif roll < 90 and iron.size() > 0:
		return iron[randi() % iron.size()]
	elif roll < 97 and copper.size() > 0:
		return copper[randi() % copper.size()]
	elif titanium.size() > 0:
		return titanium[randi() % titanium.size()]
	else:
		# Fallback if category is empty
		return base[randi() % base.size()] if base.size() > 0 else "unknown"

func pick_unique_obstacle(obstacle_tiles: Array, placed_grid: Array, x: int, y: int) -> String:
	"""Pick an obstacle tile that's different from adjacent obstacles"""
	var adjacent_obstacles = get_adjacent_obstacles(placed_grid, x, y)
	var available = obstacle_tiles.filter(func(t): return t not in adjacent_obstacles)
	
	if available.size() > 0:
		return available[randi() % available.size()]
	else:
		# If all adjacent tiles have all obstacle types, just pick random
		return obstacle_tiles[randi() % obstacle_tiles.size()]

func get_adjacent_obstacles(placed_grid: Array, x: int, y: int) -> Array:
	"""Get adjacent obstacle tiles at position (x, y)"""
	var adjacent = []
	
	# Check all 6 adjacent positions in staggered grid
	var neighbors = []
	if y % 2 == 0:  # Even row
		neighbors = [
			[x - 1, y], [x + 1, y],  # left, right
			[x - 1, y - 1], [x, y - 1],  # top-left, top-right
			[x - 1, y + 1], [x, y + 1]   # bottom-left, bottom-right
		]
	else:  # Odd row
		neighbors = [
			[x - 1, y], [x + 1, y],  # left, right
			[x, y - 1], [x + 1, y - 1],  # top-left, top-right
			[x, y + 1], [x + 1, y + 1]   # bottom-left, bottom-right
		]
	
	for neighbor in neighbors:
		var nx = neighbor[0]
		var ny = neighbor[1]
		
		if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
			var tile_name = placed_grid[ny][nx]
			if tile_name != "" and "obstacle" in tile_name:
				adjacent.append(tile_name)
	
	return adjacent

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				print("Regenerating...")
				for child in get_children():
					if child != camera:
						child.queue_free()
				await get_tree().process_frame
				generate_flat_map()
			KEY_ESCAPE:
				get_tree().quit()
	
	# Zoom controls
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var zoom_factor = 1.0 + zoom_speed if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 - zoom_speed
			camera.zoom *= zoom_factor
			camera.zoom = camera.zoom.clamp(Vector2(0.1, 0.1), Vector2(5.0, 5.0))
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_PAGEUP:
			camera.zoom *= (1.0 + zoom_speed)
			camera.zoom = camera.zoom.clamp(Vector2(0.1, 0.1), Vector2(5.0, 5.0))
		elif event.keycode == KEY_PAGEDOWN:
			camera.zoom *= (1.0 - zoom_speed)
			camera.zoom = camera.zoom.clamp(Vector2(0.1, 0.1), Vector2(5.0, 5.0))

func _process(delta: float) -> void:
	# Movement controls
	var movement = Vector2.ZERO
	
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		movement.x += 30
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		movement.x -= 30
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		movement.y += 30
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		movement.y -= 30
	
	if movement != Vector2.ZERO:
		movement = movement.normalized()
		camera.global_position += movement * camera_speed * delta
