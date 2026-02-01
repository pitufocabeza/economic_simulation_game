extends Node3D

################################################################################
# TEMPERATE PLOT GENERATOR
# Seed-based procedural terrain generation for small 3D dioramas.
# Each plot is a single terrain mesh with an associated buildable grid.
#
# BIOME: TEMPERATE
# 
# ARCHETYPES:
#   1. Flat Plains      (~80% buildable, mostly MID height)
#   2. Coastal Shelf    (~65% buildable, LOW band along edge + MID)
#   3. Gentle Hills     (~70% buildable, rolling MID + soft HIGH ridges)
#   4. River Basin      (~60% buildable, meandering LOW strip through MID)
#   5. Forest Edge      (~65% buildable, MID clearings framed by HIGH edges)
#   6. Agricultural Plateau (~75% buildable, raised flat MID region)
#
# HEIGHT BANDS:
#   LOW  : 0.0 – 0.3  (unbuildable, water/depression)
#   MID  : 0.3 – 0.7  (buildable, construction terrain)
#   HIGH : 0.7 – 1.0  (decorative, cliff faces, ridges)
#
# TERRAIN GENERATION PROCESS:
#   1. Create low-res height mask (4x4 or 5x5 grid)
#   2. Interpolate to target resolution (16x16 or 20x20)
#   3. Apply smoothstep for soft transitions
#   4. Derive buildable grid from MID-band tiles
#
################################################################################

# Height and resolution settings
var HEIGHT_GRID_RESOLUTION = 16  # 16x16 final height map
var HEIGHT_MASK_RESOLUTION = 5   # 5x5 base control points
var SMOOTH_ITERATIONS = 1        # Smoothstep iterations

# Height band thresholds
var HEIGHT_LOW = 0.3    # Boundary between LOW and MID
var HEIGHT_HIGH = 0.7   # Boundary between MID and HIGH

# Archetype definitions with control point patterns
var ARCHETYPES = {
	"Flat Plains": {
		"buildable_ratio": 0.80,
		"description": "Mostly MID height, very playable",
		"pattern": func(_rng: RandomNumberGenerator) -> Array:
	return [
		[0.5, 0.5, 0.5, 0.5, 0.5],
		[0.5, 0.5, 0.5, 0.5, 0.5],
		[0.5, 0.5, 0.5, 0.5, 0.5],
		[0.5, 0.5, 0.5, 0.5, 0.5],
		[0.5, 0.5, 0.5, 0.5, 0.5],
	]
	},
	"Coastal Shelf": {
		"buildable_ratio": 0.65,
		"description": "LOW band along one edge (water line), MID elsewhere",
		"pattern": func(_rng: RandomNumberGenerator) -> Array:
	return [
		[0.2, 0.2, 0.2, 0.2, 0.2],
		[0.4, 0.5, 0.5, 0.5, 0.4],
		[0.5, 0.5, 0.5, 0.5, 0.5],
		[0.5, 0.5, 0.5, 0.5, 0.5],
		[0.5, 0.5, 0.5, 0.5, 0.5],
	]
	},
	"Gentle Hills": {
		"buildable_ratio": 0.70,
		"description": "Rolling MID with soft HIGH ridges",
		"pattern": func(_rng: RandomNumberGenerator) -> Array:
	return [
		[0.45, 0.5, 0.55, 0.5, 0.45],
		[0.5, 0.55, 0.65, 0.55, 0.5],
		[0.55, 0.65, 0.75, 0.65, 0.55],
		[0.5, 0.55, 0.65, 0.55, 0.5],
		[0.45, 0.5, 0.55, 0.5, 0.45],
	]
	},
	"River Basin": {
		"buildable_ratio": 0.60,
		"description": "Meandering LOW strip through MID terrain",
		"pattern": func(_rng: RandomNumberGenerator) -> Array:
	return [
		[0.5, 0.5, 0.5, 0.5, 0.5],
		[0.5, 0.45, 0.4, 0.45, 0.5],
		[0.4, 0.25, 0.2, 0.25, 0.4],
		[0.5, 0.45, 0.4, 0.45, 0.5],
		[0.5, 0.5, 0.5, 0.5, 0.5],
	]
	},
	"Forest Edge": {
		"buildable_ratio": 0.65,
		"description": "MID clearings framed by HIGH edges",
		"pattern": func(_rng: RandomNumberGenerator) -> Array:
	return [
		[0.8, 0.8, 0.8, 0.8, 0.8],
		[0.8, 0.5, 0.5, 0.5, 0.8],
		[0.8, 0.5, 0.5, 0.5, 0.8],
		[0.8, 0.5, 0.5, 0.5, 0.8],
		[0.8, 0.8, 0.8, 0.8, 0.8],
	]
	},
	"Agricultural Plateau": {
		"buildable_ratio": 0.75,
		"description": "Raised flat MID region with LOW surroundings",
		"pattern": func(_rng: RandomNumberGenerator) -> Array:
	return [
		[0.25, 0.25, 0.25, 0.25, 0.25],
		[0.25, 0.55, 0.55, 0.55, 0.25],
		[0.25, 0.55, 0.65, 0.55, 0.25],
		[0.25, 0.55, 0.55, 0.55, 0.25],
		[0.25, 0.25, 0.25, 0.25, 0.25],
	]
	},
}


################################################################################
# PRIMARY INTERFACE
################################################################################

## Generate a complete plot for a given seed.
## Returns a dictionary with terrain data and buildable grid.
func generate_plot(seed: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	
	# Deterministically select archetype
	var archetype = _select_archetype(rng)
	print("🌿 Temperate Plot Generated | Archetype: %s | Seed: %d" % [archetype, seed])
	
	# Generate height map from archetype pattern
	var height_map = _generate_height_map(archetype, rng)
	
	# Derive buildable grid from height bands
	var buildable_map = _generate_buildable_map(height_map)
	
	return {
		"archetype": archetype,
		"height_map": height_map,
		"buildable_map": buildable_map,
	}


################################################################################
# ARCHETYPE SELECTION
################################################################################

func _select_archetype(rng: RandomNumberGenerator) -> String:
	"""
	Deterministically select an archetype using RNG.
	Flat archetypes have higher weight for playability.
	"""
	var archetype_names = ARCHETYPES.keys()
	
	# Weight flat archetypes more heavily
	var weights = []
	for name in archetype_names:
		match name:
			"Flat Plains", "Agricultural Plateau":
				weights.append(2.0)  # Double weight
			_:
				weights.append(1.0)
	
	# Normalize weights
	var total_weight = weights.reduce(func(acc, w): return acc + w, 0.0)
	for i in range(weights.size()):
		weights[i] /= total_weight
	
	# Cumulative probability selection
	var rand_val = rng.randf()
	var cumulative = 0.0
	for i in range(weights.size()):
		cumulative += weights[i]
		if rand_val <= cumulative:
			return archetype_names[i]
	
	return archetype_names[0]  # Fallback


################################################################################
# HEIGHT MAP GENERATION
################################################################################

func _generate_height_map(archetype: String, rng: RandomNumberGenerator) -> Array:
	"""
	Generate a HEIGHT_GRID_RESOLUTION x HEIGHT_GRID_RESOLUTION height map
	by interpolating the archetype's low-res pattern.
	"""
	# Get the archetype's base pattern (low-res control points)
	var pattern_func = ARCHETYPES[archetype]["pattern"]
	var low_res_grid = pattern_func.call(rng)
	
	# Interpolate from low-res to full resolution
	var interpolated = _bilinear_interpolate(low_res_grid, HEIGHT_GRID_RESOLUTION)
	
	# Apply smoothstep for soft transitions
	for _iter in range(SMOOTH_ITERATIONS):
		interpolated = _apply_smoothstep(interpolated)
	
	return interpolated


func _bilinear_interpolate(low_res: Array, target_size: int) -> Array:
	"""
	Bilinear interpolation from low-res grid to target resolution.
	Returns a target_size x target_size grid.
	"""
	var result = []
	for y in range(target_size):
		var row = []
		for x in range(target_size):
			# Map from target grid to low-res grid
			var u = float(x) / float(target_size - 1) * (low_res[0].size() - 1)
			var v = float(y) / float(target_size - 1) * float(low_res.size() - 1)
			
			# Bilinear interpolation
			var x0 = int(floor(u))
			var x1 = min(x0 + 1, low_res[0].size() - 1)
			var y0 = int(floor(v))
			var y1 = min(y0 + 1, low_res.size() - 1)
			
			var fx = u - float(x0)
			var fy = v - float(y0)
			
			var v00 = low_res[y0][x0]
			var v10 = low_res[y0][x1]
			var v01 = low_res[y1][x0]
			var v11 = low_res[y1][x1]
			
			var v0 = v00 * (1.0 - fx) + v10 * fx
			var v1 = v01 * (1.0 - fx) + v11 * fx
			var value = v0 * (1.0 - fy) + v1 * fy
			
			row.append(clamp(value, 0.0, 1.0))
		
		result.append(row)
	
	return result


func _apply_smoothstep(grid: Array) -> Array:
	"""
	Apply smoothstep smoothing to soften height transitions.
	Blends each cell with its neighbors.
	"""
	var size = grid.size()
	var result = []
	
	for y in range(size):
		var row = []
		for x in range(size):
			var sum = 0.0
			var count = 0
			
			# Sample cell and neighbors (3x3 kernel, clamped at edges)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var ny = clampi(y + dy, 0, size - 1)
					var nx = clampi(x + dx, 0, size - 1)
					sum += grid[ny][nx]
					count += 1
			
			var smoothed = sum / float(count)
			row.append(clamp(smoothed, 0.0, 1.0))
		
		result.append(row)
	
	return result


################################################################################
# BUILDABLE GRID GENERATION
################################################################################

func _generate_buildable_map(height_map: Array) -> Array:
	"""
	Generate buildable grid from height map.
	Only MID-band tiles (0.3 <= height < 0.7) are buildable.
	"""
	var buildable = []
	
	for y in range(height_map.size()):
		var row = []
		for x in range(height_map[y].size()):
			var height = height_map[y][x]
			var is_buildable = height >= HEIGHT_LOW and height < HEIGHT_HIGH
			row.append(is_buildable)
		
		buildable.append(row)
	
	return buildable
