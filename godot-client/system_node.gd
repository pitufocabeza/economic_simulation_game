extends Node2D
var star_data: StarData

signal system_selected(star_data)

@export var system_id: String
@export var system_name: String
@export var region_type: String  # Faction | Outlaw | Player

@onready var star := $StarIcon
@onready var selection_ring := $SelectionRing
@onready var label := $Label

var select_tween: Tween
var area: Area2D

func _ready():
	label.text = system_name
	label.position = Vector2(0, 26)
	var c := Color(0.3, 0.6, 1.0) # faction example
	star.modulate = c
	$Glow.modulate = c
	$Glow.modulate.a = 0.25

	# brighten the core slightly
	star.modulate = star.modulate.lightened(0.25)
	_create_click_area()
	star.z_index = 1
	selection_ring.z_index = 2
	label.z_index = 3
	
	selection_ring.visible = false
	selection_ring.scale = Vector2.ONE * 1.6
	selection_ring.modulate = Color(0.7, 0.85, 1.0, 0.45)


func _create_click_area():
	area = Area2D.new()
	add_child(area)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 300   # adjust to star size
	shape.shape = circle

	area.add_child(shape)
	area.input_event.connect(_on_area_input_event)


func _on_area_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		emit_signal("system_selected", star_data)

func _process(_delta):
	var cam := get_viewport().get_camera_2d()
	if cam:
		var z: float = cam.zoom.x
		label.modulate.a = clamp(1.0 - (z / 1200.0), 0.0, 1.0)
		label.visible = z < 900.0
	if selection_ring.visible:
		selection_ring.rotation += _delta * 0.25
		
func set_selected(selected: bool):
	selection_ring.visible = selected
	
	if select_tween and select_tween.is_valid():
		select_tween.kill()

	
	if selected:
		selection_ring.scale = Vector2.ONE * 1.6
		select_tween = create_tween().set_loops()
		select_tween.tween_property(
			selection_ring,
			"scale",
			Vector2.ONE * 2.0,
			0.8
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func update_visuals(z: float) -> void:
	# Pure stylistic scaling only (no camera compensation)
	var star_scale := 1.0

	if z >= 600.0:
		star_scale = 1.2
	elif z >= 300.0:
		star_scale = 1.1

	star.scale = Vector2.ONE * 0.8
	$Glow.scale = Vector2.ONE * 2.8
	selection_ring.scale = Vector2.ONE * star_scale * 1.8

	label.visible = z < 650.0
	label.modulate.a = clamp(1.0 - (z / 600.0), 0.0, 1.0)
