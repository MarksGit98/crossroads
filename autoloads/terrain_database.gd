## Loads terrain rules and biome configs.
extends Node

var terrain_types: Dictionary = {}  # terrain_id -> terrain data dict
var biome_configs: Dictionary = {}  # biome_id -> biome config dict


func _ready() -> void:
	pass  # TODO: Load terrain/biome definitions from assets/data/terrain/


func get_terrain(terrain_id: String) -> Dictionary:
	return terrain_types.get(terrain_id, {})


func get_biome(biome_id: String) -> Dictionary:
	return biome_configs.get(biome_id, {})
