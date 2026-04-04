## Contextual action menu that appears when a creature is selected.
## Positioned at the creature's screen location, shows available actions
## (Move, Attack, Cast Active) based on the creature's current state.
## Lives in a CanvasLayer so it renders above the game world.
class_name CreatureActionMenu
extends PanelContainer

# =============================================================================
# Signals
# =============================================================================

## Emitted when the player picks an action. Values: &"move", &"attack", &"active".
signal action_selected(action: StringName)

## Emitted when the menu is closed without selecting an action.
signal menu_closed()

# =============================================================================
# Node References
# =============================================================================

@onready var _move_button: Button = $VBox/MoveButton
@onready var _attack_button: Button = $VBox/AttackButton
@onready var _active_button: Button = $VBox/ActiveButton

# =============================================================================
# State
# =============================================================================

## The creature this menu is currently showing for.
var _creature: Creature = null


# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	visible = false
	# Stop mouse clicks from passing through the menu to the game world.
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Connect button presses.
	_move_button.pressed.connect(_on_move_pressed)
	_attack_button.pressed.connect(_on_attack_pressed)
	_active_button.pressed.connect(_on_active_pressed)


# =============================================================================
# Public API
# =============================================================================

## Show the menu for a given creature at a screen position.
## Enables/disables buttons based on what the creature can currently do.
func show_for_creature(creature: Creature, screen_pos: Vector2) -> void:
	_creature = creature

	# Enable/disable based on creature capabilities.
	_move_button.disabled = not creature.can_move()
	_attack_button.disabled = not creature.can_attack()

	# Active button: visible only if the creature has actives, disabled if none are usable.
	if creature.active_count() > 0:
		_active_button.visible = true
		_active_button.disabled = not _can_use_any_active(creature)
	else:
		_active_button.visible = false

	# Position the menu to the right of the creature sprite.
	# Offset right so the menu doesn't overlap the character.
	var menu_offset: Vector2 = Vector2(60.0, -size.y * 0.5)
	position = screen_pos + menu_offset

	# Clamp to viewport so the menu doesn't go offscreen.
	# If it would go off the right edge, flip to the left side instead.
	var vp_size: Vector2 = get_viewport_rect().size
	if position.x + size.x > vp_size.x - 4.0:
		position.x = screen_pos.x - size.x - 60.0
	position.x = clampf(position.x, 4.0, vp_size.x - size.x - 4.0)
	position.y = clampf(position.y, 4.0, vp_size.y - size.y - 4.0)

	visible = true
	# Grab focus so keyboard/gamepad can navigate.
	_move_button.grab_focus()


## Hide the menu and emit menu_closed.
func hide_menu() -> void:
	visible = false
	_creature = null
	menu_closed.emit()


## Whether the menu is currently visible.
func is_open() -> bool:
	return visible


# =============================================================================
# Input
# =============================================================================

## Consume any mouse click on the panel so it doesn't propagate to the game.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()


# =============================================================================
# Button Handlers
# =============================================================================

func _on_move_pressed() -> void:
	visible = false
	action_selected.emit(&"move")


func _on_attack_pressed() -> void:
	visible = false
	action_selected.emit(&"attack")


func _on_active_pressed() -> void:
	visible = false
	action_selected.emit(&"active")


# =============================================================================
# Helpers
# =============================================================================

## Check if the creature can use any of its active abilities.
func _can_use_any_active(creature: Creature) -> bool:
	# We pass an empty context for now — the full context check happens
	# when the player actually tries to use the active.
	for i: int in range(creature.active_count()):
		if creature.can_use_active(i, {}):
			return true
	return false
