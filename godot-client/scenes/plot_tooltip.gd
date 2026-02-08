extends PanelContainer

## Floating tooltip that follows the mouse cursor.
## Shown when hovering over a plot hex on the planet.

@onready var lbl_archetype: Label = $VBox/LblArchetype
@onready var lbl_size: Label = $VBox/LblSize
@onready var lbl_resources: Label = $VBox/LblResources

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func show_for_plot(info: PlotInfo) -> void:
	lbl_archetype.text = "Archetype: %s" % info.archetype
	lbl_size.text = "Plot Size: %dx%d" % [info.plot_size, info.plot_size]
	lbl_resources.text = "Resources: %d" % info.get_total_resources()
	visible = true

func follow_mouse(screen_pos: Vector2) -> void:
	# Offset so cursor doesn't obscure the tooltip
	var offset: Vector2 = Vector2(16.0, 16.0)
	var vp_size: Vector2 = get_viewport_rect().size
	var target: Vector2 = screen_pos + offset

	# Keep tooltip on screen
	if target.x + size.x > vp_size.x:
		target.x = screen_pos.x - size.x - 8.0
	if target.y + size.y > vp_size.y:
		target.y = screen_pos.y - size.y - 8.0

	global_position = target

func hide_tooltip() -> void:
	visible = false
