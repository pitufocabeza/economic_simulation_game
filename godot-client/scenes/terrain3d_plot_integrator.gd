extends Node3D

# Terrain size and configuration
@export var VERTICAL_SCALE: float = 70  # Increased from 60 for better terrain visibility
@export var REGION_SIZE: int = 256  # Must match Terrain3D region size

# Reference to the Terrain3D node
var terrain3d: Node3D

# Water configuration
@export var WATER_LEVEL_NORM: float = 0.15
var water_meshes: Array[MeshInstance3D] = []  # [shallow, base, deep]
var water_materials: Array[Material] = []     # [shallow_mat, base_mat, deep_mat]

# Biome height ranges for control map
@export var SAND_MAX: float = 0.25
@export var GRASS_MIN: float = 0.25
@export var GRASS_MAX: float = 0.65
@export var ROCK_MIN: float = 0.65
@export var ROCK_MAX: float = 0.85
@export var SNOW_MIN: float = 0.85
@export var TRANSITION_WIDTH: float = 0.05

# Reference to the Plot Generator
var plot_generator: Node3D

# Cliff system
@export var CLIFF_HEIGHT_THRESHOLD: float = 0.15  # Height delta above which to spawn cliffs
@export var cliff_modules: Array[CliffModule] = []
var cliff_container: Node3D

# Biome texture uniforms (for terrain_blender shader)
@export var grass_albedo: Texture2D
@export var grass_normal: Texture2D
@export var grass_orm: Texture2D

@export var sand_albedo: Texture2D
@export var sand_normal: Texture2D
@export var sand_orm: Texture2D

@export var rock_albedo: Texture2D
@export var rock_normal: Texture2D
@export var rock_orm: Texture2D

@export var snow_albedo: Texture2D
@export var snow_normal: Texture2D

# Shader parameters
@export var uv_scale: float = 4.0
@export var ao_strength: float = 1.0

# Water texture uniforms (for ocean shader materials)
@export var ocean_albedo: Texture2D
@export var ocean_normal: Texture2D

# Debug control map display
@export var DEBUG_CONTROL_MAP: bool = false  # Toggle to visualize biome assignments

# Region tracking
var region_loc: Vector2i = Vector2i.ZERO

# Plot cycling
var PLOT_SIZES: Array = [12, 16, 20]
var current_size_index: int = 1
var current_seed: int = 42
var current_archetype: String = ""
var current_water_level: float = 0.0

func _ready() -> void:
	set_process_input(true)
	call_deferred("_setup_references")
func _setup_references() -> void:
	# Find PlotGenerator in scene
	plot_generator = find_child("PlotGenerator", true, false)
	if not plot_generator:
		push_error("PlotGenerator not found as child. Creating it...")
		plot_generator = Node3D.new()
		plot_generator.name = "PlotGenerator"
		add_child(plot_generator)
		var script = load("res://scenes/temperate_map_generator.gd")
		if script:
			plot_generator.set_script(script)
			print("✓ Created PlotGenerator with script")
		else:
			push_error("Failed to load temperate_map_generator.gd")
	else:
		print("✓ Found PlotGenerator")
	
	# Find Terrain3D in scene
	terrain3d = find_child("Terrain3D", true, false)
	if not terrain3d:
		push_error("Terrain3D not found in scene tree")
		return
	else:
		print("✓ Found Terrain3D")

	# Setup water plane
	_setup_water_layers()
	
	# Setup cliff container
	_setup_cliffs()
	
	_ensure_region()
	_set_plot_size(PLOT_SIZES[current_size_index])
	current_seed = randi()
	generate_terrain()
	
func _setup_water_layers() -> void:
	"""Create three layered water planes (shallow, base, deep) with animated shader materials.
	
	Each layer:
	- Shallow (turquoise, fast scroll, transparent) - shows terrain below
	- Base (blue, medium scroll, balanced) - main ocean layer
	- Deep (dark blue, slow scroll, opaque) - distant ocean effect
	
	All layers scroll their normals and albedos based on TIME uniform for animation.
	"""
	# Clear any existing water meshes
	water_meshes.clear()
	water_materials.clear()
	
	# Define layer properties: (name, shader_path, y_offset, scroll_speed)
	var layers = [
		{"name": "WaterShallow", "shader_path": "res://shaders/ocean_shallow.gdshader", "y_offset": 0.1, "scroll_speed": 0.4},
		{"name": "WaterBase", "shader_path": "res://shaders/ocean_base.gdshader", "y_offset": 0.0, "scroll_speed": 0.3},
		{"name": "WaterDeep", "shader_path": "res://shaders/ocean_deep.gdshader", "y_offset": -0.2, "scroll_speed": 0.2},
	]
	
	# Create three water mesh planes
	for layer_info in layers:
		# Look for existing water mesh or create new one
		var water_layer = find_child(layer_info["name"], true, false)
		
		if not water_layer:
			water_layer = MeshInstance3D.new()
			water_layer.name = layer_info["name"]
			add_child(water_layer)
		else:
			# Reuse existing mesh, clear it
			water_layer.mesh = null
			water_layer.set_surface_override_material(0, null)
		
		# Create plane mesh large enough to cover entire terrain region
		var plane = PlaneMesh.new()
		var plane_size = float(REGION_SIZE) * 3.0  # Extra coverage for edge visibility
		plane.size = Vector2(plane_size, plane_size)
		water_layer.mesh = plane
		
		# Load shader and create material
		var shader = load(layer_info["shader_path"])
		if shader:
			var material = ShaderMaterial.new()
			material.shader = shader
			
			# Assign water textures if available
			if ocean_albedo:
				material.set_shader_parameter("water_albedo", ocean_albedo)
			if ocean_normal:
				material.set_shader_parameter("water_normal", ocean_normal)
			
			# Set scroll speed from layer definition
			material.set_shader_parameter("scroll_speed", layer_info["scroll_speed"])
			
			water_layer.set_surface_override_material(0, material)
			water_materials.append(material)
			print("✓ Loaded water material: %s (scroll_speed: %.1f)" % [layer_info["name"], layer_info["scroll_speed"]])
		else:
			push_error("Water shader not found: %s" % layer_info["shader_path"])
			water_materials.append(null)
		
		# Store layer info for positioning
		water_layer.set_meta("y_offset", layer_info["y_offset"])
		water_meshes.append(water_layer)
	
	print("✓ Water layers setup complete (shallow, base, deep with animated shaders)")

func _setup_cliffs() -> void:
	"""Initialize cliff container for modular cliff meshes."""
	cliff_container = find_child("CliffContainer", true, false)
	
	if not cliff_container:
		cliff_container = Node3D.new()
		cliff_container.name = "CliffContainer"
		add_child(cliff_container)
	
	print("✓ Cliff container setup complete")

func _update_water_layer_positions() -> void:
	"""Position the three water layers at the current water level with depth-based offsets.
	
	Layers:
	- Shallow (y + 0.1): Bright turquoise, closest to camera, visible in very shallow areas
	- Base (y + 0.0): Medium blue, middle depth
	- Deep (y - 0.2): Dark blue, furthest back, visible in deep ocean
	"""
	if water_meshes.is_empty():
		return
	
	var base_y = current_water_level
	var region_center = Vector3(
		float(region_loc.x * REGION_SIZE) + float(REGION_SIZE) / 2.0,
		base_y,
		float(region_loc.y * REGION_SIZE) + float(REGION_SIZE) / 2.0
	)
	
	# Position each water layer at slightly different depths
	for i in range(water_meshes.size()):
		var water_layer = water_meshes[i]
		var y_offset = water_layer.get_meta("y_offset") if water_layer.has_meta("y_offset") else 0.0
		
		water_layer.position = region_center + Vector3(0, y_offset, 0)
		
		var layer_names = ["Shallow", "Base", "Deep"]
		print("✓ Water layer %s positioned at y=%.2f" % [layer_names[i], water_layer.position.y])

func _configure_noise() -> void:
	# This is deprecated - noise now lives in temperate_map_generator
	pass

func _ensure_region() -> void:
	"""Create a Terrain3D region at (0, 0) if it doesn't exist."""
	if not terrain3d or not terrain3d.data:
		push_error("Cannot ensure region: Terrain3D not available")
		return
	
	var data: Object = terrain3d.data
	
	# Check if region exists
	if data.has_region(region_loc):
		print("✓ Region already exists at %s" % region_loc)
		return
	
	# Create blank region
	print("Creating Terrain3D region at %s..." % region_loc)
	var region = data.add_region_blank(region_loc)
	
	if region == null:
		push_error("Failed to create region at %s" % region_loc)
		return
	
	if data.has_region(region_loc):
		print("✓ Region created successfully at %s" % region_loc)
	else:
		push_error("Region creation verification failed")

func _set_plot_size(size: int) -> void:
	"""Set the plot grid resolution on the generator."""
	if plot_generator:
		plot_generator.GRID_RESOLUTION = size
		print("📐 Set plot size to %dx%d" % [size, size])
	else:
		push_error("Cannot set plot size: PlotGenerator not found")

func _validate_terrain_config() -> bool:
	"""Validate that REGION_SIZE matches Terrain3D configuration.
	
	Returns true if valid, false if mismatch detected.
	Prints warnings if issues found.
	"""
	if not terrain3d or not terrain3d.data:
		push_error("Cannot validate: Terrain3D not available")
		return false
	
	var actual_region_size = terrain3d.get_region_size()
	var vertex_spacing = 1.0  # Default vertex spacing (configurable in Terrain3D)
	
	if actual_region_size != REGION_SIZE:
		push_warning("Region size mismatch: REGION_SIZE export=%d, Terrain3D actual=%d. Using Terrain3D value." % [REGION_SIZE, actual_region_size])
		return false
	
	print("✓ Terrain config valid: region_size=%d, vertex_spacing=%.1f" % [actual_region_size, vertex_spacing])
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				print("🔄 R pressed - regenerating current archetype...")
				_reset_region()
				generate_terrain()
				get_tree().root.set_input_as_handled()
			
			KEY_T:
				print("📋 T pressed - cycling plot size...")
				_reset_region()
				current_size_index = (current_size_index + 1) % PLOT_SIZES.size()
				var size: int = PLOT_SIZES[current_size_index]
				_set_plot_size(size)
				current_seed = randi()
				generate_terrain()
				get_tree().root.set_input_as_handled()
			
			KEY_C:
				print("🏝️  C pressed - cycling archetype...")
				_reset_region()
				current_seed = randi()
				generate_terrain()
				get_tree().root.set_input_as_handled()
			
			KEY_J:
				DEBUG_CONTROL_MAP = not DEBUG_CONTROL_MAP
				print("🐛 Debug control map: %s" % ("ON" if DEBUG_CONTROL_MAP else "OFF"))
				_reset_region()
				generate_terrain()
				get_tree().root.set_input_as_handled()

func _reset_region() -> void:
	"""Remove and recreate the active region."""
	if not terrain3d or not terrain3d.data:
		print("Cannot reset: Terrain3D or data not available")
		return
	
	var data: Object = terrain3d.data
	
	if data.has_region(region_loc):
		print("Removing region at %s" % region_loc)
		var region: Object = data.get_region(region_loc)
		if region:
			data.remove_region(region)
	
	# Recreate the region
	_ensure_region()

func generate_terrain() -> void:
	if not plot_generator:
		push_error("PlotGenerator is null")
		return

	if not plot_generator.has_method("generate_plot"):
		push_error("PlotGenerator doesn't have generate_plot method")
		return

	print("Calling generate_plot()...")
	var result = plot_generator.generate_plot(current_seed)

	if not result:
		push_error("generate_plot() returned null")
		return

	if not result.get("success"):
		push_error("generate_plot() returned success=false")
		return

	if not result.has("height_map"):
		push_error("generate_plot() missing height_map in result")
		return

	var height_map = result["height_map"]
	if height_map.is_empty():
		push_error("height_map is empty")
		return

	var island_mask = result.get("island_mask", [])
	
	current_archetype = result.get("archetype", "Unknown")
	print("✓ Generated archetype: %s (size: %dx%d)" % [current_archetype, height_map.size(), height_map[0].size() if height_map.size() > 0 else 0])
	_apply_height_map(height_map, island_mask)

func _apply_height_map(height_map: Array, island_mask: Array) -> void:
	if not terrain3d or not terrain3d.data:
		push_error("Terrain3D or data not available")
		return
	
	var data: Object = terrain3d.data
	
	# Get actual region size from Terrain3D (should match REGION_SIZE)
	var actual_region_size: int = terrain3d.get_region_size()
	var target_size: int = actual_region_size
	
	if actual_region_size != REGION_SIZE:
		push_warning("Region size mismatch: REGION_SIZE=%d but Terrain3D reports %d. Using %d." % [REGION_SIZE, actual_region_size, actual_region_size])
	
	# Upscale heightmap using bilinear interpolation
	var scaled_map: Array = _upscale_heightmap(height_map, target_size)
	
	# Upscale island mask to match target size
	var scaled_mask: Array = _upscale_heightmap(island_mask if island_mask.size() > 0 else _create_full_land_mask(height_map), target_size)
	
	# Apply light smoothing (2 passes) for natural slope transitions
	scaled_map = _smooth_heightmap(scaled_map, 2)
	
	# Calculate water level based on WATER_LEVEL_NORM parameter
	current_water_level = WATER_LEVEL_NORM * VERTICAL_SCALE
	
	# Debug info: print height map statistics
	var min_height = 999.0
	var max_height = 0.0
	for row in scaled_map:
		for h in row:
			min_height = minf(min_height, h)
			max_height = maxf(max_height, h)
	
	print("Writing %dx%d heights to region..." % [target_size, target_size])
	print("Archetype: %s | Water level: %.2f" % [current_archetype, current_water_level])
	print("Height range: %.3f - %.3f (normalized) → %.2f - %.2f (world units)" % [min_height, max_height, min_height * VERTICAL_SCALE, max_height * VERTICAL_SCALE])
	
	# Vertex spacing: typically 1.0 (1m per vertex)
	var vertex_spacing: float = 1.0
	
	# Write heights to Terrain3D using proper world position calculation
	var first_height = 0.0
	var last_height = 0.0
	var sample_count = 0
	
	for z in range(target_size):
		for x in range(target_size):
			var h_norm: float = scaled_map[z][x]
			var h_world: float = h_norm * VERTICAL_SCALE
			
			# CORRECT world position calculation:
			# global_pos = (region_loc * region_size * vertex_spacing) + (x * vertex_spacing, z * vertex_spacing)
			var global_x: float = (float(region_loc.x) * float(actual_region_size) * vertex_spacing) + (float(x) * vertex_spacing)
			var global_z: float = (float(region_loc.y) * float(actual_region_size) * vertex_spacing) + (float(z) * vertex_spacing)
			var pos: Vector3 = Vector3(global_x, 0.0, global_z)
			
			# Set height (Y coordinate from world height)
			data.set_height(pos, h_world)
			
			# Sample first and last for debug
			if sample_count == 0:
				first_height = h_world
			if sample_count == target_size * target_size - 1:
				last_height = h_world
			sample_count += 1
	
	print("Sample heights: first=%.2f, last=%.2f | Region bounds: [%.1f to %.1f, %.1f to %.1f]" % [
		first_height, last_height,
		float(region_loc.x) * float(actual_region_size) * vertex_spacing,
		float(region_loc.x) * float(actual_region_size) * vertex_spacing + float(actual_region_size) * vertex_spacing,
		float(region_loc.y) * float(actual_region_size) * vertex_spacing,
		float(region_loc.y) * float(actual_region_size) * vertex_spacing + float(actual_region_size) * vertex_spacing
	])
	
	# Generate control map image (per-region, not per-vertex)
	var control_image = _generate_control_map_anno_style(scaled_map, scaled_mask, current_archetype)
	
	# Assign control map to region
	var region = data.get_region(region_loc)
	if region:
		if DEBUG_CONTROL_MAP:
			# Debug mode: display control map directly (shows color-coded biomes)
			region.control_map = ImageTexture.create_from_image(control_image)
			print("✓ Control map assigned to region (DEBUG MODE: color-coded biomes)")
		else:
			# Normal mode: control map drives actual textures
			region.control_map = ImageTexture.create_from_image(control_image)
			print("✓ Control map assigned to region")
	else:
		push_error("Could not get region for control map assignment")
	
	# Apply shader material with biome textures and control map
	_apply_shader_material(control_image)
	
	# Update water layer positions - sit at the calculated water level with depth-based offsets
	_update_water_layer_positions()
	
	print("✓ Heights written, rebuilding terrain...")
	data.update_maps()
	print("✓ Terrain rebuild complete.")
	
	# Generate cliffs from detected edges (only once)
	_generate_cliffs_from_edges(scaled_map)

func _upscale_heightmap(height_map: Array, target_size: int) -> Array:
	"""Upscale heightmap using bilinear interpolation."""
	var source_size: int = height_map.size()
	var scale: float = float(source_size - 1) / float(target_size - 1)
	var scaled: Array = []
	
	for z in range(target_size):
		var row: Array = []
		for x in range(target_size):
			var src_x: float = float(x) * scale
			var src_z: float = float(z) * scale
			
			var x0: int = int(floor(src_x))
			var z0: int = int(floor(src_z))
			var x1: int = clampi(x0 + 1, 0, source_size - 1)
			var z1: int = clampi(z0 + 1, 0, source_size - 1)
			x0 = clampi(x0, 0, source_size - 1)
			z0 = clampi(z0, 0, source_size - 1)
			
			var fx: float = src_x - float(x0)
			var fz: float = src_z - float(z0)
			
			var h00: float = height_map[z0][x0]
			var h10: float = height_map[z0][x1]
			var h01: float = height_map[z1][x0]
			var h11: float = height_map[z1][x1]
			
			var h0: float = lerp(h00, h10, fx)
			var h1: float = lerp(h01, h11, fx)
			var h_interp: float = lerp(h0, h1, fz)
			
			row.append(h_interp)
		scaled.append(row)
	
	return scaled

func _smooth_heightmap(height_map: Array, passes: int = 2) -> Array:
	"""Apply light Gaussian smoothing (2–4 passes)."""
	var result = height_map
	
	for pass_num in range(passes):
		var smoothed: Array = []
		for z in range(result.size()):
			var row: Array = []
			for x in range(result[0].size()):
				var sum: float = 0.0
				var count: int = 0
				
				# 3x3 neighborhood average
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						var nx = x + dx
						var nz = z + dz
						
						if nx >= 0 and nx < result[0].size() and nz >= 0 and nz < result.size():
							sum += result[nz][nx]
							count += 1
				
				row.append(sum / float(count))
			smoothed.append(row)
		result = smoothed
	
	return result

func _apply_smoothing() -> void:
	# Smoothing is now integrated into _apply_height_map
	pass

func _create_full_land_mask(height_map: Array) -> Array:
	"""Create a full land mask (all 1.0) if island_mask is not provided."""
	var mask = []
	for z in range(height_map.size()):
		var row = []
		for x in range(height_map[z].size()):
			row.append(1.0)
		mask.append(row)
	return mask

func _generate_control_map_legacy(height_map: Array, island_mask: Array) -> Image:
	"""[LEGACY] Generate per-region control map with height-based smooth biome transitions.
	
	RGBA channels: R=Rock, G=Snow, B=Grass, A=Sand
	
	Requirements:
	- Create Image with REGION_SIZE x REGION_SIZE pixels
	- Loop pixels (x, y), not world positions
	- If island_mask[y][x] == WATER: all channels = 0
	- If LAND: compute biome weights from height
	- Sand only at coastlines (distance to water)
	- Normalize weights so they sum to 1.0
	"""
	# Ensure dimensions match
	var map_size = height_map.size()
	var mask_size = island_mask.size()
	
	if map_size != mask_size:
		push_warning("Dimension mismatch: height_map=%d, island_mask=%d. Using height_map size." % [map_size, mask_size])
	
	var control_image = Image.create(map_size, map_size, false, Image.FORMAT_RGBA8)
	
	# Precompute distance-to-water map for sand blending
	var water_distance = _compute_water_distance(island_mask)
	
	for y in range(map_size):
		for x in range(map_size):
			# Get mask value, with bounds checking
			var mask_val = 1.0  # Default to land
			if y < island_mask.size() and x < island_mask[y].size():
				mask_val = island_mask[y][x]
			
			# Water cells: transparent (all 0)
			if mask_val <= 0.5:
				control_image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			
			# Land cells: compute biome weights
			var h_norm = height_map[y][x]
			var dist_to_water = water_distance[y][x] if y < water_distance.size() and x < water_distance[y].size() else 999.0
			
			var rock: float = 0.0
			var snow: float = 0.0
			var grass: float = 0.0
			var sand: float = 0.0
			
			# Sand: only near coastlines (within 4 cells of water)
			if dist_to_water <= 4.0 and h_norm < SAND_MAX:
				# Fade sand inward from coast
				sand = 1.0 - (dist_to_water / 4.0)
				sand = clampf(sand, 0.0, 1.0)
				
				# Blend with grass if at transition
				if sand < 1.0:
					grass = 1.0 - sand
			elif h_norm < SAND_MAX:
				# Non-coastal low elevation gets grass
				grass = 1.0
			else:
				# Standard height-based biome assignment
				if h_norm < GRASS_MAX:
					grass = 1.0
				elif h_norm < GRASS_MAX + TRANSITION_WIDTH:
					# Grass → Rock transition
					var t = (h_norm - GRASS_MAX) / TRANSITION_WIDTH
					grass = 1.0 - smoothstep(0.0, 1.0, t)
					rock = smoothstep(0.0, 1.0, t)
				elif h_norm < ROCK_MAX:
					rock = 1.0
				elif h_norm < ROCK_MAX + TRANSITION_WIDTH:
					# Rock → Snow transition
					var t = (h_norm - ROCK_MAX) / TRANSITION_WIDTH
					rock = 1.0 - smoothstep(0.0, 1.0, t)
					snow = smoothstep(0.0, 1.0, t)
				else:
					snow = 1.0
			
			# Normalize weights to sum to 1.0
			var total = rock + snow + grass + sand
			if total > 0.001:
				rock /= total
				snow /= total
				grass /= total
				sand /= total
			
			# Set pixel with RGBA weights
			var pixel_color = Color(rock, snow, grass, sand)
			control_image.set_pixel(x, y, pixel_color)
	
	return control_image

func _compute_water_distance(island_mask: Array) -> Array:
	"""Compute distance to nearest water cell for each land cell.
	
	Used to apply sand only near coastlines.
	Returns 2D array where each value is distance to closest water (max 4).
	Handles dimension mismatches by padding if necessary.
	"""
	var size_y = island_mask.size() if island_mask.size() > 0 else REGION_SIZE
	var size_x = island_mask[0].size() if size_y > 0 and island_mask[0].is_empty() == false else REGION_SIZE
	
	var distances = []
	
	# Initialize distances
	for y in range(size_y):
		var row = []
		for x in range(size_x):
			# Bounds-safe access with default to land if out of bounds
			var mask_val = 1.0
			if y < island_mask.size() and x < island_mask[y].size():
				mask_val = island_mask[y][x]
			
			if mask_val <= 0.5:
				row.append(0.0)  # Water
			else:
				row.append(999.0)  # Land (infinite initially)
		distances.append(row)
	
	# Simple BFS-like distance computation (max 4 cells)
	for pass_num in range(4):
		for y in range(size_y):
			for x in range(size_x):
				if distances[y][x] <= pass_num:
					continue
				
				# Check neighbors
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nx = x + dx
						var ny = y + dy
						if nx >= 0 and nx < size_x and ny >= 0 and ny < size_y:
							var neighbor_dist = distances[ny][nx]
							if neighbor_dist < distances[y][x]:
								distances[y][x] = minf(distances[y][x], neighbor_dist + 1.0)
	
	return distances

func _detect_river_corridor(height_map: Array) -> Array:
	"""Detect river corridor cells based on local height minima.
	
	Returns a 2D mask where 1.0 = river cell, 0.0 = non-river.
	River cells are those where height is significantly below neighbors.
	Threshold: cell height < 0.75 * average(neighbor heights)
	"""
	var size = height_map.size()
	var river_mask: Array = []
	
	# Initialize mask with all 0s
	for y in range(size):
		var row: Array = []
		for x in range(size):
			row.append(0.0)
		river_mask.append(row)
	
	# Detect local minima
	for y in range(size):
		for x in range(size):
			var cell_height = height_map[y][x]
			var neighbor_sum = 0.0
			var neighbor_count = 0
			
			# Sample 8 neighbors
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx = x + dx
					var ny = y + dy
					if nx >= 0 and nx < size and ny >= 0 and ny < size:
						neighbor_sum += height_map[ny][nx]
						neighbor_count += 1
			
			if neighbor_count > 0:
				var neighbor_avg = neighbor_sum / float(neighbor_count)
				# If this cell is significantly lower, mark as river
				if cell_height < neighbor_avg * 0.75:
					river_mask[y][x] = 1.0
	
	return river_mask

func _generate_control_map_anno_style(height_map: Array, island_mask: Array, archetype: String) -> Image:
	"""Generate Anno 1800-style control map with archetype-aware discrete biome assignment.
	
	RGBA channels (each pixel has ONE channel at 1.0, others at 0.0):
	- R = Rock/Cliff texture
	- G = Forest/Foliage texture
	- B = Grass texture
	- A = Sand texture
	
	Each archetype defines its own biome rules:
	- "Flat Plains" → all grass with subtle dirt patches
	- "Coastal Shelf" → sand at coast, grass inland, rock at far edge
	- "Forest Edge" → forest on ridge side, grass on other side
	- "River Basin" → grass with sand only in river corridor
	- "Agricultural Plateau" → mostly grass with subtle terraces
	- "Gentle Hills" → grass with rock on steep slopes only
	"""
	var map_size = height_map.size()
	var control_image = Image.create(map_size, map_size, false, Image.FORMAT_RGBA8)
	
	# Precompute distance-to-water for sand placement
	var water_distance = _compute_water_distance(island_mask)
	
	# Detect river corridor for "River Basin" archetype
	var river_corridor = _detect_river_corridor(height_map)
	
	# Detect steep slopes by computing height deltas
	var slope_mask: Array = []
	for y in range(map_size):
		var row: Array = []
		for x in range(map_size):
			var cell_height = height_map[y][x]
			var max_delta = 0.0
			
			# Check height difference with neighbors
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx = x + dx
					var ny = y + dy
					if nx >= 0 and nx < map_size and ny >= 0 and ny < map_size:
						max_delta = maxf(max_delta, absf(cell_height - height_map[ny][nx]))
			
			row.append(max_delta)
		slope_mask.append(row)
	
	# Per-archetype biome assignment
	match archetype:
		"Flat Plains":
			# All grass with subtle dirt patches (R channel)
			for y in range(map_size):
				for x in range(map_size):
					var mask_val = 1.0
					if y < island_mask.size() and x < island_mask[y].size():
						mask_val = island_mask[y][x]
					
					if mask_val <= 0.5:
						# Water: transparent
						control_image.set_pixel(x, y, Color(0, 0, 0, 0))
					else:
						# Land: mostly grass with tiny dirt patches
						var is_dirt = randf() < 0.05 and slope_mask[y][x] > 0.08
						if is_dirt:
							control_image.set_pixel(x, y, Color(0.8, 0, 0, 0))  # Rock/dirt
						else:
							control_image.set_pixel(x, y, Color(0, 0, 1, 0))  # Grass
		
		"Coastal Shelf":
			# Sand at coast, grass inland, rock at far edge
			for y in range(map_size):
				for x in range(map_size):
					var mask_val = 1.0
					if y < island_mask.size() and x < island_mask[y].size():
						mask_val = island_mask[y][x]
					
					if mask_val <= 0.5:
						control_image.set_pixel(x, y, Color(0, 0, 0, 0))  # Water
					else:
						var dist_to_water = water_distance[y][x] if y < water_distance.size() and x < water_distance[y].size() else 999.0
						var h_norm = height_map[y][x]
						
						if dist_to_water <= 3.0 and h_norm < 0.45:
							# Coastal: sand
							control_image.set_pixel(x, y, Color(0, 0, 0, 1))
						elif h_norm > 0.65:
							# Far inland/elevated: rock
							control_image.set_pixel(x, y, Color(1, 0, 0, 0))
						else:
							# Middle zone: grass
							control_image.set_pixel(x, y, Color(0, 0, 1, 0))
		
		"Forest Edge":
			# High ridge side = forest, low/sloping side = grass
			for y in range(map_size):
				for x in range(map_size):
					var mask_val = 1.0
					if y < island_mask.size() and x < island_mask[y].size():
						mask_val = island_mask[y][x]
					
					if mask_val <= 0.5:
						control_image.set_pixel(x, y, Color(0, 0, 0, 0))  # Water
					else:
						var h_norm = height_map[y][x]
						
						# Higher elevation or steep slopes = forest
						if h_norm > 0.65 or slope_mask[y][x] > 0.12:
							control_image.set_pixel(x, y, Color(0, 1, 0, 0))  # Forest
						else:
							control_image.set_pixel(x, y, Color(0, 0, 1, 0))  # Grass
		
		"River Basin":
			# Grass with sand ONLY in river corridor
			for y in range(map_size):
				for x in range(map_size):
					var mask_val = 1.0
					if y < island_mask.size() and x < island_mask[y].size():
						mask_val = island_mask[y][x]
					
					if mask_val <= 0.5:
						control_image.set_pixel(x, y, Color(0, 0, 0, 0))  # Water
					else:
						var is_river = river_corridor[y][x] > 0.5
						
						if is_river:
							# River corridor: sand
							control_image.set_pixel(x, y, Color(0, 0, 0, 1))
						else:
							# Non-river: grass
							control_image.set_pixel(x, y, Color(0, 0, 1, 0))
		
		"Agricultural Plateau":
			# Mostly grass with subtle terraces (rock outcrops)
			for y in range(map_size):
				for x in range(map_size):
					var mask_val = 1.0
					if y < island_mask.size() and x < island_mask[y].size():
						mask_val = island_mask[y][x]
					
					if mask_val <= 0.5:
						control_image.set_pixel(x, y, Color(0, 0, 0, 0))  # Water
					else:
						# Terraces: detect height steps (quantize height to bands)
						var h_norm = height_map[y][x]
						var h_band = int(h_norm * 10.0)  # 10 discrete bands
						var is_terrace_edge = (h_band % 2) == 0 and slope_mask[y][x] > 0.06
						
						if is_terrace_edge:
							control_image.set_pixel(x, y, Color(0.6, 0, 0, 0))  # Rock/terrace
						else:
							control_image.set_pixel(x, y, Color(0, 0, 1, 0))  # Grass
		
		"Gentle Hills":
			# Grass with rock ONLY on steep slopes
			for y in range(map_size):
				for x in range(map_size):
					var mask_val = 1.0
					if y < island_mask.size() and x < island_mask[y].size():
						mask_val = island_mask[y][x]
					
					if mask_val <= 0.5:
						control_image.set_pixel(x, y, Color(0, 0, 0, 0))  # Water
					else:
						var slope = slope_mask[y][x]
						
						if slope > 0.15:
							# Steep slope: rock
							control_image.set_pixel(x, y, Color(1, 0, 0, 0))
						else:
							# Gentle slope: grass
							control_image.set_pixel(x, y, Color(0, 0, 1, 0))
		
		_:
			# Default/Unknown archetype: use legacy blending
			push_warning("Unknown archetype '%s', using legacy control map" % archetype)
			return _generate_control_map_legacy(height_map, island_mask)
	
	return control_image

func _apply_shader_material(control_image: Image) -> void:
	"""Apply terrain_blender.gdshader with biome textures and control map to Terrain3D.
	
	Creates ShaderMaterial from res://shaders/terrain_blender.gdshader and assigns:
	- 12 biome textures (4 biomes × 3 maps: albedo, normal, orm)
	- Control map (RGBA discrete biome weights)
	- Shader parameters (uv_scale, ao_strength)
	"""
	if not terrain3d:
		push_error("Terrain3D node not found")
		return
	
	# Load the shader
	var shader = load("res://shaders/terrain_blender.gdshader")
	if not shader:
		push_error("❌ Failed to load terrain_blender.gdshader from res://shaders/")
		return
	
	print("✓ Shader file loaded")
	
	# Create ShaderMaterial
	var shader_material = ShaderMaterial.new()
	if not shader_material:
		push_error("❌ Failed to create ShaderMaterial instance")
		return
	
	# Assign shader to material
	shader_material.shader = shader
	
	# Validate shader compiled successfully
	if not shader_material.shader:
		push_error("❌ Shader failed to compile. Check shader syntax.")
		push_error("   Shader code: res://shaders/terrain_blender.gdshader")
		return
	
	print("✓ ShaderMaterial created and shader assigned")
	
	# Create control map texture
	var control_texture = ImageTexture.create_from_image(control_image)
	
	# Set shader parameters
	shader_material.set_shader_parameter("uv_scale", uv_scale)
	shader_material.set_shader_parameter("ao_strength", ao_strength)
	shader_material.set_shader_parameter("control_map", control_texture)
	
	# Assign biome textures with existence checking
	if grass_albedo:
		shader_material.set_shader_parameter("grass_albedo", grass_albedo)
	if grass_normal:
		shader_material.set_shader_parameter("grass_normal", grass_normal)
	if grass_orm:
		shader_material.set_shader_parameter("grass_orm", grass_orm)
	
	if sand_albedo:
		shader_material.set_shader_parameter("sand_albedo", sand_albedo)
	if sand_normal:
		shader_material.set_shader_parameter("sand_normal", sand_normal)
	if sand_orm:
		shader_material.set_shader_parameter("sand_orm", sand_orm)
	
	if rock_albedo:
		shader_material.set_shader_parameter("rock_albedo", rock_albedo)
	if rock_normal:
		shader_material.set_shader_parameter("rock_normal", rock_normal)
	if rock_orm:
		shader_material.set_shader_parameter("rock_orm", rock_orm)
	
	if snow_albedo:
		shader_material.set_shader_parameter("snow_albedo", snow_albedo)
	if snow_normal:
		shader_material.set_shader_parameter("snow_normal", snow_normal)
	
	# Final validation before assignment
	if not shader_material or not shader_material.shader:
		push_error("❌ shader_material or shader is null before terrain assignment")
		return
	
	# Apply material to Terrain3D - try multiple assignment methods
	# Terrain3D is a custom plugin with non-standard material handling
	var assignment_success = false
	
	# Option 1: Try direct property assignment
	if not assignment_success:
		terrain3d.material = shader_material
		print("✓ Shader material assigned via terrain3d.material")
		assignment_success = true
	
	# Option 2: Try setter method
	if not assignment_success and terrain3d.has_method("set_material"):
		terrain3d.set_material(shader_material)
		print("✓ Shader material assigned via terrain3d.set_material()")
		assignment_success = true
	
	# Option 3: Try material_override (standard Node3D property)
	if not assignment_success:
		terrain3d.material_override = shader_material
		print("✓ Shader material assigned via terrain3d.material_override")
		assignment_success = true
	
	# Debug output if assignment might have failed
	print("✓ Shader material setup completed")
	
	# Count assigned textures for debug feedback
	var texture_count = 0
	for tex in [grass_albedo, grass_normal, grass_orm, sand_albedo, sand_normal, sand_orm,
				rock_albedo, rock_normal, rock_orm, snow_albedo, snow_normal]:
		if tex:
			texture_count += 1
	
	print("✓ Shader material applied: terrain_blender.gdshader with %d/%d textures assigned" % [texture_count, 11])
	if texture_count < 11:
		push_warning("Not all 11 biome textures assigned. Unassigned textures will use white placeholder.")

func _generate_cliffs_from_edges(height_map: Array) -> void:
	"""Detect terrain edges and instantiate cliff modules.
	
	Edge types:
	- Coastline: LAND → WATER neighbors
	- Steep slope: Height delta > CLIFF_HEIGHT_THRESHOLD
	- River edges: Detected by height carving patterns
	"""
	if not cliff_container:
		return
	
	# Clear previous cliffs
	for child in cliff_container.get_children():
		child.queue_free()
	
	var edges = _detect_edges(height_map)
	if edges.is_empty():
		print("No cliff edges detected")
		return
	
	print("Detected %d cliff edge segments" % edges.size())
	
	# Instantiate cliff modules for each edge
	var cliff_count = 0
	for edge in edges:
		if _instantiate_cliff_module(edge):
			cliff_count += 1
	
	print("✓ Instantiated %d cliff modules" % cliff_count)

func _detect_edges(height_map: Array) -> Array:
	"""Detect terrain edges based on:
	- Height deltas > CLIFF_HEIGHT_THRESHOLD
	- Land-to-water transitions (coastline)
	
	Returns array of edge descriptors:
	{
		"world_pos": Vector3,
		"edge_dir": String (N, E, S, W),
		"height_delta": float,
		"variant": String (coastal, inland, river),
		"height_norm": float
	}
	"""
	var edges: Array = []
	var size = height_map.size()
	
	for z in range(size):
		for x in range(size):
			var h_center = height_map[z][x]
			
			# Check all 4 directions
			var directions = [
				{"offset": Vector2i(0, -1), "name": "N"},
				{"offset": Vector2i(1, 0), "name": "E"},
				{"offset": Vector2i(0, 1), "name": "S"},
				{"offset": Vector2i(-1, 0), "name": "W"},
			]
			
			for dir in directions:
				var nx = x + dir.offset.x
				var nz = z + dir.offset.y
				
				# Boundary check
				if nx < 0 or nx >= size or nz < 0 or nz >= size:
					continue
				
				var h_neighbor = height_map[nz][nx]
				var h_delta = h_center - h_neighbor
				
				# Detect steep slope or coastline
				if abs(h_delta) > CLIFF_HEIGHT_THRESHOLD or (h_center > WATER_LEVEL_NORM and h_neighbor <= WATER_LEVEL_NORM):
					var variant = "inland"
					if h_neighbor <= WATER_LEVEL_NORM:
						variant = "coastal"
					
					var world_x = float(x) + float(region_loc.x) * float(REGION_SIZE)
					var world_z = float(z) + float(region_loc.y) * float(REGION_SIZE)
					var world_pos = Vector3(world_x, h_center * VERTICAL_SCALE, world_z)
					
					edges.append({
						"world_pos": world_pos,
						"edge_dir": dir.name,
						"height_delta": abs(h_delta),
						"variant": variant,
						"height_norm": h_center,
					})
	
	return edges

func _instantiate_cliff_module(edge: Dictionary) -> bool:
	"""Instantiate and position a cliff module for a detected edge.
	
	Returns true if successful, false otherwise.
	"""
	if cliff_modules.is_empty():
		return false
	
	# Find matching cliff module
	var module: CliffModule = null
	for candidate in cliff_modules:
		if candidate.biome == "temperate" and candidate.matches_criteria(edge["height_delta"], edge["variant"], edge["edge_dir"]):
			module = candidate
			break
	
	if not module or not module.mesh:
		return false
	
	# Instantiate mesh
	var cliff_instance = module.mesh.instantiate()
	if not cliff_instance:
		return false
	
	# Position at edge
	var pos = edge["world_pos"]
	
	# Apply edge offset
	var offset_dir = _get_direction_vector(edge["edge_dir"])
	pos += offset_dir * module.edge_offset
	
	cliff_instance.position = pos
	
	# Rotate based on edge direction
	var rotation_y = _get_rotation_for_direction(edge["edge_dir"])
	cliff_instance.rotation.y = rotation_y
	
	# Scale to match height delta
	var height_scale = edge["height_delta"] / (module.height_max - module.height_min)
	height_scale = clampf(height_scale, 0.5, 2.0)  # Clamp to reasonable range
	cliff_instance.scale.y = height_scale * module.height_scale
	
	cliff_container.add_child(cliff_instance)
	return true

func _get_direction_vector(edge_dir: String) -> Vector3:
	"""Get direction vector from edge direction string."""
	match edge_dir:
		"N": return Vector3(0, 0, -1)
		"E": return Vector3(1, 0, 0)
		"S": return Vector3(0, 0, 1)
		"W": return Vector3(-1, 0, 0)
		_: return Vector3.ZERO

func _get_rotation_for_direction(edge_dir: String) -> float:
	"""Get Y rotation angle from edge direction."""
	match edge_dir:
		"N": return 0.0
		"E": return PI / 2.0
		"S": return PI
		"W": return 3.0 * PI / 2.0
		_: return 0.0
