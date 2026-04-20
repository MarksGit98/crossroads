## Screen-space HUD display for a secondary card pile (discard, graveyard).
## Shows a texture icon with a live count label, clickable to open a viewer
## listing every card in the pile — same UX as the Deck display but
## parameterized by which pile it tracks.
##
## Each instance points at a pile via pile_kind and observes the shared
## Deck for signal-driven count updates. The icon texture is exported so
## each instance can supply its own art (deck_icon / discard_pile / graveyard).
class_name CardPileDisplay
extends Node2D


# =============================================================================
# Config
# =============================================================================

enum PileKind { DISCARD, GRAVEYARD }

@export var pile_kind: PileKind = PileKind.DISCARD

## Title shown at the top of the viewer overlay ("Discard" / "Graveyard").
@export var display_title: String = "Discard"

## Icon texture — assigned at _ready to the internal Sprite2D. Each pile
## instance in the duel scene supplies its own image.
@export var icon_texture: Texture2D

## Sprite scale. Matches the Deck's existing 0.1 so all three pile
## displays are sized consistently.
@export var icon_scale: float = 0.1


# =============================================================================
# Layout
# =============================================================================

const COUNT_FONT_SIZE: int = 40
## Click detection radius, in pixels relative to the scaled sprite. Adjusted
## per scene instance by the parent if sprite proportions differ.
const CLICK_RADIUS: float = 44.0


# =============================================================================
# Internal nodes
# =============================================================================

var _sprite: Sprite2D = null
var _count_label: Label = null
var _click_area: Area2D = null

var _viewer: Control = null
var _viewer_open: bool = false

## Deck we're observing — injected via set_deck().
var _deck: Deck = null


# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_build_sprite()
	_build_count_label()
	_build_click_area()


func _build_sprite() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = icon_texture
	_sprite.scale = Vector2(icon_scale, icon_scale)
	add_child(_sprite)


func _build_count_label() -> void:
	_count_label = Label.new()
	_count_label.text = "0"
	_count_label.add_theme_font_size_override("font_size", COUNT_FONT_SIZE)
	_count_label.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	_count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_count_label.add_theme_constant_override("outline_size", 6)
	# Center the label roughly on the sprite — match DeckCountLabel offsets.
	_count_label.offset_left = -30.0
	_count_label.offset_top = -39.0
	_count_label.offset_right = 32.0
	_count_label.offset_bottom = 16.0
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_count_label)


func _build_click_area() -> void:
	_click_area = Area2D.new()
	var cs: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = CLICK_RADIUS
	cs.shape = shape
	cs.position = Vector2(2, -2)  # match Deck's click offset
	_click_area.add_child(cs)
	add_child(_click_area)
	_click_area.input_event.connect(_on_click_area_input)


## Attach to the deck whose piles we display. Connects to the relevant
## change signal so the count updates live as the pile mutates.
func set_deck(deck: Deck) -> void:
	if _deck == deck:
		return
	_deck = deck
	if _deck == null:
		return
	match pile_kind:
		PileKind.DISCARD:
			if not _deck.discard_changed.is_connected(_refresh):
				_deck.discard_changed.connect(_refresh)
		PileKind.GRAVEYARD:
			if not _deck.graveyard_changed.is_connected(_refresh):
				_deck.graveyard_changed.connect(_refresh)
	_refresh()


# =============================================================================
# Rendering
# =============================================================================

func _refresh() -> void:
	if _count_label == null:
		return
	_count_label.text = str(_current_pile().size())


func _current_pile() -> Array[CardData]:
	if _deck == null:
		return []
	match pile_kind:
		PileKind.DISCARD:
			return _deck.discard_pile
		PileKind.GRAVEYARD:
			return _deck.graveyard_pile
	return []


# =============================================================================
# Click + viewer
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
	var parent: Node = get_parent()
	if parent:
		parent.add_child(_viewer)
	_viewer_open = true


func _close_viewer() -> void:
	if _viewer:
		_viewer.queue_free()
		_viewer = null
	_viewer_open = false


## Build a modal card-list viewer. Mirrors Deck._build_viewer in shape but
## reads from this pile — and reverses display order so the most-recently-
## added card is at the top (players care most about the latest corpse /
## most recently played card).
func _build_viewer() -> Control:
	var screen_size: Vector2 = get_viewport_rect().size

	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.size = screen_size
	backdrop.gui_input.connect(_on_backdrop_input)

	var panel: PanelContainer = PanelContainer.new()
	var panel_width: float = 500.0
	var panel_height: float = 600.0
	panel.position = Vector2(
		(screen_size.x - panel_width) * 0.5,
		(screen_size.y - panel_height) * 0.5,
	)
	panel.size = Vector2(panel_width, panel_height)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)

	var vbox: VBoxContainer = VBoxContainer.new()

	var title: Label = Label.new()
	title.text = "%s  (%d cards)" % [display_title, _current_pile().size()]
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var reversed_pile: Array[CardData] = _current_pile().duplicate()
	reversed_pile.reverse()
	for card_data: CardData in reversed_pile:
		list.add_child(_build_card_row(card_data))

	scroll.add_child(list)
	vbox.add_child(scroll)
	margin.add_child(vbox)
	panel.add_child(margin)
	backdrop.add_child(panel)
	return backdrop


func _build_card_row(data: CardData) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()

	var name_label: Label = Label.new()
	name_label.text = data.card_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var type_label: Label = Label.new()
	type_label.text = CardTypes.CardType.keys()[data.card_type].capitalize()
	type_label.add_theme_font_size_override("font_size", 14)
	type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	type_label.custom_minimum_size.x = 100.0
	row.add_child(type_label)

	var cost_label: Label = Label.new()
	cost_label.text = str(data.cost_value)
	cost_label.add_theme_font_size_override("font_size", 16)
	cost_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_label.custom_minimum_size.x = 30.0
	row.add_child(cost_label)

	return row


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_close_viewer()


func _input(event: InputEvent) -> void:
	if _viewer_open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_viewer()
		get_viewport().set_input_as_handled()
