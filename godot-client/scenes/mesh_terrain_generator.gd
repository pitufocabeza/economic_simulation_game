extends Node3D

################################################################################
# MESH TERRAIN GENERATOR
# Converts procedural heightmaps to visible 3D mesh
################################################################################

var plot_generator: Node3D
var mesh_instance: MeshInstance3D
var camera: Camera3D

var VERTICAL_SCALE: float = 200.0
var camera_speed: float = 50.0
var camera_sensitivity: float = 0.003
var camera_rotation: Vector2 = Vector2.ZERO  # (pitch, yaw)

func _ready() -> void:
	print("🎬 Mesh Terrain Setup Starting...")
	_setup_nodes()
	_generate_initial_plot(42)
	print("✅ Mesh Terrain Ready!")
	print("Use WASD to move camera, Q/E to up/down, SPACE to regenerate")

func _process(delta: float) -> void:
	if not camera:
		return
	
	# Movement in camera space
	var movement = Vector3.ZERO
	
	if Input.is_key_pressed(KEY_W):
		movement.z -= 1
	if Input.is_key_pressed(KEY_S):
		movement.z += 1
	if Input.is_key_pressed(KEY_A):
		movement.x -= 1
	if Input.is_key_pressed(KEY_D):
		movement.x += 1
	if Input.is_key_pressed(KEY_SPACE):
		movement.y += 1
	if Input.is_key_pressed(KEY_CTRL):
		movement.y -= 1
	
	if movement.length() > 0:
		movement = movement.normalized()
		# Move in camera's local space (forward/right/up)
		var camera_basis = camera.global_transform.basis
		var world_movement = camera_basis * movement * camera_speed * delta
		camera.global_position += world_movement

func _setup_nodes() -> void:
	# Find or create PlotGenerator
	plot_generator = find_child("PlotGenerator", true, false)
	if not plot_generator:
		plot_generator = Node3D.new()
		plot_generator.name = "PlotGenerator"
		add_child(plot_generator)
		plot_generator.set_script(load("res://scenes/temperate_map_generator.gd"))
		print("✓ Created PlotGenerator")
	
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
	
	# Position camera to see terrain from an angle
	camera.position = Vector3(20, 80, 20)
	camera.look_at(Vector3(0, 80, 0), Vector3.UP)
	camera.current = true
	print("✓ Camera positioned at %.1f, %.1f, %.1f" % [camera.position.x, camera.position.y, camera.position.z])
	print("   Mouse to look around, WASD to move, SPACE/CTRL to up/down, SPACE to regenerate")

func _generate_initial_plot(seed: int) -> void:
	if not plot_generator:
		return
	
	var plot_data: Dictionary = plot_generator.generate_plot(seed)
	var height_map: Array = plot_data["height_map"]
	var archetype: String = plot_data["archetype"]
	
	print("🌿 Generated %s plot" % archetype)
	_apply_height_map_to_mesh(height_map)

func _apply_height_map_to_mesh(height_map: Array) -> void:
	var size: int = height_map.size()
	
	# Use SurfaceTool to build mesh
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	print("Building mesh from %dx%d heightmap..." % [size, size])
	
	# Add vertices (center mesh at origin)
	for z in range(size):
		for x in range(size):
			var h: float = height_map[z][x] * VERTICAL_SCALE
			var pos = Vector3(float(x) - float(size) / 2.0, h, float(z) - float(size) / 2.0)
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
	
	# Now apply material after mesh exists
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.GREEN
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.cull_mode = BaseMaterial3D.CULL_BACK
	mesh_instance.set_surface_override_material(0, material)
	
	# Debug info
	var bounds = mesh.get_aabb()
	var max_pos = bounds.position + bounds.size
	print("✓ Mesh created with %d vertices" % (size * size))
	print("  Mesh bounds: min=(%.1f,%.1f,%.1f) max=(%.1f,%.1f,%.1f)" % [bounds.position.x, bounds.position.y, bounds.position.z, max_pos.x, max_pos.y, max_pos.z])
	print("  Centered at (0, %.0f/2, 0)" % [VERTICAL_SCALE])

func _input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion:
		var mouse_event = event as InputEventMouseMotion
		var delta = mouse_event.relative
		
		camera_rotation.y -= delta.x * camera_sensitivity  # Yaw
		camera_rotation.x -= delta.y * camera_sensitivity  # Pitch
		
		# Clamp pitch to prevent flipping
		camera_rotation.x = clamp(camera_rotation.x, -PI/2, PI/2)
		
		# Apply rotation to camera
		var euler = Vector3(camera_rotation.x, camera_rotation.y, 0)
		camera.rotation = euler
		get_tree().root.set_input_as_handled()
	
	# Regenerate terrain on SPACE
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		var new_seed = randi()
		_generate_initial_plot(new_seed)
		print("Regenerated with seed: %d" % new_seed)
