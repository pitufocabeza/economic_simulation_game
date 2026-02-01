extends Node

# TileSet Generator from PNG files
# Creates a TileSet .tres resource file from temperate tile PNGs

var tiles_dir = "res://assets/tilesets/isometric/temperate/"
var output_path = "res://assets/tilesets/temperate_tileset.tres"

func _ready():
	print("=== Generating TileSet Resource ===")
	generate_tileset()

func generate_tileset():
	"""Generate a TileSet resource from PNG files"""
	print("Loading tiles from: ", tiles_dir)
	
	var dir = DirAccess.open(tiles_dir)
	if dir == null:
		print("ERROR: Could not open directory: ", tiles_dir)
		return
	
	# Create TileSet
	var tileset = TileSet.new()
	
	# Configure for isometric layout - let Godot do the math
	tileset.tile_layout = 1  # ISOMETRIC_ODD_X
	tileset.tile_offset_axis = 1  # Y axis offset
	print("TileSet configured for isometric layout")
	
	# Collect PNG files
	var png_files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".png"):
			png_files.append(file_name)
		file_name = dir.get_next()
	
	png_files.sort()
	print("Found %d PNG files: %s" % [png_files.size(), png_files])
	
	if png_files.is_empty():
		print("ERROR: No PNG files found in: ", tiles_dir)
		return
	
	# Add each PNG as a source
	var source_id = 0
	for png_file in png_files:
		var tile_path = tiles_dir + png_file
		
		# Load image directly
		var image = Image.new()
		var error = image.load(tile_path)
		
		if error != OK:
			print("ERROR: Could not load image %s (error code: %d)" % [tile_path, error])
			continue
		
		if image.is_empty():
			print("ERROR: Image is empty: ", tile_path)
			continue
		
		# Create texture from image
		var texture = ImageTexture.create_from_image(image)
		
		# Create atlas source
		var source = TileSetAtlasSource.new()
		source.texture = texture
		
		# Use FULL image size - Godot will handle isometric spacing
		var tile_width = int(image.get_width())
		var tile_height = int(image.get_height())
		
		# For isometric: height should be ~50% of width for proper diamond shape
		# But since your tiles are square (768x768), set region accordingly
		source.texture_region_size = Vector2i(tile_width, tile_height)
		
		# Add source to tileset
		tileset.add_source(source, source_id)
		
		# Create tile at (0,0)
		source.create_tile(Vector2i(0, 0))
		
		print("  ✓ Added source %d: %s (region: %dx%d)" % [source_id, png_file, tile_width, tile_height])
		source_id += 1
	
	# Save as resource
	var error = ResourceSaver.save(tileset, output_path)
	if error == OK:
		print("✓ TileSet saved to: ", output_path)
	else:
		print("ERROR: Failed to save TileSet (error code: ", error, ")")
	
	print("TileSet generation complete!")
