extends MeshInstance3D

@export var radius: float = 5000.0
@export var segments: int = 128
@export var color: Color = Color(0.6, 0.7, 1.0, 0.35)

func _ready():
	_draw_orbit()


func _draw_orbit():
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()

	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.disable_depth_test = false

	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)

	for i in range(segments + 1):
		var t := float(i) / segments * TAU
		var x := cos(t) * radius
		var z := sin(t) * radius
		mesh.surface_add_vertex(Vector3(x, 0.05, z))

	mesh.surface_end()
	self.mesh = mesh
