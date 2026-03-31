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


## Standard 9x7 Tundra duel board (horizontal layout).
## Col 0-2: Enemy territory (left)
## Col 3-5: Contested zone with river
## Col 6-8: Player territory (right)
static func tundra_standard() -> Array:
	return [
		#  col0  col1  col2  col3  col4  col5  col6  col7  col8
		[  G,    G,    G,    G,    M,    G,    G,    G,    G  ],  # Row 0
		[  G,    FG,   G,    G,    R,    G,    G,    FG,   G  ],  # Row 1
		[  G,    G,    F,    G,    R,    G,    F,    G,    G  ],  # Row 2
		[  G,    G,    G,    RU,   B,    RU,   G,    G,    G  ],  # Row 3: center — ruins + bridge
		[  G,    G,    F,    G,    R,    G,    F,    G,    G  ],  # Row 4
		[  G,    FG,   G,    G,    R,    G,    G,    FG,   G  ],  # Row 5
		[  G,    G,    G,    G,    M,    G,    G,    G,    G  ],  # Row 6
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
		[  G,  G,  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G,  G,  G  ],
	]
