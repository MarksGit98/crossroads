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

	# Draw cards.
	var draw_count: int = INITIAL_DRAW if _is_first_turn else TURN_DRAW
	_is_first_turn = false
	hand.draw_cards(draw_count)

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

	# TODO: Enemy AI resolves intents here.
	# For now, just pause briefly to show it's the enemy's turn.
	await get_tree().create_timer(ENEMY_TURN_DELAY).timeout

	enemy_turn_ended.emit()
	turn_ended.emit(turn_number)

	# Loop back to the next player turn.
	_start_player_turn()


# =============================================================================
# Creature Helpers
# =============================================================================

## Reset has_moved / has_attacked / has_used_active on all friendly creatures.
func _reset_friendly_creatures() -> void:
	for child: Node in creatures_node.get_children():
		if child is Creature and not child is EnemyCreature:
			(child as Creature).start_turn()


## Fire end-of-turn effects on all friendly creatures.
func _end_turn_friendly_creatures() -> void:
	for child: Node in creatures_node.get_children():
		if child is Creature and not child is EnemyCreature:
			(child as Creature).end_turn()


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
