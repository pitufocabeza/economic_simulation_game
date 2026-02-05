extends Node2D
var star_data: StarData

signal system_selected(star_data)

@export var system_id: String
@export var system_name: String
@export var region_type: String  # Faction | Outlaw | Player

@onready var sprite := $StarIcon
@onready var selection_ring := $SelectionRing
@onready var label := $Label

var area: Area2D

func _ready():
	label.text = system_name
	label.position = Vector2(0, 26)
	match region_type:
		"Faction":
			sprite.modulate = Color(0.3, 0.6, 1.0)
		"Outlaw":
			sprite.modulate = Color(0.8, 0.2, 0.2)
		"Player":
			sprite.modulate = Color(0.2, 0.8, 0.2)
			
	_create_click_area()
	sprite.z_index = 1
	selection_ring.z_index = 2
	label.z_index = 3
	
	selection_ring.visible = false
	selection_ring.scale = Vector2.ONE * 1.2
	selection_ring.modulate.a = 0.6


func _create_click_area():
	area = Area2D.new()
	add_child(area)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 300   # adjust to sprite size
	shape.shape = circle

	area.add_child(shape)
	area.input_event.connect(_on_area_input_event)


func _on_area_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		emit_signal("system_selected", star_data)

func _process(_delta):
	var cam := get_viewport().get_camera_2d()
	if cam:
		scale = Vector2.ONE / cam.zoom
		var z: float = cam.zoom.x
		label.modulate.a = clamp(1.0 - (z / 1200.0), 0.0, 1.0)
		label.visible = z < 900.0
		
func set_selected(selected: bool):
	selection_ring.visible = selected
	if selected:
		var tween := create_tween().set_loops()
		tween.tween_property(
			selection_ring,
			"scale",
			Vector2.ONE * 1.6,
			0.8
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func update_visuals(z: float) -> void:
	# Screen-space biased scaling
	var t: float = clamp((z - 300.0) / 1200.0, 0.0, 1.0)

	# Stars get slightly larger when zoomed out, but never explode
	var star_scale: float = lerp(1.0, 1.8, t)
	$Star.scale = Vector2.ONE * star_scale
	$Glow.scale = Vector2.ONE * star_scale * 1.8

	# Labels only at closer zoom
	label.visible = z < 650.0
	label.modulate.a = clamp(1.0 - (z / 600.0), 0.0, 1.0)
