extends Node3D

################################################################################
# MESH TERRAIN GENERATOR
# Converts procedural heightmaps to visible 3D mesh
################################################################################

var plot_generator: Node3D
var mesh_instance: MeshInstance3D
var camera: Camera3D

@export var plot_size: int = 16  # 12, 16, or 20 cell plots
var VERTICAL_SCALE: float = 3.0
var camera_speed: float = 35.0

# Plot size cycling
var PLOT_SIZES: Array = [12, 16, 20]  # Available plot sizes
var current_size_index: int = 1  # Index in PLOT_SIZES (default 16)

# Camera tilt control
var camera_pitch: float = 0.0  # Vertical tilt angle in radians
var camera_yaw: float = 0.0    # Horizontal rotation angle in radians
var tilt_speed: float = 0.05   # Mouse wheel tilt sensitivity

# Debug color palette
var COLOR_WATER = Color(0.1, 0.3, 0.8)        # Blue
var COLOR_BEACH = Color(0.85, 0.8, 0.55)      # Sand
var COLOR_BUILDABLE = Color(0.2, 0.7, 0.3)    # Green
var COLOR_UNBUILDABLE = Color(0.5, 0.5, 0.5)  # Grey/Rock

func _ready() -> void:
	print("🎬 Mesh Terrain Setup Starting...")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_setup_nodes()
	_generate_initial_plot(42)
	print("✅ Mesh Terrain Ready!")
	print("📷 Free-fly Camera Controls:")
	print("   WASD = forward/back/strafe left/right")
	print("   Q/E = move down/up")
	print("   Mouse = look around")
	print("   R = regenerate island")
	print("   T = cycle plot sizes (12/16/20)")
	print("   ESC = release mouse")

func _process(delta: float) -> void:
	if not camera:
		return
	
	# Free-fly camera movement in camera's local space
	var direction = Vector3.ZERO
	
	if Input.is_key_pressed(KEY_W):
		direction -= camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		direction += camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		direction -= camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		direction += camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_Q):
		direction -= camera.global_transform.basis.y
	if Input.is_key_pressed(KEY_E):
		direction += camera.global_transform.basis.y
	
	if direction != Vector3.ZERO:
		camera.global_position += direction.normalized() * camera_speed * delta

func _setup_nodes() -> void:
	# Find or create PlotGenerator
	plot_generator = find_child("PlotGenerator", true, false)
	if not plot_generator:
		plot_generator = Node3D.new()
		plot_generator.name = "PlotGenerator"
		add_child(plot_generator)
		plot_generator.set_script(load("res://scenes/temperate_map_generator.gd"))
		print("✓ Created PlotGenerator")
	
	# Configure plot size on the generator
	if plot_generator.has_method("set_grid_resolution"):
		plot_generator.set_grid_resolution(plot_size)
	else:
		# Direct property access if method doesn't exist
		plot_generator.GRID_RESOLUTION = plot_size
	
	# Find or create MeshInstance3D
	mesh_instance = find_child("TerrainMesh", true, false) as MeshInstance3D
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "TerrainMesh"
		add_child(mesh_instance)
		print("✓ Created TerrainMesh")
	
	# Add lighting
	var light = find_child("DirectionalLight3D", true, false)
	if not light:
		light = DirectionalLight3D.new()
		light.name = "DirectionalLight3D"
		add_child(light)
		light.rotation = Vector3(deg_to_rad(-45), deg_to_rad(-45), 0)
		print("✓ Created lighting")
	
	# Position camera
	camera = find_child("Camera3D", true, false) as Camera3D
	if not camera:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
	
	# Calculate camera position based on plot size
	var half_size = float(plot_size) / 2.0
	var cam_dist = half_size * 1.0  # Distance from center scaled to plot size
	camera.position = Vector3(cam_dist, half_size * 2.5, cam_dist)
	camera.look_at(Vector3(0, half_size * 0.5, 0), Vector3.UP)
	camera.current = true
	print("✓ Camera positioned isometric at %.1f, %.1f, %.1f" % [camera.position.x, camera.position.y, camera.position.z])
	print("   Plot size: %dx%d cells" % [plot_size, plot_size])

func _generate_initial_plot(seed: int) -> void:
	if not plot_generator:
		return
	
	var plot_data: Dictionary = plot_generator.generate_plot(seed)
	var height_map: Array = plot_data["height_map"]
	var archetype: String = plot_data["archetype"]
	var island_mask: Array = plot_data["island_mask"]
	var buildable_map: Array = plot_data["buildable_map"]
	
	print("🏝️ Generated %s island (seed: %d)" % [archetype, seed])
	_apply_height_map_to_mesh(height_map, island_mask, buildable_map)

func _apply_height_map_to_mesh(height_map: Array, island_mask: Array, buildable_map: Array) -> void:
	var size: int = height_map.size()
	
	# Use SurfaceTool to build mesh
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	print("Building mesh from %dx%d heightmap..." % [size, size])
	
	# Generate debug colors for each vertex
	var vertex_colors = _generate_debug_colors(island_mask, height_map, buildable_map)
	
	# Add vertices with debug colors (center mesh at origin)
	# IMPORTANT: set_color() must be called BEFORE add_vertex() to establish format
	for z in range(size):
		for x in range(size):
			var h: float = height_map[z][x] * VERTICAL_SCALE
			var pos = Vector3(float(x) - float(size) / 2.0, h, float(z) - float(size) / 2.0)
			var color = vertex_colors[z][x]
			surface_tool.set_color(color)  # Set color BEFORE vertex
			surface_tool.add_vertex(pos)
	
	# Add triangles (two per grid square)
	for z in range(size - 1):
		for x in range(size - 1):
			var a = z * size + x
			var b = z * size + (x + 1)
			var c = (z + 1) * size + x
			var d = (z + 1) * size + (x + 1)
			
			# First triangle
			surface_tool.add_index(a)
			surface_tool.add_index(c)
			surface_tool.add_index(b)
			
			# Second triangle
			surface_tool.add_index(b)
			surface_tool.add_index(c)
			surface_tool.add_index(d)
	
	# Create mesh and assign to instance
	surface_tool.generate_normals()
	var mesh = surface_tool.commit()
	mesh_instance.mesh = mesh
	
	# Apply terrain shader material
	var terrain_material = load("res://scenes/terrain_material.tres")
	if terrain_material:
		mesh_instance.set_surface_override_material(0, terrain_material)
		print("✓ Applied shader material with textures")
	else:
		# Fallback if material not found
		var material = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color.WHITE
		mesh_instance.set_surface_override_material(0, material)
		print("⚠️ Terrain material not found, using fallback")
	
	# Debug info
	var bounds = mesh.get_aabb()
	var max_pos = bounds.position + bounds.size
	print("✓ Mesh created with %d vertices" % (size * size))
	print("  Mesh bounds: min=(%.1f,%.1f,%.1f) max=(%.1f,%.1f,%.1f)" % [bounds.position.x, bounds.position.y, bounds.position.z, max_pos.x, max_pos.y, max_pos.z])
	print("  Centered at (0, %.0f/2, 0)" % [VERTICAL_SCALE])

func _generate_debug_colors(island_mask: Array, height_map: Array, buildable_map: Array) -> Array:
	"""Generate debug colors for terrain based on mask topology and buildability.
	
	Classification order (topology-first):
	1) If island_mask[z][x] == WATER (0) → WATER (blue)
	2) Else if LAND with WATER neighbor → BEACH (sand)
	3) Else if buildable_map[z][x] == true → BUILDABLE LAND (green)
	4) Else → UNBUILDABLE LAND (grey)
	"""
	var size = island_mask.size()
	var colors = []
	
	for z in range(size):
		colors.append([])
		for x in range(size):
			var color: Color
			var mask_val = island_mask[z][x]
			var buildable_val = buildable_map[z][x]
			
			# Classification logic (topology-based)
			if mask_val == 0:  # Water
				color = COLOR_WATER  # Blue
			elif _has_water_neighbor(x, z, island_mask):  # Land adjacent to water
				color = COLOR_BEACH  # Sand
			elif buildable_val:  # Buildable land (interior)
				color = COLOR_BUILDABLE  # Green
			else:  # Unbuildable land (interior)
				color = COLOR_UNBUILDABLE  # Grey
			
			colors[z].append(color)
	
	return colors

func _has_water_neighbor(x: int, z: int, mask: Array) -> bool:
	"""Check if a LAND cell has at least one WATER neighbor (N/E/S/W)."""
	var size = mask.size()
	var neighbors = [
		Vector2i(x, z - 1),  # North
		Vector2i(x + 1, z),  # East
		Vector2i(x, z + 1),  # South
		Vector2i(x - 1, z),  # West
	]
	
	for neighbor in neighbors:
		if neighbor.x >= 0 and neighbor.x < size and neighbor.y >= 0 and neighbor.y < size:
			if mask[neighbor.y][neighbor.x] == 0:  # WATER
				return true
	
	return false

func _input(event: InputEvent) -> void:
	if not camera:
		return
	
	# Regenerate terrain on R key
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		var new_seed = randi()
		_generate_initial_plot(new_seed)
		print("🔄 Regenerated with seed: %d" % new_seed)
		get_tree().root.set_input_as_handled()
	
	# Toggle mouse capture with ESC
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Cycle plot sizes with T key
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		current_size_index = (current_size_index + 1) % PLOT_SIZES.size()
		plot_size = PLOT_SIZES[current_size_index]
		print("📋 Plot size changed to %dx%d" % [plot_size, plot_size])
		_setup_nodes()  # Reconfigure with new size
		var new_seed = randi()
		_generate_initial_plot(new_seed)
		print("🔄 Regenerated with seed: %d" % new_seed)
		get_tree().root.set_input_as_handled()
	
	# Mouse wheel tilt/pan controls
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_pitch = clamp(camera_pitch + tilt_speed, -0.6, 0.6)
			_update_camera_transform()
			get_tree().root.set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_pitch = clamp(camera_pitch - tilt_speed, -0.6, 0.6)
			_update_camera_transform()
			get_tree().root.set_input_as_handled()

func _update_camera_transform() -> void:
	if not camera:
		return
	
	# Get the current camera distance and lookat point
	var half_size = float(plot_size) / 2.0
	var lookat_point = Vector3(0, half_size * 0.5, 0)
	var cam_dist = half_size * 1.2
	
	# Calculate camera position with tilt applied
	# Base position in isometric view (45° both axes)
	var base_angle = PI / 4.0  # 45 degrees
	var horizontal_dist = cam_dist * cos(camera_pitch)
	var vertical_offset = cam_dist * sin(camera_pitch)
	
	var pos_x = horizontal_dist * cos(base_angle)
	var pos_z = horizontal_dist * sin(base_angle)
	var pos_y = (half_size * 2.5) + vertical_offset
	
	camera.global_position = Vector3(pos_x, pos_y, pos_z)
	camera.look_at(lookat_point, Vector3.UP)
