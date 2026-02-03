extends Node3D

# Import HTerrain classes
const HTerrainData = preload("res://addons/zylann.hterrain/hterrain_data.gd")

# HTerrain size and configuration
@export var TERRAIN_SIZE: int = 1025  # Must be power-of-2 + 1 (257, 513, 1025)
@export var VERTICAL_SCALE: float = 200

# Reference to the HTerrain node
var hterrain: Node
var hterrain_data: Resource  # HTerrainData

# Water configuration
@export var WATER_LEVEL_NORM: float = 0.25
var water_meshes: Array[MeshInstance3D] = []  # [shallow, base, deep]
var water_materials: Array[Material] = []

# Biome height ranges for splatmap generation
@export var SAND_MAX: float = 0.30
@export var GRASS_MIN: float = 0.30
@export var GRASS_MAX: float = 0.55
@export var ROCK_MIN: float = 0.55
@export var ROCK_MAX: float = 0.85
@export var SNOW_MIN: float = 0.85
@export var TRANSITION_WIDTH: float = 0.05

# Reference to the Plot Generator
var plot_generator: Node3D

# Water texture uniforms (for ocean shader materials)
@export var ocean_albedo: Texture2D
@export var ocean_normal: Texture2D

# Plot cycling
var PLOT_SIZES: Array = [12, 16, 20]
var current_size_index: int = 1
var current_seed: int = 42
var current_archetype: String = ""
var current_water_level: float = 0.0

# ============================================================================
# BUILDABILITY LAYER - gameplay grid support
# ============================================================================

# Buildability thresholds (in degrees)
@export var BUILDABLE_SLOPE_MAX: float = 10.0     # Fully buildable (houses, industry)
@export var CONDITIONAL_SLOPE_MAX: float = 18.0   # Roads, farms only
# Above CONDITIONAL_SLOPE_MAX = non-buildable (cliffs, mountains)

# Gameplay grid resolution (updated when terrain generates)
var gameplay_grid_size: int = 16  # 12-20 depending on archetype

# Cached slope data (sampled at gameplay grid resolution)
var slope_grid: Array = []  # [z][x] -> slope in degrees

# Debug visualization
@export var show_buildability_debug: bool = false
var debug_overlay: MeshInstance3D = null

func _ready() -> void:
	set_process_input(true)
	call_deferred("_setup_references")

func _setup_terrain_shader() -> void:
	"""Configure HTerrain to use Classic4 shader with enhanced visuals."""
	if not hterrain:
		return
	
	# Set shader type to Classic4 (triplanar + better blending)
	# Available types: "Classic4", "Classic4Lite", "LowPoly", "Array", "MultiSplat16", "Custom"
	
	if hterrain.has_method("set_shader_type"):
		hterrain.set_shader_type("Classic4")
		print("✓ Enabled Classic4 shader")
		
		# Wait for shader to be loaded then configure parameters
		await get_tree().process_frame
		
		# Enable triplanar for steep slopes
		if hterrain.has_method("set_shader_param"):
			hterrain.set_shader_param("u_triplanar_enabled", true)
			hterrain.set_shader_param("u_triplanar_sharpness", 8.0)
			print("✓ Enabled triplanar mapping")
			
			# Improve texture detail
			hterrain.set_shader_param("u_depth_blending", true)
			print("✓ Enabled depth blending")
		
		# Reduce terrain shininess (make ground matte, not reflective)
		_reduce_terrain_shininess()
	else:
		push_warning("HTerrain doesn't support set_shader_type - configure shader manually in inspector")

func _reduce_terrain_shininess() -> void:
	"""Make terrain less reflective/shiny by adjusting shader parameters."""
	if not hterrain:
		return
	
	await get_tree().process_frame
	
	if hterrain.has_method("set_shader_param"):
		# Reduce specular/shininess
		hterrain.set_shader_param("u_ground_specular", 0.1)
		# Increase roughness multiplier
		hterrain.set_shader_param("u_roughness_scale", 1.5)
		print("✓ Reduced terrain shininess")

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
	
	# Find HTerrain in scene
	hterrain = find_child("HTerrain", true, false)
	if not hterrain:
		push_error("HTerrain not found in scene tree")
		return
	else:
		print("✓ Found HTerrain")
	
	# Get HTerrainData resource
	hterrain_data = hterrain.get_data()
	if not hterrain_data:
		push_error("HTerrainData not found on HTerrain node")
		return
	else:
		print("✓ Found HTerrainData")
	
	# Enable Classic4 shader for better visuals
	_setup_terrain_shader()
	
	# Ensure terrain data is properly initialized with all channels
	var current_resolution = hterrain_data.get_resolution()
	if current_resolution != TERRAIN_SIZE:
		print("Initializing terrain resolution to %dx%d..." % [TERRAIN_SIZE, TERRAIN_SIZE])
		# Call _edit_load_default to properly initialize all maps
		hterrain_data._edit_load_default()
		if hterrain_data.get_resolution() != TERRAIN_SIZE:
			hterrain_data.resize(TERRAIN_SIZE)
	else:
		# Even if resolution matches, ensure all maps exist
		var height_check = hterrain_data.get_image(HTerrainData.CHANNEL_HEIGHT)
		if not height_check:
			print("Initializing terrain maps...")
			hterrain_data._edit_load_default()
	
	# Verify splatmap exists, create if needed
	var splat_check = hterrain_data.get_image(HTerrainData.CHANNEL_SPLAT)
	if not splat_check:
		print("Creating splatmap...")
		# Create default splatmap (red channel = first texture)
		var splat_image = Image.create(TERRAIN_SIZE, TERRAIN_SIZE, false, Image.FORMAT_RGBA8)
		splat_image.fill(Color(1, 0, 0, 0))  # R=1 means first texture slot (grass)
		
		# Get the internal map structure and assign the image
		var splat_maps = hterrain_data._maps[HTerrainData.CHANNEL_SPLAT]
		if splat_maps.size() > 0:
			splat_maps[0].image = splat_image
			splat_maps[0].modified = true
			print("✓ Splatmap created in memory")
		else:
			push_error("Splatmap array not initialized")

	# Setup water plane
	_setup_water_layers()
	
	_set_plot_size(PLOT_SIZES[current_size_index])
	current_seed = randi()
	generate_terrain()

func _setup_water_layers() -> void:
	"""Create calm, strategy-game-style water plane with subtle animation.
	
	Water is SEPARATE from HTerrain and purely visual:
	- Single PlaneMesh covering terrain area
	- Calm shader with slow normal map animation
	- No vertex displacement
	- High transparency for readability
	- Positioned at constant Y level
	"""
	water_meshes.clear()
	water_materials.clear()
	
	# Create single calm water layer
	var water_layer = find_child("CalmWater", true, false)
	
	if not water_layer:
		water_layer = MeshInstance3D.new()
		water_layer.name = "CalmWater"
		add_child(water_layer)
	else:
		water_layer.mesh = null
		water_layer.set_surface_override_material(0, null)
	
	# Create plane mesh larger than terrain
	var plane = PlaneMesh.new()
	var plane_size = float(TERRAIN_SIZE) * 1.2
	plane.size = Vector2(plane_size, plane_size)
	plane.subdivide_width = 1  # Minimal subdivisions (no vertex displacement)
	plane.subdivide_depth = 1
	water_layer.mesh = plane
	
	# Load strategy ocean shader
	var shader = load("res://shaders/strategy_ocean.gdshader")
	if shader:
		var material = ShaderMaterial.new()
		material.shader = shader
		
		# Load ocean textures from assets/materials
		var ocean_deep_alb = load("res://assets/materials/ocean_deep_albedo.png")
		var ocean_base_alb = load("res://assets/materials/ocean_base_albedo.png")
		var ocean_shallow_alb = load("res://assets/materials/ocean_shallow_albedo.png")
		var ocean_normal1 = load("res://assets/materials/ocean_normal_1.png")
		var ocean_normal2 = load("res://assets/materials/ocean_normal_2.png")
		var foam_mask_tex = load("res://assets/materials/ocean_foam_mask.png")
		
		# Assign textures
		if ocean_deep_alb:
			material.set_shader_parameter("ocean_deep_albedo", ocean_deep_alb)
		if ocean_base_alb:
			material.set_shader_parameter("ocean_base_albedo", ocean_base_alb)
		if ocean_shallow_alb:
			material.set_shader_parameter("ocean_shallow_albedo", ocean_shallow_alb)
		if ocean_normal1:
			material.set_shader_parameter("ocean_normal_1", ocean_normal1)
		if ocean_normal2:
			material.set_shader_parameter("ocean_normal_2", ocean_normal2)
		if foam_mask_tex:
			material.set_shader_parameter("foam_mask", foam_mask_tex)
		
		print("✓ Ocean textures loaded")
		
		# Set water plane Y to match current water level
		material.set_shader_parameter("water_plane_y", current_water_level)
		
		# Depth parameters (adjust based on VERTICAL_SCALE)
		material.set_shader_parameter("shallow_depth", 2.0)
		material.set_shader_parameter("deep_depth", 15.0)
		material.set_shader_parameter("depth_fade_power", 1.2)
		
		# Animation parameters (slowed down)
		material.set_shader_parameter("normal_1_speed", 0.008)
		material.set_shader_parameter("normal_1_direction", Vector2(1.0, 0.3))
		material.set_shader_parameter("normal_2_speed", 0.005)
		material.set_shader_parameter("normal_2_direction", Vector2(-0.5, 1.0))
		material.set_shader_parameter("foam_speed", 0.012)
		material.set_shader_parameter("foam_direction", Vector2(0.8, 0.6))
		
		# Visual properties
		material.set_shader_parameter("uv_scale", 0.05)
		material.set_shader_parameter("normal_strength", 0.8)
		material.set_shader_parameter("foam_intensity", 0.6)
		material.set_shader_parameter("foam_cutoff", 0.4)
		material.set_shader_parameter("foam_color", Color(1.0, 1.0, 1.0, 1.0))
		
		# Ocean color tints (dark blue to turquoise gradient)
		material.set_shader_parameter("deep_tint", Color(0.02, 0.15, 0.35, 1.0))     # Dark blue
		material.set_shader_parameter("base_tint", Color(0.08, 0.35, 0.55, 1.0))     # Medium blue
		material.set_shader_parameter("shallow_tint", Color(0.25, 0.65, 0.75, 1.0))  # Turquoise
		
		# Material properties
		material.set_shader_parameter("deep_roughness", 0.15)
		material.set_shader_parameter("shallow_roughness", 0.35)
		material.set_shader_parameter("specular_strength", 0.5)
		material.set_shader_parameter("water_alpha", 0.92)
		
		water_layer.set_surface_override_material(0, material)
		water_materials.append(material)
		print("✓ Strategy ocean material loaded")
	else:
		push_error("Strategy ocean shader not found: res://shaders/strategy_ocean.gdshader")
		water_materials.append(null)
	
	water_layer.set_meta("y_offset", 0.0)
	water_meshes.append(water_layer)
	
	print("✓ Calm water layer setup complete")

func _update_water_layer_positions() -> void:
	"""Position water plane at current water level.
	
	Water is positioned at constant Y (world height).
	Centered on terrain in X/Z but never moves horizontally.
	"""
	if water_meshes.is_empty():
		return
	
	var terrain_center = Vector3(
		float(TERRAIN_SIZE) / 2.0,
		current_water_level,
		float(TERRAIN_SIZE) / 2.0
	)
	
	for water_layer in water_meshes:
		var y_offset = water_layer.get_meta("y_offset", 0.0)
		water_layer.position = terrain_center + Vector3(0, y_offset, 0)

func _set_plot_size(size: int) -> void:
	"""Set the plot grid resolution on the generator."""
	if plot_generator:
		plot_generator.GRID_RESOLUTION = size
		print("📐 Set plot size to %dx%d" % [size, size])

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				print("🔄 R pressed - regenerating...")
				generate_terrain()
				get_tree().root.set_input_as_handled()
			
			KEY_T:
				print("📋 T pressed - cycling plot size...")
				current_size_index = (current_size_index + 1) % PLOT_SIZES.size()
				var size: int = PLOT_SIZES[current_size_index]
				_set_plot_size(size)
				current_seed = randi()
				generate_terrain()
				get_tree().root.set_input_as_handled()
			
			KEY_C:
				print("🏝️  C pressed - cycling archetype...")
				current_seed = randi()
				generate_terrain()
				get_tree().root.set_input_as_handled()
			
			KEY_B:
				print("🎨 B pressed - toggling buildability overlay...")
				toggle_buildability_debug()
				get_tree().root.set_input_as_handled()

func generate_terrain() -> void:
	"""Generate heightmap from plot_generator and apply to HTerrain."""
	if not plot_generator:
		push_error("PlotGenerator is null")
		return

	if not plot_generator.has_method("generate_plot"):
		push_error("PlotGenerator doesn't have generate_plot method")
		return

	print("Calling generate_plot()...")
	var result = plot_generator.generate_plot(current_seed)

	if not result or not result.get("success"):
		push_error("generate_plot() failed")
		return

	var height_map = result["height_map"]
	if height_map.is_empty():
		push_error("height_map is empty")
		return

	var island_mask = result.get("island_mask", [])
	current_archetype = result.get("archetype", "Unknown")
	
	print("✓ Generated archetype: %s (size: %dx%d)" % [current_archetype, height_map.size(), height_map[0].size() if height_map.size() > 0 else 0])
	
	_apply_to_hterrain(height_map, island_mask)

func _apply_to_hterrain(height_map: Array, island_mask: Array) -> void:
	"""Apply heightmap and splatmap to HTerrain."""
	if not hterrain_data:
		push_error("HTerrainData not available")
		return
	
	# Upscale to HTerrain resolution
	var scaled_map: Array = _upscale_heightmap(height_map, TERRAIN_SIZE)
	var scaled_mask: Array = _upscale_heightmap(
		island_mask if island_mask.size() > 0 else _create_full_land_mask(height_map), 
		TERRAIN_SIZE
	)
	
	# Apply light smoothing
	scaled_map = _smooth_heightmap(scaled_map, 2)
	
	# Calculate water level
	current_water_level = WATER_LEVEL_NORM * VERTICAL_SCALE
	
	# Debug info
	var min_height = 999.0
	var max_height = 0.0
	for row in scaled_map:
		for h in row:
			min_height = minf(min_height, h)
			max_height = maxf(max_height, h)
	
	print("Writing %dx%d heights to HTerrain..." % [TERRAIN_SIZE, TERRAIN_SIZE])
	print("Archetype: %s | Water level: %.2f" % [current_archetype, current_water_level])
	print("Height range: %.3f - %.3f (norm) → %.2f - %.2f (world)" % [min_height, max_height, min_height * VERTICAL_SCALE, max_height * VERTICAL_SCALE])
	
	# Apply heights to HTerrain using Image-based API
	var height_image: Image = hterrain_data.get_image(HTerrainData.CHANNEL_HEIGHT)
	if not height_image:
		push_error("Failed to get height image from HTerrain")
		return
	
	# Ensure image is the correct size
	if height_image.get_width() != TERRAIN_SIZE or height_image.get_height() != TERRAIN_SIZE:
		push_warning("Height image size mismatch. Resizing HTerrainData...")
		hterrain_data.resize(TERRAIN_SIZE)
		height_image = hterrain_data.get_image(HTerrainData.CHANNEL_HEIGHT)
	
	# Write heights to image (HTerrain stores heights as red channel floats)
	for z in range(TERRAIN_SIZE):
		for x in range(TERRAIN_SIZE):
			var h_norm = scaled_map[z][x]
			var h_world = h_norm * VERTICAL_SCALE
			# HTerrain stores height in the red channel as a float
			height_image.set_pixel(x, z, Color(h_world, 0, 0))
	
	# Notify HTerrain of changes
	var modified_region = Rect2(0, 0, TERRAIN_SIZE, TERRAIN_SIZE)
	hterrain_data.notify_region_change(modified_region, HTerrainData.CHANNEL_HEIGHT)
	
	print("✓ Heights applied to HTerrain")
	
	# Generate and apply splatmap (no need to check - resize ensures it exists)
	var splatmap = _generate_splatmap(scaled_map, scaled_mask)
	_apply_splatmap(splatmap)
	
	# Update water
	_update_water_layer_positions()
	
	# Compute buildability layer
	_compute_buildability_layer(scaled_map)
	
	print("✓ Terrain generation complete")

func _generate_splatmap(height_map: Array, island_mask: Array) -> Image:
	"""Generate RGBA splatmap for HTerrain texture blending.
	
	HTerrain ground texture slots:
	- R (slot 0) = Grass
	- G (slot 1) = Sand
	- B (slot 2) = Rock
	- A (slot 3) = Snow
	"""
	var size = height_map.size()
	var splatmap = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var water_level = WATER_LEVEL_NORM
	
	for y in range(size):
		for x in range(size):
			var height_norm = height_map[y][x]
			var height = height_norm * VERTICAL_SCALE
			var is_land = island_mask[y][x] > 0.5
			
			var r = 0.0  # Grass
			var g = 0.0  # Sand
			var b = 0.0  # Rock
			var a = 0.0  # Snow
			
			# Calculate local slope for slope-based texturing
			var local_slope = _compute_local_slope_at(x, y, height_map)
			
			if is_land:
				# Discrete biome assignment
				if height_norm < SAND_MAX:
					g = 1.0  # Pure sand
				elif height_norm >= GRASS_MIN and height_norm < GRASS_MAX:
					r = 1.0  # Pure grass
				elif height_norm >= ROCK_MIN and height_norm < ROCK_MAX:
					b = 1.0  # Pure rock
				elif height_norm >= SNOW_MIN:
					a = 1.0  # Pure snow
				else:
					# Transition zones - blend between biomes
					if height_norm >= SAND_MAX and height_norm < GRASS_MIN:
						# Sand to grass transition
						var t = (height_norm - SAND_MAX) / (GRASS_MIN - SAND_MAX)
						g = 1.0 - t
						r = t
					elif height_norm >= GRASS_MAX and height_norm < ROCK_MIN:
						# Grass to rock transition
						var t = (height_norm - GRASS_MAX) / (ROCK_MIN - GRASS_MAX)
						r = 1.0 - t
						b = t
					elif height_norm >= ROCK_MAX and height_norm < SNOW_MIN:
						# Rock to snow transition
						var t = (height_norm - ROCK_MAX) / (SNOW_MIN - ROCK_MAX)
						b = 1.0 - t
						a = t
			else:
				# Water - use sand texture
				g = 1.0
			
			# Slope-based rock override: steep slopes show rock regardless of height
			if local_slope > 25.0 and height_norm > SAND_MAX:
				var slope_blend = clampf((local_slope - 25.0) / 15.0, 0.0, 1.0)
				# Blend toward rock (blue channel)
				r = r * (1.0 - slope_blend * 0.7)
				g = g * (1.0 - slope_blend * 0.7)
				b = max(b, slope_blend)
				a = a * (1.0 - slope_blend * 0.5)
			
			# Convert to 0-255 and write to image
			var pixel = Color(r, g, b, a)
			splatmap.set_pixel(x, y, pixel)
	
	return splatmap

func _compute_local_slope_at(x: int, y: int, height_map: Array) -> float:
	"""Compute slope in degrees at a specific position."""
	var size = height_map.size()
	if x <= 0 or x >= size - 1 or y <= 0 or y >= size - 1:
		return 0.0
	
	var h_center = height_map[y][x]
	var h_right = height_map[y][x + 1]
	var h_left = height_map[y][x - 1]
	var h_down = height_map[y + 1][x]
	var h_up = height_map[y - 1][x]
	
	var dx = (h_right - h_left) * 0.5 * VERTICAL_SCALE
	var dz = (h_down - h_up) * 0.5 * VERTICAL_SCALE
	var grid_spacing = 512.0 / float(size)
	
	var gradient = sqrt(dx * dx + dz * dz) / grid_spacing
	return rad_to_deg(atan(gradient))

func _apply_splatmap(splatmap: Image) -> void:
	"""Apply splatmap to HTerrain."""
	if not hterrain_data:
		return
	
	# Get the splatmap image from HTerrainData
	var splat_image: Image = hterrain_data.get_image(HTerrainData.CHANNEL_SPLAT)
	if not splat_image:
		push_error("Failed to get splatmap from HTerrain")
		return
	
	# Copy our generated splatmap to the terrain's splatmap
	for y in range(splatmap.get_height()):
		for x in range(splatmap.get_width()):
			splat_image.set_pixel(x, y, splatmap.get_pixel(x, y))
	
	# Notify HTerrain of changes
	var modified_region = Rect2(0, 0, TERRAIN_SIZE, TERRAIN_SIZE)
	hterrain_data.notify_region_change(modified_region, HTerrainData.CHANNEL_SPLAT)
	print("✓ Splatmap applied to HTerrain")

func _upscale_heightmap(height_map: Array, target_size: int) -> Array:
	"""Upscale heightmap using bilinear interpolation."""
	if height_map.is_empty():
		return []
	
	var src_size = height_map.size()
	var scaled: Array = []
	
	for y in range(target_size):
		var row: Array = []
		var src_y = float(y) / float(target_size - 1) * float(src_size - 1)
		var y0 = int(floor(src_y))
		var y1 = int(ceil(src_y))
		y0 = clampi(y0, 0, src_size - 1)
		y1 = clampi(y1, 0, src_size - 1)
		var fy = src_y - floor(src_y)
		
		for x in range(target_size):
			var src_x = float(x) / float(target_size - 1) * float(src_size - 1)
			var x0 = int(floor(src_x))
			var x1 = int(ceil(src_x))
			x0 = clampi(x0, 0, src_size - 1)
			x1 = clampi(x1, 0, src_size - 1)
			var fx = src_x - floor(src_x)
			
			var h00 = height_map[y0][x0]
			var h10 = height_map[y0][x1]
			var h01 = height_map[y1][x0]
			var h11 = height_map[y1][x1]
			
			var h0 = lerpf(h00, h10, fx)
			var h1 = lerpf(h01, h11, fx)
			var h = lerpf(h0, h1, fy)
			
			row.append(h)
		
		scaled.append(row)
	
	return scaled

func _smooth_heightmap(height_map: Array, iterations: int) -> Array:
	"""Apply box blur smoothing to heightmap."""
	if height_map.is_empty():
		return []
	
	var size = height_map.size()
	var smoothed = height_map.duplicate(true)
	
	for _iter in range(iterations):
		var temp = []
		for y in range(size):
			var row = []
			for x in range(size):
				var sum = 0.0
				var count = 0
				
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var nx = x + dx
						var ny = y + dy
						if nx >= 0 and nx < size and ny >= 0 and ny < size:
							sum += smoothed[ny][nx]
							count += 1
				
				row.append(sum / float(count))
			temp.append(row)
		smoothed = temp
	
	return smoothed

func _create_full_land_mask(height_map: Array) -> Array:
	"""Create a mask with all land (no water)."""
	var size = height_map.size()
	var mask = []
	
	for y in range(size):
		var row = []
		for x in range(size):
			row.append(1.0)  # All land
		mask.append(row)
	
	return mask


# ============================================================================
# BUILDABILITY LAYER - Slope-based gameplay grid evaluation
# ============================================================================

func _compute_buildability_layer(height_map: Array) -> void:
	"""Compute slope-based buildability for gameplay grid.
	
	Process:
	1. Compute slope map from heightmap (in world space)
	2. Sample slope at gameplay grid resolution
	3. Use conservative evaluation (max slope within tile)
	4. Optionally visualize results
	"""
	if height_map.is_empty():
		push_error("Cannot compute buildability: height_map is empty")
		return
	
	# Get current gameplay grid size from plot generator
	if plot_generator and "GRID_RESOLUTION" in plot_generator:
		gameplay_grid_size = plot_generator.GRID_RESOLUTION
	else:
		gameplay_grid_size = 16  # Default fallback
	
	print("Computing buildability layer for %dx%d gameplay grid..." % [gameplay_grid_size, gameplay_grid_size])
	
	# Compute full-resolution slope map
	var slope_map: Array = _compute_slope_map(height_map)
	
	# Sample slopes at gameplay grid resolution (conservative max)
	slope_grid = _sample_slopes_at_gameplay_grid(slope_map, gameplay_grid_size)
	
	# Count buildability statistics
	var buildable_count = 0
	var conditional_count = 0
	var blocked_count = 0
	
	for row in slope_grid:
		for slope in row:
			if slope <= BUILDABLE_SLOPE_MAX:
				buildable_count += 1
			elif slope <= CONDITIONAL_SLOPE_MAX:
				conditional_count += 1
			else:
				blocked_count += 1
	
	var total_tiles = gameplay_grid_size * gameplay_grid_size
	print("✓ Buildability computed:")
	print("  - Buildable: %d/%d (%.1f%%)" % [buildable_count, total_tiles, 100.0 * buildable_count / total_tiles])
	print("  - Conditional: %d/%d (%.1f%%)" % [conditional_count, total_tiles, 100.0 * conditional_count / total_tiles])
	print("  - Blocked: %d/%d (%.1f%%)" % [blocked_count, total_tiles, 100.0 * blocked_count / total_tiles])
	
	# Update debug visualization if enabled
	if show_buildability_debug:
		_create_buildability_debug_overlay()


func _compute_slope_map(height_map: Array) -> Array:
	"""Compute slope in degrees for each point in the heightmap.
	
	Uses central differences for accurate slope estimation.
	Returns Array[z][x] -> slope in degrees.
	"""
	var size = height_map.size()
	var slope_map: Array = []
	
	# World-space distance between samples
	var terrain_world_size = float(TERRAIN_SIZE)
	var sample_distance = terrain_world_size / float(size - 1) if size > 1 else 1.0
	
	for z in range(size):
		var row: Array = []
		for x in range(size):
			# Get neighboring heights (clamped to edges)
			var h_center = height_map[z][x] * VERTICAL_SCALE
			
			var x_prev = max(x - 1, 0)
			var x_next = min(x + 1, size - 1)
			var z_prev = max(z - 1, 0)
			var z_next = min(z + 1, size - 1)
			
			var h_left = height_map[z][x_prev] * VERTICAL_SCALE
			var h_right = height_map[z][x_next] * VERTICAL_SCALE
			var h_top = height_map[z_prev][x] * VERTICAL_SCALE
			var h_bottom = height_map[z_next][x] * VERTICAL_SCALE
			
			# Central difference for gradient
			var dx_dist = sample_distance * (x_next - x_prev)
			var dz_dist = sample_distance * (z_next - z_prev)
			
			var gradient_x = (h_right - h_left) / dx_dist if dx_dist > 0 else 0.0
			var gradient_z = (h_bottom - h_top) / dz_dist if dz_dist > 0 else 0.0
			
			# Slope magnitude (rise/run)
			var slope_ratio = sqrt(gradient_x * gradient_x + gradient_z * gradient_z)
			
			# Convert to degrees
			var slope_degrees = rad_to_deg(atan(slope_ratio))
			
			row.append(slope_degrees)
		slope_map.append(row)
	
	return slope_map


func _sample_slopes_at_gameplay_grid(slope_map: Array, grid_size: int) -> Array:
	"""Sample slope map at gameplay grid resolution using conservative max.
	
	Each gameplay tile samples multiple slope values and takes the maximum.
	This ensures we never mark a steep area as buildable (false negative preference).
	
	Returns Array[tile_z][tile_x] -> max slope in degrees within that tile.
	"""
	var terrain_res = slope_map.size()
	var sampled_grid: Array = []
	
	# Calculate how many terrain samples per gameplay tile
	var samples_per_tile = float(terrain_res) / float(grid_size)
	
	for tile_z in range(grid_size):
		var row: Array = []
		for tile_x in range(grid_size):
			# Map gameplay tile to terrain heightmap region
			var terrain_x_start = int(tile_x * samples_per_tile)
			var terrain_x_end = int((tile_x + 1) * samples_per_tile)
			var terrain_z_start = int(tile_z * samples_per_tile)
			var terrain_z_end = int((tile_z + 1) * samples_per_tile)
			
			# Clamp to valid range
			terrain_x_end = min(terrain_x_end, terrain_res)
			terrain_z_end = min(terrain_z_end, terrain_res)
			
			# Find maximum slope within this tile (conservative)
			var max_slope = 0.0
			for z in range(terrain_z_start, terrain_z_end):
				for x in range(terrain_x_start, terrain_x_end):
					if z < slope_map.size() and x < slope_map[z].size():
						max_slope = maxf(max_slope, slope_map[z][x])
			
			row.append(max_slope)
		sampled_grid.append(row)
	
	return sampled_grid


# ============================================================================
# PUBLIC API - Query buildability from gameplay code
# ============================================================================

func get_tile_slope(tile_x: int, tile_z: int) -> float:
	"""Get the maximum slope (in degrees) for a gameplay tile.
	
	Args:
		tile_x: Tile X coordinate (0 to gameplay_grid_size-1)
		tile_z: Tile Z coordinate (0 to gameplay_grid_size-1)
	
	Returns:
		Slope in degrees, or -1.0 if out of bounds or not computed yet.
	"""
	if slope_grid.is_empty():
		push_warning("Buildability layer not computed yet")
		return -1.0
	
	if tile_z < 0 or tile_z >= slope_grid.size():
		return -1.0
	if tile_x < 0 or tile_x >= slope_grid[tile_z].size():
		return -1.0
	
	return slope_grid[tile_z][tile_x]


func is_tile_buildable(tile_x: int, tile_z: int) -> bool:
	"""Check if a tile is fully buildable (houses, industry, etc.).
	
	Args:
		tile_x: Tile X coordinate
		tile_z: Tile Z coordinate
	
	Returns:
		true if slope <= BUILDABLE_SLOPE_MAX (default 5°), false otherwise.
	"""
	var slope = get_tile_slope(tile_x, tile_z)
	if slope < 0.0:
		return false  # Out of bounds or not computed
	
	return slope <= BUILDABLE_SLOPE_MAX


func is_tile_conditionally_buildable(tile_x: int, tile_z: int) -> bool:
	"""Check if a tile is conditionally buildable (roads, farms only).
	
	Args:
		tile_x: Tile X coordinate
		tile_z: Tile Z coordinate
	
	Returns:
		true if slope <= CONDITIONAL_SLOPE_MAX (default 8°), false otherwise.
	"""
	var slope = get_tile_slope(tile_x, tile_z)
	if slope < 0.0:
		return false
	
	return slope <= CONDITIONAL_SLOPE_MAX


func get_buildability_status(tile_x: int, tile_z: int) -> String:
	"""Get human-readable buildability status for a tile.
	
	Args:
		tile_x: Tile X coordinate
		tile_z: Tile Z coordinate
	
	Returns:
		"buildable", "conditional", "blocked", or "invalid"
	"""
	var slope = get_tile_slope(tile_x, tile_z)
	if slope < 0.0:
		return "invalid"
	
	if slope <= BUILDABLE_SLOPE_MAX:
		return "buildable"
	elif slope <= CONDITIONAL_SLOPE_MAX:
		return "conditional"
	else:
		return "blocked"


# ============================================================================
# DEBUG VISUALIZATION
# ============================================================================

func _create_buildability_debug_overlay() -> void:
	"""Create a colored grid overlay showing buildability status.
	
	Green  = buildable (slope <= 5°)
	Yellow = conditional (slope <= 8°)
	Red    = blocked (slope > 8°)
	"""
	# Remove existing overlay
	if debug_overlay:
		debug_overlay.queue_free()
		debug_overlay = null
	
	if slope_grid.is_empty():
		return
	
	# Create mesh
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# World-space tile size
	var tile_size = float(TERRAIN_SIZE) / float(gameplay_grid_size)
	var overlay_height = VERTICAL_SCALE * 1.05  # Slightly above max terrain height
	
	for tile_z in range(gameplay_grid_size):
		for tile_x in range(gameplay_grid_size):
			var slope = slope_grid[tile_z][tile_x]
			
			# Determine color based on buildability
			var color: Color
			if slope <= BUILDABLE_SLOPE_MAX:
				color = Color(0.0, 1.0, 0.0, 0.5)  # Green (buildable)
			elif slope <= CONDITIONAL_SLOPE_MAX:
				color = Color(1.0, 1.0, 0.0, 0.5)  # Yellow (conditional)
			else:
				color = Color(1.0, 0.0, 0.0, 0.5)  # Red (blocked)
			
			# Calculate tile corners in world space
			var x0 = tile_x * tile_size
			var x1 = (tile_x + 1) * tile_size
			var z0 = tile_z * tile_size
			var z1 = (tile_z + 1) * tile_size
			
			# Create quad (two triangles)
			var v0 = Vector3(x0, overlay_height, z0)
			var v1 = Vector3(x1, overlay_height, z0)
			var v2 = Vector3(x1, overlay_height, z1)
			var v3 = Vector3(x0, overlay_height, z1)
			
			# Triangle 1
			surface_tool.set_color(color)
			surface_tool.add_vertex(v0)
			surface_tool.add_vertex(v1)
			surface_tool.add_vertex(v2)
			
			# Triangle 2
			surface_tool.add_vertex(v0)
			surface_tool.add_vertex(v2)
			surface_tool.add_vertex(v3)
	
	var mesh = surface_tool.commit()
	
	# Create MeshInstance3D
	debug_overlay = MeshInstance3D.new()
	debug_overlay.mesh = mesh
	debug_overlay.name = "BuildabilityDebugOverlay"
	
	# Create transparent material
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_overlay.set_surface_override_material(0, material)
	
	add_child(debug_overlay)
	print("✓ Debug buildability overlay created")


func toggle_buildability_debug() -> void:
	"""Toggle debug visualization on/off."""
	show_buildability_debug = not show_buildability_debug
	
	if show_buildability_debug:
		_create_buildability_debug_overlay()
	else:
		if debug_overlay:
			debug_overlay.queue_free()
			debug_overlay = null
	
	print("Buildability debug overlay: %s" % ("ON" if show_buildability_debug else "OFF"))


# ============================================================================
# WATER SYSTEM - Helper Functions
# ============================================================================

func update_water_level(new_y_value: float) -> void:
	"""Update water level and reposition water planes.
	
	Args:
		new_y_value: New water height in world coordinates (meters)
	"""
	current_water_level = new_y_value
	_update_water_layer_positions()
	print("Water level updated to: %.2f" % current_water_level)


func is_position_underwater(world_position: Vector3) -> bool:
	"""Check if a world position is below the water surface.
	
	Args:
		world_position: Position in world coordinates (Vector3)
	
	Returns:
		true if position Y is below current_water_level, false otherwise
	"""
	return world_position.y < current_water_level


func get_water_depth_at_position(world_position: Vector3) -> float:
	"""Get water depth at a specific position.
	
	Args:
		world_position: Position in world coordinates (Vector3)
	
	Returns:
		Positive value = depth below water surface
		Negative value = height above water surface
		Zero = exactly at water surface
	"""
	return current_water_level - world_position.y
