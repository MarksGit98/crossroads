## All hex terrain types and their properties.
## Passability, LOS, and tile effects are defined here as data.
class_name TerrainTypes
extends RefCounted

enum Terrain {
	GRASSLAND,
	FOREST,
	MOUNTAIN,
	RIVER,
	BRIDGE,
	RUINS,
	VANTAGE_POINT,
	FROZEN_GROUND,
	ICE_WALL,
	LAVA,
	LAVA_RIVER,
	CACTUS_FIELD,
	OASIS,
	FOG_TILE,
	OBJECTIVE,
	PRESSURE_PLATE,
}

enum Passability { PASSABLE, IMPASSABLE, CONDITIONAL }
enum LOSType { OPEN, FULL_BLOCK, PASSABLE_BLOCK, RANGED_BLOCK, PARTIAL_COVER }
enum Elevation { LOW, NORMAL, HIGH }

## Static terrain property lookup. Returns {passability, los, elevation, effect}.
static func get_properties(terrain: Terrain) -> Dictionary:
	match terrain:
		Terrain.GRASSLAND:
			return {passability = Passability.PASSABLE, los = LOSType.OPEN, elevation = Elevation.NORMAL, effect = ""}
		Terrain.FOREST:
			return {passability = Passability.IMPASSABLE, los = LOSType.PASSABLE_BLOCK, elevation = Elevation.NORMAL, effect = ""}
		Terrain.MOUNTAIN:
			return {passability = Passability.IMPASSABLE, los = LOSType.FULL_BLOCK, elevation = Elevation.HIGH, effect = "elevation_bonus"}
		Terrain.RIVER:
			return {passability = Passability.IMPASSABLE, los = LOSType.RANGED_BLOCK, elevation = Elevation.NORMAL, effect = ""}
		Terrain.BRIDGE:
			return {passability = Passability.CONDITIONAL, los = LOSType.OPEN, elevation = Elevation.NORMAL, effect = "one_unit_max"}
		Terrain.RUINS:
			return {passability = Passability.PASSABLE, los = LOSType.PARTIAL_COVER, elevation = Elevation.NORMAL, effect = "cover"}
		Terrain.VANTAGE_POINT:
			return {passability = Passability.PASSABLE, los = LOSType.OPEN, elevation = Elevation.HIGH, effect = "elevation_bonus"}
		Terrain.FROZEN_GROUND:
			return {passability = Passability.PASSABLE, los = LOSType.OPEN, elevation = Elevation.NORMAL, effect = "shackle_on_stop"}
		Terrain.ICE_WALL:
			return {passability = Passability.IMPASSABLE, los = LOSType.FULL_BLOCK, elevation = Elevation.NORMAL, effect = "meltable"}
		Terrain.LAVA:
			return {passability = Passability.PASSABLE, los = LOSType.OPEN, elevation = Elevation.NORMAL, effect = "burn_per_turn"}
		Terrain.LAVA_RIVER:
			return {passability = Passability.IMPASSABLE, los = LOSType.RANGED_BLOCK, elevation = Elevation.NORMAL, effect = ""}
		Terrain.CACTUS_FIELD:
			return {passability = Passability.PASSABLE, los = LOSType.OPEN, elevation = Elevation.NORMAL, effect = "damage_on_enter"}
		Terrain.OASIS:
			return {passability = Passability.PASSABLE, los = LOSType.OPEN, elevation = Elevation.NORMAL, effect = "heal_once"}
		Terrain.FOG_TILE:
			return {passability = Passability.PASSABLE, los = LOSType.FULL_BLOCK, elevation = Elevation.NORMAL, effect = "concealment"}
		Terrain.OBJECTIVE:
			return {passability = Passability.PASSABLE, los = LOSType.OPEN, elevation = Elevation.NORMAL, effect = "capture_point"}
		Terrain.PRESSURE_PLATE:
			return {passability = Passability.PASSABLE, los = LOSType.OPEN, elevation = Elevation.NORMAL, effect = "trigger_once"}
		_:
			return {passability = Passability.PASSABLE, los = LOSType.OPEN, elevation = Elevation.NORMAL, effect = ""}


## Color for debug/placeholder rendering of each terrain type.
static func get_debug_color(terrain: Terrain) -> Color:
	match terrain:
		Terrain.GRASSLAND:      return Color(0.4, 0.7, 0.3)       # green
		Terrain.FOREST:         return Color(0.15, 0.4, 0.15)     # dark green
		Terrain.MOUNTAIN:       return Color(0.5, 0.45, 0.4)      # grey-brown
		Terrain.RIVER:          return Color(0.2, 0.4, 0.8)       # blue
		Terrain.BRIDGE:         return Color(0.6, 0.45, 0.25)     # brown
		Terrain.RUINS:          return Color(0.55, 0.5, 0.45)     # tan
		Terrain.VANTAGE_POINT:  return Color(0.7, 0.65, 0.5)      # light brown
		Terrain.FROZEN_GROUND:  return Color(0.75, 0.85, 0.95)    # light blue
		Terrain.ICE_WALL:       return Color(0.6, 0.75, 0.9)      # ice blue
		Terrain.LAVA:           return Color(0.9, 0.3, 0.1)       # orange-red
		Terrain.LAVA_RIVER:     return Color(0.8, 0.2, 0.05)      # dark red
		Terrain.CACTUS_FIELD:   return Color(0.7, 0.75, 0.3)      # yellow-green
		Terrain.OASIS:          return Color(0.3, 0.8, 0.7)       # teal
		Terrain.FOG_TILE:       return Color(0.6, 0.6, 0.65)      # grey
		Terrain.OBJECTIVE:      return Color(0.9, 0.8, 0.2)       # gold
		Terrain.PRESSURE_PLATE: return Color(0.7, 0.3, 0.6)       # purple
		_:                      return Color(1.0, 0.0, 1.0)       # magenta (error)
