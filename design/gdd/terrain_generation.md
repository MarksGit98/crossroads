# Terrain Generation System

## Overview

Procedural hex map generator for Crossroads duel boards. Creates 15x7 hex grids
with natural biome clustering, logical terrain transitions, and balanced symmetry
for competitive play.

## Player Fantasy

Each duel takes place on a unique battlefield that feels hand-crafted — forests
give way to frozen tundra, rivers carve through contested ground, ruins dot the
landscape at terrain boundaries. No two matches play the same.

## Detailed Rules

### Zone Layout (15 columns x 7 rows)

| Zone | Columns | Purpose | Terrain Pool |
|------|---------|---------|-------------|
| Player Spawn | 0-2 | Summoning area | Grassland, Frozen Ground |
| Player Approach | 3-4 | Path to center | Grassland, Frozen Ground, Forest, Ruins |
| Contested | 5-9 | Fight zone | All terrain types |
| Enemy Approach | 10-11 | Mirrored | Same as Player Approach |
| Enemy Spawn | 12-14 | Mirrored | Same as Player Spawn |

### Generation Phases

1. **Zone Fill** — Spawn zones get passable terrain. Approach corridors get
   weighted random (60% grassland).
2. **Seed Placement** — 3-5 biome seeds placed in contested zone. Seeds are
   mirrored left-right for fairness.
3. **Cluster Growth** — Each seed grows via flood fill (3-6 tiles) respecting
   adjacency rules. Promotes natural biome clumping.
4. **River Carving** — 70% chance of a river flowing top-to-bottom through
   contested zone. Meanders ±1 column. Avoids mountains.
5. **Transition Fill** — Empty tiles filled with the most compatible terrain
   based on neighbors. Grassland is universal fallback.
6. **Feature Placement** — Bridges at river crossings, ruins at terrain
   boundaries, vantage points near mountains.
7. **Validation** — Spawn zones forced passable, adjacency violations fixed.

### Terrain Adjacency Rules

Each terrain type defines which others can be its hex neighbor:

| Terrain | Can Border |
|---------|-----------|
| Grassland | Forest, River, Bridge, Ruins, Vantage Point, Frozen Ground, Mountain |
| Forest | Grassland, Ruins, Frozen Ground |
| Mountain | Grassland, Frozen Ground, Vantage Point |
| River | Grassland, Bridge, Frozen Ground |
| Bridge | River, Grassland |
| Ruins | Grassland, Forest |
| Vantage Point | Grassland, Mountain |
| Frozen Ground | Grassland, Forest, Mountain, River, Ice Wall |
| Ice Wall | Frozen Ground |

### Natural Transition Chains

- Forest → Grassland → River (woodland to shore)
- Mountain → Frozen Ground → Ice Wall (altitude to arctic)
- Forest → Frozen Ground → Mountain (temperate to alpine)
- Grassland → Ruins (civilization in clearing)
- River → Bridge → Grassland (crossing point)

## Formulas

- **Cluster count**: `randi_range(3, 5)` seeds per map
- **Cluster size**: `randi_range(3, 6)` tiles per cluster
- **River probability**: 70% per map
- **Ruins count**: Up to 2, placed at terrain transition boundaries
- **Vantage points**: Up to 1, placed adjacent to mountains
- **Approach terrain weights**: 60% Grassland, 40% random from approach pool

## Edge Cases

- River blocked by mountain: shifts to adjacent column
- No compatible terrain for a tile: falls back to Grassland
- Adjacency violation after all phases: iterative fix pass (max 10 rounds)
- Seeds land on same tile: second seed skipped
- All frontier tiles incompatible: cluster stops growing early

## Dependencies

- `TerrainTypes` — terrain enum and properties
- `TerrainAdjacency` — adjacency rules and validation
- `HexHelper` — neighbor calculation for flood fill
- `HexGrid.load_layout()` — consumes the output 2D array

## Tuning Knobs

| Parameter | Default | Effect |
|-----------|---------|--------|
| `CLUSTER_COUNT_MIN/MAX` | 3-5 | More clusters = more varied terrain |
| `CLUSTER_SIZE_MIN/MAX` | 3-6 | Larger clusters = bigger biome patches |
| `RIVER_CHANCE` | 0.7 | Probability of a river on the map |
| `RUINS_COUNT` | 2 | Max ruins features placed |
| `VANTAGE_COUNT` | 1 | Max vantage point features |
| Approach grassland weight | 0.6 | Higher = more open approach corridors |

## Acceptance Criteria

- [ ] Generated maps display with correct tile art for all terrain types
- [ ] Same seed produces identical map every time
- [ ] No adjacency violations in output (forest never borders river, etc.)
- [ ] Spawn zones (cols 0-2, 12-14) contain only passable terrain
- [ ] Terrain clusters are visually distinct (not scattered single tiles)
- [ ] Rivers flow as connected paths, not isolated water tiles
- [ ] Bridges only appear adjacent to river tiles
- [ ] Press R regenerates with a new random seed
- [ ] Map feels varied across 10+ regenerations
