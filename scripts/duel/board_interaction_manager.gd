## Manages player interaction with the hex board after cards are played.
## Owns the board-level state machine: creature selection, action menu,
## movement targeting, attack targeting, and active ability targeting.
## Wired by the duel scene — listens to creature clicks and hex clicks.
class_name BoardInteractionManager
extends Node

# =============================================================================
# Signals
# =============================================================================

## Emitted whenever the interaction state changes.
signal state_changed(old_state: int, new_state: int)

# =============================================================================
# State Enum
# =============================================================================

enum BoardState {
	IDLE,               ## Default — hex clicks show info, creature clicks open menu.
	CREATURE_SELECTED,  ## Action menu is visible for a creature.
	MOVE_TARGETING,     ## Valid move hexes are highlighted; waiting for hex click.
	ATTACK_TARGETING,   ## (Future) Valid attack hexes are highlighted.
	ACTIVE_TARGETING,   ## (Future) Valid active target hexes are highlighted.
	EXECUTING,          ## An action is being executed (tween in progress); input blocked.
}

# =============================================================================
# Dependencies (set via setup())
# =============================================================================

## Duel-wide context — single source of truth for player, board, etc.
## All references below are derived accessors for readability.
var ctx: DuelContext

## The action menu + camera aren't duel-scoped — they're injected directly
## since they don't need to live on the context object.
var action_menu: CreatureActionMenu
var camera: Camera2D

# -- Convenience accessors derived from ctx --

var hex_grid: HexGrid:
	get: return ctx.board if ctx else null

var hand: Node2D:
	get: return ctx.hand if ctx else null

var player: Player:
	get: return ctx.player if ctx else null

# =============================================================================
# State
# =============================================================================

var current_state: int = BoardState.IDLE
var _selected_creature: Creature = null
var _valid_targets: Array[Vector2i] = []
var _active_ability_index: int = -1

## Shared targeting arrow, spawned once in setup() and kept as a sibling of
## the creatures node so it renders in world space. Driven by _process()
## whenever we're in a targeting state.
var _arrow: TargetingArrow = null

## Whether the manager is enabled (accepts player input).
## Disabled during non-action phases (draw, end turn, enemy turn).
var _enabled: bool = true

## Highlight colors for different interaction modes.
const MOVE_HIGHLIGHT_COLOR: Color = Color(0.2, 0.7, 1.0, 0.35)
const ATTACK_HIGHLIGHT_COLOR: Color = Color(1.0, 0.3, 0.2, 0.35)
const ACTIVE_HIGHLIGHT_COLOR: Color = Color(0.8, 0.4, 1.0, 0.35)

## Soft-white highlight on the hex of the currently-selected creature.
## Applied when the action menu opens and kept layered under any range
## previews the player triggers by hovering menu buttons.
const SELECTED_CREATURE_HIGHLIGHT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.28)


# =============================================================================
# Setup
# =============================================================================

## Wire all dependencies. Called by the duel scene in _ready().
## The DuelContext provides hex_grid/hand/player; only the menu and camera
## (which are UI-scoped, not duel-scoped) are injected separately.
func setup(p_ctx: DuelContext, p_menu: CreatureActionMenu, p_camera: Camera2D) -> void:
	ctx = p_ctx
	action_menu = p_menu
	camera = p_camera

	# Connect hex grid signals.
	hex_grid.hex_clicked.connect(_on_hex_clicked)

	# Connect action menu signals.
	action_menu.action_selected.connect(_on_action_selected)
	action_menu.active_ability_selected.connect(_on_active_ability_selected)
	action_menu.menu_closed.connect(_on_menu_closed)
	# Hover-to-preview: show the action's range while the player hovers
	# its button, clear back to the selected-creature highlight on exit.
	action_menu.action_button_hovered.connect(_on_action_button_hovered)
	action_menu.action_button_unhovered.connect(_on_action_button_unhovered)

	# Spawn the targeting arrow as a sibling of the creatures node so it
	# renders in world space above hex tiles and creatures.
	_arrow = TargetingArrow.new()
	var world_parent: Node = ctx.creatures_node.get_parent() if ctx.creatures_node else self
	world_parent.add_child(_arrow)


## Register a creature's signals so the manager can respond to clicks.
## Call this whenever a new creature is spawned on the board.
func register_creature(creature: Creature) -> void:
	if not creature.clicked.is_connected(_on_creature_clicked):
		creature.clicked.connect(_on_creature_clicked)


# =============================================================================
# Input
# =============================================================================

## Drive the targeting arrow every frame while we're in a targeting state.
## Source = selected creature's world position, target = mouse world position,
## validity = whether the hex under the mouse is in _valid_targets.
func _process(_delta: float) -> void:
	if _arrow == null or _selected_creature == null or camera == null:
		return

	match current_state:
		BoardState.MOVE_TARGETING, BoardState.ATTACK_TARGETING, BoardState.ACTIVE_TARGETING:
			var mouse_world: Vector2 = camera.get_global_mouse_position()
			var hovered_coord: Vector2i = HexHelper.world_to_hex(mouse_world, hex_grid.hex_size)
			var is_valid: bool = hovered_coord in _valid_targets
			_arrow.show_arrow(_selected_creature.global_position, mouse_world, is_valid)
		_:
			if _arrow.is_showing():
				_arrow.hide_arrow()


## Handle ESC and right-click to cancel the current interaction.
func _unhandled_input(event: InputEvent) -> void:
	if current_state == BoardState.IDLE or current_state == BoardState.EXECUTING:
		return

	# ESC cancels any active interaction.
	if event is InputEventKey:
		var kb: InputEventKey = event as InputEventKey
		if kb.pressed and kb.keycode == KEY_ESCAPE:
			_cancel_interaction()
			get_viewport().set_input_as_handled()
			return

	# Right-click cancels any active interaction.
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_interaction()
			get_viewport().set_input_as_handled()
			return


# =============================================================================
# Creature Click Handler
# =============================================================================

func _on_creature_clicked(creature: Creature) -> void:
	# Don't process clicks when disabled or during card targeting / execution.
	if not _enabled:
		return
	if hand.is_targeting():
		return
	if current_state == BoardState.EXECUTING:
		return

	# During attack targeting, clicking a creature means clicking its hex.
	if current_state == BoardState.ATTACK_TARGETING:
		_handle_attack_target_click(creature.hex_position)
		return

	# If already in an interaction, cancel it first.
	if current_state != BoardState.IDLE:
		_cancel_interaction()

	# Select this creature and show the action menu.
	_selected_creature = creature
	_transition_to(BoardState.CREATURE_SELECTED)

	# Paint just the creature's own hex so the player sees which unit is
	# selected without cluttering the board with neighbor-range highlights.
	# The menu's hover handlers overlay ability/move/attack ranges on top
	# while the mouse is over each button.
	_paint_selection_highlight()

	# Pre-compute whether this creature has valid attack targets.
	var attack_targets: Array[Vector2i] = hex_grid.get_valid_attack_targets_for(creature)
	var has_attack_targets: bool = not attack_targets.is_empty()

	# Convert creature world position to screen position for the menu.
	var screen_pos: Vector2 = _world_to_screen(creature.global_position)
	action_menu.show_for_creature(creature, screen_pos, has_attack_targets, ctx)


# =============================================================================
# Hex Click Handler
# =============================================================================

func _on_hex_clicked(coord: Vector2i) -> void:
	if not _enabled:
		return
	# During card targeting, the hand handles hex clicks.
	if hand.is_targeting():
		return

	match current_state:
		BoardState.MOVE_TARGETING:
			_handle_move_target_click(coord)
		BoardState.ATTACK_TARGETING:
			_handle_attack_target_click(coord)
		BoardState.ACTIVE_TARGETING:
			_handle_active_target_click(coord)
		BoardState.CREATURE_SELECTED:
			# Clicking a hex while the menu is open cancels selection.
			_cancel_interaction()
		BoardState.IDLE:
			pass  # Normal hex info display — handled by duel_test_scene.
		BoardState.EXECUTING:
			pass  # Ignore clicks during execution.


# =============================================================================
# Action Menu Handler
# =============================================================================

func _on_action_selected(action: StringName) -> void:
	if _selected_creature == null:
		_cancel_interaction()
		return

	match action:
		&"move":
			_enter_move_targeting()
		&"attack":
			_enter_attack_targeting()
		_:
			_cancel_interaction()


## Called when the player picks a specific active ability button from the menu.
func _on_active_ability_selected(ability_index: int) -> void:
	if _selected_creature == null:
		_cancel_interaction()
		return
	_enter_active_targeting(ability_index)


func _on_menu_closed() -> void:
	# If the menu closed without selecting an action, return to idle.
	if current_state == BoardState.CREATURE_SELECTED:
		_transition_to(BoardState.IDLE)
		_selected_creature = null


# =============================================================================
# Move Targeting
# =============================================================================

func _enter_move_targeting() -> void:
	if _selected_creature == null or not _selected_creature.can_move():
		_cancel_interaction()
		return

	_valid_targets = hex_grid.get_valid_moves_for(_selected_creature)
	if _valid_targets.is_empty():
		_cancel_interaction()
		return

	# Highlight valid move hexes.
	var highlights: Dictionary = {}
	for coord: Vector2i in _valid_targets:
		highlights[coord] = MOVE_HIGHLIGHT_COLOR
	hex_grid.set_highlights(highlights)

	_transition_to(BoardState.MOVE_TARGETING)


func _handle_move_target_click(coord: Vector2i) -> void:
	if coord not in _valid_targets:
		return  # Invalid hex — ignore, stay in targeting mode.

	# Execute the move.
	_transition_to(BoardState.EXECUTING)
	hex_grid.clear_highlights()
	if _arrow:
		_arrow.hide_arrow()

	# Update tile occupancy.
	var old_tile: HexTileData = hex_grid.get_tile(_selected_creature.hex_position)
	if old_tile:
		old_tile.occupant = null
	var new_tile: HexTileData = hex_grid.get_tile(coord)
	if new_tile:
		new_tile.occupant = _selected_creature

	# Animate the move (awaited — creature tweens to the new hex). Pass ctx
	# so deployables on the old/new hex can fire their enter/exit hooks
	# (e.g. axe pickup).
	_selected_creature.move_to(coord, hex_grid.hex_size, ctx)

	# After move completes, clean up. Use a tween callback since move_to uses await.
	# We wait a frame longer than the tween duration to be safe.
	await _selected_creature.moved

	_selected_creature = null
	_valid_targets.clear()
	_transition_to(BoardState.IDLE)


# =============================================================================
# Attack Targeting (stub — future implementation)
# =============================================================================

func _enter_attack_targeting() -> void:
	if _selected_creature == null or not _selected_creature.can_attack():
		_cancel_interaction()
		return

	_valid_targets = hex_grid.get_valid_attack_targets_for(_selected_creature)
	if _valid_targets.is_empty():
		_cancel_interaction()
		return

	# Highlight valid attack targets in red.
	var highlights: Dictionary = {}
	for coord: Vector2i in _valid_targets:
		highlights[coord] = ATTACK_HIGHLIGHT_COLOR
	hex_grid.set_highlights(highlights)

	_transition_to(BoardState.ATTACK_TARGETING)


func _handle_attack_target_click(coord: Vector2i) -> void:
	if coord not in _valid_targets:
		return

	var tile: HexTileData = hex_grid.get_tile(coord)
	if tile == null or not tile.is_occupied():
		return

	var target: Creature = tile.occupant
	var attacker: Creature = _selected_creature

	# Execute the attack.
	_transition_to(BoardState.EXECUTING)
	hex_grid.clear_highlights()
	if _arrow:
		_arrow.hide_arrow()

	await attacker.perform_attack(target, hex_grid)

	_selected_creature = null
	_valid_targets.clear()
	_transition_to(BoardState.IDLE)


# =============================================================================
# Active Targeting
# =============================================================================

func _enter_active_targeting(ability_index: int) -> void:
	if _selected_creature == null:
		_cancel_interaction()
		return

	# Validate the requested ability is usable with the current duel state.
	if not _selected_creature.can_use_active(ability_index, ctx):
		_cancel_interaction()
		return

	_active_ability_index = ability_index
	# Go through the creature's variant-aware accessor so an upgraded
	# Wizard picks up Arcane Blast+ rules (range, target_rule, etc.).
	var ability: Dictionary = _selected_creature.get_active(_active_ability_index)
	var target_rule: int = ability.get("target_rule", CardTypes.TargetRule.ANY_HEX)

	# SELF-targeting abilities execute immediately without a targeting phase.
	if target_rule == CardTypes.TargetRule.SELF:
		_execute_active_on_target(_selected_creature.hex_position)
		return

	# Compute valid targets and highlight them.
	_valid_targets = _selected_creature.get_active_targets(_active_ability_index, hex_grid)
	if _valid_targets.is_empty():
		_cancel_interaction()
		return

	var highlights: Dictionary = {}
	for coord: Vector2i in _valid_targets:
		highlights[coord] = ACTIVE_HIGHLIGHT_COLOR
	hex_grid.set_highlights(highlights)

	_transition_to(BoardState.ACTIVE_TARGETING)


func _handle_active_target_click(coord: Vector2i) -> void:
	if coord not in _valid_targets:
		return

	_execute_active_on_target(coord)


## Execute the selected active ability against a target hex.
func _execute_active_on_target(coord: Vector2i) -> void:
	_transition_to(BoardState.EXECUTING)
	hex_grid.clear_highlights()
	if _arrow:
		_arrow.hide_arrow()

	# Stamp the target hex on the context so effects can read it uniformly
	# with how hand-played spell targets are passed.
	ctx.set_targets([coord], [], _selected_creature)
	_selected_creature.use_active(_active_ability_index, ctx)
	ctx.clear_transient()

	# Wait a beat for the attack animation to play.
	if _selected_creature.state_machine and _selected_creature.state_machine.current_state == CreatureStateMachine.State.ATTACKING:
		await _selected_creature.state_machine.animation_finished

	_selected_creature = null
	_valid_targets.clear()
	_active_ability_index = -1
	_transition_to(BoardState.IDLE)


# =============================================================================
# Cancel / Reset
# =============================================================================

# =============================================================================
# Selection highlight + hover-to-preview
# =============================================================================

## Paint the currently-selected creature's hex in the "selected" soft-white
## color. No other hexes are highlighted at this stage — range previews are
## layered on top while the player hovers action-menu buttons.
func _paint_selection_highlight() -> void:
	if _selected_creature == null:
		return
	var highlights: Dictionary = {}
	highlights[_selected_creature.hex_position] = SELECTED_CREATURE_HIGHLIGHT_COLOR
	hex_grid.set_highlights(highlights)


## Handle the action menu's hover signal. Paints the action's full range
## on top of the selected-creature highlight so the player sees reach at
## a glance before clicking the button.
func _on_action_button_hovered(kind: StringName, ability_index: int) -> void:
	if _selected_creature == null or current_state != BoardState.CREATURE_SELECTED:
		return

	var highlights: Dictionary = {}
	# Always keep the creature's own hex lit so it stays visually selected.
	highlights[_selected_creature.hex_position] = SELECTED_CREATURE_HIGHLIGHT_COLOR

	match kind:
		&"move":
			for coord: Vector2i in hex_grid.get_valid_moves_for(_selected_creature):
				highlights[coord] = MOVE_HIGHLIGHT_COLOR
		&"attack":
			for coord: Vector2i in hex_grid.get_valid_attack_targets_for(_selected_creature):
				highlights[coord] = ATTACK_HIGHLIGHT_COLOR
		&"active":
			for coord: Vector2i in _selected_creature.get_active_targets(ability_index, hex_grid):
				highlights[coord] = ACTIVE_HIGHLIGHT_COLOR

	hex_grid.set_highlights(highlights)


## Clear the range preview and revert to just the creature's own hex.
func _on_action_button_unhovered() -> void:
	if _selected_creature == null or current_state != BoardState.CREATURE_SELECTED:
		return
	_paint_selection_highlight()


## Cancel any active interaction and return to idle.
func _cancel_interaction() -> void:
	if action_menu.is_open():
		action_menu.hide_menu()
	hex_grid.clear_highlights()
	if _arrow:
		_arrow.hide_arrow()
	_selected_creature = null
	_valid_targets.clear()
	_active_ability_index = -1
	_transition_to(BoardState.IDLE)


## Whether the manager is in an active interaction (not idle).
func is_busy() -> bool:
	return current_state != BoardState.IDLE


## Enable or disable player interaction.
## When disabled, all clicks are ignored and any active interaction is cancelled.
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled and current_state != BoardState.IDLE:
		_cancel_interaction()


# =============================================================================
# State Transitions
# =============================================================================

func _transition_to(new_state: int) -> void:
	var old: int = current_state
	current_state = new_state
	if old != new_state:
		state_changed.emit(old, new_state)


# =============================================================================
# Coordinate Helpers
# =============================================================================

## Convert a world position to screen position, accounting for camera transform.
func _world_to_screen(world_pos: Vector2) -> Vector2:
	if camera:
		var canvas_transform: Transform2D = camera.get_viewport().get_canvas_transform()
		return canvas_transform * world_pos
	return world_pos
