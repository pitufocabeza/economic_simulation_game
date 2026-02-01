extends Node

# Water Edge Mask Generator for TileMap
# Generates per-tile water edge masks showing foam, algae, and shallow water zones
# Supports 8-directional neighbor detection and edge-based mask selection

# ===================================================================
# BIOME TYPE CONSTANTS
# ===================================================================

const BIOME_GRASS = 0
const BIOME_SAND = 1
const BIOME_WATER = 2

# ===================================================================
# DIRECTION CONSTANTS (for 8-directional neighbor checking)
# ===================================================================

const DIR_N = 0    # North (up)
const DIR_NE = 1   # Northeast
const DIR_E = 2    # East (right)
const DIR_SE = 3   # Southeast
const DIR_S = 4    # South (down)
const DIR_SW = 5   # Southwest
const DIR_W = 6    # West (left)
const DIR_NW = 7   # Northwest

const NEIGHBOR_OFFSETS = [
	Vector2i.UP,                        # N  (0)
	Vector2i.UP + Vector2i.RIGHT,       # NE (1)
	Vector2i.RIGHT,                     # E  (2)
	Vector2i.DOWN + Vector2i.RIGHT,     # SE (3)
	Vector2i.DOWN,                      # S  (4)
	Vector2i.DOWN + Vector2i.LEFT,      # SW (5)
	Vector2i.LEFT,                      # W  (6)
	Vector2i.UP + Vector2i.LEFT,        # NW (7)
]

# ===================================================================
# MASK TEXTURE CONFIGURATIONS
# ===================================================================

# Edge mask texture names organized by directional patterns
# Key: "edge_signature" (bitmask), Value: ["texture_variants"]
# Bitmask: bit N = 1 if neighbor in direction N is land
var edge_mask_variants = {
	# Single edge (4 cardinal directions)
	0b00000001: ["water_edge_north"],           # Land to north
	0b00000100: ["water_edge_east"],            # Land to east
	0b00010000: ["water_edge_south"],           # Land to south
	0b01000000: ["water_edge_west"],            # Land to west
	
	# Corners (land in two adjacent cardinal directions)
	0b00010001: ["water_edge_ne"],              # Land north + east
	0b00010100: ["water_edge_se"],              # Land south + east
	0b01010000: ["water_edge_sw"],              # Land south + west
	0b01000001: ["water_edge_nw"],              # Land north + west
	
	# Two opposite edges (north + south, east + west)
	0b00010001: ["water_edge_ns"],              # Land north + south
	0b01010100: ["water_edge_ew"],              # Land east + west
	
	# L-shapes
	0b00010101: ["water_edge_ne_long"],         # N, E, SE
	0b00010110: ["water_edge_se_long"],         # E, S, SW
	0b01010110: ["water_edge_sw_long"],         # S, W, NW
	0b01010011: ["water_edge_nw_long"],         # W, N, NE
	
	# U-shapes
	0b01010001: ["water_edge_u_ns"],            # N, S, W
	0b00010101: ["water_edge_u_ew"],            # E, W, N
	0b01010100: ["water_edge_u_ew_s"],          # E, W, S
	0b01000101: ["water_edge_u_ns_w"],          # N, S, E
	
	# Interior corner (land in 3+ directions)
	0b00010111: ["water_edge_inner_ne"],        # Interior NE corner
	0b00010111: ["water_edge_inner_se"],        # Interior SE corner
	0b01010110: ["water_edge_inner_sw"],        # Interior SW corner
	0b01010011: ["water_edge_inner_nw"],        # Interior NW corner
	
	# Full shoreline (land everywhere)
	0b01010101: ["water_edge_full"],            # All cardinal directions
}

# Alternative: simpler 4-directional variants (if you only have cardinal edges)
var edge_mask_simple = {
	0b0001: ["water_edge_north"],
	0b0010: ["water_edge_east"],
	0b0100: ["water_edge_south"],
	0b1000: ["water_edge_west"],
	0b0011: ["water_edge_ne"],
	0b0110: ["water_edge_se"],
	0b1100: ["water_edge_sw"],
	0b1001: ["water_edge_nw"],
	0b0111: ["water_edge_inner_ne"],
	0b1110: ["water_edge_inner_nw"],
	0b1101: ["water_edge_inner_se"],
	0b1011: ["water_edge_inner_sw"],
	0b1111: ["water_edge_full"],
}

# Texture path prefix for edge masks
var edge_mask_texture_dir = "res://assets/tilesets/temperate/"

# ===================================================================
# PARAMETERS
# ===================================================================

var tilemap: TileMap
var tileset: TileSet
var biome_map: Dictionary = {}  # Grid of biome types
var mask_rotations_enabled = true  # Support rotation of edge textures
var use_simple_edges = false  # Use 4-directional vs 8-directional

# ===================================================================
# INITIALIZATION
# ===================================================================

func _ready():
	print("=== Water Edge Mask Generator ===")

func initialize(p_tilemap: TileMap, p_tileset: TileSet, p_biome_map: Dictionary):
	"""Initialize with tilemap, tileset, and biome grid"""
	tilemap = p_tilemap
	tileset = p_tileset
	biome_map = p_biome_map
	print("Initialized with %d biome cells" % biome_map.size())

# ===================================================================
# BIOME DETECTION HELPERS
# ===================================================================

func is_water(biome_type: int) -> bool:
	"""Check if biome type is water"""
	return biome_type == BIOME_WATER

func is_land(biome_type: int) -> bool:
	"""Check if biome type is land (non-water)"""
	return biome_type != BIOME_WATER

func get_biome_at(pos: Vector2i) -> int:
	"""Get biome type at position, return GRASS if out of bounds"""
	if biome_map.has(pos):
		return biome_map[pos]
	return BIOME_GRASS  # Default to land for out-of-bounds

func has_land_neighbor_cardinal(pos: Vector2i) -> bool:
	"""Check if water tile has land neighbor in cardinal directions (4-directional)"""
	var cardinal_dirs = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for offset in cardinal_dirs:
		var neighbor_pos = pos + offset
		if is_land(get_biome_at(neighbor_pos)):
			return true
	return false

func has_land_neighbor_diagonal(pos: Vector2i) -> bool:
	"""Check if water tile has land neighbor in diagonal directions"""
	var diagonal_dirs = [
		Vector2i.UP + Vector2i.RIGHT,
		Vector2i.DOWN + Vector2i.RIGHT,
		Vector2i.DOWN + Vector2i.LEFT,
		Vector2i.UP + Vector2i.LEFT,
	]
	for offset in diagonal_dirs:
		var neighbor_pos = pos + offset
		if is_land(get_biome_at(neighbor_pos)):
			return true
	return false

func has_land_neighbor(pos: Vector2i) -> bool:
	"""Check if water tile has ANY land neighbor (8-directional)"""
	return has_land_neighbor_cardinal(pos) or has_land_neighbor_diagonal(pos)

# ===================================================================
# EDGE SIGNATURE CALCULATION
# ===================================================================

func compute_edge_signature_8dir(pos: Vector2i) -> int:
	"""
	Compute 8-bit edge signature for 8-directional neighbors.
	Each bit represents a direction: 1 = land neighbor, 0 = water neighbor
	Bit order: N, NE, E, SE, S, SW, W, NW (bit 0 to 7)
	"""
	var signature = 0
	
	for dir in range(8):
		var neighbor_pos = pos + NEIGHBOR_OFFSETS[dir]
		if is_land(get_biome_at(neighbor_pos)):
			signature |= (1 << dir)
	
	return signature

func compute_edge_signature_4dir(pos: Vector2i) -> int:
	"""
	Compute 4-bit edge signature for cardinal neighbors only.
	Bit order: N, E, S, W (bit 0 to 3)
	"""
	var signature = 0
	
	var cardinal_offsets = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for dir in range(4):
		var neighbor_pos = pos + cardinal_offsets[dir]
		if is_land(get_biome_at(neighbor_pos)):
			signature |= (1 << dir)
	
	return signature

# ===================================================================
# EDGE MASK TEXTURE SELECTION
# ===================================================================

func get_edge_mask_texture(signature: int) -> String:
	"""
	Select edge mask texture based on neighbor signature.
	Returns texture name or empty string if no match.
	"""
	var variants_dict = edge_mask_simple if use_simple_edges else edge_mask_variants
	
	if variants_dict.has(signature):
		var textures = variants_dict[signature]
		if not textures.is_empty():
			# Return random variant if multiple exist
			var texture_name = textures[randi() % textures.size()]
			return texture_name
	
	return ""  # No mask for this pattern

func get_edge_rotation(signature: int) -> int:
	"""
	Determine rotation (0, 90, 180, 270) for edge mask based on signature.
	Helps reuse textures in different orientations.
	"""
	if not mask_rotations_enabled:
		return 0
	
	# Simple heuristic: find "primary" land direction and rotate to normalize
	# This allows using a single directional texture in 4 rotations
	
	var north_bit = (signature & 0b00000001) != 0
	var east_bit = (signature & 0b00000100) != 0
	var south_bit = (signature & 0b00010000) != 0
	var west_bit = (signature & 0b01000000) != 0
	
	# Rotate so primary edge is at north
	if east_bit and not north_bit:
		return 3  # 270° (west becomes north)
	elif south_bit and not north_bit and not east_bit:
		return 2  # 180°
	elif west_bit and not north_bit and not east_bit and not south_bit:
		return 1  # 90°
	
	return 0  # North is primary

func get_edge_flip(signature: int) -> bool:
	"""
	Determine if texture should be flipped horizontally based on signature.
	Adds variation to prevent repetitive appearance.
	"""
	# Simple approach: flip if east presence > west presence
	var east_bit = (signature & 0b00000100) != 0
	var west_bit = (signature & 0b01000000) != 0
	
	return east_bit and not west_bit

# ===================================================================
# MATERIAL & TEXTURE APPLICATION
# ===================================================================

func create_water_shader_material() -> ShaderMaterial:
	"""Create a ShaderMaterial for water tiles"""
	var material = ShaderMaterial.new()
	material.shader = load("res://assets/shaders/water_2_5d.gdshader")
	return material

func apply_edge_mask_to_tile(pos: Vector2i, mask_texture: String, rotation: int = 0, flip_h: bool = false):
	"""
	Apply edge mask texture to a water tile's material.
	Updates the shader material's water_edge_mask uniform.
	"""
	var cell_data = tilemap.get_cell_tile_data(0, pos)
	if cell_data == null:
		return
	
	# Get or create material for this tile
	var material = tilemap.get_cell_tile_data(0, pos).material
	if material == null:
		material = create_water_shader_material()
	
	# Load and assign mask texture
	if mask_texture != "":
		var texture_path = edge_mask_texture_dir + mask_texture + ".png"
		var mask_tex = load(texture_path)
		
		if mask_tex != null:
			if material is ShaderMaterial:
				material.set_shader_parameter("water_edge_mask", mask_tex)
				# TODO: Apply rotation and flip via TileData alternative tiles or custom data
		else:
			print("WARNING: Could not load mask texture: ", texture_path)

func generate_all_water_edge_masks():
	"""
	Main function: iterate all water tiles and generate edge masks.
	"""
	print("Generating water edge masks...")
	
	var masks_applied = 0
	var shoreline_tiles = 0
	var deep_water_tiles = 0
	
	# Iterate all cells in biome map
	for pos in biome_map.keys():
		var biome = biome_map[pos]
		
		if not is_water(biome):
			continue
		
		# Check if this water tile touches land
		if not has_land_neighbor(pos):
			# Deep water - no mask needed
			deep_water_tiles += 1
			continue
		
		# Shoreline water - generate edge mask
		shoreline_tiles += 1
		
		var signature = compute_edge_signature_4dir(pos) if use_simple_edges else compute_edge_signature_8dir(pos)
		var mask_texture = get_edge_mask_texture(signature)
		
		if mask_texture != "":
			var rotation = get_edge_rotation(signature) if mask_rotations_enabled else 0
			var flip_h = get_edge_flip(signature) if mask_rotations_enabled else false
			
			apply_edge_mask_to_tile(pos, mask_texture, rotation, flip_h)
			masks_applied += 1
	
	print("  Shoreline tiles: %d" % shoreline_tiles)
	print("  Deep water tiles: %d" % deep_water_tiles)
	print("  Masks applied: %d" % masks_applied)

# ===================================================================
# DEBUG & VISUALIZATION
# ===================================================================

func debug_signature_at(pos: Vector2i):
	"""Print edge signature for a specific position"""
	var biome = get_biome_at(pos)
	if not is_water(biome):
		print("Position %s is not water (biome: %d)" % [pos, biome])
		return
	
	var sig_4 = compute_edge_signature_4dir(pos)
	var sig_8 = compute_edge_signature_8dir(pos)
	var mask_tex = get_edge_mask_texture(sig_4)
	
	print("Position %s:" % pos)
	print("  4-dir signature: %s (0x%02x)" % [format_bits(sig_4, 4), sig_4])
	print("  8-dir signature: %s (0x%02x)" % [format_bits(sig_8, 8), sig_8])
	print("  Edge mask texture: %s" % mask_tex)
	print("  Rotation: %d°" % (get_edge_rotation(sig_4) * 90))
	print("  Flip H: %s" % get_edge_flip(sig_4))

func format_bits(value: int, num_bits: int) -> String:
	"""Format integer as binary string"""
	var result = ""
	for i in range(num_bits - 1, -1, -1):
		result += "1" if (value & (1 << i)) else "0"
	return result

func print_signature_stats():
	"""Print distribution of edge signatures across map"""
	var signature_counts = {}
	var shoreline_count = 0
	
	for pos in biome_map.keys():
		if not is_water(biome_map[pos]):
			continue
		
		if not has_land_neighbor(pos):
			continue
		
		shoreline_count += 1
		var sig = compute_edge_signature_4dir(pos)
		
		if not signature_counts.has(sig):
			signature_counts[sig] = 0
		signature_counts[sig] += 1
	
	print("\n=== Edge Signature Distribution ===")
	print("Total shoreline tiles: %d" % shoreline_count)
	for sig in signature_counts.keys():
		var count = signature_counts[sig]
		var percent = (count * 100.0) / shoreline_count
		print("  Signature 0x%02x: %d (%.1f%%)" % [sig, count, percent])

# ===================================================================
# CONVENIENCE FUNCTIONS
# ===================================================================

func set_simple_edges(enabled: bool):
	"""Switch between 4-directional and 8-directional edge detection"""
	use_simple_edges = enabled
	print("Simple edges (4-dir): %s" % enabled)

func set_rotation_enabled(enabled: bool):
	"""Enable/disable automatic rotation of edge textures"""
	mask_rotations_enabled = enabled
	print("Rotation support: %s" % enabled)

func register_custom_edge_variant(signature: int, texture_names: Array):
	"""Register custom texture variants for a signature pattern"""
	var variants_dict = edge_mask_simple if use_simple_edges else edge_mask_variants
	variants_dict[signature] = texture_names
	print("Registered custom edge variant: 0x%02x -> %s" % [signature, texture_names])
