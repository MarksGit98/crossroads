## Hardcoded test layouts for development.
## Each layout is a 2D array: layout[row][col] = TerrainTypes.Terrain enum value.
## Replace with procedural generation (TerrainGenerator) later.
class_name TestLayouts
extends RefCounted

# Shorthand aliases for readability
const G: int = TerrainTypes.Terrain.GRASSLAND
const F: int = TerrainTypes.Terrain.FOREST
const M: int = TerrainTypes.Terrain.MOUNTAIN
const R: int = TerrainTypes.Terrain.RIVER
const B: int = TerrainTypes.Terrain.BRIDGE
const RU: int = TerrainTypes.Terrain.RUINS
const V: int = TerrainTypes.Terrain.VANTAGE_POINT
const FG: int = TerrainTypes.Terrain.FROZEN_GROUND
const IW: int = TerrainTypes.Terrain.ICE_WALL


## Standard 15x7 Tundra duel board (horizontal layout).
## Col 0-2:   Player territory (left, spawn zone on col 0)
## Col 3-4:   Player approach
## Col 5-9:   Contested zone with river
## Col 10-11: Enemy approach
## Col 12-14: Enemy territory (right)
static func tundra_standard() -> Array:
	return [
		#  col0  col1  col2  col3  col4  col5  col6  col7  col8  col9  col10 col11 col12 col13 col14
		[  G,    G,    G,    G,    FG,   G,    G,    M,    G,    G,    FG,   G,    G,    G,    G  ],  # Row 0
		[  G,    G,    FG,   G,    G,    G,    G,    R,    G,    G,    G,    G,    FG,   G,    G  ],  # Row 1
		[  G,    G,    G,    F,    G,    G,    G,    R,    G,    G,    G,    F,    G,    G,    G  ],  # Row 2
		[  G,    G,    G,    G,    RU,   G,    RU,   B,    RU,   G,    RU,   G,    G,    G,    G  ],  # Row 3: center
		[  G,    G,    G,    F,    G,    G,    G,    R,    G,    G,    G,    F,    G,    G,    G  ],  # Row 4
		[  G,    G,    FG,   G,    G,    G,    G,    R,    G,    G,    G,    G,    FG,   G,    G  ],  # Row 5
		[  G,    G,    G,    G,    FG,   G,    G,    M,    G,    G,    FG,   G,    G,    G,    G  ],  # Row 6
	]


## Small 5x5 test board for quick iteration.
static func tiny_test() -> Array:
	return [
		[  G,  G,  G,  G,  G  ],
		[  G,  F,  G,  F,  G  ],
		[  G,  R,  B,  R,  G  ],
		[  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G  ],
	]


## Open field — no terrain obstacles. For testing movement and combat.
static func open_field() -> Array:
	return [
		[  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G,  G  ],
	]
