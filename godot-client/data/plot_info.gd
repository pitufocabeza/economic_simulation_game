class_name PlotInfo
extends Resource

## Lightweight data container for a single plot on a planet.
## Will later be populated from the backend; for now uses dummy data.

@export var plot_id: int = -1
@export var archetype: String = "Unknown"
@export var plot_size: int = 256			# grid side length (256 = 256x256)
@export var claimed: bool = false
@export var claimed_by: int = -1				# company id (-1 = unclaimed)

# Resource deposits on this plot: { "Iron Ore": 1200, "Coal": 800, ... }
@export var resources: Dictionary = {}

func get_total_resources() -> int:
	var total: int = 0
	for amount: Variant in resources.values():
		total += int(amount)
	return total

func get_resource_summary() -> String:
	if resources.is_empty():
		return "None"
	var parts: PackedStringArray = PackedStringArray()
	for res_name: String in resources.keys():
		parts.append("%s: %d" % [res_name, resources[res_name]])
	return ", ".join(parts)
