extends Node3D

################################################################################
# TEST SCENE SETUP - SIMPLIFIED
# Assumes Terrain3D is already in the scene
################################################################################

var plot_generator: Node3D
var terrain3d: Node3D
var plot_integrator: Node3D
var camera: Camera3D

func _ready() -> void:
	print("🎬 Test Scene Setup Starting...")
	_find_existing_nodes()
	_setup_integrator_references()
	_generate_initial_plot(42)
	print("✅ Test Scene Ready!")

func _find_existing_nodes() -> void:
	# Check if current node IS Terrain3D
	if self.is_class("Terrain3D"):
		terrain3d = self
	else:
		# Look for existing nodes in the scene
		terrain3d = find_child("Terrain3D", true, false)
	
	plot_generator = find_child("PlotGenerator", true, false)
	plot_integrator = find_child("PlotIntegrator", true, false)
	camera = find_child("Camera3D", true, false)
	
	# Create PlotGenerator if missing
	if not plot_generator:
		plot_generator = Node3D.new()
		plot_generator.name = "PlotGenerator"
		add_child(plot_generator)
		plot_generator.set_script(load("res://scenes/temperate_map_generator.gd"))
		print("✓ Created PlotGenerator")
	
	# Create PlotIntegrator if missing
	if not plot_integrator:
		plot_integrator = Node3D.new()
		plot_integrator.name = "PlotIntegrator"
		add_child(plot_integrator)
		plot_integrator.set_script(load("res://scenes/terrain3d_plot_integrator.gd"))
		print("✓ Created PlotIntegrator")
	
	# Warn if Terrain3D not found
	if not terrain3d:
		print("⚠️  Terrain3D not found in scene. Please add it manually in the editor.")
		print("⚠️  Make sure to create at least one region in Terrain3D's data.")
		return
	
	print("✓ Found Terrain3D in scene")

func _setup_integrator_references() -> void:
	if not plot_integrator or not plot_generator:
		return
	
	plot_integrator.plot_generator = plot_generator
	if terrain3d:
		plot_integrator.terrain3d = terrain3d
		plot_integrator.VERTICAL_SCALE = 8.0
		print("✓ Integrator references configured")

func _generate_initial_plot(seed: int) -> void:
	if plot_integrator and terrain3d:
		var result = plot_integrator.generate_and_apply(seed)
		print("Generated plot archetype: %s" % result.get("archetype", "unknown"))
	else:
		print("⚠️  Ct generate plot - missing Terrain3D or PlotIntegrator")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		var new_seed = randi()
		_generate_initial_plot(new_seed)
		print("Regenerated with seed: %d" % new_seed)
