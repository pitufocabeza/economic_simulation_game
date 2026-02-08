extends PanelContainer

## Detail panel shown when a plot is selected (clicked).
## Displays full plot info and a "Claim Plot" button.

signal claim_requested(plot_id: int)
signal enter_requested(plot_id: int)
signal closed()

var current_plot_id: int = -1

@onready var lbl_title: Label = $MarginContainer/VBox/LblTitle
@onready var lbl_archetype: Label = $MarginContainer/VBox/LblArchetype
@onready var lbl_size: Label = $MarginContainer/VBox/LblSize
@onready var lbl_total: Label = $MarginContainer/VBox/LblTotal
@onready var resource_list: VBoxContainer = $MarginContainer/VBox/ResourceList
@onready var btn_claim: Button = $MarginContainer/VBox/BtnClaim
@onready var btn_close: Button = $MarginContainer/VBox/BtnClose

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	btn_claim.pressed.connect(_on_claim_pressed)
	btn_close.pressed.connect(_on_close_pressed)

func show_for_plot(info: PlotInfo) -> void:
	current_plot_id = info.plot_id
	lbl_title.text = "Plot #%d" % info.plot_id
	lbl_archetype.text = "Archetype: %s" % info.archetype
	lbl_size.text = "Size: %dx%d" % [info.plot_size, info.plot_size]
	lbl_total.text = "Total Resources: %d" % info.get_total_resources()

	# Populate individual resources
	for c: Node in resource_list.get_children():
		c.queue_free()

	for res_name: String in info.resources.keys():
		var lbl: Label = Label.new()
		lbl.text = "  %s: %d" % [res_name, info.resources[res_name]]
		lbl.add_theme_font_size_override("font_size", 13)
		resource_list.add_child(lbl)

	# Button state depends on ownership
	if not info.claimed:
		btn_claim.text = "Claim Plot"
		btn_claim.disabled = false
	elif info.claimed_by == GameState.current_company_id:
		btn_claim.text = "Enter Plot"
		btn_claim.disabled = false
	else:
		btn_claim.text = "Claimed"
		btn_claim.disabled = true

	visible = true

func _on_claim_pressed() -> void:
	# Re-check current info to decide which signal to emit
	if btn_claim.text == "Enter Plot":
		emit_signal("enter_requested", current_plot_id)
	else:
		emit_signal("claim_requested", current_plot_id)

func _on_close_pressed() -> void:
	visible = false
	emit_signal("closed")
