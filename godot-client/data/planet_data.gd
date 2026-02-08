class_name PlanetData
extends Resource

@export var planet_id: int
@export var system_id: int
@export var seed: int
@export var biome: int
@export var radius: float
@export var plot_count: int

# mutable / gameplay state
@export var claimed_plots: Array[int] = []
