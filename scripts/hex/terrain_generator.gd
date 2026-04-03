## Procedural hex map generator for duel boards.
## Generates terrain layouts with natural biome clustering and transitions.
##
## Algorithm phases:
##   1. Zone layout (spawn, approach, contested)
##   2. Seed placement (biome clusters with symmetry)
##   3. Cluster growth (flood fill with adjacency rules)
##   4. River carving (connected water paths)
##   5. Transition fill (compatible terrain for remaining tiles)
##   6. Feature placement (bridges, ruins, vantage points)
##   7. Validation (passable spawns, pathing, adjacency)
class_name TerrainGenerator
extends RefCounted

## Map dimensions.
const COLS: int = 15
const ROWS: int = 7

## Zone column boundaries.
const SPAWN_LEFT_END: int = 2     # cols 0-2
const APPROACH_LEFT_END: int = 4  # cols 3-4
const CONTESTED_START: int = 5    # cols 5-9
const CONTESTED_END: int = 9
const APPROACH_RIGHT_START: int = 10  # cols 10-11
const SPAWN_RIGHT_START: int = 12     # cols 12-14

## Generation parameters.
const CLUSTER_COUNT_MIN: int = 3
const CLUSTER_COUNT_MAX: int = 5
const CLUSTER_SIZE_MIN: int = 3
const CLUSTER_SIZE_MAX: int = 6
const RIVER_CHANCE: float = 0.7
const RUINS_COUNT: int = 2
const VANTAGE_COUNT: int = 1

## Internal working grid: coord -> TerrainTypes.Terrain (or -1 for unassigned).
var _grid: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Generate a complete duel map layout.
## Returns a 2D array: layout[row][col] = TerrainTypes.Terrain value.
func generate(seed_value: int = -1) -> Array:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

	_init_grid()
	_phase_1_zones()
	_phase_2_seeds()
	_phase_3_grow_clusters()
	_phase_4_rivers()
	_phase_5_fill_transitions()
	_phase_6_features()
	_phase_7_validate()

	return _to_layout_array()


## Initialize grid with all tiles unassigned (-1).
func _init_grid() -> void:
	_grid.clear()
	for row: int in range(ROWS):
		for col: int in range(COLS):
			_grid[Vector2i(col, row)] = -1


## Phase 1: Fill spawn zones with passable terrain.
func _phase_1_zones() -> void:
	for row: int in range(ROWS):
		for col: int in range(COLS):
			var coord: Vector2i = Vector2i(col, row)
			# Spawn zones — passable only
			if col <= SPAWN_LEFT_END or col >= SPAWN_RIGHT_START:
				_grid[coord] = _pick_spawn_terrain()
			# Approach corridors — mostly passable with some variety
			elif col <= APPROACH_LEFT_END or col >= APPROACH_RIGHT_START:
				_grid[coord] = _pick_approach_terrain()


## Phase 2: Place biome seed clusters in the contested zone.
## Seeds are mirrored left-right for fairness.
func _phase_2_seeds() -> void:
	var cluster_count: int = _rng.randi_range(CLUSTER_COUNT_MIN, CLUSTER_COUNT_MAX)

	for i: int in range(cluster_count):
		var terrain: TerrainTypes.Terrain = _pick_cluster_terrain()
		var target_size: int = _rng.randi_range(CLUSTER_SIZE_MIN, CLUSTER_SIZE_MAX)

		# Place seed in the left half of contested zone (cols 5-7)
		var seed_col: int = _rng.randi_range(CONTESTED_START, CONTESTED_START + 2)
		var seed_row: int = _rng.randi_range(0, ROWS - 1)
		var seed_coord: Vector2i = Vector2i(seed_col, seed_row)

		# Only place if the tile is unassigned
		if _grid[seed_coord] == -1:
			_grid[seed_coord] = terrain

			# Mirror on the right side of contested zone
			var mirror_col: int = CONTESTED_END - (seed_col - CONTESTED_START)
			var mirror_coord: Vector2i = Vector2i(mirror_col, seed_row)
			if _grid.has(mirror_coord) and _grid[mirror_coord] == -1:
				_grid[mirror_coord] = terrain


## Phase 3: Grow each seed cluster outward via flood fill.
func _phase_3_grow_clusters() -> void:
	# Find all seeds (assigned tiles in contested zone)
	var seeds: Array[Vector2i] = []
	for row: int in range(ROWS):
		for col: int in range(CONTESTED_START, CONTESTED_END + 1):
			var coord: Vector2i = Vector2i(col, row)
			if _grid[coord] != -1:
				seeds.append(coord)

	# Grow each seed
	for seed_coord: Vector2i in seeds:
		var terrain: TerrainTypes.Terrain = _grid[seed_coord] as TerrainTypes.Terrain
		var target_size: int = _rng.randi_range(CLUSTER_SIZE_MIN, CLUSTER_SIZE_MAX)
		_grow_cluster(seed_coord, terrain, target_size)


## Grow a cluster from a seed position outward.
func _grow_cluster(seed_coord: Vector2i, terrain: TerrainTypes.Terrain, target_size: int) -> void:
	var cluster: Array[Vector2i] = [seed_coord]
	var frontier: Array[Vector2i] = []

	# Initialize frontier with unassigned neighbors
	for neighbor: Vector2i in HexHelper.hex_neighbors(seed_coord):
		if _is_valid_coord(neighbor) and _grid[neighbor] == -1:
			if not frontier.has(neighbor):
				frontier.append(neighbor)

	while cluster.size() < target_size and frontier.size() > 0:
		# Pick a random frontier tile
		var idx: int = _rng.randi_range(0, frontier.size() - 1)
		var coord: Vector2i = frontier[idx]
		frontier.remove_at(idx)

		# Check adjacency compatibility
		var neighbor_terrains: Array = _get_assigned_neighbor_terrains(coord)
		if TerrainAdjacency.compatible_with_all(terrain, neighbor_terrains):
			_grid[coord] = terrain
			cluster.append(coord)

			# Add new unassigned neighbors to frontier
			for neighbor: Vector2i in HexHelper.hex_neighbors(coord):
				if _is_valid_coord(neighbor) and _grid[neighbor] == -1:
					if not frontier.has(neighbor):
						frontier.append(neighbor)


## Phase 4: Carve a river through the contested zone.
func _phase_4_rivers() -> void:
	if _rng.randf() > RIVER_CHANCE:
		return

	# River flows roughly top-to-bottom through the center column area
	var river_col: int = _rng.randi_range(CONTESTED_START + 1, CONTESTED_END - 1)

	for row: int in range(ROWS):
		var coord: Vector2i = Vector2i(river_col, row)

		# Slight horizontal meander
		var meander: int = _rng.randi_range(-1, 1)
		var meander_col: int = clampi(river_col + meander, CONTESTED_START, CONTESTED_END)
		coord = Vector2i(meander_col, row)

		if _is_valid_coord(coord):
			# Don't overwrite mountains — river goes around
			if _grid[coord] == TerrainTypes.Terrain.MOUNTAIN:
				# Try adjacent column
				var alt_col: int = meander_col + (1 if meander_col <= river_col else -1)
				alt_col = clampi(alt_col, CONTESTED_START, CONTESTED_END)
				var alt_coord: Vector2i = Vector2i(alt_col, row)
				if _is_valid_coord(alt_coord) and _grid[alt_coord] != TerrainTypes.Terrain.MOUNTAIN:
					_grid[alt_coord] = TerrainTypes.Terrain.RIVER
			else:
				_grid[coord] = TerrainTypes.Terrain.RIVER

		river_col = meander_col  # Track meander for continuity


## Phase 5: Fill remaining unassigned tiles with transition-compatible terrain.
func _phase_5_fill_transitions() -> void:
	# Multiple passes — each pass may unlock new fills as neighbors get assigned
	for pass_num: int in range(5):
		var filled_any: bool = false
		for row: int in range(ROWS):
			for col: int in range(COLS):
				var coord: Vector2i = Vector2i(col, row)
				if _grid[coord] != -1:
					continue

				var neighbor_terrains: Array = _get_assigned_neighbor_terrains(coord)
				if neighbor_terrains.is_empty():
					continue

				var best_terrain: TerrainTypes.Terrain = _pick_best_transition(coord, neighbor_terrains)
				_grid[coord] = best_terrain
				filled_any = true

		if not filled_any:
			break

	# Final fallback: any still-unassigned tiles become grassland
	for row: int in range(ROWS):
		for col: int in range(COLS):
			var coord: Vector2i = Vector2i(col, row)
			if _grid[coord] == -1:
				_grid[coord] = TerrainTypes.Terrain.GRASSLAND


## Phase 6: Place strategic features (bridges, ruins, vantage points).
func _phase_6_features() -> void:
	_place_bridges()
	_place_ruins()
	_place_vantage_points()


## Place bridges where rivers cross approach corridors or paths.
func _place_bridges() -> void:
	for row: int in range(ROWS):
		for col: int in range(COLS):
			var coord: Vector2i = Vector2i(col, row)
			if _grid[coord] != TerrainTypes.Terrain.RIVER:
				continue

			# Check if this river tile has grassland/passable on opposite sides
			var neighbors: Array[Vector2i] = HexHelper.hex_neighbors(coord)
			var has_land_neighbors: int = 0
			for n: Vector2i in neighbors:
				if _is_valid_coord(n):
					var t: int = _grid[n]
					if t == TerrainTypes.Terrain.GRASSLAND or t == TerrainTypes.Terrain.FROZEN_GROUND:
						has_land_neighbors += 1

			# Bridge if surrounded by enough land (natural crossing point)
			# Only place 1-2 bridges, and prefer center rows
			if has_land_neighbors >= 3 and absi(row - ROWS / 2) <= 1:
				_grid[coord] = TerrainTypes.Terrain.BRIDGE
				return  # Only one bridge per river


## Place ruins on grassland/dirt tiles in interesting positions.
func _place_ruins() -> void:
	var candidates: Array[Vector2i] = []
	for row: int in range(ROWS):
		for col: int in range(APPROACH_LEFT_END, APPROACH_RIGHT_START + 1):
			var coord: Vector2i = Vector2i(col, row)
			if _grid[coord] == TerrainTypes.Terrain.GRASSLAND:
				# Prefer tiles near terrain transitions
				var neighbor_terrains: Array = _get_assigned_neighbor_terrains(coord)
				var unique_types: Array = []
				for t: TerrainTypes.Terrain in neighbor_terrains:
					if not unique_types.has(t):
						unique_types.append(t)
				if unique_types.size() >= 2:
					candidates.append(coord)

	# Place up to RUINS_COUNT ruins
	candidates.shuffle()
	var placed: int = 0
	for coord: Vector2i in candidates:
		if placed >= RUINS_COUNT:
			break
		# Verify adjacency is still valid
		var neighbor_terrains: Array = _get_assigned_neighbor_terrains(coord)
		if TerrainAdjacency.compatible_with_all(TerrainTypes.Terrain.RUINS, neighbor_terrains):
			_grid[coord] = TerrainTypes.Terrain.RUINS
			placed += 1


## Place vantage points on high ground near the contested center.
func _place_vantage_points() -> void:
	var candidates: Array[Vector2i] = []
	for row: int in range(ROWS):
		for col: int in range(CONTESTED_START, CONTESTED_END + 1):
			var coord: Vector2i = Vector2i(col, row)
			if _grid[coord] == TerrainTypes.Terrain.GRASSLAND:
				# Prefer tiles adjacent to mountains
				var neighbor_terrains: Array = _get_assigned_neighbor_terrains(coord)
				if TerrainTypes.Terrain.MOUNTAIN in neighbor_terrains:
					candidates.append(coord)

	candidates.shuffle()
	var placed: int = 0
	for coord: Vector2i in candidates:
		if placed >= VANTAGE_COUNT:
			break
		var neighbor_terrains: Array = _get_assigned_neighbor_terrains(coord)
		if TerrainAdjacency.compatible_with_all(TerrainTypes.Terrain.VANTAGE_POINT, neighbor_terrains):
			_grid[coord] = TerrainTypes.Terrain.VANTAGE_POINT
			placed += 1


## Phase 7: Validate the generated map.
func _phase_7_validate() -> void:
	# Ensure spawn zones are all passable
	for row: int in range(ROWS):
		for col: int in [0, 1, 2, 12, 13, 14]:
			var coord: Vector2i = Vector2i(col, row)
			var terrain: TerrainTypes.Terrain = _grid[coord] as TerrainTypes.Terrain
			var props: Dictionary = TerrainTypes.get_properties(terrain)
			if props.passability != TerrainTypes.Passability.PASSABLE:
				_grid[coord] = TerrainTypes.Terrain.GRASSLAND

	# Fix any adjacency violations
	_fix_adjacency_violations()


## Scan for and fix adjacency violations by replacing offenders with grassland.
func _fix_adjacency_violations() -> void:
	var violations_found: bool = true
	var max_passes: int = 10
	var pass_count: int = 0

	while violations_found and pass_count < max_passes:
		violations_found = false
		pass_count += 1
		for row: int in range(ROWS):
			for col: int in range(COLS):
				var coord: Vector2i = Vector2i(col, row)
				var terrain: TerrainTypes.Terrain = _grid[coord] as TerrainTypes.Terrain
				var neighbor_terrains: Array = _get_assigned_neighbor_terrains(coord)
				if not TerrainAdjacency.compatible_with_all(terrain, neighbor_terrains):
					# Replace with the best compatible terrain
					_grid[coord] = _pick_best_transition(coord, neighbor_terrains)
					violations_found = true


# --- Helper functions ---

## Pick a random spawn-safe terrain.
func _pick_spawn_terrain() -> TerrainTypes.Terrain:
	var options: Array = TerrainAdjacency.SPAWN_TERRAIN
	return options[_rng.randi_range(0, options.size() - 1)] as TerrainTypes.Terrain


## Pick a random approach terrain.
func _pick_approach_terrain() -> TerrainTypes.Terrain:
	var options: Array = TerrainAdjacency.APPROACH_TERRAIN
	# Weight grassland higher (60% chance)
	if _rng.randf() < 0.6:
		return TerrainTypes.Terrain.GRASSLAND
	return options[_rng.randi_range(0, options.size() - 1)] as TerrainTypes.Terrain


## Pick a random cluster terrain for seeds.
func _pick_cluster_terrain() -> TerrainTypes.Terrain:
	var options: Array = TerrainAdjacency.CLUSTER_TERRAIN
	return options[_rng.randi_range(0, options.size() - 1)] as TerrainTypes.Terrain


## Pick the best transition terrain for an empty tile based on its neighbors.
func _pick_best_transition(coord: Vector2i, neighbor_terrains: Array) -> TerrainTypes.Terrain:
	var compatible: Array = TerrainAdjacency.get_compatible_terrains(neighbor_terrains)
	if compatible.is_empty():
		return TerrainTypes.Terrain.GRASSLAND

	# Score each option: prefer terrain that matches more neighbors
	var best_terrain: TerrainTypes.Terrain = TerrainTypes.Terrain.GRASSLAND
	var best_score: int = -1

	for terrain: TerrainTypes.Terrain in compatible:
		var score: int = TerrainAdjacency.compatibility_score(terrain, neighbor_terrains)
		# Bonus for matching an existing neighbor (promotes clustering)
		if terrain in neighbor_terrains:
			score += 2
		# Small random factor to avoid uniform fills
		score += _rng.randi_range(0, 1)
		if score > best_score:
			best_score = score
			best_terrain = terrain

	return best_terrain


## Get assigned terrain types of all neighbors of a coord.
func _get_assigned_neighbor_terrains(coord: Vector2i) -> Array:
	var result: Array = []
	for neighbor: Vector2i in HexHelper.hex_neighbors(coord):
		if _is_valid_coord(neighbor) and _grid[neighbor] != -1:
			result.append(_grid[neighbor] as TerrainTypes.Terrain)
	return result


## Check if a coordinate is within grid bounds.
func _is_valid_coord(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < COLS and coord.y >= 0 and coord.y < ROWS


## Convert internal grid dictionary to a 2D array for load_layout().
func _to_layout_array() -> Array:
	var layout: Array = []
	for row: int in range(ROWS):
		var row_data: Array = []
		for col: int in range(COLS):
			row_data.append(_grid[Vector2i(col, row)])
		layout.append(row_data)
	return layout
