## Spawns enemies onto the hex grid at battle start.
## Selects random enemy types and places them on the right side of the board.
## Difficulty scales with combat count — more enemies, more elites.
class_name EnemySpawner
extends RefCounted

## All available regular enemy data factories.
var _regular_pool: Array[Callable] = [
	EnemyData_Orc.data,
	EnemyData_Skeleton.data,
	EnemyData_Slime.data,
	EnemyData_SkeletonArcher.data,
	EnemyData_ArmoredOrc.data,
	EnemyData_ArmoredSkeleton.data,
	EnemyData_OrcRider.data,
	EnemyData_Werewolf.data,
]

## Elite enemy data factories (unlocked at higher combat counts).
var _elite_pool: Array[Callable] = [
	EnemyData_GreatswordSkeleton.data,
	EnemyData_EliteOrc.data,
	EnemyData_Werebear.data,
]


## Spawn enemies onto the grid. Returns the spawned EnemyCreature nodes.
## combat_count: how many combats the player has completed (0 = first fight).
## hex_grid: the grid to query for valid spawn positions.
## creature_parent: the Node2D to add enemy nodes to.
func spawn_enemies(combat_count: int, hex_grid: HexGrid, creature_parent: Node2D) -> Array[EnemyCreature]:
	var enemy_count: int = _get_enemy_count(combat_count)
	var include_elite: bool = combat_count >= 3
	var spawn_hexes: Array[Vector2i] = _get_enemy_spawn_hexes(hex_grid)

	if spawn_hexes.is_empty():
		push_warning("EnemySpawner: no valid spawn hexes on right side of grid")
		return []

	# Shuffle spawn positions.
	spawn_hexes.shuffle()

	var spawned: Array[EnemyCreature] = []

	# For the current test build we always plant one Minotaur as a legendary
	# encounter. Uses the first available spawn hex so he lands somewhere
	# visible; the remaining hexes feed the random pool below.
	if not spawn_hexes.is_empty():
		var minotaur_data: EnemyData = EnemyData_Minotaur.data()
		var minotaur: EnemyCreature = spawn_one_at(minotaur_data, hex_grid, creature_parent, spawn_hexes[0])
		if minotaur:
			spawned.append(minotaur)
			spawn_hexes.remove_at(0)

	var count: int = mini(enemy_count, spawn_hexes.size())

	for i: int in range(count):
		var data: EnemyData = _pick_random_enemy(include_elite)
		var enemy: EnemyCreature = spawn_one_at(data, hex_grid, creature_parent, spawn_hexes[i])
		if enemy:
			spawned.append(enemy)

	return spawned


## Spawn a specific enemy at a specific hex. Returns the spawned instance
## (or null on failure). Used both by the random spawner above and by
## bosses/scripted encounters that need to plant a known enemy at a known
## location.
func spawn_one_at(data: EnemyData, hex_grid: HexGrid, creature_parent: Node2D, hex: Vector2i) -> EnemyCreature:
	if data == null or data.creature_scene_path == "":
		return null
	var scene: PackedScene = load(data.creature_scene_path) as PackedScene
	if scene == null:
		push_warning("EnemySpawner: failed to load scene '%s'" % data.creature_scene_path)
		return null
	var enemy: EnemyCreature = scene.instantiate() as EnemyCreature
	if enemy == null:
		return null
	creature_parent.add_child(enemy)
	enemy.initialize_enemy(data, hex, hex_grid.hex_size)

	# Register occupancy on the grid.
	var tile: HexTileData = hex_grid.get_tile(hex)
	if tile:
		tile.occupant = enemy

	return enemy


## Determine how many enemies to spawn based on combat count.
func _get_enemy_count(combat_count: int) -> int:
	# Base 3 enemies, scaling up slightly.
	if combat_count <= 1:
		return 3
	elif combat_count <= 3:
		return 3 + randi_range(0, 1)
	elif combat_count <= 6:
		return 4 + randi_range(0, 1)
	else:
		return 5 + randi_range(0, 1)


## Pick a random enemy, with a chance for elites if allowed.
func _pick_random_enemy(include_elite: bool) -> EnemyData:
	if include_elite and randf() < 0.25:
		var factory: Callable = _elite_pool[randi() % _elite_pool.size()]
		return factory.call() as EnemyData
	var factory: Callable = _regular_pool[randi() % _regular_pool.size()]
	return factory.call() as EnemyData


## Get valid spawn hexes on the right side of the grid.
## Uses the rightmost column, rows 1 through grid_rows-2.
func _get_enemy_spawn_hexes(hex_grid: HexGrid) -> Array[Vector2i]:
	var hexes: Array[Vector2i] = []
	var spawn_col: int = hex_grid.grid_cols - 1
	for row: int in range(1, hex_grid.grid_rows - 1):
		var coord: Vector2i = Vector2i(spawn_col, row)
		var tile: HexTileData = hex_grid.get_tile(coord)
		if tile and not tile.is_occupied() and tile.get_properties().passability == TerrainTypes.Passability.PASSABLE:
			hexes.append(coord)
	return hexes
