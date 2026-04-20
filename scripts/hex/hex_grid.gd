## Visual hex grid for the duel board.
## Owns the grid data (Dictionary of HexTileData) and delegates rendering
## to HexTileRenderer (Sprite2D per tile with 2.5D depth).
## Click detection converts mouse position to hex coordinates.
class_name HexGrid
extends Node2D

## Emitted when a hex is clicked. Passes the offset coordinate.
signal hex_clicked(coord: Vector2i)
## Emitted when the mouse hovers over a new hex.
signal hex_hovered(coord: Vector2i)

## Size of each hex (center to vertex distance in pixels).
## Derived from tile asset width: 120 / 2 = 60.
@export var hex_size: float = 60.0

## Grid dimensions (columns x rows).
var grid_cols: int = 0
var grid_rows: int = 0
## The actual grid data: offset coord -> HexTileData.
var tiles: Dictionary = {}
## Currently hovered hex (-1, -1 means none).
var hovered_hex: Vector2i = Vector2i(-1, -1)
## Currently selected hex (-1, -1 means none).
var selected_hex: Vector2i = Vector2i(-1, -1)
## Set of hex coords to highlight (e.g. movement range, attack range).
var highlight_tiles: Dictionary = {}  # coord -> Color

## Node2D that holds spawned creature instances. Set by the duel scene.
## If null, creatures are added as children of this HexGrid.
var creature_parent: Node2D = null

## Tile renderer child — manages all Sprite2D visuals.
var _renderer: HexTileRenderer = null


func _ready() -> void:
	_renderer = HexTileRenderer.new()
	add_child(_renderer)


## Initialize the grid from a 2D array of terrain types.
## layout[row][col] = TerrainTypes.Terrain value.
func load_layout(layout: Array) -> void:
	tiles.clear()
	grid_rows = layout.size()
	grid_cols = layout[0].size() if grid_rows > 0 else 0

	for row: int in range(grid_rows):
		for col: int in range(grid_cols):
			var coord: Vector2i = Vector2i(col, row)
			var terrain: int = layout[row][col]
			tiles[coord] = HexTileData.new(coord, terrain as TerrainTypes.Terrain)

	_assign_spawn_tiles()
	_renderer.build_visuals(tiles, hex_size)


## Mark which tiles are valid spawn zones for the player.
## Left side: column 0, rows 1 through grid_rows-2 (excludes corner rows).
func _assign_spawn_tiles() -> void:
	var spawn_col: int = 0
	for row: int in range(1, grid_rows - 1):
		var coord: Vector2i = Vector2i(spawn_col, row)
		var tile: HexTileData = tiles.get(coord)
		if tile:
			tile.valid_spawn = true


## Get the HexTileData at a coordinate, or null if out of bounds.
func get_tile(coord: Vector2i) -> HexTileData:
	return tiles.get(coord)


## Check if a coordinate is within the grid bounds.
func is_in_bounds(coord: Vector2i) -> bool:
	return tiles.has(coord)


## Set highlight tiles (e.g. for showing movement range).
func set_highlights(coords: Dictionary) -> void:
	highlight_tiles = coords
	_renderer.set_highlights(coords)


## Clear all highlights.
func clear_highlights() -> void:
	highlight_tiles.clear()
	_renderer.clear_highlights()


## Toggle hex border lines on/off.
func set_borders_visible(visible_flag: bool) -> void:
	_renderer.set_borders_visible(visible_flag)


## Whether hex borders are currently visible.
func are_borders_visible() -> bool:
	return _renderer.are_borders_visible()


## Mark a hex as a valid spawn location at runtime and update its visual overlay.
func mark_spawn(coord: Vector2i) -> void:
	var tile: HexTileData = get_tile(coord)
	if tile == null:
		return
	if tile.valid_spawn:
		return  # Already a spawn tile — nothing to do.
	tile.valid_spawn = true
	_renderer.add_spawn_overlay(coord)


## Return all valid spawn hexes (passable, in spawn zone, unoccupied).
func get_valid_spawn_hexes() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for coord: Vector2i in tiles:
		var tile: HexTileData = tiles[coord]
		if tile.valid_spawn and tile.is_passable() and not tile.is_occupied():
			result.append(coord)
	return result


## Count all friendly (non-enemy) creatures currently on the board.
func count_friendly_creatures() -> int:
	var count: int = 0
	for coord: Vector2i in tiles:
		var tile: HexTileData = tiles[coord]
		if tile.is_occupied() and not tile.occupant.is_enemy():
			count += 1
	return count


## Place a creature on a hex, setting the tile's occupant reference.
## Returns true if placement succeeded.
func place_creature(creature: Creature, coord: Vector2i) -> bool:
	var tile: HexTileData = get_tile(coord)
	if tile == null or tile.is_occupied():
		return false
	tile.occupant = creature
	creature.position = HexHelper.hex_to_world(coord, hex_size)
	if creature.get_parent() != self:
		add_child(creature)
	return true


## Remove a creature from its hex, clearing the tile's occupant.
func remove_creature(coord: Vector2i) -> void:
	var tile: HexTileData = get_tile(coord)
	if tile:
		tile.occupant = null


## Compute all valid movement destinations for a creature using BFS.
## Respects move_range, passability, occupancy, and grid bounds.
## At range 1 this returns walkable adjacent hexes; at higher ranges it
## correctly avoids pathing through blocked tiles.
func get_valid_moves_for(creature: Creature) -> Array[Vector2i]:
	var start: Vector2i = creature.hex_position
	var max_steps: int = creature.current_move_range
	if max_steps <= 0:
		return []

	var visited: Dictionary = {}  # coord -> true
	visited[start] = true

	var frontier: Array[Vector2i] = [start]
	var reachable: Array[Vector2i] = []

	for step: int in range(max_steps):
		var next_frontier: Array[Vector2i] = []
		for coord: Vector2i in frontier:
			var neighbors: Array[Vector2i] = HexHelper.hex_neighbors(coord)
			for neighbor: Vector2i in neighbors:
				if visited.has(neighbor):
					continue
				if not is_in_bounds(neighbor):
					continue
				var tile: HexTileData = get_tile(neighbor)
				if tile == null:
					continue
				if not tile.is_passable():
					continue
				if tile.is_occupied():
					continue
				visited[neighbor] = true
				reachable.append(neighbor)
				next_frontier.append(neighbor)
		frontier = next_frontier

	return reachable


## Find a shortest-path route from `start` toward `goal`, routing around
## impassable terrain and other creatures. Used by enemy AI to plan
## multi-turn approaches when the direct line is blocked.
##
## The returned array EXCLUDES the start hex and INCLUDES every step up to
## and including the last walkable hex before `goal` (so "walk onto the
## target's hex" is not suggested, but "walk adjacent and be in attack
## range" is). Empty array if no route exists within `max_search` expansions.
##
## Callers typically only consume the first few entries (up to the unit's
## move_range); the rest describes the broader plan for debugging / future
## multi-turn caching.
func find_path_toward(start: Vector2i, goal: Vector2i, max_search: int = 200) -> Array[Vector2i]:
	if start == goal:
		return []

	# BFS. Track came_from[] so we can reconstruct the path at the end.
	var came_from: Dictionary = {}  # coord -> coord that led here
	came_from[start] = start

	var frontier: Array[Vector2i] = [start]
	var found: bool = false
	var expansions: int = 0

	while not frontier.is_empty() and expansions < max_search:
		var current: Vector2i = frontier.pop_front()
		if current == goal:
			found = true
			break
		expansions += 1
		for neighbor: Vector2i in HexHelper.hex_neighbors(current):
			if came_from.has(neighbor):
				continue
			if not is_in_bounds(neighbor):
				continue
			var tile: HexTileData = get_tile(neighbor)
			if tile == null:
				continue
			# Allow the goal hex even if occupied (that's the target we're
			# approaching). For all other hexes, respect passability and
			# don't path through occupied squares.
			if neighbor != goal:
				if not tile.is_passable():
					continue
				if tile.is_occupied():
					continue
			came_from[neighbor] = current
			frontier.append(neighbor)

	# Reconstruct path by walking came_from backward from goal (or the
	# closest approach if we didn't reach the goal but still expanded).
	if not found:
		return []
	var path: Array[Vector2i] = []
	var node: Vector2i = goal
	while node != start:
		path.push_front(node)
		node = came_from[node]
	# Drop the final hex if it's the goal's own occupied tile — the enemy
	# should stop adjacent, not walk onto the target.
	if not path.is_empty() and path[-1] == goal:
		var goal_tile: HexTileData = get_tile(goal)
		if goal_tile and goal_tile.is_occupied():
			path.pop_back()
	return path


## Compute all valid attack target hexes for a creature.
## Returns hexes within attack_range that contain a hostile creature.
func get_valid_attack_targets_for(creature: Creature) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	var hexes_in_range: Array[Vector2i] = HexHelper.hex_range(creature.hex_position, creature.attack_range)
	for coord: Vector2i in hexes_in_range:
		if not is_in_bounds(coord):
			continue
		var tile: HexTileData = get_tile(coord)
		if tile == null or not tile.is_occupied():
			continue
		if tile.occupant == creature:
			continue
		if creature.is_hostile_to(tile.occupant):
			targets.append(coord)
	return targets


# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local_pos: Vector2 = get_local_mouse_position()
		var coord: Vector2i = HexHelper.world_to_hex(local_pos, hex_size)
		if is_in_bounds(coord) and coord != hovered_hex:
			hovered_hex = coord
			hex_hovered.emit(coord)
			_renderer.set_hover(coord)
		elif not is_in_bounds(coord) and hovered_hex != Vector2i(-1, -1):
			hovered_hex = Vector2i(-1, -1)
			_renderer.clear_hover()

	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var local_pos: Vector2 = get_local_mouse_position()
			var coord: Vector2i = HexHelper.world_to_hex(local_pos, hex_size)
			if is_in_bounds(coord):
				selected_hex = coord
				hex_clicked.emit(coord)
				_renderer.set_selection(coord)
