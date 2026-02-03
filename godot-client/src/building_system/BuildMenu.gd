extends Control

signal building_selected(definition: BuildingDefinition)

@export var building_definitions: Array[Resource]

func _ready():
	var vbox = $VBoxContainer
	for def in building_definitions:
		var btn = Button.new()
		btn.text = def.name
		if def.icon:
			btn.icon = def.icon
		btn.pressed.connect(func():
			emit_signal("building_selected", def)
		)
		vbox.add_child(btn)
