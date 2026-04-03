## Data for a single hex tile on the duel grid.
## This is the logical layer — separate from visual representation.
class_name HexTileData
extends RefCounted

var coord: Vector2i  # offset coordinates (col, row)
var terrain: TerrainTypes.Terrain = TerrainTypes.Terrain.GRASSLAND
var occupant: Creature = null  # creature standing on this hex, or null
var is_destroyed: bool = false  # for destructible terrain (bridge, forest)
var effect_used: bool = false  # for one-time effects (oasis, pressure plate)
var valid_spawn: bool = false  # whether the player can summon creatures here


func _init(p_coord: Vector2i, p_terrain: TerrainTypes.Terrain) -> void:
	coord = p_coord
	terrain = p_terrain


func get_properties() -> Dictionary:
	return TerrainTypes.get_properties(terrain)


func is_passable() -> bool:
	if is_destroyed:
		# Destroyed bridges become impassable, destroyed forest becomes open
		if terrain == TerrainTypes.Terrain.BRIDGE:
			return false
		if terrain == TerrainTypes.Terrain.FOREST:
			return true
	var props: Dictionary = get_properties()
	return props.passability == TerrainTypes.Passability.PASSABLE


func is_occupied() -> bool:
	return occupant != null
