## Manages the draw pile and discard pile for a player's deck.
## Positioned in a CanvasLayer (screen-space). Clicking the deck sprite
## opens a viewer showing remaining cards in jumbled order.
class_name Deck
extends Node2D

signal card_drawn(card_data: CardData)
signal deck_shuffled
signal deck_empty
signal deck_ready

var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []

## Whether the deck viewer overlay is currently open.
var _viewer_open: bool = false

## The viewer panel instance (created on first open, reused after).
var _viewer: Control = null

## Margin from the bottom-right corner of the viewport.
const MARGIN_RIGHT: float = 60.0
const MARGIN_BOTTOM: float = 70.0

## Label showing remaining card count. Wired via @onready.
@onready var count_label: Label = $DeckCountLabel
@onready var click_area: Area2D = $ClickArea

## Example card IDs used for testing.
const EXAMPLE_DECK: Array[String] = [
	# Creatures
	"viking_archer",
	"viking_armored_axeman",
	"viking_axed_marauder",
	"viking_knight",
	"viking_knight_templar",
	"viking_lancer",
	"viking_soldier",
	"viking_swordsman",
	"viking_wizard",
	# Spells
	"viking_war_horn",
	"viking_healing_rune",
	"viking_frost_bolt",
	"viking_frost_bolt",
	"viking_shield_wall",
	"viking_ragnaroks_echo",
	# Equipment
	"viking_wolfskin_cloak",
	"viking_runic_axe",
	"viking_iron_helm",
]


func _ready() -> void:
	# Anchor to bottom-right corner regardless of viewport size.
	_anchor_to_corner()
	get_viewport().size_changed.connect(_anchor_to_corner)

	build(EXAMPLE_DECK)
	shuffle()
	_update_count_label()
	# Keep the label current whenever the piles change.
	card_drawn.connect(_on_pile_changed)
	deck_shuffled.connect(_on_pile_changed)
	deck_empty.connect(_on_pile_changed)
	# Wire click detection.
	click_area.input_event.connect(_on_click_area_input)
	# Signal that the deck is built and ready to be drawn from.
	deck_ready.emit()


## Position at bottom-right corner of the viewport.
func _anchor_to_corner() -> void:
	var screen: Vector2 = get_viewport_rect().size
	position = Vector2(screen.x - MARGIN_RIGHT, screen.y - MARGIN_BOTTOM)


func _on_pile_changed(_arg: Variant = null) -> void:
	_update_count_label()


func _update_count_label() -> void:
	if count_label:
		count_label.text = str(draw_pile.size())


# =============================================================================
# Click to View Deck Contents
# =============================================================================

func _on_click_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_toggle_viewer()
		get_viewport().set_input_as_handled()


func _toggle_viewer() -> void:
	if _viewer_open:
		_close_viewer()
	else:
		_open_viewer()


func _open_viewer() -> void:
	if _viewer:
		_viewer.queue_free()

	_viewer = _build_viewer()
	# Add to the same CanvasLayer parent so it's screen-space.
	get_parent().add_child(_viewer)
	_viewer_open = true


func _close_viewer() -> void:
	if _viewer:
		_viewer.queue_free()
		_viewer = null
	_viewer_open = false


## Build the viewer overlay — a semi-transparent panel with a scrollable
## grid of card names/types showing all cards remaining in the draw pile.
## Cards are displayed in jumbled order (not actual draw order).
func _build_viewer() -> Control:
	var screen_size: Vector2 = get_viewport_rect().size

	# -- Backdrop: click to close --
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.size = screen_size
	backdrop.gui_input.connect(_on_backdrop_input)

	# -- Panel --
	var panel := PanelContainer.new()
	var panel_width: float = 500.0
	var panel_height: float = 600.0
	panel.position = Vector2(
		(screen_size.x - panel_width) * 0.5,
		(screen_size.y - panel_height) * 0.5,
	)
	panel.size = Vector2(panel_width, panel_height)
	# Prevent clicks on the panel from closing the backdrop.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# -- Inner margin --
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)

	# -- VBox with title + scroll --
	var vbox := VBoxContainer.new()

	# Title
	var title := Label.new()
	title.text = "Deck  (%d cards)" % draw_pile.size()
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Scrollable card list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Show cards in jumbled order — copy and shuffle so we don't reveal draw order.
	var jumbled: Array[CardData] = draw_pile.duplicate()
	jumbled.shuffle()

	for card_data: CardData in jumbled:
		var row := _build_card_row(card_data)
		list.add_child(row)

	scroll.add_child(list)
	vbox.add_child(scroll)
	margin.add_child(vbox)
	panel.add_child(margin)
	backdrop.add_child(panel)

	return backdrop


## Build one row for the card list: "Name — Type (Cost) [+ Hand?]"
##
## When DevMode is active, each row gains a "+ Hand" button on the right
## that spawns a copy of that card directly into the player's hand —
## a testing affordance so you don't have to repeatedly shuffle and draw
## to try out a specific card.
func _build_card_row(data: CardData) -> HBoxContainer:
	var row := HBoxContainer.new()

	# Card name
	var name_label := Label.new()
	name_label.text = data.card_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	# Card type
	var type_label := Label.new()
	type_label.text = CardTypes.CardType.keys()[data.card_type].capitalize()
	type_label.add_theme_font_size_override("font_size", 14)
	type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	type_label.custom_minimum_size.x = 100.0
	row.add_child(type_label)

	# Cost
	var cost_label := Label.new()
	cost_label.text = str(data.cost_value)
	cost_label.add_theme_font_size_override("font_size", 16)
	cost_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_label.custom_minimum_size.x = 30.0
	row.add_child(cost_label)

	# Dev-mode: "+ Hand" button materializes this card directly into the
	# player's hand (bypasses the normal draw flow). Only visible when
	# DevMode.enabled; keeps in sync via the changed signal.
	var add_btn := Button.new()
	add_btn.text = "+ Hand"
	add_btn.add_theme_font_size_override("font_size", 12)
	add_btn.custom_minimum_size = Vector2(70, 22)
	add_btn.visible = DevMode.enabled
	add_btn.pressed.connect(_on_dev_add_card_pressed.bind(data))
	# Hide/show as DevMode flips — use the button itself to lifetime-own
	# the connection so it disconnects automatically on queue_free().
	DevMode.changed.connect(func(enabled: bool) -> void:
		if is_instance_valid(add_btn):
			add_btn.visible = enabled
	)
	row.add_child(add_btn)

	return row


## Dev-tool handler for the "+ Hand" button. Looks up the Hand node and
## spawns the chosen card via its dev helper, then closes the viewer so
## the tester can immediately use the new card.
func _on_dev_add_card_pressed(data: CardData) -> void:
	var hand: Node2D = _find_hand_node()
	if hand == null:
		push_warning("Deck dev-add: could not locate Hand node in scene tree")
		return
	if hand.has_method("add_card_to_hand_from_dev"):
		hand.add_card_to_hand_from_dev(data)
	_close_viewer()


## Walk up the scene tree looking for a Hand node. Not ideal (breaks if
## the hand moves) but good enough for a dev-only feature. Once we have a
## DuelContext reference here we can replace this with ctx.hand directly.
func _find_hand_node() -> Node2D:
	var n: Node = get_tree().get_first_node_in_group("hand")
	if n is Node2D:
		return n
	# Fallback: scan by class name.
	var root: Node = get_tree().current_scene
	if root:
		return _find_hand_recursive(root)
	return null


func _find_hand_recursive(node: Node) -> Node2D:
	if node.get_script() and node.get_script().resource_path.ends_with("/hand.gd"):
		return node as Node2D
	for child: Node in node.get_children():
		var found: Node2D = _find_hand_recursive(child)
		if found:
			return found
	return null


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_close_viewer()


func _input(event: InputEvent) -> void:
	# ESC closes the viewer.
	if _viewer_open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_viewer()
		get_viewport().set_input_as_handled()


# =============================================================================
# Core Pile Operations
# =============================================================================

## Build the deck from an array of card IDs, querying CardDatabase for each.
func build(card_ids: Array[String]) -> void:
	draw_pile.clear()
	discard_pile.clear()
	for card_id: String in card_ids:
		var data: CardData = CardDatabase.get_card(card_id)
		if data:
			draw_pile.append(data)
		else:
			push_warning("Deck: Card not found in database: %s" % card_id)
	_update_count_label()


## Shuffle the draw pile in place.
func shuffle() -> void:
	draw_pile.shuffle()
	deck_shuffled.emit()


## Draw one card from the top of the draw pile. Returns null if both piles empty.
func draw() -> CardData:
	if draw_pile.is_empty():
		reshuffle_discard()
	if draw_pile.is_empty():
		deck_empty.emit()
		return null
	var data: CardData = draw_pile.pop_back()
	card_drawn.emit(data)
	return data


## Draw multiple cards and return them as an array.
func draw_multiple(count: int) -> Array[CardData]:
	var drawn: Array[CardData] = []
	for i: int in range(count):
		var data: CardData = draw()
		if data == null:
			break
		drawn.append(data)
	return drawn


## Add a card to the discard pile.
func add_to_discard(data: CardData) -> void:
	discard_pile.append(data)
	_update_count_label()


## Move all cards from the discard pile into the draw pile and shuffle.
func reshuffle_discard() -> void:
	if discard_pile.is_empty():
		return
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	shuffle()


# =============================================================================
# Advanced Pile Operations
# =============================================================================

## Look at the top N cards without removing them (scry / discover).
func peek(count: int) -> Array[CardData]:
	var result: Array[CardData] = []
	var peek_count: int = mini(count, draw_pile.size())
	for i: int in range(peek_count):
		result.append(draw_pile[draw_pile.size() - 1 - i])
	return result


## Search the draw pile for cards matching a filter callable.
## The callable receives a CardData and returns bool.
## Does NOT remove the cards — use remove_from_draw() after the player picks.
func search(filter: Callable) -> Array[CardData]:
	var result: Array[CardData] = []
	for data: CardData in draw_pile:
		if filter.call(data):
			result.append(data)
	return result


## Remove a specific card from the draw pile (tutor picked it). Returns true if found.
func remove_from_draw(data: CardData) -> bool:
	var idx: int = draw_pile.find(data)
	if idx < 0:
		return false
	draw_pile.remove_at(idx)
	_update_count_label()
	return true


## Place a card on top of the draw pile (next card drawn).
func insert_at_top(data: CardData) -> void:
	draw_pile.append(data)
	_update_count_label()


## Place a card at the bottom of the draw pile (drawn last).
func insert_at_bottom(data: CardData) -> void:
	draw_pile.insert(0, data)
	_update_count_label()


## Insert a card at a random position in the draw pile.
func insert_at_random(data: CardData) -> void:
	if draw_pile.is_empty():
		draw_pile.append(data)
	else:
		var idx: int = randi_range(0, draw_pile.size())
		draw_pile.insert(idx, data)
	_update_count_label()


# =============================================================================
# Queries
# =============================================================================

## Return how many cards remain in the draw pile.
func remaining() -> int:
	return draw_pile.size()


## Return the total card count across both piles.
func total() -> int:
	return draw_pile.size() + discard_pile.size()


## Return how many cards are in the discard pile.
func discard_count() -> int:
	return discard_pile.size()
