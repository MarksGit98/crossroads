## Single source of truth for duel-scoped state. One instance per duel,
## owned by the duel root scene and injected into every subsystem that needs
## to know about the game in progress (Hand, BoardInteractionManager,
## TurnManager, Cards, Creatures, AI, etc.).
##
## Persistent refs (player, board, turn_manager, …) are set once at duel
## start and never reassigned during play. Live-state helpers (current_phase,
## active_side, …) delegate to their owning subsystem so the context always
## reflects current reality without needing to be "refreshed." Transient
## per-action data (target_hexes, caster) is mutated freely and cleared
## between actions via clear_transient().
##
## Future sub-registries (CreatureRegistry, SpellEffectRegistry, TrapRegistry,
## EquipmentRegistry, TileEffectRegistry) will hang off this object so any
## system can ask "what creatures are alive?", "what auras affect this hex?",
## etc., with targeted queries instead of scanning the entire board.
class_name DuelContext
extends RefCounted


# =============================================================================
# Persistent References (set once via configure())
# =============================================================================

## The human player's state container (mana, health, play_restrictions, …).
var player: Player

## The AI opponent's state container. Null until 2-sided duels are wired.
var enemy_player: Player

## The active hex board.
var board: HexGrid

## Orchestrates turn phases, draw, enemy AI.
var turn_manager: TurnManager

## The Hand scene root (drag/drop, targeting, discard).
var hand: Node2D

## Top-level Node2D that parents all spawned Creatures.
var creatures_node: Node2D

## The active gamemode (Team Deathmatch, Capture the Flag, …).
var gamemode: GamemodeTypes.Mode = GamemodeTypes.DEFAULT_MODE

## Registry of all deployables currently on the board (thrown axes, traps,
## summoned zones, etc.). Subsystems query this to ask "what's on hex X?"
## or "who owns this object?" rather than tracking deployables in their own
## ad hoc structures. One registry per duel, created in configure().
var deployables: DeployableRegistry = null


# =============================================================================
# Transient Per-Action Data
# =============================================================================
# These fields are mutated each time a card or ability resolves. They represent
# "the targets of *this* action" and are cleared afterwards so stale data can't
# leak into the next play.

## Hex(es) selected for the current action. Single-target cards use [hex]; multi-
## target traps and AoE spells use the full list.
var target_hexes: Array[Vector2i] = []

## Unit(s) explicitly selected for the current action (independent of target_hexes).
var target_units: Array = []

## The creature initiating the current action (for creature-cast abilities).
## Null for hand-played cards.
var caster: Creature = null


# =============================================================================
# Configuration
# =============================================================================

## Wire all persistent references at duel start. Call this once from the duel
## root scene's _ready(), after all subsystems are instantiated.
func configure(
	p_player: Player,
	p_board: HexGrid,
	p_turn_manager: TurnManager,
	p_hand: Node2D,
	p_creatures_node: Node2D,
	p_gamemode: GamemodeTypes.Mode = GamemodeTypes.DEFAULT_MODE,
	p_enemy_player: Player = null,
) -> void:
	player = p_player
	board = p_board
	turn_manager = p_turn_manager
	hand = p_hand
	creatures_node = p_creatures_node
	gamemode = p_gamemode
	enemy_player = p_enemy_player
	# Fresh registry per duel. Lives for the duel's lifetime and is cleared
	# when the duel ends (implicitly — the whole DuelContext goes out of scope).
	deployables = DeployableRegistry.new()


# =============================================================================
# Transient Management
# =============================================================================

## Stamp target data for the action about to resolve. Called by the subsystem
## triggering the action (Hand before card.play(), BoardInteractionManager
## before creature.use_active(), …).
func set_targets(hexes: Array[Vector2i] = [], units: Array = [], p_caster: Creature = null) -> void:
	target_hexes = hexes
	target_units = units
	caster = p_caster


## Wipe transient fields between actions so stale targets don't leak.
func clear_transient() -> void:
	target_hexes.clear()
	target_units.clear()
	caster = null


# =============================================================================
# Live-State Helpers
# =============================================================================
# These query the owning subsystem on each call — they always reflect the
# current truth without needing to be pushed updates.

## Current turn phase (DRAW, ACTION, ENEMY_TURN, …). Returns INACTIVE if
## the turn manager is not yet set up.
func current_phase() -> TurnManager.Phase:
	if turn_manager == null:
		return TurnManager.Phase.INACTIVE
	return turn_manager.current_phase


## Turn counter from the player's perspective.
func turn_number() -> int:
	return player.turn_number if player else 0


## Whether it is currently the player's action phase.
func is_player_turn() -> bool:
	return turn_manager != null and turn_manager.is_player_action_phase()


## Identifier for whose side is currently active (&"player" or &"enemy").
func active_side() -> StringName:
	return &"player" if is_player_turn() else &"enemy"


# =============================================================================
# Convenience Queries
# =============================================================================
# These are thin helpers that aggregate across sub-registries. As registries
# get added (CreatureRegistry, SpellEffectRegistry, …), they become the
# single call site for cross-cutting queries.

## Aggregate of play restrictions from both sides. Useful for effects that
## need to see "all restrictions currently in play" regardless of owner.
func play_restrictions_all() -> Array:
	var all: Array = []
	if player and player.play_restrictions:
		all.append_array(player.play_restrictions.get_active_restrictions())
	if enemy_player and enemy_player.play_restrictions:
		all.append_array(enemy_player.play_restrictions.get_active_restrictions())
	return all
