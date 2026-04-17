## Orchestrates the turn flow for a duel.
## Cycles through phases: Draw -> Action -> End Turn -> Enemy Turn.
## Manages card draw, mana reset, creature turn resets, and enemy AI.
class_name TurnManager
extends Node

# =============================================================================
# Phase Enum
# =============================================================================

enum Phase {
	INACTIVE,       ## Before the first turn starts.
	DRAW_PHASE,     ## Player draws cards, start-of-turn effects fire.
	ACTION_PHASE,   ## Player can play cards, move, attack, use abilities.
	END_TURN_PHASE, ## End-of-turn effects fire, status effects tick.
	ENEMY_TURN,     ## Enemy AI resolves intents, moves, attacks.
}

# =============================================================================
# Signals
# =============================================================================

## Emitted when the phase changes.
signal phase_changed(new_phase: Phase)

## Emitted at the start of each player turn (after draw phase begins).
signal turn_started(turn_number: int)

## Emitted when the full turn cycle completes (player + enemy).
signal turn_ended(turn_number: int)

## Emitted when the enemy turn begins.
signal enemy_turn_started()

## Emitted when the enemy turn ends and player turn is about to begin.
signal enemy_turn_ended()

# =============================================================================
# Configuration
# =============================================================================

## Cards drawn on the very first turn.
const INITIAL_DRAW: int = 5

## Cards drawn on subsequent turns.
const TURN_DRAW: int = 1

## Brief pause during enemy turn (seconds) so the player can see what happens.
const ENEMY_TURN_DELAY: float = 1.0

## How long the turn banner stays on screen (seconds).
const BANNER_HOLD_TIME: float = 1.0

## How long the turn banner fades in and out (seconds each).
const BANNER_FADE_TIME: float = 0.3

## Font size for the turn banner.
const BANNER_FONT_SIZE: int = 48

# =============================================================================
# Dependencies (set via setup())
# =============================================================================

var player: Player
var hand: Node2D  ## The Hand node — has draw_cards() method.
var hex_grid: HexGrid
var creatures_node: Node2D  ## Parent of all creature nodes on the board.
var interaction_manager: BoardInteractionManager

# =============================================================================
# State
# =============================================================================

var current_phase: Phase = Phase.INACTIVE
var turn_number: int = 0
var _is_first_turn: bool = true


# =============================================================================
# Setup
# =============================================================================

## Wire all dependencies. Called by the duel scene in _ready().
func setup(
	p_player: Player,
	p_hand: Node2D,
	p_grid: HexGrid,
	p_creatures: Node2D,
	p_interaction: BoardInteractionManager,
) -> void:
	player = p_player
	hand = p_hand
	hex_grid = p_grid
	creatures_node = p_creatures
	interaction_manager = p_interaction


# =============================================================================
# Turn Flow
# =============================================================================

## Start the first turn. Call this once after setup and after deck is ready.
func begin_combat() -> void:
	_is_first_turn = true
	_start_player_turn()


## Called when the player clicks the End Turn button.
func on_end_turn_pressed() -> void:
	if current_phase != Phase.ACTION_PHASE:
		return
	_end_player_turn()


# =============================================================================
# Player Turn Phases
# =============================================================================

func _start_player_turn() -> void:
	turn_number += 1

	# Reset mana and increment turn counter on the player.
	player.start_turn()

	# Reset all friendly creatures for the new turn.
	_reset_friendly_creatures()

	# Enter draw phase.
	_set_phase(Phase.DRAW_PHASE)
	turn_started.emit(turn_number)

	# On the very first turn, draw the opening hand before the banner.
	if _is_first_turn:
		hand.draw_cards(INITIAL_DRAW)
		await get_tree().create_timer(0.3).timeout

	_is_first_turn = false

	# Show the turn banner, then draw the normal per-turn card.
	await _show_turn_banner(turn_number)
	hand.draw_cards(TURN_DRAW)

	# Brief pause so the player sees the draw, then enter action phase.
	await get_tree().create_timer(0.3).timeout
	_enter_action_phase()


func _enter_action_phase() -> void:
	_set_phase(Phase.ACTION_PHASE)
	# Enable player interaction.
	interaction_manager.set_enabled(true)


func _end_player_turn() -> void:
	# Disable player interaction immediately.
	interaction_manager.set_enabled(false)

	_set_phase(Phase.END_TURN_PHASE)

	# Fire end-of-turn effects on all friendly creatures.
	_end_turn_friendly_creatures()

	player.end_turn()

	# Small delay before enemy turn.
	await get_tree().create_timer(0.2).timeout
	_start_enemy_turn()


# =============================================================================
# Enemy Turn
# =============================================================================

func _start_enemy_turn() -> void:
	_set_phase(Phase.ENEMY_TURN)
	enemy_turn_started.emit()

	# Reset all enemy creatures for their turn.
	_reset_enemy_creatures()

	# Process each living enemy sequentially so each sees updated board state.
	var enemies: Array[EnemyCreature] = _get_living_enemies()

	for enemy: EnemyCreature in enemies:
		if not enemy.is_alive():
			continue

		await _resolve_enemy_action(enemy)

		# Brief pause between enemies so the player can follow the action.
		await get_tree().create_timer(0.4).timeout

		# Check if all player creatures are dead.
		if _get_living_player_creatures().is_empty():
			break

	enemy_turn_ended.emit()
	turn_ended.emit(turn_number)

	# TODO: Emit combat_won / combat_lost signals for game flow.
	# For now, just loop to the next player turn.
	_start_player_turn()


# =============================================================================
# Enemy AI
# =============================================================================

## Resolve a single enemy's turn: decide action, then execute.
func _resolve_enemy_action(enemy: EnemyCreature) -> void:
	var player_creatures: Array[Creature] = _get_living_player_creatures()
	if player_creatures.is_empty():
		return

	var nearest: Creature = _find_nearest_player_creature(enemy, player_creatures)
	if nearest == null:
		return

	var distance: int = HexHelper.hex_distance(enemy.hex_position, nearest.hex_position)

	# Decision: attack if in range, otherwise move toward target.
	if distance <= enemy.attack_range and enemy.can_attack():
		enemy.set_intent(EnemyCreature.Intent.ATTACK, enemy.current_atk)
		await get_tree().create_timer(0.3).timeout
		await enemy.perform_attack(nearest, hex_grid)
	elif enemy.can_move():
		enemy.set_intent(EnemyCreature.Intent.MOVE)
		await get_tree().create_timer(0.3).timeout
		await _move_enemy_toward(enemy, nearest)

		# After moving, check if now in attack range.
		if enemy.can_attack() and nearest.is_alive():
			var new_distance: int = HexHelper.hex_distance(enemy.hex_position, nearest.hex_position)
			if new_distance <= enemy.attack_range:
				enemy.set_intent(EnemyCreature.Intent.ATTACK, enemy.current_atk)
				await get_tree().create_timer(0.2).timeout
				await enemy.perform_attack(nearest, hex_grid)

	# Clear intent after acting.
	enemy.set_intent(EnemyCreature.Intent.NONE)


## Find the nearest player creature to an enemy by hex distance.
func _find_nearest_player_creature(enemy: EnemyCreature, targets: Array[Creature]) -> Creature:
	var best: Creature = null
	var best_dist: int = 999
	for target: Creature in targets:
		var dist: int = HexHelper.hex_distance(enemy.hex_position, target.hex_position)
		if dist < best_dist:
			best_dist = dist
			best = target
	return best


## Move an enemy one step toward a target creature using BFS valid moves.
func _move_enemy_toward(enemy: EnemyCreature, target: Creature) -> void:
	var valid_moves: Array[Vector2i] = hex_grid.get_valid_moves_for(enemy)
	if valid_moves.is_empty():
		return

	# Pick the valid move hex closest to the target.
	var best_hex: Vector2i = valid_moves[0]
	var best_dist: int = HexHelper.hex_distance(best_hex, target.hex_position)
	for coord: Vector2i in valid_moves:
		var dist: int = HexHelper.hex_distance(coord, target.hex_position)
		if dist < best_dist:
			best_dist = dist
			best_hex = coord

	# Only move if it actually gets closer.
	var current_dist: int = HexHelper.hex_distance(enemy.hex_position, target.hex_position)
	if best_dist >= current_dist:
		return

	# Update tile occupancy.
	hex_grid.remove_creature(enemy.hex_position)
	var new_tile: HexTileData = hex_grid.get_tile(best_hex)
	if new_tile:
		new_tile.occupant = enemy

	# Animate the move.
	await enemy.move_to(best_hex, hex_grid.hex_size)


# =============================================================================
# Turn Banner
# =============================================================================

## Display a centered "Turn N" label that fades in, holds, then fades out.
func _show_turn_banner(turn: int) -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)

	var label := Label.new()
	label.text = "Turn %d" % turn
	label.add_theme_font_size_override("font_size", BANNER_FONT_SIZE)
	label.add_theme_color_override("font_color", Color(1, 1, 0.85, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.modulate.a = 0.0
	canvas_layer.add_child(label)

	# Fade in → hold → fade out.
	var tween: Tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, BANNER_FADE_TIME)
	tween.tween_interval(BANNER_HOLD_TIME)
	tween.tween_property(label, "modulate:a", 0.0, BANNER_FADE_TIME)
	await tween.finished

	canvas_layer.queue_free()


# =============================================================================
# Creature Helpers
# =============================================================================

## Reset has_moved / has_attacked / has_used_active on all friendly creatures.
func _reset_friendly_creatures() -> void:
	for child: Node in creatures_node.get_children():
		if child is Creature and not child is EnemyCreature:
			(child as Creature).start_turn()


## Reset all enemy creatures for their turn.
func _reset_enemy_creatures() -> void:
	for child: Node in creatures_node.get_children():
		if child is EnemyCreature:
			(child as EnemyCreature).start_turn()


## Fire end-of-turn effects on all friendly creatures.
func _end_turn_friendly_creatures() -> void:
	for child: Node in creatures_node.get_children():
		if child is Creature and not child is EnemyCreature:
			(child as Creature).end_turn()


## Get all living enemy creatures on the board.
func _get_living_enemies() -> Array[EnemyCreature]:
	var enemies: Array[EnemyCreature] = []
	for child: Node in creatures_node.get_children():
		if child is EnemyCreature and (child as Creature).is_alive():
			enemies.append(child as EnemyCreature)
	return enemies


## Get all living player (non-enemy) creatures on the board.
func _get_living_player_creatures() -> Array[Creature]:
	var friendlies: Array[Creature] = []
	for child: Node in creatures_node.get_children():
		if child is Creature and not child is EnemyCreature and (child as Creature).is_alive():
			friendlies.append(child as Creature)
	return friendlies


# =============================================================================
# Phase Management
# =============================================================================

func _set_phase(new_phase: Phase) -> void:
	current_phase = new_phase
	phase_changed.emit(new_phase)


## Whether it's currently the player's action phase.
func is_player_action_phase() -> bool:
	return current_phase == Phase.ACTION_PHASE


## Human-readable phase name for UI display.
func get_phase_name() -> String:
	match current_phase:
		Phase.INACTIVE:
			return "Waiting"
		Phase.DRAW_PHASE:
			return "Draw Phase"
		Phase.ACTION_PHASE:
			return "Your Turn"
		Phase.END_TURN_PHASE:
			return "End Turn"
		Phase.ENEMY_TURN:
			return "Enemy Turn"
	return ""
