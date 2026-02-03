extends Control
class_name BuildMenu

signal building_selected(definition)

@export var building_definitions: Array[BuildingDefinition]

var grid: Control

func _ready():
	grid = get_node_or_null("Panel/GridContainer")
	if grid == null:
		grid = get_node_or_null("VBoxContainer")
	if grid == null:
		push_error("BuildMenu: Missing container. Expected Panel/GridContainer or VBoxContainer.")
		return
	_populate_menu()

func _populate_menu():
	for child in grid.get_children():
		if child is Button:
			child.queue_free()

	if building_definitions.is_empty():
		push_warning("BuildMenu: No building_definitions assigned.")
		return

	for def in building_definitions:
		var button := Button.new()
		button.text = def.name
		if def.icon:
			button.icon = def.icon

		button.pressed.connect(func():
			print("BuildMenu: pressed ", def.name)
			emit_signal("building_selected", def)
		)

		grid.add_child(button)
