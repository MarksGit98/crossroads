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

var hex_grid: HexGrid
var hand: Node2D  # The Hand node — checked via hand.is_targeting()
var action_menu: CreatureActionMenu
var camera: Camera2D

# =============================================================================
# State
# =============================================================================

var current_state: int = BoardState.IDLE
var _selected_creature: Creature = null
var _valid_targets: Array[Vector2i] = []

## Whether the manager is enabled (accepts player input).
## Disabled during non-action phases (draw, end turn, enemy turn).
var _enabled: bool = true

## Highlight colors for different interaction modes.
const MOVE_HIGHLIGHT_COLOR: Color = Color(0.2, 0.7, 1.0, 0.35)
const ATTACK_HIGHLIGHT_COLOR: Color = Color(1.0, 0.3, 0.2, 0.35)
const ACTIVE_HIGHLIGHT_COLOR: Color = Color(0.8, 0.4, 1.0, 0.35)


# =============================================================================
# Setup
# =============================================================================

## Wire all dependencies. Called by the duel scene in _ready().
func setup(p_grid: HexGrid, p_hand: Node2D, p_menu: CreatureActionMenu, p_camera: Camera2D) -> void:
	hex_grid = p_grid
	hand = p_hand
	action_menu = p_menu
	camera = p_camera

	# Connect hex grid signals.
	hex_grid.hex_clicked.connect(_on_hex_clicked)

	# Connect action menu signals.
	action_menu.action_selected.connect(_on_action_selected)
	action_menu.menu_closed.connect(_on_menu_closed)


## Register a creature's signals so the manager can respond to clicks.
## Call this whenever a new creature is spawned on the board.
func register_creature(creature: Creature) -> void:
	if not creature.clicked.is_connected(_on_creature_clicked):
		creature.clicked.connect(_on_creature_clicked)


# =============================================================================
# Input
# =============================================================================

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

	# If already in an interaction, cancel it first.
	if current_state != BoardState.IDLE:
		_cancel_interaction()

	# Select this creature and show the action menu.
	_selected_creature = creature
	_transition_to(BoardState.CREATURE_SELECTED)

	# Convert creature world position to screen position for the menu.
	var screen_pos: Vector2 = _world_to_screen(creature.global_position)
	action_menu.show_for_creature(creature, screen_pos)


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
		&"active":
			_enter_active_targeting()
		_:
			_cancel_interaction()


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

	# Update tile occupancy.
	var old_tile: HexTileData = hex_grid.get_tile(_selected_creature.hex_position)
	if old_tile:
		old_tile.occupant = null
	var new_tile: HexTileData = hex_grid.get_tile(coord)
	if new_tile:
		new_tile.occupant = _selected_creature

	# Animate the move (awaited — creature tweens to the new hex).
	_selected_creature.move_to(coord, hex_grid.hex_size)

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
	# TODO: Compute valid attack targets, highlight them, transition state.
	# For now, cancel back to idle.
	_cancel_interaction()


func _handle_attack_target_click(_coord: Vector2i) -> void:
	# TODO: Execute attack against target on the clicked hex.
	pass


# =============================================================================
# Active Targeting (stub — future implementation)
# =============================================================================

func _enter_active_targeting() -> void:
	# TODO: Compute valid active targets, highlight them, transition state.
	# For now, cancel back to idle.
	_cancel_interaction()


func _handle_active_target_click(_coord: Vector2i) -> void:
	# TODO: Execute active ability against the clicked hex.
	pass


# =============================================================================
# Cancel / Reset
# =============================================================================

## Cancel any active interaction and return to idle.
func _cancel_interaction() -> void:
	if action_menu.is_open():
		action_menu.hide_menu()
	hex_grid.clear_highlights()
	_selected_creature = null
	_valid_targets.clear()
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
