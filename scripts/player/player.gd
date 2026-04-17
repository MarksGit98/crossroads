## Player state container — holds mana, health, attack, and other per-player data.
## Lives in the scene tree so other systems can reference it via signals.
class_name Player
extends Node

# =============================================================================
# Signals
# =============================================================================

signal mana_changed(current: int, max_mana: int)
signal health_changed(current: int, max_health: int)
signal attack_changed(current: int)
signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)

# =============================================================================
# Constants — tune these or make them data-driven later
# =============================================================================

const STARTING_MANA: int = 5
const STARTING_HEALTH: int = 30
const STARTING_ATTACK: int = 0
const DEFAULT_MAX_CREATURES: int = 5

# =============================================================================
# Child References
# =============================================================================

## ManaDisplay lives as a child of Player inside a CanvasLayer.
## Auto-wired in _ready() so DuelTestScene doesn't need to manage it.
@onready var mana_display: ManaDisplay = $ManaCanvasLayer/ManaDisplay

# =============================================================================
# State
# =============================================================================

## Current / maximum mana. Resets to max each turn.
var current_mana: int = STARTING_MANA
var max_mana: int = STARTING_MANA

## Current / maximum health. Player loses when this hits 0.
var current_health: int = STARTING_HEALTH
var max_health: int = STARTING_HEALTH

## Current attack value (from equipped weapons, hero power, etc.).
var current_attack: int = STARTING_ATTACK

## Maximum number of friendly creatures allowed on the board at once.
## Can be modified by cards, class abilities, or other effects.
var max_creatures: int = DEFAULT_MAX_CREATURES

## Turn counter — incremented each time start_turn() is called.
var turn_number: int = 0

## Tracks play-limiting effects from creatures, hex tiles, and persistent cards.
## Queried by Card.can_play() to veto plays that would exceed any active cap
## (e.g. "max 1 spell per turn") and updated as restrictions come and go.
var play_restrictions: PlayRestrictionRegistry = PlayRestrictionRegistry.new()


func _ready() -> void:
	# Auto-wire the mana display if it exists as a child.
	if mana_display:
		mana_display.set_player(self)
	# Emit initial values so any UI wired at startup gets the correct state.
	mana_changed.emit(current_mana, max_mana)
	health_changed.emit(current_health, max_health)
	attack_changed.emit(current_attack)


# =============================================================================
# Turn Flow
# =============================================================================

## Called at the start of each player turn. Resets mana to max.
func start_turn() -> void:
	turn_number += 1
	current_mana = max_mana
	mana_changed.emit(current_mana, max_mana)
	turn_started.emit(turn_number)


## Called at the end of each player turn.
func end_turn() -> void:
	# Clear per-turn play counts and expire turn-bound restrictions.
	play_restrictions.on_turn_ended()
	turn_ended.emit(turn_number)


# =============================================================================
# Mana
# =============================================================================

## Try to spend mana. Returns true if affordable, false otherwise.
func spend_mana(amount: int) -> bool:
	if amount > current_mana:
		return false
	current_mana -= amount
	mana_changed.emit(current_mana, max_mana)
	return true


## Restore mana (e.g. from a card effect). Clamped to max.
func restore_mana(amount: int) -> void:
	current_mana = mini(current_mana + amount, max_mana)
	mana_changed.emit(current_mana, max_mana)


## Permanently increase max mana (ramp). Also fills the gained amount.
func increase_max_mana(amount: int) -> void:
	max_mana += amount
	current_mana = mini(current_mana + amount, max_mana)
	mana_changed.emit(current_mana, max_mana)


# =============================================================================
# Health
# =============================================================================

## Deal damage to the player. Returns actual damage taken.
func take_damage(amount: int) -> int:
	var actual: int = mini(amount, current_health)
	current_health -= actual
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		_on_defeated()
	return actual


## Heal the player. Clamped to max.
func heal(amount: int) -> void:
	current_health = mini(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func _on_defeated() -> void:
	# TODO: Emit a game_over signal, trigger defeat screen, etc.
	pass


# =============================================================================
# Attack
# =============================================================================

## Set attack value (e.g. from equipping a weapon).
func set_attack(value: int) -> void:
	current_attack = maxi(value, 0)
	attack_changed.emit(current_attack)


## Modify attack by a delta.
func modify_attack(delta: int) -> void:
	current_attack = maxi(current_attack + delta, 0)
	attack_changed.emit(current_attack)


# =============================================================================
# Cost System
# =============================================================================

## Whether the player can afford a given cost of the given type.
## Defaults to MANA for backward compatibility with older call sites.
## Supported cost types: MANA, HEALTH. Unsupported types return false.
func can_afford(cost: int, cost_type: CardTypes.CostType = CardTypes.CostType.MANA) -> bool:
	if cost <= 0:
		return true
	match cost_type:
		CardTypes.CostType.MANA:
			return current_mana >= cost
		CardTypes.CostType.HEALTH:
			# Cost must leave the player alive (pay N requires > N health).
			return current_health > cost
		_:
			# SACRIFICE / DISCARD / EXHAUST not yet supported.
			push_warning("Player.can_afford: unsupported cost type %s" % cost_type)
			return false


## Deduct a cost of the given type. Returns true on success, false if the
## player could not afford it (no partial payment). Emits the appropriate
## *_changed signal when a deduction actually occurs.
func pay_cost(cost: int, cost_type: CardTypes.CostType = CardTypes.CostType.MANA) -> bool:
	if not can_afford(cost, cost_type):
		return false
	if cost <= 0:
		return true
	match cost_type:
		CardTypes.CostType.MANA:
			current_mana -= cost
			mana_changed.emit(current_mana, max_mana)
		CardTypes.CostType.HEALTH:
			current_health -= cost
			health_changed.emit(current_health, max_health)
			if current_health <= 0:
				_on_defeated()
		_:
			return false
	return true
