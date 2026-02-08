extends Node3D
signal clicked(plot_id: int)

@export var plot_id: int
var is_claimed: bool = false
var is_selected: bool = false
var hex_radius: float = 25.0
var hex_thickness: float = 3.0

@onready var area: Area3D = $Area3D
@onready var mesh_inst: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	area.input_event.connect(_on_area_input_event)
	area.input_ray_pickable = true
	_build_hex_mesh()
	_update_material()

func set_state(claimed: bool, selected: bool) -> void:
	is_claimed = claimed
	is_selected = selected
	_update_material()

func _build_hex_mesh() -> void:
	mesh_inst.mesh = _create_hex_array_mesh(hex_radius, hex_thickness)

	# Update collision shape to match hex
	var col: CollisionShape3D = area.get_node("CollisionShape3D") as CollisionShape3D
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = hex_radius
	cyl.height = hex_thickness * 2.0
	col.shape = cyl

func _create_hex_array_mesh(hex_radius: float, thickness: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var verts: Array[Vector3] = []
	for i: int in range(6):
		var angle: float = TAU * float(i) / 6.0
		verts.append(Vector3(cos(angle) * hex_radius, 0.0, sin(angle) * hex_radius))

	var center_top: Vector3 = Vector3(0.0, thickness * 0.5, 0.0)
	var center_bot: Vector3 = Vector3(0.0, -thickness * 0.5, 0.0)

	# Top face
	for i: int in range(6):
		var i_next: int = (i + 1) % 6
		var v0: Vector3 = verts[i] + Vector3(0.0, thickness * 0.5, 0.0)
		var v1: Vector3 = verts[i_next] + Vector3(0.0, thickness * 0.5, 0.0)

		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(center_top)

		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5 + cos(TAU * float(i) / 6.0) * 0.5, 0.5 + sin(TAU * float(i) / 6.0) * 0.5))
		st.add_vertex(v0)

		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5 + cos(TAU * float(i_next) / 6.0) * 0.5, 0.5 + sin(TAU * float(i_next) / 6.0) * 0.5))
		st.add_vertex(v1)

	# Bottom face
	for i: int in range(6):
		var i_next: int = (i + 1) % 6
		var v0: Vector3 = verts[i] + Vector3(0.0, -thickness * 0.5, 0.0)
		var v1: Vector3 = verts[i_next] + Vector3(0.0, -thickness * 0.5, 0.0)

		st.set_normal(Vector3.DOWN)
		st.add_vertex(center_bot)
		st.set_normal(Vector3.DOWN)
		st.add_vertex(v1)
		st.set_normal(Vector3.DOWN)
		st.add_vertex(v0)

	# Side faces
	for i: int in range(6):
		var i_next: int = (i + 1) % 6
		var top0: Vector3 = verts[i] + Vector3(0.0, thickness * 0.5, 0.0)
		var top1: Vector3 = verts[i_next] + Vector3(0.0, thickness * 0.5, 0.0)
		var bot0: Vector3 = verts[i] + Vector3(0.0, -thickness * 0.5, 0.0)
		var bot1: Vector3 = verts[i_next] + Vector3(0.0, -thickness * 0.5, 0.0)

		var edge: Vector3 = (verts[i_next] - verts[i]).normalized()
		var side_normal: Vector3 = edge.cross(Vector3.UP).normalized()

		st.set_normal(side_normal)
		st.add_vertex(top0)
		st.set_normal(side_normal)
		st.add_vertex(bot0)
		st.set_normal(side_normal)
		st.add_vertex(top1)

		st.set_normal(side_normal)
		st.add_vertex(top1)
		st.set_normal(side_normal)
		st.add_vertex(bot0)
		st.set_normal(side_normal)
		st.add_vertex(bot1)

	st.generate_tangents()
	return st.commit()

func _update_material() -> void:
	if mesh_inst == null:
		return

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	if is_selected:
		mat.albedo_color = Color(1.0, 0.85, 0.1, 0.9)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.85, 0.1)
		mat.emission_energy_multiplier = 0.3
	elif is_claimed:
		mat.albedo_color = Color(0.85, 0.2, 0.15, 0.75)
		mat.emission_enabled = true
		mat.emission = Color(0.85, 0.2, 0.15)
		mat.emission_energy_multiplier = 0.15
	else:
		mat.albedo_color = Color(0.15, 0.8, 0.35, 0.6)
		mat.emission_enabled = true
		mat.emission = Color(0.15, 0.8, 0.35)
		mat.emission_energy_multiplier = 0.1

	mesh_inst.material_override = mat

func _on_area_input_event(
	camera: Camera3D,
	event: InputEvent,
	event_position: Vector3,
	normal: Vector3,
	shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			emit_signal("clicked", plot_id)
