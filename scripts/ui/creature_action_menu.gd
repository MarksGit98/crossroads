## Contextual action menu that appears when a creature is selected.
## Positioned at the creature's screen location, shows available actions
## (Move, Attack, and per-ability active buttons) based on creature state.
## Lives in a CanvasLayer so it renders above the game world.
## Hovering over an active ability button shows a description tooltip.
class_name CreatureActionMenu
extends PanelContainer

# =============================================================================
# Signals
# =============================================================================

## Emitted when the player picks a non-active action. Values: &"move", &"attack".
signal action_selected(action: StringName)

## Emitted when the player picks a specific active ability by index.
signal active_ability_selected(ability_index: int)

## Emitted when the menu is closed without selecting an action.
signal menu_closed()

# =============================================================================
# Node References
# =============================================================================

@onready var _vbox: VBoxContainer = $VBox
@onready var _move_button: Button = $VBox/MoveButton
@onready var _attack_button: Button = $VBox/AttackButton

# =============================================================================
# State
# =============================================================================

## The creature this menu is currently showing for.
var _creature: Creature = null

## Duel-wide context passed in via show_for_creature(). Used for mana
## affordability + effect-specific checks (MARK_SPAWN, etc.).
var _ctx: DuelContext = null

## Dynamically created buttons for each active ability.
var _active_buttons: Array[Button] = []

## Tooltip panel for active ability descriptions (created dynamically).
var _tooltip_panel: PanelContainer = null
var _tooltip_name_label: Label = null
var _tooltip_cost_label: Label = null
var _tooltip_desc_label: RichTextLabel = null

## Which ability index the tooltip is currently showing (-1 = none).
var _hovered_ability_index: int = -1

# =============================================================================
# Constants
# =============================================================================

const TOOLTIP_WIDTH: float = 220.0
const TOOLTIP_GAP: float = 4.0
const BUTTON_HEIGHT: float = 28.0
const BUTTON_FONT_SIZE: int = 13


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

	# Build the tooltip panel (hidden by default).
	_build_tooltip()


# =============================================================================
# Public API
# =============================================================================

## Show the menu for a given creature at a screen position.
## Enables/disables buttons based on what the creature can currently do.
## has_attack_targets indicates whether any hostile creatures are within attack range.
## p_ctx is the DuelContext — the menu queries it for mana affordability,
## effect-specific availability, etc.
func show_for_creature(creature: Creature, screen_pos: Vector2, has_attack_targets: bool = false, p_ctx: DuelContext = null) -> void:
	_creature = creature
	_ctx = p_ctx

	# Enable/disable based on creature capabilities.
	_move_button.disabled = not creature.can_move()
	_attack_button.disabled = not creature.can_attack() or not has_attack_targets

	# Remove old active ability buttons from previous show call.
	_clear_active_buttons()

	# Create a button for each active ability.
	for i: int in range(creature.active_count()):
		var ability: Dictionary = creature.card_data.actives[i]
		var ability_name: String = ability.get("name", "Active %d" % (i + 1))

		var btn: Button = Button.new()
		btn.text = ability_name
		btn.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
		btn.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
		btn.disabled = not creature.can_use_active(i, _ctx)

		# Capture the index for the lambda closures.
		var idx: int = i
		btn.pressed.connect(_on_active_ability_pressed.bind(idx))
		btn.mouse_entered.connect(_on_active_hover_enter.bind(idx))
		btn.mouse_exited.connect(_on_active_hover_exit)
		btn.focus_entered.connect(_on_active_hover_enter.bind(idx))
		btn.focus_exited.connect(_on_active_hover_exit)

		_vbox.add_child(btn)
		_active_buttons.append(btn)

	# Hide the tooltip until the player hovers.
	_tooltip_panel.visible = false
	_hovered_ability_index = -1

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
	_tooltip_panel.visible = false
	_hovered_ability_index = -1
	_creature = null
	_ctx = null
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
	_tooltip_panel.visible = false
	action_selected.emit(&"move")


func _on_attack_pressed() -> void:
	visible = false
	_tooltip_panel.visible = false
	action_selected.emit(&"attack")


func _on_active_ability_pressed(ability_index: int) -> void:
	visible = false
	_tooltip_panel.visible = false
	active_ability_selected.emit(ability_index)


# =============================================================================
# Active Tooltip
# =============================================================================

## Build the tooltip panel programmatically. It's a sibling of this menu
## in the same CanvasLayer so it renders at the same UI level.
func _build_tooltip() -> void:
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0)
	_tooltip_panel.visible = false
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_tooltip_panel.add_child(vbox)

	# Ability name (bold, larger).
	_tooltip_name_label = Label.new()
	_tooltip_name_label.add_theme_font_size_override("font_size", 14)
	_tooltip_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(_tooltip_name_label)

	# Mana cost line.
	_tooltip_cost_label = Label.new()
	_tooltip_cost_label.add_theme_font_size_override("font_size", 12)
	_tooltip_cost_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	vbox.add_child(_tooltip_cost_label)

	# Separator.
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	# Description (multi-line, wraps text).
	_tooltip_desc_label = RichTextLabel.new()
	_tooltip_desc_label.bbcode_enabled = true
	_tooltip_desc_label.fit_content = true
	_tooltip_desc_label.scroll_active = false
	_tooltip_desc_label.custom_minimum_size = Vector2(TOOLTIP_WIDTH - 16, 0)
	_tooltip_desc_label.add_theme_font_size_override("normal_font_size", 12)
	vbox.add_child(_tooltip_desc_label)

	# Add tooltip as a sibling so it's not clipped by this panel.
	# Deferred so the parent is available.
	_add_tooltip_deferred.call_deferred()


## Add the tooltip to our parent once the tree is ready.
func _add_tooltip_deferred() -> void:
	var p: Node = get_parent()
	if p:
		p.add_child(_tooltip_panel)
	else:
		add_child(_tooltip_panel)


## Show the tooltip for a specific ability when the player hovers its button.
func _on_active_hover_enter(ability_index: int) -> void:
	if _creature == null or _creature.card_data == null:
		return
	if not visible:
		return
	if ability_index < 0 or ability_index >= _creature.card_data.actives.size():
		return

	_hovered_ability_index = ability_index
	_populate_tooltip(ability_index)

	# Position tooltip to the right of this menu panel.
	_tooltip_panel.position = Vector2(position.x + size.x + TOOLTIP_GAP, position.y)

	# If it would go off the right edge, show it on the left instead.
	var vp_size: Vector2 = get_viewport_rect().size
	if _tooltip_panel.position.x + TOOLTIP_WIDTH > vp_size.x - 4.0:
		_tooltip_panel.position.x = position.x - TOOLTIP_WIDTH - TOOLTIP_GAP

	# Clamp vertically.
	_tooltip_panel.position.y = clampf(
		_tooltip_panel.position.y, 4.0,
		vp_size.y - _tooltip_panel.size.y - 4.0
	)

	_tooltip_panel.visible = true


## Hide the tooltip when the mouse leaves an ability button.
func _on_active_hover_exit() -> void:
	_tooltip_panel.visible = false
	_hovered_ability_index = -1


## Fill tooltip labels with data from a single active ability.
func _populate_tooltip(ability_index: int) -> void:
	if _creature == null or _creature.card_data == null:
		return

	var actives: Array = _creature.card_data.actives
	if ability_index < 0 or ability_index >= actives.size():
		return

	var ability: Dictionary = actives[ability_index]
	var ability_name: String = ability.get("name", "Unknown")
	var cost: int = ability.get("cost", 0)
	var cooldown: int = ability.get("cooldown", 0)
	var description: String = ability.get("description", "No description.")
	var cd_remaining: int = _creature.get_active_cooldown(ability_index)

	# Name.
	_tooltip_name_label.text = ability_name
	_tooltip_name_label.visible = true

	# Cost and cooldown line.
	var cost_text: String = "Mana: %d" % cost if cost > 0 else "Mana: Free"
	if cooldown > 0:
		cost_text += "  |  CD: %d turns" % cooldown
	if cd_remaining > 0:
		cost_text += "  (Ready in %d)" % cd_remaining
	_tooltip_cost_label.text = cost_text
	_tooltip_cost_label.visible = true

	# Description.
	_tooltip_desc_label.text = description


# =============================================================================
# Helpers
# =============================================================================

## Remove all dynamically created active ability buttons.
func _clear_active_buttons() -> void:
	for btn: Button in _active_buttons:
		btn.queue_free()
	_active_buttons.clear()
