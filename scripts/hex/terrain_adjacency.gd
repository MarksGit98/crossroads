## Static terrain adjacency rules for procedural map generation.
## Defines which terrain types can naturally border each other,
## and provides transition validation utilities.
class_name TerrainAdjacency
extends RefCounted

## Adjacency table: for each terrain, the set of terrains that can be neighbors.
## Symmetric — if A can border B, then B can border A.
const ADJACENCY: Dictionary = {
	TerrainTypes.Terrain.GRASSLAND: [
		TerrainTypes.Terrain.GRASSLAND,
		TerrainTypes.Terrain.FOREST,
		TerrainTypes.Terrain.RIVER,
		TerrainTypes.Terrain.BRIDGE,
		TerrainTypes.Terrain.RUINS,
		TerrainTypes.Terrain.VANTAGE_POINT,
		TerrainTypes.Terrain.FROZEN_GROUND,
		TerrainTypes.Terrain.MOUNTAIN,
	],
	TerrainTypes.Terrain.FOREST: [
		TerrainTypes.Terrain.FOREST,
		TerrainTypes.Terrain.GRASSLAND,
		TerrainTypes.Terrain.RUINS,
		TerrainTypes.Terrain.FROZEN_GROUND,
	],
	TerrainTypes.Terrain.MOUNTAIN: [
		TerrainTypes.Terrain.MOUNTAIN,
		TerrainTypes.Terrain.GRASSLAND,
		TerrainTypes.Terrain.FROZEN_GROUND,
		TerrainTypes.Terrain.VANTAGE_POINT,
	],
	TerrainTypes.Terrain.RIVER: [
		TerrainTypes.Terrain.RIVER,
		TerrainTypes.Terrain.GRASSLAND,
		TerrainTypes.Terrain.BRIDGE,
		TerrainTypes.Terrain.FROZEN_GROUND,
	],
	TerrainTypes.Terrain.BRIDGE: [
		TerrainTypes.Terrain.RIVER,
		TerrainTypes.Terrain.GRASSLAND,
	],
	TerrainTypes.Terrain.RUINS: [
		TerrainTypes.Terrain.RUINS,
		TerrainTypes.Terrain.GRASSLAND,
		TerrainTypes.Terrain.FOREST,
	],
	TerrainTypes.Terrain.VANTAGE_POINT: [
		TerrainTypes.Terrain.GRASSLAND,
		TerrainTypes.Terrain.MOUNTAIN,
	],
	TerrainTypes.Terrain.FROZEN_GROUND: [
		TerrainTypes.Terrain.FROZEN_GROUND,
		TerrainTypes.Terrain.GRASSLAND,
		TerrainTypes.Terrain.FOREST,
		TerrainTypes.Terrain.MOUNTAIN,
		TerrainTypes.Terrain.RIVER,
		TerrainTypes.Terrain.ICE_WALL,
	],
	TerrainTypes.Terrain.ICE_WALL: [
		TerrainTypes.Terrain.ICE_WALL,
		TerrainTypes.Terrain.FROZEN_GROUND,
	],
}

## Terrain types that are valid in spawn zones (must be passable ground).
const SPAWN_TERRAIN: Array = [
	TerrainTypes.Terrain.GRASSLAND,
	TerrainTypes.Terrain.FROZEN_GROUND,
]

## Terrain types that can appear in approach corridors.
const APPROACH_TERRAIN: Array = [
	TerrainTypes.Terrain.GRASSLAND,
	TerrainTypes.Terrain.FROZEN_GROUND,
	TerrainTypes.Terrain.FOREST,
	TerrainTypes.Terrain.RUINS,
]

## Terrain types eligible for biome seed clusters in the contested zone.
const CLUSTER_TERRAIN: Array = [
	TerrainTypes.Terrain.FOREST,
	TerrainTypes.Terrain.MOUNTAIN,
	TerrainTypes.Terrain.FROZEN_GROUND,
	TerrainTypes.Terrain.ICE_WALL,
]


## Check if two terrain types can be adjacent.
static func can_border(a: TerrainTypes.Terrain, b: TerrainTypes.Terrain) -> bool:
	if not ADJACENCY.has(a):
		return false
	return b in ADJACENCY[a]


## Check if a terrain type is compatible with ALL of the given neighbor terrains.
static func compatible_with_all(terrain: TerrainTypes.Terrain, neighbors: Array) -> bool:
	for neighbor_terrain: TerrainTypes.Terrain in neighbors:
		if not can_border(terrain, neighbor_terrain):
			return false
	return true


## Return all terrain types that are compatible with every terrain in the neighbor list.
## Used during transition fill to pick the best terrain for an empty tile.
static func get_compatible_terrains(neighbors: Array) -> Array:
	var result: Array = []
	for terrain_value: int in TerrainTypes.Terrain.values():
		var terrain: TerrainTypes.Terrain = terrain_value as TerrainTypes.Terrain
		if compatible_with_all(terrain, neighbors):
			result.append(terrain)
	return result


## Score how well a terrain fits among its neighbors.
## Higher = more neighbors it's compatible with.
static func compatibility_score(terrain: TerrainTypes.Terrain, neighbors: Array) -> int:
	var score: int = 0
	for neighbor_terrain: TerrainTypes.Terrain in neighbors:
		if can_border(terrain, neighbor_terrain):
			score += 1
	return score
