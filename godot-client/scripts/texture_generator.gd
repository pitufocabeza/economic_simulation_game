extends Node

# Procedural Water & Overlay Texture Generator
# Generates placeholder textures for water shader and edge overlays if they don't exist

class_name TextureGenerator

static func create_water_textures(output_dir: String = "res://assets/tilesets/temperate/") -> bool:
	"""Create procedural water textures if they don't exist"""
	
	print("Checking water textures...")
	
	# Check and create water base color
	if not ResourceLoader.exists(output_dir + "water_base_color.png"):
		print("  Creating water_base_color.png...")
		var img = Image.create(256, 256, false, Image.FORMAT_RGB8)
		for y in range(256):
			for x in range(256):
				# Gradient from dark blue (deep) to lighter blue (shallow)
				var factor = float(y) / 256.0
				var r = int(lerp(25.0, 76.0, factor))
				var g = int(lerp(51.0, 153.0, factor))
				var b = int(lerp(102.0, 204.0, factor))
				img.set_pixel(x, y, Color8(r, g, b, 255))
		# Save would go here, but we can't save in-engine easily
		print("    (Would save but requires filesystem access)")
	
	# Check and create water normal map
	if not ResourceLoader.exists(output_dir + "water_normal.png"):
		print("  Creating water_normal.png...")
		var img = Image.create(256, 256, false, Image.FORMAT_RGB8)
		for y in range(256):
			for x in range(256):
				# Create simple wave pattern
				var wave = sin((x + y) * 0.1) * 0.5 + 0.5
				var r = int(wave * 255)
				var g = int(127)  # Normal map neutral Y
				var b = int(255)   # Normal map neutral Z
				img.set_pixel(x, y, Color8(r, g, b, 255))
		print("    (Would save but requires filesystem access)")
	
	# Check and create edge mask
	if not ResourceLoader.exists(output_dir + "water_edge_combined_mask.png"):
		print("  Creating water_edge_combined_mask.png...")
		var img = Image.create(256, 256, false, Image.FORMAT_L8)
		for y in range(256):
			for x in range(256):
				# Edges are brighter (white = shoreline)
				var edge_dist = min(x, y, 255 - x, 255 - y)
				var value = int(255 * (1.0 - (edge_dist / 64.0)))  # Fade from edge
				img.set_pixel(x, y, Color8(value, value, value, 255))
		print("    (Would save but requires filesystem access)")
	
	print("Water texture check complete")
	return true

static func generate_white_texture(size: int = 256) -> ImageTexture:
	"""Generate a simple white texture"""
	var img = Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)

static func generate_normal_texture(size: int = 256) -> ImageTexture:
	"""Generate a simple normal map (blue/purple)"""
	var img = Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in range(size):
		for x in range(size):
			# Wave pattern for normals
			var wave = sin((x + y) * 0.1) * 0.3 + 0.5
			img.set_pixel(x, y, Color(wave, 0.5, 1.0, 1.0))
	return ImageTexture.create_from_image(img)

static func generate_edge_mask_texture(size: int = 256) -> ImageTexture:
	"""Generate edge mask (bright at edges, dark in center)"""
	var img = Image.create(size, size, false, Image.FORMAT_L8)
	var center = size / 2.0
	var max_dist = sqrt(center * center * 2)
	
	for y in range(size):
		for x in range(size):
			var dx = x - center
			var dy = y - center
			var dist = sqrt(dx * dx + dy * dy)
			var value = 1.0 - (dist / max_dist)  # 1.0 at center, 0.0 at edges
			img.set_pixel(x, y, Color(value, value, value, 1.0))
	
	return ImageTexture.create_from_image(img)
