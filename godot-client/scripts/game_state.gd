extends Node

var current_company_id: int = 0
var current_location_id: int = 0
var player_inventory: Dictionary = {}

# ── Plot state cache ────────────────────────────────────────────────
# Key: "star_id:plot_id"  →  Value: Dictionary {
#     "buildings": [{ "def_path": String, "position": Vector3, "rotation_y": float,
#                     "tiles": [Vector2i, ...] }, ...],
#     "occupied_tiles": { Vector2i: true, ... },
#     "visited": true
# }
var plot_cache: Dictionary = {}

func _ready():
	pass

## Build a unique key for a given plot on a given star.
func plot_key(star_id: int, plot_id: int) -> String:
	return "%d:%d" % [star_id, plot_id]

## Return cached state dict for a plot, or an empty dict if none.
func get_plot_state(key: String) -> Dictionary:
	return plot_cache.get(key, {})

## Store plot state.
func set_plot_state(key: String, state: Dictionary) -> void:
	plot_cache[key] = state

## Check whether a plot has cached state.
func has_plot_state(key: String) -> bool:
	return plot_cache.has(key)
