## Trap card — placed face-down on one or more hexes, triggers when an enemy enters.
class_name TrapCard
extends Card

## Axial hex coordinates where this trap is placed.
var placed_hexes: Array[Vector2i] = []

## Whether this trap has been placed on the board.
var is_placed: bool = false

## Whether this trap has already triggered (one-shot by default).
var is_triggered: bool = false


# =============================================================================
# Play System — place trap on one or more hexes
# =============================================================================

func can_play(ctx: DuelContext) -> bool:
	if not super.can_play(ctx):
		return false
	# TODO: Validate target hexes are empty and in valid zone when board is wired.
	return true


func play(ctx: DuelContext) -> void:
	super.play(ctx)
	if ctx == null:
		return
	for hex: Vector2i in ctx.target_hexes:
		_place_on_hex(hex)


func needs_targeting() -> bool:
	return true


## How many hexes this trap needs selected. Uses aoe_radius from data if set.
func target_hex_count() -> int:
	if card_data and card_data.aoe_radius > 0:
		return card_data.aoe_radius
	return 1


func get_valid_targets(board: HexGrid) -> Array[Vector2i]:
	if board == null:
		return []
	# Traps can be placed on empty, passable hexes.
	var valid: Array[Vector2i] = []
	for coord: Vector2i in board.tiles:
		var tile: HexTileData = board.tiles[coord]
		if tile.is_passable() and not tile.is_occupied():
			valid.append(coord)
	return valid


# =============================================================================
# Placement & Trigger
# =============================================================================

## Place the trap on a single hex.
func _place_on_hex(hex: Vector2i) -> void:
	placed_hexes.append(hex)
	is_placed = true


## Check if a unit stepping onto a trapped hex should trigger the trap.
func should_trigger(_unit: Creature, hex: Vector2i) -> bool:
	if is_triggered or not is_placed:
		return false
	if hex not in placed_hexes:
		return false
	# TODO: Check trigger conditions from card_data.
	return true


## Fire the trap's effects and mark it as triggered.
func trigger(ctx: DuelContext) -> void:
	if card_data == null:
		return
	is_triggered = true
	resolve_effects(ctx)
