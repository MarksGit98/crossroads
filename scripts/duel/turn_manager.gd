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

## Duel-wide context — single source of truth for player, board, hand, etc.
## All references below are derived accessors for readability in this file.
var ctx: DuelContext

## Interaction manager isn't duel-scoped (it's a UI concern), so it's passed
## directly alongside the context.
var interaction_manager: BoardInteractionManager

# -- Convenience accessors derived from ctx --

var player: Player:
	get: return ctx.player if ctx else null

var hand: Node2D:
	get: return ctx.hand if ctx else null

var hex_grid: HexGrid:
	get: return ctx.board if ctx else null

var creatures_node: Node2D:
	get: return ctx.creatures_node if ctx else null

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
## The DuelContext carries player, hand, board, and creatures_node; the
## interaction manager is injected separately because it's UI-scoped.
func setup(p_ctx: DuelContext, p_interaction: BoardInteractionManager) -> void:
	ctx = p_ctx
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
##
## AI priority (highest first):
##   1. Self-AoE heavy attack (e.g. Minotaur's Earthquake Slam): reposition
##      to the hex that hits the most player creatures, then slam.
##   2. Target-range heavy attack: if in range and the heavy is ready.
##   3. Basic attack if in range.
##   4. Otherwise, move toward the nearest player creature.
func _resolve_enemy_action(enemy: EnemyCreature) -> void:
	var player_creatures: Array[Creature] = _get_living_player_creatures()
	if player_creatures.is_empty():
		return

	# -- Priority 1: self-AoE heavy attack (e.g. Minotaur) --
	if enemy.can_use_heavy_attack() and _is_self_aoe_heavy_attack(enemy):
		if await _try_use_self_aoe_heavy(enemy, player_creatures):
			enemy.set_intent(EnemyCreature.Intent.NONE)
			return

	var nearest: Creature = _find_nearest_player_creature(enemy, player_creatures)
	if nearest == null:
		return

	var distance: int = HexHelper.hex_distance(enemy.hex_position, nearest.hex_position)
	var heavy_range: int = _heavy_attack_range(enemy)

	# -- Priority 2: target-range heavy attack if in range --
	if enemy.can_use_heavy_attack() and distance <= heavy_range and enemy.can_attack():
		enemy.set_intent(EnemyCreature.Intent.ATTACK, enemy.current_atk)
		await get_tree().create_timer(0.3).timeout
		await enemy.perform_heavy_attack(nearest.hex_position, hex_grid, _ctx())
		enemy.set_intent(EnemyCreature.Intent.NONE)
		return

	# -- Priority 3: basic attack if in range --
	if distance <= enemy.attack_range and enemy.can_attack():
		enemy.set_intent(EnemyCreature.Intent.ATTACK, enemy.current_atk)
		await get_tree().create_timer(0.3).timeout
		await enemy.perform_attack(nearest, hex_grid)
	# -- Priority 4: move toward nearest, then opportunistic attack --
	elif enemy.can_move():
		enemy.set_intent(EnemyCreature.Intent.MOVE)
		await get_tree().create_timer(0.3).timeout
		await _move_enemy_toward(enemy, nearest)

		if enemy.can_attack() and nearest.is_alive():
			var new_distance: int = HexHelper.hex_distance(enemy.hex_position, nearest.hex_position)
			# Prefer heavy if the move brought it into heavy range.
			if enemy.can_use_heavy_attack() and new_distance <= heavy_range:
				enemy.set_intent(EnemyCreature.Intent.ATTACK, enemy.current_atk)
				await get_tree().create_timer(0.2).timeout
				await enemy.perform_heavy_attack(nearest.hex_position, hex_grid, _ctx())
			elif new_distance <= enemy.attack_range:
				enemy.set_intent(EnemyCreature.Intent.ATTACK, enemy.current_atk)
				await get_tree().create_timer(0.2).timeout
				await enemy.perform_attack(nearest, hex_grid)

	# Clear intent after acting.
	enemy.set_intent(EnemyCreature.Intent.NONE)


## Whether an enemy's heavy attack is a self-centered AoE (e.g. Minotaur's
## Earthquake Slam — "target_rule: SELF" with aoe_center: "caster" in effects).
func _is_self_aoe_heavy_attack(enemy: EnemyCreature) -> bool:
	if enemy.enemy_data == null:
		return false
	var spec: Dictionary = enemy.enemy_data.heavy_attack
	if spec.is_empty():
		return false
	var rule: int = spec.get("target_rule", -1)
	return rule == CardTypes.TargetRule.SELF


## Pull the heavy-attack range out of the enemy's data. Defaults to 1.
func _heavy_attack_range(enemy: EnemyCreature) -> int:
	if enemy.enemy_data == null:
		return 1
	return enemy.enemy_data.heavy_attack.get("range", 1)


## Attempt to use a self-AoE heavy attack. Scans candidate hexes (current
## position + valid move destinations) for the one that maximizes the count
## of player creatures adjacent to it. If moving there first is required,
## moves the enemy. Then fires the heavy attack.
##
## Returns true if the heavy attack was performed.
func _try_use_self_aoe_heavy(enemy: EnemyCreature, player_creatures: Array[Creature]) -> bool:
	if enemy.enemy_data == null or enemy.enemy_data.heavy_attack.is_empty():
		return false
	var spec: Dictionary = enemy.enemy_data.heavy_attack
	# Determine the AoE radius from the heavy attack's first damage-dealing effect.
	var aoe_radius: int = 1
	for e: Dictionary in spec.get("effects", []):
		if e.has("aoe_radius"):
			aoe_radius = e.get("aoe_radius", 1)
			break

	# Candidate hexes: current hex + every hex the enemy could step to this turn.
	var candidates: Array[Vector2i] = [enemy.hex_position]
	if enemy.can_move():
		candidates.append_array(hex_grid.get_valid_moves_for(enemy))

	# Score each candidate by how many player creatures fall within aoe_radius.
	var best_hex: Vector2i = enemy.hex_position
	var best_score: int = _count_players_in_range(enemy.hex_position, aoe_radius, player_creatures)

	for hex: Vector2i in candidates:
		if hex == enemy.hex_position:
			continue
		var score: int = _count_players_in_range(hex, aoe_radius, player_creatures)
		if score > best_score:
			best_score = score
			best_hex = hex

	# Only fire the heavy if at least one player creature is hit.
	if best_score <= 0:
		return false

	# Move into position first if needed.
	if best_hex != enemy.hex_position:
		enemy.set_intent(EnemyCreature.Intent.MOVE)
		await get_tree().create_timer(0.3).timeout
		await _move_enemy_to(enemy, best_hex)

	# Fire the heavy attack against the enemy's own hex (self-AoE).
	enemy.set_intent(EnemyCreature.Intent.ATTACK, enemy.current_atk)
	await get_tree().create_timer(0.3).timeout
	await enemy.perform_heavy_attack(enemy.hex_position, hex_grid, _ctx())
	return true


## Count how many player creatures are within N hexes of the given hex.
func _count_players_in_range(center: Vector2i, radius: int, players: Array[Creature]) -> int:
	var n: int = 0
	for p: Creature in players:
		if HexHelper.hex_distance(p.hex_position, center) <= radius:
			n += 1
	return n


## Move an enemy directly to a specific hex (used by AI positioning).
## Updates tile occupancy and awaits the movement tween.
func _move_enemy_to(enemy: EnemyCreature, hex: Vector2i) -> void:
	if hex == enemy.hex_position:
		return
	hex_grid.remove_creature(enemy.hex_position)
	var new_tile: HexTileData = hex_grid.get_tile(hex)
	if new_tile:
		new_tile.occupant = enemy
	await enemy.move_to(hex, hex_grid.hex_size, ctx)


## Shorthand for the turn manager's DuelContext reference. Heavy attacks
## need the full context to resolve effects/targets.
func _ctx() -> DuelContext:
	return ctx


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


## Move an enemy toward a target creature, routing around impassable terrain
## and other units. Uses BFS pathfinding so walls, rivers, and blocked tiles
## no longer trap the AI in a local minimum (previously enemies stood still
## when the straight line to the target was blocked).
##
## The enemy walks up to `current_move_range` hexes along the planned path,
## stopping at whichever hex along the route is:
##   (a) actually reachable this turn (not beyond move_range), AND
##   (b) within the set of hexes the creature could legally move to per
##       its move_pattern / passability rules.
##
## If no path exists at all (entirely walled off from the target), the
## enemy does nothing and the turn advances cleanly instead of hanging.
func _move_enemy_toward(enemy: EnemyCreature, target: Creature) -> void:
	var move_range: int = enemy.current_move_range
	if move_range <= 0:
		return

	# Plan a full route from enemy to a hex adjacent to target.
	var path: Array[Vector2i] = hex_grid.find_path_toward(
		enemy.hex_position, target.hex_position
	)
	if path.is_empty():
		# No path — enemy is completely walled off. Stay put and let the
		# turn advance so we don't hang waiting on a move that can't happen.
		return

	# Pick the furthest hex along the path that this enemy can legally move
	# to THIS turn. Cap at move_range and validate against the creature's
	# own move filter so e.g. a SWIM-only unit can't land on non-water path
	# hexes the BFS might suggest.
	var valid_moves_set: Dictionary = {}
	for coord: Vector2i in hex_grid.get_valid_moves_for(enemy):
		valid_moves_set[coord] = true

	var step_target: Vector2i = enemy.hex_position
	var reach: int = mini(move_range, path.size())
	for i: int in range(reach):
		var candidate: Vector2i = path[i]
		if valid_moves_set.has(candidate):
			step_target = candidate
		# If the path calls for a hex outside our legal moves (e.g. move
		# pattern restriction), stop advancing — don't skip that hex.
		else:
			break

	if step_target == enemy.hex_position:
		return

	# Update tile occupancy.
	hex_grid.remove_creature(enemy.hex_position)
	var new_tile: HexTileData = hex_grid.get_tile(step_target)
	if new_tile:
		new_tile.occupant = enemy

	# Animate the move. ctx is passed so deployable enter/exit hooks fire
	# if the enemy steps onto or off of a deployable-hosting hex.
	await enemy.move_to(step_target, hex_grid.hex_size, ctx)


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
