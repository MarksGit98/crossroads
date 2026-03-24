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


## Standard 7x9 Tundra duel board.
## Row 0-2: Enemy territory (top)
## Row 3-4: Contested zone with river
## Row 5-8: Player territory (bottom)
static func tundra_standard() -> Array:
	return [
		# === Enemy Territory ===
		#  col0  col1  col2  col3  col4  col5  col6
		[  G,    G,    G,    G,    G,    G,    G  ],  # Row 0: enemy back line
		[  G,    FG,   G,    G,    G,    FG,   G  ],  # Row 1: frozen ground flanks
		[  G,    G,    F,    G,    F,    G,    G  ],  # Row 2: forest screens

		# === Contested Zone ===
		[  G,    G,    G,    RU,   G,    G,    G  ],  # Row 3: ruins for cover mid
		[  M,    R,    R,    B,    R,    R,    M  ],  # Row 4: river + bridge center, mountains block edges

		# === Player Territory ===
		[  G,    G,    G,    RU,   G,    G,    G  ],  # Row 5: ruins mirror
		[  G,    G,    F,    G,    F,    G,    G  ],  # Row 6: forest screens mirror
		[  G,    FG,   G,    G,    G,    FG,   G  ],  # Row 7: frozen ground flanks mirror
		[  G,    G,    G,    G,    G,    G,    G  ],  # Row 8: player back line
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
		[  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G  ],
		[  G,  G,  G,  G,  G,  G,  G  ],
	]
