extends Node3D

## A single star system on the 3-D galaxy map.
## Emissive sphere + glow halo + selection ring + Label3D.

signal system_selected(star_data: StarData)

var _star_data: StarData
var _region_color: Color = Color.WHITE
var _selected: bool = false

@onready var star_mesh: MeshInstance3D = $StarMesh
@onready var glow_mesh: MeshInstance3D = $GlowMesh
@onready var selection_ring: MeshInstance3D = $SelectionRing
@onready var label: Label3D = $Label3D
@onready var click_area: Area3D = $ClickArea

func setup(sys_name: String, _region_name: String, region_color: Color, star_data: StarData) -> void:
	_star_data = star_data
	_region_color = region_color

	# Label
	label.text = sys_name
	label.modulate = Color(0.85, 0.85, 0.85, 0.8)

	# Star mesh material
	var star_mat: StandardMaterial3D = star_mesh.material_override as StandardMaterial3D
	if star_mat != null:
		star_mat = star_mat.duplicate() as StandardMaterial3D
		star_mat.albedo_color = region_color.lightened(0.3)
		star_mat.emission = region_color
		star_mat.emission_energy_multiplier = 1.5
		star_mesh.material_override = star_mat

	# Glow mesh material
	var glow_mat: StandardMaterial3D = glow_mesh.material_override as StandardMaterial3D
	if glow_mat != null:
		glow_mat = glow_mat.duplicate() as StandardMaterial3D
		glow_mat.albedo_color = Color(region_color.r, region_color.g, region_color.b, 0.2)
		glow_mat.emission = region_color
		glow_mat.emission_energy_multiplier = 0.6
		glow_mesh.material_override = glow_mat

	selection_ring.visible = false

func _ready() -> void:
	click_area.input_event.connect(_on_area_input)

func _on_area_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			system_selected.emit(_star_data)

func get_star_data() -> StarData:
	return _star_data

func set_selected(sel: bool) -> void:
	_selected = sel
	selection_ring.visible = sel

func set_label_alpha(a: float) -> void:
	label.modulate.a = clampf(a * 0.8, 0.0, 0.8)

func _process(delta: float) -> void:
	if _selected and selection_ring.visible:
		selection_ring.rotate_y(delta * 0.5)
