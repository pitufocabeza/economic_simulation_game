class_name CliffModule
extends Resource

## Reusable cliff mesh module for edge-based cliff rendering.
## Cliffs are instantiated procedurally at detected terrain edges.

## Mesh scene (packed with materials, variants, etc.)
@export var mesh: PackedScene

## Height range (in normalized terrain units, 0-1)
@export var height_min: float = 0.0
@export var height_max: float = 1.0

## Planet biome this cliff belongs to
@export var biome: String = "temperate"  # temperate, volcanic, ice

## Variant type
@export var variant: String = "inland"  # inland, coastal, river

## Edge directions this module supports (N, E, S, W or empty for all)
@export var supported_edges: Array[String] = []

## Scale multiplier for height matching
@export var height_scale: float = 1.0

## Horizontal offset from edge (for overhangs, etc.)
@export var edge_offset: float = 0.0

## Whether to randomize rotation variants
@export var allow_mirror: bool = false

## Description for debugging
@export var description: String = ""

func _init() -> void:
	pass

func matches_criteria(height_delta: float, variant_type: String, edge_dir: String) -> bool:
	"""Check if this module matches the given criteria."""
	if height_delta < height_min or height_delta > height_max:
		return false
	
	if variant != variant_type:
		return false
	
	if supported_edges.size() > 0 and edge_dir not in supported_edges:
		return false
	
	return true
