extends Node3D

# Archetype Definitions for Temperate Planet
var ARCHETYPES = {
	"Flat Plains": {
		"buildable_ratio": 0.80,
		"sea_level": 0.35,
		"coast_falloff": 0.12,
		"height_power": 1.2,
		"base_roughness": 0.3,
		"noise_scale": 1.0,
		"octaves": 4,
		"frequency": 0.04,
		"macro_shape": "central_valley",
		"valley_radius": 0.35,
		"rim_height": 0.65,
		"height_pattern": func(_rng: RandomNumberGenerator) -> Array:
			return [
				[0.45, 0.45, 0.45, 0.45],
				[0.45, 0.45, 0.45, 0.45],
				[0.45, 0.45, 0.45, 0.45],
				[0.45, 0.45, 0.45, 0.45]
			],
	},
	"Coastal Shelf": {
		"buildable_ratio": 0.65,
		"sea_level": 0.40,
		"coast_falloff": 0.15,
		"height_power": 1.1,
		"base_roughness": 0.5,
		"noise_scale": 0.8,
		"octaves": 5,
		"frequency": 0.035,
		"has_coast": true,
		"has_river": true,
		"river_width": 2,
		"river_depth": 0.4,
		"macro_shape": "one_sided_coast",
		"shelf_depth": 0.15,
		"inland_wall": 0.45,
		"height_pattern": func(_rng: RandomNumberGenerator) -> Array:
			return [
				[0.50, 0.50, 0.55, 0.55],
				[0.50, 0.55, 0.55, 0.60],
				[0.55, 0.45, 0.45, 0.50],
				[0.50, 0.45, 0.40, 0.45]
			],
	},
	"Gentle Hills": {
		"buildable_ratio": 0.70,
		"sea_level": 0.30,
		"coast_falloff": 0.10,
		"height_power": 1.4,
		"base_roughness": 0.6,
		"noise_scale": 1.2,
		"octaves": 6,
		"frequency": 0.045,
		"height_pattern": func(_rng: RandomNumberGenerator) -> Array:
			return [
				[0.45, 0.50, 0.55, 0.50],
				[0.50, 0.55, 0.65, 0.55],
				[0.55, 0.65, 0.75, 0.65],
				[0.50, 0.55, 0.65, 0.55]
			],
	},
	"River Basin": {
		"buildable_ratio": 0.60,
		"sea_level": 0.38,
		"coast_falloff": 0.14,
		"height_power": 1.3,
		"base_roughness": 0.4,
		"noise_scale": 0.9,
		"octaves": 5,
		"frequency": 0.05,
		"has_river": true,
		"river_width": 3,
		"river_depth": 0.45,
		"macro_shape": "gentle_bowl",
		"bowl_gradient": 0.25,
		"height_pattern": func(_rng: RandomNumberGenerator) -> Array:
			return [
				[0.50, 0.48, 0.45, 0.48],
				[0.48, 0.45, 0.35, 0.45],
				[0.45, 0.35, 0.25, 0.35],
				[0.48, 0.45, 0.35, 0.45]
			],
	},
	"Forest Edge": {
		"buildable_ratio": 0.65,
		"sea_level": 0.32,
		"coast_falloff": 0.11,
		"height_power": 1.6,
		"base_roughness": 0.8,
		"noise_scale": 1.3,
		"octaves": 6,
		"frequency": 0.055,
		"macro_shape": "forested_ridge",
		"ridge_height": 0.70,
		"height_pattern": func(_rng: RandomNumberGenerator) -> Array:
			return [
				[0.70, 0.75, 0.80, 0.75],
				[0.75, 0.65, 0.60, 0.70],
				[0.80, 0.60, 0.65, 0.75],
				[0.75, 0.70, 0.75, 0.80]
			],
	},
	"Agricultural Plateau": {
		"buildable_ratio": 0.75,
		"sea_level": 0.35,
		"coast_falloff": 0.10,
		"height_power": 1.1,
		"base_roughness": 0.35,
		"noise_scale": 0.7,
		"octaves": 4,
		"frequency": 0.03,
		"macro_shape": "stepped_plateau",
		"plateau_height": 0.55,
		"plateau_tilt": 0.08,
		"height_pattern": func(_rng: RandomNumberGenerator) -> Array:
			return [
				[0.65, 0.65, 0.65, 0.65],
				[0.65, 0.55, 0.60, 0.65],
				[0.65, 0.60, 0.70, 0.65],
				[0.65, 0.65, 0.65, 0.65]
			],
	}
}

@export var GRID_RESOLUTION: int = 16
var noise: FastNoiseLite = FastNoiseLite.new()
var light: DirectionalLight3D

func _ready() -> void:
	set_process(true)
	_setup_lighting()
	_configure_noise()

func _setup_lighting() -> void:
	"""Create a DirectionalLight3D positioned above the terrain."""
	if light and not light.is_queued_for_deletion():
		light.queue_free()
	
	light = DirectionalLight3D.new()
	light.name = "TerrainLight"
	add_child(light)
	
	light.position = Vector3(32.0, 64.0, 32.0)
	light.rotation = Vector3(deg_to_rad(-45.0), deg_to_rad(-45.0), 0.0)
	
	light.energy = 2.0
	light.shadow_enabled = true
	light.shadow_blur = 1
	
	print("✓ Terrain lighting setup complete")

func _configure_noise() -> void:
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

func generate_plot(seed: int) -> Dictionary:
	noise.seed = seed
	
	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	
	var archetype = _select_archetype(rng)
	print("Selected Archetype: %s" % archetype)
	
	var height_map = _generate_height_map(archetype, rng)
	var island_mask = _generate_island_mask(archetype, rng)
	
	return {"archetype": archetype, "height_map": height_map, "island_mask": island_mask, "success": true}

func _select_archetype(rng: RandomNumberGenerator) -> String:
	var archetype_names = ARCHETYPES.keys()
	var rand_index = rng.randi_range(0, archetype_names.size() - 1)
	return archetype_names[rand_index]

func _generate_island_mask(archetype: String, rng: RandomNumberGenerator) -> Array:
	var mask = []
	var pattern_size = 4
	
	for z in range(pattern_size):
		var row = []
		for x in range(pattern_size):
			row.append(1.0)
		mask.append(row)
	
	return mask

func _fbm(x: float, z: float, frequency: float, octaves: int) -> float:
	"""Compute multi-octave Fractional Brownian Motion manually."""
	var amplitude = 1.0
	var max_value = 0.0
	var value = 0.0
	var freq = frequency
	
	for i in range(octaves):
		var sample = noise.get_noise_2d(x * freq, z * freq)
		value += sample * amplitude
		max_value += amplitude
		amplitude *= 0.5
		freq *= 2.0
	
	return (value / max_value) if max_value > 0.0 else 0.0

func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	"""Smooth Hermite interpolation (0 at edge0, 1 at edge1)."""
	var t = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _blur_mask(mask: Array, radius: int) -> Array:
	"""Apply box blur to smooth mask edges."""
	var blurred = []
	var h = mask.size()
	var w = mask[0].size() if h > 0 else 0
	
	for z in range(h):
		var row = []
		for x in range(w):
			var sum_val = 0.0
			var count = 0
			
			for dz in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					var nx = x + dx
					var nz = z + dz
					if nx >= 0 and nx < w and nz >= 0 and nz < h:
						sum_val += mask[nz][nx]
						count += 1
			
			row.append(sum_val / float(count) if count > 0 else 0.0)
		blurred.append(row)
	
	return blurred

func _macro_height(archetype: String, x_n: float, z_n: float) -> float:
	"""Compute archetype-specific macro-scale height shapes (before noise).
	
	x_n, z_n are normalized coordinates in [0, 1].
	Returns height in [0, 1] representing the base macro shape for this archetype.
	"""
	var archetype_data = ARCHETYPES[archetype]
	var sea_level = archetype_data.get("sea_level", 0.35)
	
	match archetype_data.get("macro_shape", "none"):
		"central_valley":
			# Flat Plains: Low center, high rim (mountain ring)
			var valley_radius = archetype_data.get("valley_radius", 0.35)
			var rim_height = archetype_data.get("rim_height", 0.65)
			var dist = sqrt(pow(x_n - 0.5, 2.0) + pow(z_n - 0.5, 2.0))
			var valley_amount = _smoothstep(valley_radius, 0.0, dist)
			return lerp(sea_level + 0.05, rim_height, valley_amount)
		
		"one_sided_coast":
			# Coastal Shelf: Shallow shelf near coast, mountain wall inland
			# Coast is typically on left edge (x_n ~ 0)
			var shelf_depth = archetype_data.get("shelf_depth", 0.15)
			var inland_wall = archetype_data.get("inland_wall", 0.45)
			var coast_dist = x_n  # Distance from left coast
			if coast_dist < 0.3:
				# Near coast: shallow shelf
				return sea_level + shelf_depth * (1.0 - (coast_dist / 0.3))
			else:
				# Far from coast: ramp up to inland wall
				var inland_blend = (coast_dist - 0.3) / 0.7
				return lerp(sea_level + shelf_depth, sea_level + inland_wall, inland_blend)
		
		"gentle_bowl":
			# River Basin: Gentle slope from one corner toward opposite
			var bowl_gradient = archetype_data.get("bowl_gradient", 0.25)
			# Slope from top-left (high) to bottom-right (low)
			var slope = (x_n + z_n) * 0.5
			var height = (sea_level + 0.25) - (slope * bowl_gradient)
			return clampf(height, sea_level * 0.85, sea_level + 0.35)
		
		"forested_ridge":
			# Forest Edge: High forested ridge on one side (e.g., top), sloping down
			var ridge_height = archetype_data.get("ridge_height", 0.70)
			# Ridge along top edge (z_n ~ 0)
			var ridge_dist = z_n
			var ridge_amount = _smoothstep(0.4, 0.0, ridge_dist)
			return lerp(sea_level + 0.15, ridge_height, ridge_amount)
		
		"stepped_plateau":
			# Agricultural Plateau: Broad elevated plateau with gentle tilt and steps
			var plateau_height = archetype_data.get("plateau_height", 0.55)
			var plateau_tilt = archetype_data.get("plateau_tilt", 0.08)
			# Base plateau
			var height = plateau_height
			# Add subtle gradient tilt
			height += (x_n - 0.5) * plateau_tilt
			# Add very subtle terracing (3-step)
			var terrace_level = floor(x_n * 3.0) / 3.0
			height = lerp(height, height + (terrace_level - x_n + 0.166) * 0.05, 0.3)
			return clampf(height, sea_level + 0.1, 0.75)
		
		_:
			# Default: neutral base
			return sea_level + 0.15

func _generate_coast_mask(archetype: String) -> Array:
	"""Generate archetype-aware coast mask (0=ocean, 1=land).
	
	For non-coastal archetypes: returns mostly 1.0 (all land).
	For Coastal Shelf: returns one-sided coastline with soft falloff.
	For other archetypes: optional weak radial mask to frame land area.
	"""
	var archetype_data = ARCHETYPES[archetype]
	var mask = []
	var coast_noise = FastNoiseLite.new()
	coast_noise.seed = noise.seed + 1
	coast_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	coast_noise.frequency = 0.06
	
	match archetype:
		"Coastal Shelf":
			# One-sided coastline: coast on left, land extends right
			# Use low-frequency noise only along coast axis (x) to perturb shoreline
			for z in range(GRID_RESOLUTION):
				var row = []
				for x in range(GRID_RESOLUTION):
					var nx = float(x) / float(GRID_RESOLUTION)
					var nz = float(z) / float(GRID_RESOLUTION)
					
					# Coast distance from left edge
					var coast_dist = nx
					
					# Perturb coastline slightly with noise along z axis only
					var perturb = coast_noise.get_noise_2d(0.0, float(z))
					var perturb_norm = (perturb * 0.5) + 0.5
					var perturb_amount = (perturb_norm - 0.5) * 0.15
					
					# Soft falloff around coast (roughly 0.25 units from coast edge)
					var coast_threshold = 0.25 + perturb_amount
					var land_value = _smoothstep(coast_threshold - 0.1, coast_threshold + 0.1, coast_dist)
					
					row.append(land_value)
				mask.append(row)
			
			# Minimal blur to smooth any remaining noise
			mask = _blur_mask(mask, 1)
			return mask
		
		_:
			# For non-coastal archetypes: return mostly land with weak radial framing
			for z in range(GRID_RESOLUTION):
				var row = []
				for x in range(GRID_RESOLUTION):
					var nx = float(x) / float(GRID_RESOLUTION)
					var nz = float(z) / float(GRID_RESOLUTION)
					
					# Weak radial frame: keep most of tile as land, slight fade at extreme edges
					var dist = sqrt(pow(nx - 0.5, 2.0) + pow(nz - 0.5, 2.0))
					
					# Large radius so entire tile is mostly land
					var land_value = _smoothstep(0.55, 0.45, dist)
					row.append(land_value)
				mask.append(row)
			
			return mask

func _generate_river_path(start_edge: int, end_edge: int, height_map: Array, coast_mask: Array, rng: RandomNumberGenerator) -> Array:
	"""Generate river path with downhill bias and clear routing toward destination.
	
	Process:
	- Each step evaluates 5 candidate directions: toward goal, plus ±45° left/right
	- Chooses lowest-height neighbor (downhill preference)
	- Ensures path length by enforcing minimum steps to destination
	- Stops when reaching ocean (coast_mask < 0.5)
	"""
	var path = []
	var start_pos: Vector2
	
	match start_edge:
		0:  # Top
			start_pos = Vector2(rng.randf_range(2.0, float(GRID_RESOLUTION - 2)), 1.0)
		1:  # Right
			start_pos = Vector2(float(GRID_RESOLUTION - 2), rng.randf_range(2.0, float(GRID_RESOLUTION - 2)))
		2:  # Bottom
			start_pos = Vector2(rng.randf_range(2.0, float(GRID_RESOLUTION - 2)), float(GRID_RESOLUTION - 2))
		3:  # Left
			start_pos = Vector2(1.0, rng.randf_range(2.0, float(GRID_RESOLUTION - 2)))
	
	var end_pos: Vector2
	match end_edge:
		0:  # Top
			end_pos = Vector2(rng.randf_range(2.0, float(GRID_RESOLUTION - 2)), 0.0)
		1:  # Right
			end_pos = Vector2(float(GRID_RESOLUTION - 1), rng.randf_range(2.0, float(GRID_RESOLUTION - 2)))
		2:  # Bottom
			end_pos = Vector2(rng.randf_range(2.0, float(GRID_RESOLUTION - 2)), float(GRID_RESOLUTION - 1))
		3:  # Left
			end_pos = Vector2(0.0, rng.randf_range(2.0, float(GRID_RESOLUTION - 2)))
	
	var current_pos = start_pos
	var max_steps = 250
	var min_steps = 15  # Ensure river has minimum length
	var step_size = 0.6
	
	for step in range(max_steps):
		path.append(current_pos)
		
		var cx = int(current_pos.x)
		var cz = int(current_pos.y)
		
		# Stop if reached ocean
		if cx >= 0 and cx < GRID_RESOLUTION and cz >= 0 and cz < GRID_RESOLUTION:
			if coast_mask.size() > 0 and coast_mask[cz][cx] < 0.5:
				if step >= min_steps:
					break
		
		# Stop if very close to end
		var dist_to_end = current_pos.distance_to(end_pos)
		if dist_to_end < 1.0 and step >= min_steps:
			break
		
		# Generate candidate directions
		var goal_dir = (end_pos - current_pos).normalized()
		var goal_angle = atan2(goal_dir.y, goal_dir.x)
		
		var candidates: Array[Vector2] = []
		candidates.append(goal_dir)  # Straight to goal
		
		# ±45° angles
		for angle_offset in [-PI * 0.25, PI * 0.25]:
			var angle = goal_angle + angle_offset
			candidates.append(Vector2(cos(angle), sin(angle)))
		
		# ±22.5° angles for more options
		for angle_offset in [-PI * 0.125, PI * 0.125]:
			var angle = goal_angle + angle_offset
			candidates.append(Vector2(cos(angle), sin(angle)))
		
		# Evaluate each candidate: prefer lower height but still moving toward goal
		var best_dir = goal_dir
		var best_score = 999999.0
		
		for cand_dir in candidates:
			var next_pos = current_pos + cand_dir * step_size
			next_pos.x = clampf(next_pos.x, 0.0, float(GRID_RESOLUTION - 1))
			next_pos.y = clampf(next_pos.y, 0.0, float(GRID_RESOLUTION - 1))
			
			var nx = int(next_pos.x)
			var nz = int(next_pos.y)
			
			# Get height at candidate position
			var candidate_height = 999.0
			if nx >= 0 and nx < GRID_RESOLUTION and nz >= 0 and nz < GRID_RESOLUTION:
				candidate_height = height_map[nz][nx]
			
			# Score: favor lower heights, but also distance toward goal
			var goal_distance_penalty = current_pos.distance_to(end_pos) - next_pos.distance_to(end_pos)
			var height_score = candidate_height - (goal_distance_penalty * 0.2)  # Downhill weighted
			
			if height_score < best_score:
				best_score = height_score
				best_dir = cand_dir
		
		current_pos += best_dir * step_size
		
		# Keep in bounds
		current_pos.x = clampf(current_pos.x, 0.0, float(GRID_RESOLUTION - 1))
		current_pos.y = clampf(current_pos.y, 0.0, float(GRID_RESOLUTION - 1))
	
	return path

func _smooth_heightmap_local(height_map: Array, center_x: int, center_z: int, radius: int) -> Array:
	"""Apply smoothing only to local region around river corridor."""
	var h = height_map.size()
	var w = height_map[0].size() if h > 0 else 0
	
	for z in range(max(0, center_z - radius), min(h, center_z + radius + 1)):
		for x in range(max(0, center_x - radius), min(w, center_x + radius + 1)):
			var sum_height = 0.0
			var count = 0
			
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var nx = x + dx
					var nz = z + dz
					if nx >= 0 and nx < w and nz >= 0 and nz < h:
						sum_height += height_map[nz][nx]
						count += 1
			
			height_map[z][x] = sum_height / float(count) if count > 0 else height_map[z][x]
	
	return height_map

func _carve_river(height_map: Array, archetype: String, coast_mask: Array, rng: RandomNumberGenerator) -> Array:
	"""Carve highly visible river valleys with downhill-following path.
	
	Features:
	- Path uses downhill bias and multi-direction evaluation
	- Gaussian depth profile for smooth valley sides
	- Carves relative to local terrain (always deeper than surroundings)
	- Ensures river bottom is well below sea_level for visibility
	- Local smoothing passes for natural valley appearance
	"""
	var archetype_data = ARCHETYPES[archetype]
	var sea_level = archetype_data.get("sea_level", 0.35)
	var river_width = archetype_data.get("river_width", 2)
	var river_depth = archetype_data.get("river_depth", 0.45)
	
	# Determine path direction based on archetype
	var start_edge: int
	var end_edge: int
	
	if archetype == "River Basin":
		# Opposite edges for deep inland river
		start_edge = rng.randi_range(0, 3)
		end_edge = (start_edge + 2) % 4
	else:  # Coastal Shelf
		# From inland toward coast
		start_edge = rng.randi_range(0, 3)
		end_edge = start_edge
	
	var path = _generate_river_path(start_edge, end_edge, height_map, coast_mask, rng)
	
	if path.size() < 5:
		return height_map  # Path too short, skip carving
	
	# Pre-compute local minima for relative carving
	var local_minima = {}
	for waypoint in path:
		var cx = int(waypoint.x)
		var cz = int(waypoint.y)
		
		if cx >= 0 and cx < GRID_RESOLUTION and cz >= 0 and cz < GRID_RESOLUTION:
			# Find minimum height in 3x3 neighborhood
			var local_min = height_map[cz][cx]
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var nx = cx + dx
					var nz = cz + dz
					if nx >= 0 and nx < GRID_RESOLUTION and nz >= 0 and nz < GRID_RESOLUTION:
						local_min = minf(local_min, height_map[nz][nx])
			
			local_minima[waypoint] = local_min
	
	# Carve river along path with relative depth
	for waypoint_idx in range(path.size()):
		var waypoint = path[waypoint_idx]
		var cx = int(waypoint.x)
		var cz = int(waypoint.y)
		
		if cx < 0 or cx >= GRID_RESOLUTION or cz < 0 or cz >= GRID_RESOLUTION:
			continue
		
		# Check if in ocean - stop carving
		if coast_mask.size() > 0 and coast_mask[cz][cx] < 0.5:
			break
		
		# Get local minimum height at this point
		var local_min = local_minima.get(waypoint, height_map[cz][cx])
		
		# Carve around waypoint with Gaussian profile
		for dz in range(-river_width * 2, river_width * 2 + 1):
			for dx in range(-river_width * 2, river_width * 2 + 1):
				var px = cx + dx
				var pz = cz + dz
				
				if px >= 0 and px < GRID_RESOLUTION and pz >= 0 and pz < GRID_RESOLUTION:
					# Gaussian falloff from center
					var dist_sq = float(dx * dx + dz * dz)
					var sigma = float(river_width) * 0.6
					var gaussian = exp(-dist_sq / (2.0 * sigma * sigma))
					
					# Carve depth relative to local terrain
					var carve_amount = river_depth * gaussian
					var current_height = height_map[pz][px]
					
					# Lower to local minimum minus carve amount
					var target_height = local_min - carve_amount
					
					# Ensure river is well below sea level for visibility
					target_height = minf(current_height - carve_amount, sea_level * 0.75)
					target_height = maxf(target_height, 0.0)
					
					height_map[pz][px] = target_height
	
	# Apply multiple smoothing passes on river corridor for natural valley shape
	for pass_idx in range(2):
		for waypoint in path:
			var cx = int(waypoint.x)
			var cz = int(waypoint.y)
			if cx >= 0 and cx < GRID_RESOLUTION and cz >= 0 and cz < GRID_RESOLUTION:
				height_map = _smooth_heightmap_local(height_map, cx, cz, river_width + 2)
	
	return height_map

func _generate_height_map(archetype: String, rng: RandomNumberGenerator) -> Array:
	"""Generate detailed heightmap with archetype-specific macro shapes.
	
	Process:
	1. Compute macro-scale height shape for archetype
	2. Generate coast mask (archetype-aware)
	3. Create multi-octave FBM noise (coarse + fine detail)
	4. Blend macro shape with FBM noise
	5. Blend base pattern (reduced tiling with FBM)
	6. Apply height power curve
	7. Respect coast boundaries
	8. Carve rivers if applicable
	"""
	var archetype_data = ARCHETYPES[archetype]
	var height_map = []
	
	var sea_level = archetype_data.get("sea_level", 0.35)
	var height_power = archetype_data.get("height_power", 1.2)
	var base_roughness = archetype_data["base_roughness"]
	var noise_scale = archetype_data["noise_scale"]
	
	var base_pattern = archetype_data["height_pattern"].call(rng)
	var pattern_h = base_pattern.size()
	var pattern_w = base_pattern[0].size() if pattern_h > 0 else 1
	
	# Generate coast mask
	var coast_mask = _generate_coast_mask(archetype)
	
	# Noise configuration
	var noise_freq = archetype_data["frequency"]
	var octaves = archetype_data["octaves"]
	
	for z in range(GRID_RESOLUTION):
		var row = []
		for x in range(GRID_RESOLUTION):
			# Normalized coordinates for macro shape
			var x_n = float(x) / float(GRID_RESOLUTION - 1) if GRID_RESOLUTION > 1 else 0.5
			var z_n = float(z) / float(GRID_RESOLUTION - 1) if GRID_RESOLUTION > 1 else 0.5
			
			# Get coast mask influence
			var coast_influence = 1.0
			if coast_mask.size() > 0 and z < coast_mask.size() and x < coast_mask[z].size():
				coast_influence = coast_mask[z][x]
			
			# Ocean: simple water level
			if coast_influence < 0.05:
				row.append(sea_level * 0.95)
			else:
				# Compute macro-scale height for this archetype
				var macro_height = _macro_height(archetype, x_n, z_n)
				
				# Generate multi-octave FBM noise
				var fbm_val = _fbm(float(x), float(z), noise_freq, octaves)
				var fbm_norm = (fbm_val * 0.5) + 0.5
				
				# Base pattern, blended with FBM to reduce tiling (especially for plateau)
				var pattern_z = z % pattern_h
				var pattern_x = x % pattern_w
				var pattern_height = base_pattern[pattern_z][pattern_x]
				
				# Blend pattern with FBM to break up 4x4 tiling
				pattern_height = lerp(pattern_height, fbm_norm, 0.3)
				
				# Fine detail (high frequency)
				var detail_freq = noise_freq * 4.0
				var detail_fbm = _fbm(float(x), float(z), detail_freq, 2)
				var detail_norm = (detail_fbm * 0.5) + 0.5
				pattern_height = lerp(pattern_height, detail_norm, 0.08 * base_roughness)
				
				# Blend macro shape with noise-based height
				var macro_noise_mix = base_roughness * noise_scale
				var height = lerp(macro_height, pattern_height, macro_noise_mix)
				
				# For Forest Edge, boost roughness/detail on ridge
				if archetype == "Forest Edge":
					var ridge_dist = z_n
					var ridge_amount = _smoothstep(0.4, 0.0, ridge_dist)
					height = lerp(height, height + (fbm_norm - 0.5) * 0.15, ridge_amount)
				
				# Apply height power curve for pronounced features
				height = pow(height, height_power)
				
				# Blend toward sea level at coastline edges
				height = lerp(sea_level, height, coast_influence)
				
				# Ensure valid range
				height = clampf(height, 0.0, 1.0)
				
				# Land above sea level
				if coast_influence > 0.1:
					height = maxf(height, sea_level * 0.98)
				
				row.append(height)
		height_map.append(row)
	
	# Carve river if archetype has one
	if archetype_data.has("has_river") and archetype_data["has_river"]:
		height_map = _carve_river(height_map, archetype, coast_mask, rng)
	
	return height_map
