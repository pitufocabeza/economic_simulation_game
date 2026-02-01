extends Node2D

# Top-down Temperate Map Generator with Multi-Layer Overlay System
# Base Layer -> Overlay Layer -> Edge Layer with noise-based probabilistic placement
# Includes biome edge detection and distance-based overlay placement

var tiles_dir = "res://assets/tilesets/temperate/"
var tileset_path = "res://assets/tilesets/temperate_tileset.tres"

# Biome type constants
const BIOME_GRASS = 0
const BIOME_SAND = 1
const BIOME_WATER = 2

var base_tiles = ["temperate_grass_base", "temperate_beach_base", "temperate_water_base"]
var detail_tiles = {
	"grass": ["temperate_grass_dry", "temperate_grass_lush", "temperate_grass_patchy", "temperate_grass_worn"],
	"beach": ["temperate_beach_dry", "temperate_beach_wet"],
	"water": ["temperate_water_deep", "temperate_water_shallow"]
}

# Overlay tiles - detail overlays for Layer 1
var overlay_tiles = {
	"grass": ["temperate_grass_dry", "temperate_grass_lush", "temperate_grass_patchy"],  # Variations
	"water": ["temperate_water_deep", "temperate_water_shallow"],  # Algae/patterns
	"beach": ["temperate_beach_dry", "temperate_beach_wet"]  # Foam/patterns
}

# Edge/mask overlay tiles - for Layer 2 (biome transitions and detail masks)
var edge_overlays = {
	"grass_dirt": ["temperate_grass_dry", "temperate_grass_patchy"],
	"water_algae": ["temperate_water_shallow"],
	"water_foam": ["temperate_water_shallow"],
	"wet_sand": ["temperate_beach_wet"],
	"erosion": ["temperate_beach_dry"]
}

var tile_to_source = {}
var tileset: TileSet
var tilemap_base: TileMap
var tilemap_overlay: TileMap
var tilemap_edges: TileMap
var camera: Camera2D
var grid_width = 32
var grid_height = 32
var tile_size = 256

# Noise parameters
var noise: FastNoiseLite
var overlay_noise: FastNoiseLite
var noise_scale = 0.08
var overlay_noise_scale = 0.15  # Different scale for detail placement
var map_seed = randi()

# Wind simulation
var wind_direction = Vector2(0.707, 0.707).normalized()  # Initial direction (northeast)
var wind_change_timer = 0.0
var wind_change_interval = 8.0  # Wind direction changes every 8 seconds

# Terrain thresholds
var DEEP_WATER_THRESHOLD = 0.20
var SHALLOW_WATER_THRESHOLD = 0.30
var BEACH_THRESHOLD = 0.38

# Overlay parameters
var DEBUG_MODE = false
var overlay_density = 0.10  # 10% of tiles get overlays (normal mode)
var debug_overlay_density = 0.45  # 45% in debug mode
var overlay_noise_threshold = 0.5  # Noise values above this get overlay candidates

# Edge overlay parameters (biome transition rules)
var GRASS_DIRT_BASE_CHANCE = 0.15  # Base probability for grass dirt
var GRASS_DIRT_NEAR_WATER_CHANCE = 0.35  # Increased near water
var GRASS_DIRT_NEAR_SAND_CHANCE = 0.25  # Increased near sand
var WET_SAND_NEAR_WATER_CHANCE = 0.60  # Wet sand close to water
var EROSION_EDGE_CHANCE = 0.25  # Erosion edge probability
var WATER_FOAM_SHORELINE_CHANCE = 0.70  # Foam at water-sand edge (high)
var WATER_ALGAE_CHANCE = 0.30  # Algae in water (lower)
var MAX_DISTANCE_TO_WATER = 2  # Maximum distance bands to check

func _ready():
	print("=== Multi-Layer Terrain Generator ===")
	print_edge_overlay_config()
	setup_noise()
	create_tileset()
	create_tilemaps()
	generate_map()

func _process(delta):
	"""Update wind direction for water shader animation"""
	update_wind(delta)

func update_wind(delta: float):
	"""Simulate changing wind direction"""
	wind_change_timer += delta
	
	if wind_change_timer >= wind_change_interval:
		wind_change_timer = 0.0
		# Random new wind direction
		var angle = randf_range(0.0, TAU)
		wind_direction = Vector2(cos(angle), sin(angle))
		print("Wind direction changed to: %.2f degrees" % rad_to_deg(angle))
		
		# Update all water tile materials with new wind direction
		update_water_wind()

func update_water_wind():
	"""Update wind direction on water shader material"""
	if tilemap_base.material and tilemap_base.material is ShaderMaterial:
		tilemap_base.material.set_shader_parameter("wind_direction", wind_direction)

func setup_noise():
	"""Initialize two noise generators - one for terrain, one for detail placement"""
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_scale
	noise.seed = map_seed
	
	overlay_noise = FastNoiseLite.new()
	overlay_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	overlay_noise.frequency = overlay_noise_scale
	overlay_noise.seed = map_seed + 1000  # Different seed offset
	
	print("Noise configured (seed: %d)" % map_seed)

#region ===== BIOME HELPER FUNCTIONS =====

func is_water(biome_type: int) -> bool:
	"""Check if biome type is water"""
	return biome_type == BIOME_WATER

func is_sand(biome_type: int) -> bool:
	"""Check if biome type is sand/beach"""
	return biome_type == BIOME_SAND

func is_grass(biome_type: int) -> bool:
	"""Check if biome type is grass"""
	return biome_type == BIOME_GRASS

func has_biome_neighbor(pos: Vector2i, target_biome: int, base_map: Dictionary) -> bool:
	"""Check if position has a neighbor of target biome (4-directional)"""
	var neighbors = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for offset in neighbors:
		var neighbor_pos = pos + offset
		if base_map.has(neighbor_pos) and base_map[neighbor_pos] == target_biome:
			return true
	return false

func get_distance_to_biome(pos: Vector2i, target_biome: int, base_map: Dictionary, max_distance: int = 3) -> int:
	"""
	Calculate minimum distance to target biome using BFS.
	Returns distance (0 = is target biome, -1 = unreachable within max_distance)
	"""
	if base_map[pos] == target_biome:
		return 0
	
	var visited = {pos: true}
	var queue = [{"pos": pos, "dist": 0}]
	var queue_index = 0
	
	while queue_index < queue.size():
		var current = queue[queue_index]
		var current_pos = current["pos"]
		var distance = current["dist"]
		
		if distance >= max_distance:
			queue_index += 1
			continue
		
		var neighbors = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		for offset in neighbors:
			var neighbor_pos = current_pos + offset
			
			if not base_map.has(neighbor_pos) or visited.has(neighbor_pos):
				continue
			
			visited[neighbor_pos] = true
			
			if base_map[neighbor_pos] == target_biome:
				return distance + 1
			
			queue.append({"pos": neighbor_pos, "dist": distance + 1})
		
		queue_index += 1
	
	return -1  # Not found within max_distance

func get_neighbor_biomes(pos: Vector2i, base_map: Dictionary) -> Dictionary:
	"""Get count of each biome type in neighbors (4-directional)"""
	var counts = {
		BIOME_GRASS: 0,
		BIOME_SAND: 0,
		BIOME_WATER: 0
	}
	
	var neighbors = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for offset in neighbors:
		var neighbor_pos = pos + offset
		if base_map.has(neighbor_pos):
			counts[base_map[neighbor_pos]] += 1
	
	return counts

func get_random_overlay_from_group(group_key: String) -> String:
	"""Get random overlay tile from edge_overlays group"""
	if not edge_overlays.has(group_key) or edge_overlays[group_key].is_empty():
		return ""
	var tiles = edge_overlays[group_key]
	return tiles[randi() % tiles.size()]

func apply_random_transform(tilemap: TileMap, pos: Vector2i, source_id: int):
	"""Apply random rotation and mirroring to a placed tile"""
	# Godot 4.x TileMap rotation is handled via TileData flags
	var _rotation = randi() % 4  # 0, 1, 2, 3 for 0°, 90°, 180°, 270°
	var _flip_h = randf() < 0.5
	var _flip_v = randf() < 0.5
	
	# Note: For advanced rotation/flipping, you may need to use alternative tiles
	# in your TileSet. For now, we set the cell and the visual rotation can be
	# applied through TileData's custom_data or use alternative tiles.
	tilemap.set_cell(0, pos, source_id, Vector2i(0, 0))

func print_edge_overlay_config():
	"""Print debug information about edge overlay configuration"""
	print("\n=== EDGE OVERLAY CONFIGURATION ===")
	print("Grass Dirt:")
	print("  - Base chance: %.1f%%" % [GRASS_DIRT_BASE_CHANCE * 100])
	print("  - Near water: %.1f%%" % [GRASS_DIRT_NEAR_WATER_CHANCE * 100])
	print("  - Near sand: %.1f%%" % [GRASS_DIRT_NEAR_SAND_CHANCE * 100])
	print("\nSand Overlays:")
	print("  - Wet sand (shoreline): %.1f%%" % [WET_SAND_NEAR_WATER_CHANCE * 100])
	print("  - Erosion edge: %.1f%%" % [EROSION_EDGE_CHANCE * 100])
	print("\nWater Overlays:")
	print("  - Foam (shoreline): %.1f%%" % [WATER_FOAM_SHORELINE_CHANCE * 100])
	print("  - Algae: %.1f%%" % [WATER_ALGAE_CHANCE * 100])
	print("  - Max distance check: %d tiles" % MAX_DISTANCE_TO_WATER)
	print("================================\n")

#endregion

func create_tileset():
	"""Create TileSet from loaded PNGs"""
	print("Creating TileSet...")
	tileset = TileSet.new()
	tileset.tile_size = Vector2i(tile_size, tile_size)
	
	var all_tiles = base_tiles.duplicate()
	for variants in detail_tiles.values():
		all_tiles.append_array(variants)
	
	var source_id = 0
	for tile_name in all_tiles:
		var tile_path = tiles_dir + tile_name + ".png"
		
		var image = Image.new()
		if image.load(tile_path) != OK:
			print("ERROR: Could not load ", tile_path)
			continue
		
		var texture = ImageTexture.create_from_image(image)
		var source = TileSetAtlasSource.new()
		source.texture = texture
		source.texture_region_size = Vector2i(tile_size, tile_size)
		
		tileset.add_source(source, source_id)
		source.create_tile(Vector2i(0, 0))
		tile_to_source[tile_name] = source_id
		
		source_id += 1
	
	ResourceSaver.save(tileset, tileset_path)
	print("TileSet created with %d tiles" % source_id)

func create_tilemaps():
	"""Create three TileMap layers with proper Z-ordering"""
	print("Creating TileMap layers...")
	
	# Base layer (Z=0)
	tilemap_base = TileMap.new()
	tilemap_base.name = "TileMap_Base"
	tilemap_base.tile_set = tileset
	tilemap_base.z_index = 0
	add_child(tilemap_base)
	
	# Overlay layer (Z=1)
	tilemap_overlay = TileMap.new()
	tilemap_overlay.name = "TileMap_Overlay"
	tilemap_overlay.tile_set = tileset
	tilemap_overlay.z_index = 1
	add_child(tilemap_overlay)
	
	# Edge layer (Z=2) - for foam, foliage at transitions
	tilemap_edges = TileMap.new()
	tilemap_edges.name = "TileMap_Edges"
	tilemap_edges.tile_set = tileset
	tilemap_edges.z_index = 2
	add_child(tilemap_edges)
	
	# Add camera
	camera = Camera2D.new()
	camera.zoom = Vector2(0.3, 0.3)
	camera.global_position = Vector2(grid_width * tile_size / 4, grid_height * tile_size / 4)
	add_child(camera)
	
	print("TileMap layers created (Z: 0, 1, 2)")

func generate_map():
	"""Generate terrain with base, overlay, and edge layers"""
	print("Generating %dx%d map..." % [grid_width, grid_height])
	
	var noise_values = {}
	var base_map = {}
	
	# Generate and normalize noise
	var min_val = 1.0
	var max_val = -1.0
	
	for y in range(grid_height):
		for x in range(grid_width):
			var value = noise.get_noise_2d(float(x), float(y))
			noise_values[Vector2i(x, y)] = value
			min_val = min(min_val, value)
			max_val = max(max_val, value)
	
	var range_val = max_val - min_val
	for pos in noise_values.keys():
		var normalized = (noise_values[pos] - min_val) / float(range_val) if range_val > 0.0 else 0.5
		noise_values[pos] = normalized
	
	# Layer 0: Place base tiles
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			var noise_val = noise_values[pos]
			
			var base_type = 0
			if noise_val < DEEP_WATER_THRESHOLD:
				base_type = 2
			elif noise_val < SHALLOW_WATER_THRESHOLD:
				base_type = 2
			elif noise_val < BEACH_THRESHOLD:
				base_type = 1
			
			base_map[pos] = base_type
			var base_tile = base_tiles[base_type]
			if tile_to_source.has(base_tile):
				var base_source = tile_to_source[base_tile]
				tilemap_base.set_cell(0, pos, base_source, Vector2i(0, 0))
			
			# Also place detail on base layer
			var detail_tile = get_detail_tile(base_type, noise_val)
			if tile_to_source.has(detail_tile):
				var detail_source = tile_to_source[detail_tile]
				tilemap_base.set_cell(0, pos, detail_source, Vector2i(0, 0))
	
	# Post-process: fix isolated grass
	fix_isolated_grass(base_map)
	
	# Layer 1: Place overlay tiles probabilistically
	place_overlays(base_map, noise_values)
	
	# Layer 2: Place edge tiles (future: foam, cliff edges, etc)
	place_edges(base_map)
	
	# Apply water shader to water tiles
	apply_water_shader(base_map)
	
	print("Map generation complete!")

func fix_isolated_grass(base_map: Dictionary):
	"""Convert grass adjacent to water to beach"""
	var neighbors = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var to_fix = []
	
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			if base_map[pos] == 0:  # Grass
				for neighbor_offset in neighbors:
					var neighbor_pos = pos + neighbor_offset
					if base_map.has(neighbor_pos) and base_map[neighbor_pos] == 2:  # Adjacent to water
						to_fix.append(pos)
						break
	
	for pos in to_fix:
		base_map[pos] = 1  # Convert to beach type
		if tile_to_source.has("temperate_beach_base"):
			var beach_source = tile_to_source["temperate_beach_base"]
			tilemap_base.set_cell(0, pos, beach_source, Vector2i(0, 0))

func place_overlays(base_map: Dictionary, _noise_values: Dictionary):
	"""Place overlay tiles probabilistically using noise"""
	print("Placing overlay tiles...")
	
	var density = debug_overlay_density if DEBUG_MODE else overlay_density
	var overlay_placed = 0
	
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			var base_type = base_map[pos]
			var overlay_noise_val = overlay_noise.get_noise_2d(float(x), float(y))
			
			# Normalize overlay noise to 0-1
			overlay_noise_val = (overlay_noise_val + 1.0) / 2.0
			
			# Determine if this tile gets an overlay
			var chance = density * (overlay_noise_val if overlay_noise_val > overlay_noise_threshold else 0.0)
			
			if randf() < chance:
				var overlay_tile = get_overlay_for_biome(base_type)
				if overlay_tile and tile_to_source.has(overlay_tile):
					var _overlay_source = tile_to_source[overlay_tile]
					var _rotation = randi() % 4  # 0-3 (0°, 90°, 180°, 270°)
					var _flip_h = randf() < 0.5
					var _flip_v = randf() < 0.5
					
					tilemap_overlay.set_cell(0, pos, tile_to_source[overlay_tile], Vector2i(0, 0))
					overlay_placed += 1
	

func get_overlay_for_biome(base_type: int) -> String:
	"""Get appropriate overlay tile for base biome type"""
	match base_type:
		0:  # Grass
			return overlay_tiles["grass"][randi() % overlay_tiles["grass"].size()]
		1:  # Beach
			return overlay_tiles["beach"][randi() % overlay_tiles["beach"].size()]
		2:  # Water
			return overlay_tiles["water"][randi() % overlay_tiles["water"].size()]
	return ""

func place_edges(base_map: Dictionary):
	"""Place edge overlays at biome transitions with distance-based rules"""
	print("Placing edge overlays...")
	
	var edges_placed = 0
	
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			var biome = base_map[pos]
			var neighbor_counts = get_neighbor_biomes(pos, base_map)
			
			# Skip if no biome neighbors (interior tile)
			var _is_edge_tile = (neighbor_counts[BIOME_GRASS] > 0 and biome != BIOME_GRASS) or \
							  (neighbor_counts[BIOME_SAND] > 0 and biome != BIOME_SAND) or \
							  (neighbor_counts[BIOME_WATER] > 0 and biome != BIOME_WATER)
			
			if biome == BIOME_GRASS:
				# GRASS OVERLAYS: dirt stains near water/sand
				if has_biome_neighbor(pos, BIOME_WATER, base_map) or has_biome_neighbor(pos, BIOME_SAND, base_map):
					var chance = GRASS_DIRT_NEAR_WATER_CHANCE if has_biome_neighbor(pos, BIOME_WATER, base_map) else GRASS_DIRT_NEAR_SAND_CHANCE
					if randf() < chance:
						var dirt_tile = get_random_overlay_from_group("grass_dirt")
						if dirt_tile and tile_to_source.has(dirt_tile):
							var source_id = tile_to_source[dirt_tile]
							apply_random_transform(tilemap_edges, pos, source_id)
							edges_placed += 1
				else:
					# Base grass dirt chance
					if randf() < GRASS_DIRT_BASE_CHANCE:
						var dirt_tile = get_random_overlay_from_group("grass_dirt")
						if dirt_tile and tile_to_source.has(dirt_tile):
							var source_id = tile_to_source[dirt_tile]
							apply_random_transform(tilemap_edges, pos, source_id)
							edges_placed += 1
			
			elif biome == BIOME_SAND:
				# SAND OVERLAYS: wet sand and erosion near water
				var distance_to_water = get_distance_to_biome(pos, BIOME_WATER, base_map, MAX_DISTANCE_TO_WATER)
				
				if distance_to_water == 0:  # Adjacent to water
					# Wet sand at shoreline
					if randf() < WET_SAND_NEAR_WATER_CHANCE:
						var wet_sand_tile = get_random_overlay_from_group("wet_sand")
						if wet_sand_tile and tile_to_source.has(wet_sand_tile):
							var source_id = tile_to_source[wet_sand_tile]
							apply_random_transform(tilemap_edges, pos, source_id)
							edges_placed += 1
				
				elif distance_to_water >= 1 and distance_to_water <= 2:
					# Erosion edges on sand near water
					if randf() < EROSION_EDGE_CHANCE:
						var erosion_tile = get_random_overlay_from_group("erosion")
						if erosion_tile and tile_to_source.has(erosion_tile):
							var source_id = tile_to_source[erosion_tile]
							apply_random_transform(tilemap_edges, pos, source_id)
							edges_placed += 1
			
			elif biome == BIOME_WATER:
				# WATER OVERLAYS: foam and algae at shoreline
				
				# Check if adjacent to sand (shoreline)
				if has_biome_neighbor(pos, BIOME_SAND, base_map):
					# High probability foam at shoreline
					if randf() < WATER_FOAM_SHORELINE_CHANCE:
						var foam_tile = get_random_overlay_from_group("water_foam")
						if foam_tile and tile_to_source.has(foam_tile):
							var source_id = tile_to_source[foam_tile]
							apply_random_transform(tilemap_edges, pos, source_id)
							edges_placed += 1
				
				# Lower probability algae in water
				if randf() < WATER_ALGAE_CHANCE:
					var algae_tile = get_random_overlay_from_group("water_algae")
					if algae_tile and tile_to_source.has(algae_tile):
						var source_id = tile_to_source[algae_tile]
						apply_random_transform(tilemap_edges, pos, source_id)
						edges_placed += 1
	
	print("  Placed %d edge overlay tiles" % edges_placed)

func apply_water_shader(base_map: Dictionary):
	"""Apply water shader to entire tilemap layer for unified animation"""
	print("Applying water shader to tilemap layer...")
	
	# Create water shader material if shader exists
	var shader_path = "res://assets/shaders/water_2_5d.gdshader"
	var shader = load(shader_path)
	
	if shader == null:
		print("  WARNING: Water shader not found at ", shader_path)
		return
	
	var water_material = ShaderMaterial.new()
	water_material.shader = shader
	
	# Set shader parameters with defaults
	water_material.set_shader_parameter("water_scroll_speed", 0.3)
	water_material.set_shader_parameter("normal_strength", 0.8)
	water_material.set_shader_parameter("foam_threshold", 0.7)
	water_material.set_shader_parameter("foam_strength", 1.5)
	water_material.set_shader_parameter("foam_fade_distance", 0.4)
	water_material.set_shader_parameter("time_scale", 1.0)
	water_material.set_shader_parameter("shallow_transition", 0.4)
	water_material.set_shader_parameter("subtle_noise_strength", 0.05)
	water_material.set_shader_parameter("wave_amplitude", 0.5)
	water_material.set_shader_parameter("wind_direction", wind_direction)
	
	# Set default colors
	water_material.set_shader_parameter("deep_water_color", Color(0.1, 0.2, 0.4, 1.0))
	water_material.set_shader_parameter("shallow_water_color", Color(0.3, 0.6, 0.4, 1.0))
	water_material.set_shader_parameter("foam_color", Color(0.95, 0.95, 1.0, 1.0))
	
	# Load textures
	var color_tex = load("res://assets/tilesets/temperate/water_base_color.png")
	var normal_tex = load("res://assets/tilesets/temperate/water_normal.png")
	
	# Load mask textures - these are important for water effects
	var water_foam_mask = load("res://assets/tilesets/temperate/water_foam_mask.png")
	var water_algae_mask = load("res://assets/tilesets/temperate/water_algae_mask.png")
	var water_edge_mask = load("res://assets/tilesets/temperate/water_edge_combined_mask.png")
	
	var foam_noise_tex = load("res://assets/tilesets/temperate/water_foam.png")
	
	# Use procedurally generated textures as fallback
	var TextureGen = load("res://scripts/texture_generator.gd")
	
	if not color_tex:
		print("  NOTE: water_base_color.png not found (shader will use computed color)")
	else:
		water_material.set_shader_parameter("water_color_tex", color_tex)
	
	if not normal_tex:
		print("  Generating procedural normal texture for water animation...")
		normal_tex = TextureGen.generate_normal_texture(256)
	
	water_material.set_shader_parameter("water_normal_tex", normal_tex)
	
	# Use actual mask textures or procedural fallback
	if water_edge_mask:
		print("  Using water_edge_combined_mask.png for shoreline detection")
		water_material.set_shader_parameter("water_edge_mask", water_edge_mask)
	else:
		print("  Generating procedural edge mask for foam/shoreline...")
		var edge_mask_tex = TextureGen.generate_edge_mask_texture(256)
		water_material.set_shader_parameter("water_edge_mask", edge_mask_tex)
	
	# Use foam mask if available
	if water_foam_mask:
		print("  Using water_foam_mask.png for foam effects")
		water_material.set_shader_parameter("foam_noise_tex", water_foam_mask)
	elif foam_noise_tex:
		water_material.set_shader_parameter("foam_noise_tex", foam_noise_tex)
	
	# Apply the SAME material instance to all water tiles
	# This ensures they all animate together since they reference the same material
	var water_tiles = 0
	for pos in base_map.keys():
		if base_map[pos] == BIOME_WATER:
			var cell_data = tilemap_base.get_cell_tile_data(0, pos)
			if cell_data:
				# All water tiles reference the SAME material instance (not duplicates)
				cell_data.material = water_material
				water_tiles += 1
	
	print("  Applied water shader to %d water tiles" % water_tiles)

func get_detail_tile(base_type: int, noise_val: float) -> String:
	"""Get detail tile variant based on noise value"""
	match base_type:
		0:  # Grass
			if noise_val > 0.75:
				return "temperate_grass_lush"
			elif noise_val > 0.60:
				return "temperate_grass_patchy"
			elif noise_val > 0.45:
				return "temperate_grass_worn"
			else:
				return "temperate_grass_dry"
		
		1:  # Beach
			if noise_val > 0.35:
				return "temperate_beach_wet"
			else:
				return "temperate_beach_dry"
		
		2:  # Water
			if noise_val < 0.22:
				return "temperate_water_deep"
			else:
				return "temperate_water_shallow"
	
	return "temperate_grass_base"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_W:
				camera.global_position.y -= 400
			KEY_A:
				camera.global_position.x -= 400
			KEY_S:
				camera.global_position.y += 400
			KEY_D:
				camera.global_position.x += 400
			KEY_UP:
				camera.global_position.y -= 400
			KEY_LEFT:
				camera.global_position.x -= 400
			KEY_DOWN:
				camera.global_position.y += 400
			KEY_RIGHT:
				camera.global_position.x += 400
			KEY_PAGEUP:
				camera.zoom += Vector2(0.2, 0.2)
				print("Zoom: %.2fx" % camera.zoom.x)
			KEY_PAGEDOWN:
				if camera.zoom.x > 0.1:
					camera.zoom -= Vector2(0.2, 0.2)
					print("Zoom: %.2fx" % camera.zoom.x)
			KEY_R:
				print("Regenerating with new seed...")
				map_seed = randi()
				setup_noise()
				tilemap_base.clear()
				tilemap_overlay.clear()
				tilemap_edges.clear()
				generate_map()
			KEY_T:  # Toggle debug mode
				DEBUG_MODE = !DEBUG_MODE
				print("Debug mode: %s (overlay density: %.1f%%)" % [DEBUG_MODE, (debug_overlay_density if DEBUG_MODE else overlay_density) * 100])
				tilemap_overlay.clear()
				tilemap_edges.clear()

				# Simplified: just regenerate everything
				generate_map()
			KEY_ESCAPE:
				get_tree().quit()
	
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				camera.zoom += Vector2(0.1, 0.1)
				print("Zoom: %.2fx" % camera.zoom.x)
				get_tree().root.set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				if camera.zoom.x > 0.2:
					camera.zoom -= Vector2(0.1, 0.1)
					if camera.zoom.x < 0.1:
						camera.zoom = Vector2(0.1, 0.1)
					print("Zoom: %.2fx" % camera.zoom.x)
				get_tree().root.set_input_as_handled()
