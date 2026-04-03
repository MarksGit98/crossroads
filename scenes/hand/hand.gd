extends Node2D

# =============================================================================
# Signals
# =============================================================================

signal card_played(card_data: CardData)
signal card_discarded(card_data: CardData)

# =============================================================================
# Fan Layout Constants
# =============================================================================
# Cards are arranged along an invisible circle (Slay the Spire / Hearthstone
# style). The circle's center sits far below the Hand node so the visible arc
# is gentle. Adjusting ARC_RADIUS controls curvature; ANGLE_PER_CARD controls
# how spread-out the fan is.

## Radius of the arc circle. Larger = gentler curve. 1600 gives a subtle
## Slay the Spire feel. Try 800-1000 for a tighter fan.
const ARC_RADIUS: float = 1600.0

## Degrees of spread added per card. 5 cards = 20 deg, 9 cards = 40 deg.
const ANGLE_PER_CARD: float = 5.0

## Hard cap on total fan angle regardless of card count.
const MAX_FAN_ANGLE: float = 40.0

## Small gap (in pixels) between the top of a hovered card and the top of the viewport.
const HOVER_MARGIN: float = 16.0

## Scale multiplier for the hovered card.
const HOVERED_CARD_SCALE: Vector2 = Vector2(1.15, 1.15)

## Default resting scale for cards.
const DEFAULT_CARD_SCALE: Vector2 = Vector2(1.0, 1.0)

## Degrees that immediate neighbors are pushed apart on hover. Cards further
## away receive proportionally less push (divided by distance from hovered card).
const NEIGHBOR_PUSH_ANGLE: float = 4.0

## How long position/rotation/scale tweens take (seconds).
const TWEEN_DURATION: float = 0.2

# =============================================================================
# Interaction Constants
# =============================================================================

const IDLE_CARD_Z_INDEX: int = 1
const HOVERED_CARD_Z_INDEX: int = 10
const SELECTED_CARD_Z_INDEX: int = 20
const DRAG_OFFSET_LERP_SPEED: float = 0.0025
const DRAG_FOLLOW_SPEED: float = 0.05
const SHAKE_INTENSITY: float = 9.0
const SHAKE_DURATION: float = 0.1

## Y coordinate (screen space) above which releasing a card attempts to play it.
## Computed in _ready(): half a card height above the hovered card's position.
var play_threshold_y: float

## Color for highlighting valid target hexes during targeting mode.
const TARGET_HIGHLIGHT_COLOR: Color = Color(0.2, 0.9, 0.3, 0.3)

# =============================================================================
# Hand Mode
# =============================================================================

## NORMAL: cards can be hovered, dragged, etc.
## TARGETING: a card has been committed, waiting for the player to pick a hex.
enum HandMode { NORMAL, TARGETING }

# =============================================================================
# Computed at runtime
# =============================================================================

var CARD_HEIGHT: float
var CARD_WIDTH: float

## How far (in local Y) a hovered card lifts above its resting arc position.
## Derived at runtime from the card's collision shape so it scales with card size.
var hover_lift: float

# =============================================================================
# State
# =============================================================================

## Offset between card position and cursor at drag start — lerps toward zero
## so the card drifts to center on the cursor over time.
var drag_offset: Vector2
var screen_size: Vector2

## Current hand interaction mode.
var _mode: HandMode = HandMode.NORMAL

## The card currently in targeting mode (waiting for hex selection).
var _pending_card: Card = null

## Valid target hexes for the pending card (cached when entering targeting mode).
var _valid_targets: Array[Vector2i] = []

## For multi-hex targeting (traps): hexes selected so far.
var _selected_targets: Array[Vector2i] = []

## How many hexes the pending card needs (1 for most, >1 for multi-hex traps).
var _required_target_count: int = 1

## How long the preview fade-out takes on confirm (seconds).
const PREVIEW_FADE_DURATION: float = 0.35

## Reference to the Deck node (Hand is inside a CanvasLayer, Deck is a sibling of that layer).
@onready var deck: Deck = $"../../DeckLayer/Deck"

## Reference to the Player node for mana checks.
@onready var player: Player = $"../../Player"

## Reference to the HexGrid for targeting. Wired by DuelTestScene.
## Uses a setter to keep _play_context in sync when assigned.
var board: HexGrid = null:
	set(value):
		board = value
		if _play_context:
			_play_context["board"] = value

## Persistent play context — built once when the board ref is set, reused every play.
## Only "target_hexes" and "target_units" are updated per play.
var _play_context: Dictionary = {}

## Preloaded card scenes by type for dynamic instantiation.
var _card_scenes: Dictionary = {
	CardTypes.CardType.CREATURE: preload("res://scenes/card/creature_card.tscn"),
	CardTypes.CardType.SPELL: preload("res://scenes/card/spell_card.tscn"),
	CardTypes.CardType.TRAP: preload("res://scenes/card/trap_card.tscn"),
	CardTypes.CardType.EQUIPMENT: preload("res://scenes/card/equip_card.tscn"),
	CardTypes.CardType.TERRAIN_MOD: preload("res://scenes/card/card.tscn"),
}


func _ready() -> void:
	screen_size = get_viewport_rect().size
	# Anchor the hand at the bottom-center of the screen.
	# All card positions calculated by arrange_hand() are relative to this point.
	position = Vector2(screen_size.x / 2.0, screen_size.y - 120.0)
	# Compute card size from a temporary instance since hand starts empty.
	_compute_card_size()
	# Compute how much we need to lift each card in the arc so that it is fully
	# visible on hover in the hand. Divide CARD_HEIGHT by ~2 as the card origin
	# point is in the center of the card.
	hover_lift = -position.y + (screen_size.y - CARD_HEIGHT / 1.9)
	_init_play_context()
	# Play threshold: half a card height above the hovered card's screen-space center.
	# Hovered card screen Y = hand position.y + hover_lift (local offset).
	# Releasing a card above this line triggers a play attempt.
	var hovered_screen_y: float = position.y + hover_lift
	play_threshold_y = hovered_screen_y - CARD_HEIGHT * 0.5
	# Wait for the deck to signal it's ready before drawing the initial hand.
	# This avoids timing issues where Hand._ready() fires before Deck._ready().
	if deck.draw_pile.size() > 0:
		draw_cards(6)
	else:
		deck.deck_ready.connect(_on_deck_ready, CONNECT_ONE_SHOT)


## Calculates card visual height from the card scene's sprite.
## Reads the texture and scale directly from the scene resource without
## instantiating into the tree (avoids triggering _ready signal connections).
## Base card scene — used for size computation (inherited scenes don't
## expose base properties in their SceneState).
var _base_card_scene: PackedScene = preload("res://scenes/card/card.tscn")

func _compute_card_size() -> void:
	var card_scene_state: SceneState = _base_card_scene.get_state()
	# Find the CardImage sprite node and read its texture + scale.
	for i: int in range(card_scene_state.get_node_count()):
		if card_scene_state.get_node_name(i) == &"CardImage":
			var tex: Texture2D = null
			var sprite_scale := Vector2(1.0, 1.0)
			for p: int in range(card_scene_state.get_node_property_count(i)):
				var prop_name: StringName = card_scene_state.get_node_property_name(i, p)
				if prop_name == &"texture":
					tex = card_scene_state.get_node_property_value(i, p)
				elif prop_name == &"scale":
					sprite_scale = card_scene_state.get_node_property_value(i, p)
			if tex:
				CARD_HEIGHT = tex.get_height() * sprite_scale.y
				CARD_WIDTH = tex.get_width() * sprite_scale.x
			break


func _process(_delta: float) -> void:
	RenderingServer.global_shader_parameter_set("mouse_screen_pos", get_viewport().get_mouse_position())
	if _mode == HandMode.TARGETING:
		return  # No hover/drag while targeting.
	var selected: Card = _get_selected_card()
	if selected:
		_apply_drag_follow(selected)
	else:
		_update_hover()


# =============================================================================
# Hover Detection (poll-based)
# =============================================================================

## Poll-based hover detection. Called every frame from _process().
## Uses bounding-rect hit testing instead of physics raycasting because
## get_global_mouse_position() returns camera-warped coordinates inside
## a CanvasLayer, making physics queries miss.
func _update_hover() -> void:
	var card_under_mouse: Card = _find_card_at_mouse()
	var current_hovered: Card = _get_hovered_card()

	if card_under_mouse == current_hovered:
		return

	# Unhover the old card
	if current_hovered:
		current_hovered.set_state(CardTypes.CardState.IDLE)

	# Hover the new card (only if it's interactable)
	if card_under_mouse and card_under_mouse.state == CardTypes.CardState.IDLE:
		card_under_mouse.set_state(CardTypes.CardState.HOVERED)
		shake_card(card_under_mouse)

	arrange_hand()


func _input(event: InputEvent) -> void:
	if _mode == HandMode.TARGETING:
		_handle_targeting_input(event)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hovered: Card = _get_hovered_card()
			if hovered:
				_start_drag(hovered)
				get_viewport().set_input_as_handled()
		else:
			var selected: Card = _get_selected_card()
			if selected:
				_finish_drag(selected)
				get_viewport().set_input_as_handled()


# =============================================================================
# Fan Layout
# =============================================================================

## Positions all cards along a circular arc, creating a Slay the Spire-style fan.
##
## -- How the arc math works --
##
## An invisible circle of radius R has its center at (0, R) relative to the
## Hand node (i.e. directly below it). Cards sit on the top portion of this
## circle. The topmost point of the circle coincides with the Hand's origin,
## so the center card (angle = 0) appears right at the Hand position.
##
##   Circle center:  C = (0, ARC_RADIUS)
##   Card at angle a from the top of the circle:
##     x = R * sin(a)           -- horizontal: positive angle = right
##     y = R * (1 - cos(a))     -- vertical: always >= 0, edges dip below center
##     rotation = a             -- tangent to the circle at this point
##
## At angle 0 (center card):  x=0, y=0, rotation=0  (straight, at anchor)
## At angle +15deg (right):   x=+414, y=+27          (shifted right, dipped slightly)
## At angle -15deg (left):    x=-414, y=+27           (mirrored)
##
## The dip is gentle because ARC_RADIUS is large relative to the fan angle.
##
## -- Hover behavior --
##
## When a card is HOVERED:
##   - It rises HOVER_LIFT pixels above its arc position
##   - Its rotation straightens to 0 (faces the player)
##   - It scales up to HOVERED_CARD_SCALE
##   - Neighboring cards are pushed apart along the arc by adding angular
##     offset: immediate neighbors get NEIGHBOR_PUSH_ANGLE degrees of push,
##     cards 2 away get half that, etc. This creates a smooth "parting" effect
##     that follows the curve naturally.

## Returns ALL Card children regardless of state. Used for queries.
func _get_all_cards() -> Array[Card]:
	var result: Array[Card] = []
	for child: Node in get_children():
		if child is Card:
			result.append(child as Card)
	return result


## Returns only cards that participate in the hand fan layout.
## Excludes PLAYED (queued for deletion), SELECTED (being dragged),
## and PREVIEWING (shown at screen center during targeting).
func _get_card_children() -> Array[Card]:
	var result: Array[Card] = []
	for child: Node in get_children():
		if child is Card:
			var card_state: CardTypes.CardState = (child as Card).state
			if card_state != CardTypes.CardState.PLAYED \
					and card_state != CardTypes.CardState.SELECTED \
					and card_state != CardTypes.CardState.PREVIEWING:
				result.append(child as Card)
	return result


func arrange_hand() -> void:
	var cards: Array[Card] = _get_card_children()
	var count: int = cards.size()
	if count == 0:
		return

	# Find the hovered card index (if any) for neighbor push calculation.
	var hovered_index: int = -1
	for idx: int in count:
		if cards[idx].state == CardTypes.CardState.HOVERED:
			hovered_index = idx
			break

	# Total fan angle scales with card count but caps at MAX_FAN_ANGLE.
	# 1 card = 0 deg (centered), 5 cards = 20 deg, 9 cards = 40 deg.
	var total_angle_deg: float = minf(ANGLE_PER_CARD * float(count - 1), MAX_FAN_ANGLE)
	var total_angle_rad: float = deg_to_rad(total_angle_deg)

	for i in count:
		var card: Card = cards[i]

		# -- Card's base angle on the arc --
		# t normalizes the card's index: 0.0 = leftmost, 1.0 = rightmost.
		# For a single card, t = 0.5 so it sits dead center (angle = 0).
		var t: float = 0.5 if count == 1 else float(i) / float(count - 1)

		# Interpolate from -half_angle (left edge) to +half_angle (right edge).
		# At t=0.5 the angle is 0 (top of circle = center of fan).
		var base_angle: float = -total_angle_rad / 2.0 + t * total_angle_rad

		# -- Neighbor push on hover --
		# When a card is hovered, push its neighbors outward along the arc.
		# Push strength = NEIGHBOR_PUSH_ANGLE / distance_from_hovered.
		# sign(distance) ensures left neighbors go left, right go right.
		var angle: float = base_angle
		if hovered_index >= 0 and i != hovered_index:
			var distance: int = i - hovered_index
			var push_rad: float = deg_to_rad(NEIGHBOR_PUSH_ANGLE) / absf(distance)
			angle += signf(distance) * push_rad

		# -- Convert angle to position on the arc --
		# x = R * sin(a):        horizontal offset from center
		# y = R * (1 - cos(a)):  vertical dip (positive = downward in screen coords)
		var card_pos := Vector2(
			ARC_RADIUS * sin(angle),
			ARC_RADIUS * (1.0 - cos(angle))
		)

		# Card rotation matches the arc tangent so cards "lean" naturally.
		var card_rot: float = angle
		var target_scale: Vector2 = DEFAULT_CARD_SCALE

		# Left-to-right draw order so right cards overlap left ones.
		var target_z: int = IDLE_CARD_Z_INDEX + i

		# -- State-driven overrides --
		match card.state:
			CardTypes.CardState.HOVERED:
				card_pos.y = hover_lift
				card_rot = 0.0
				target_scale = HOVERED_CARD_SCALE
				target_z = HOVERED_CARD_Z_INDEX
			CardTypes.CardState.DISABLED:
				# Disabled cards stay in arc position but are visually dimmed
				# (handled by card._apply_state_visuals).
				pass

		card.z_index = target_z
		# Tween to the target transform. A new tween on the same property
		# automatically supersedes any in-progress tween in Godot 4.
		var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.set_parallel(true)
		tween.tween_property(card, "position", card_pos, TWEEN_DURATION)
		tween.tween_property(card, "rotation", card_rot, TWEEN_DURATION)
		tween.tween_property(card, "scale", target_scale, TWEEN_DURATION)


# =============================================================================
# Drag System
# =============================================================================

func _apply_drag_follow(card: Card) -> void:
	# Shrink the grab offset toward zero so the card drifts to the cursor over time.
	drag_offset = drag_offset.lerp(Vector2.ZERO, DRAG_OFFSET_LERP_SPEED)
	var target: Vector2 = get_viewport().get_mouse_position() + drag_offset
	# Clamp to viewport so the card can't be dragged offscreen.
	target.x = clampf(target.x, 0.0, screen_size.x)
	target.y = clampf(target.y, 0.0, screen_size.y)
	# Use global_position since Hand is offset from the world origin.
	card.global_position = card.global_position.lerp(target, DRAG_FOLLOW_SPEED)


func _start_drag(card: Card) -> void:
	card.set_state(CardTypes.CardState.SELECTED)
	# Store the initial offset between card and cursor so the grab doesn't snap.
	drag_offset = card.global_position - get_viewport().get_mouse_position()
	card.scale = DEFAULT_CARD_SCALE
	card.z_index = SELECTED_CARD_Z_INDEX
	arrange_hand()


func _finish_drag(card: Card) -> void:
	# Check the card's actual screen position — more accurate than raw mouse
	# because the card lerps toward the cursor and may lag slightly behind.
	if card.global_position.y < play_threshold_y:
		_try_play_card(card)
	else:
		# Return to hand — released below the play threshold.
		card.set_state(CardTypes.CardState.IDLE)
		var hovered: Card = _find_card_at_mouse()
		if hovered and hovered.state == CardTypes.CardState.IDLE:
			hovered.set_state(CardTypes.CardState.HOVERED)
		arrange_hand()


# =============================================================================
# Play Card System
# =============================================================================

## Attempt to play a card after it's been dragged above the play threshold.
func _try_play_card(card: Card) -> void:
	_set_play_targets()

	# Pre-condition 1: Can the player afford this card?
	if not card.can_play(_play_context):
		card.set_state(CardTypes.CardState.IDLE)
		arrange_hand()
		shake_card(card, 10)
		return

	if card.needs_targeting():
		# Pre-condition 2: Are there any valid target hexes?
		if board == null:
			push_warning("Hand: cannot play targeting card — no board reference.")
			card.set_state(CardTypes.CardState.IDLE)
			arrange_hand()
			shake_card(card, 10)
			return

		var targets: Array[Vector2i] = card.get_valid_targets(board)
		if targets.is_empty():
			# No valid hexes — reject with shake, don't enter targeting.
			card.set_state(CardTypes.CardState.IDLE)
			arrange_hand()
			shake_card(card, 10)
			return

		_enter_targeting(card, targets)
	else:
		# No targeting needed — play immediately.
		card.play(_play_context)
		_finalize_play(card)


## Build the persistent play context once. Called from _ready() and when board is set.
## Static refs (player, board) live for the entire duel; per-play fields are stamped
## via _set_play_targets() before each play call.
func _init_play_context() -> void:
	_play_context = {
		"player": player,
		"board": board,
		"target_hexes": [],
		"target_units": [],
	}


## Stamp per-play target data onto the cached context. Cheap — no allocation.
func _set_play_targets(target_hexes: Array[Vector2i] = [], target_units: Array = []) -> void:
	_play_context["target_hexes"] = target_hexes
	_play_context["target_units"] = target_units


## Finalize playing a card: transition state, discard data, free the node.
func _finalize_play(card: Card) -> void:
	if card.state != CardTypes.CardState.PLAYED:
		card.set_state(CardTypes.CardState.PLAYED)
	if card.card_data:
		deck.add_to_discard(card.card_data)
		card_played.emit(card.card_data)
	card.queue_free()
	arrange_hand()


# =============================================================================
# Targeting Mode
# =============================================================================

## Enter targeting mode: show card at screen center in PREVIEWING state,
## highlight valid hexes, wait for player to click a hex.
## Targets are pre-computed by _try_play_card().
func _enter_targeting(card: Card, targets: Array[Vector2i]) -> void:
	_mode = HandMode.TARGETING
	_pending_card = card
	_selected_targets.clear()
	_valid_targets = targets

	# Determine how many targets are needed (multi-hex traps).
	if card is TrapCard:
		_required_target_count = (card as TrapCard).target_hex_count()
	else:
		_required_target_count = 1

	# Highlight valid hexes on the board.
	_highlight_valid_targets()

	# Move the card to screen center in PREVIEWING state.
	# This excludes it from the fan layout so remaining cards re-fan.
	# The card must go SELECTED → IDLE first (valid transition), then IDLE → PREVIEWING.
	card.set_state(CardTypes.CardState.IDLE)
	_show_card_preview(card)
	arrange_hand()

	# Listen for hex clicks from the board.
	if not board.hex_clicked.is_connected(_on_target_hex_clicked):
		board.hex_clicked.connect(_on_target_hex_clicked)


## Cancel targeting mode — return card to hand, clear highlights.
func _cancel_targeting() -> void:
	if board:
		board.clear_highlights()
		if board.hex_clicked.is_connected(_on_target_hex_clicked):
			board.hex_clicked.disconnect(_on_target_hex_clicked)

	if _pending_card:
		# Return card from PREVIEWING → IDLE (valid transition).
		_hide_card_preview(_pending_card)

	_mode = HandMode.NORMAL
	_pending_card = null
	_valid_targets.clear()
	_selected_targets.clear()
	_required_target_count = 1
	arrange_hand()


## Highlight valid target hexes on the board.
func _highlight_valid_targets() -> void:
	var highlights: Dictionary = {}
	for coord: Vector2i in _valid_targets:
		highlights[coord] = TARGET_HIGHLIGHT_COLOR
	# Also highlight already-selected hexes in a brighter color.
	for coord: Vector2i in _selected_targets:
		highlights[coord] = Color(0.1, 1.0, 0.4, 0.5)
	board.set_highlights(highlights)


## Move the card to screen center in PREVIEWING state.
## The card stays as a child of Hand but is positioned via global_position
## and excluded from the fan layout by _get_card_children().
func _show_card_preview(card: Card) -> void:
	card.set_state(CardTypes.CardState.PREVIEWING)
	card.z_index = 100
	card.scale = DEFAULT_CARD_SCALE
	card.rotation = 0.0
	# Position at screen center (upper-center so hex grid is visible below).
	card.global_position = Vector2(screen_size.x * 0.5, screen_size.y * 0.35)
	card.visible = true


## Return the previewing card back to hand (used on cancel).
func _hide_card_preview(card: Card) -> void:
	if card == null:
		return
	card.set_state(CardTypes.CardState.IDLE)
	card.z_index = IDLE_CARD_Z_INDEX


## Fade out the previewing card (used on confirm), then finalize.
func _fade_out_card_preview(card: Card) -> void:
	if card == null:
		return
	var tween: Tween = card.create_tween()
	tween.tween_property(card, "modulate:a", 0.0, PREVIEW_FADE_DURATION)
	# Don't free here — _finalize_play() handles queue_free.


## Handle input during targeting mode.
func _handle_targeting_input(event: InputEvent) -> void:
	# Right-click or ESC cancels targeting.
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_targeting()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			_cancel_targeting()
			get_viewport().set_input_as_handled()


## Called when the player clicks a hex while in targeting mode.
func _on_target_hex_clicked(coord: Vector2i) -> void:
	if _mode != HandMode.TARGETING or _pending_card == null:
		return

	# Ignore clicks on invalid hexes.
	if coord not in _valid_targets:
		return

	# Ignore duplicate selections for multi-hex targeting.
	if coord in _selected_targets:
		return

	_selected_targets.append(coord)

	# If we still need more targets (multi-hex trap), update highlights and wait.
	if _selected_targets.size() < _required_target_count:
		_highlight_valid_targets()
		return

	# All targets selected — play the card.
	_confirm_targeting()


## Confirm targeting: fade card preview, spend mana, spawn creature, clean up.
func _confirm_targeting() -> void:
	var card: Card = _pending_card
	var targets: Array[Vector2i] = _selected_targets.duplicate()

	# Fade out the card at screen center (cosmetic — doesn't block gameplay).
	_fade_out_card_preview(card)

	# Disconnect hex_clicked before playing to avoid re-entrancy.
	if board and board.hex_clicked.is_connected(_on_target_hex_clicked):
		board.hex_clicked.disconnect(_on_target_hex_clicked)
	if board:
		board.clear_highlights()

	# Reset mode before play() so any signals emitted during play see NORMAL mode.
	_mode = HandMode.NORMAL
	_pending_card = null
	_valid_targets.clear()
	_selected_targets.clear()
	_required_target_count = 1

	# Transition PREVIEWING → PLAYED, then stamp targets and execute.
	# Mana is spent inside card.play() -> super.play().
	card.set_state(CardTypes.CardState.PLAYED)
	_set_play_targets(targets)
	card.play(_play_context)
	_finalize_play(card)


# =============================================================================
# Card Queries
# =============================================================================

## Find the card under the mouse using bounding-rect hit testing.
## Cards live inside a CanvasLayer so global_position == screen position.
## We compare against get_viewport().get_mouse_position() which is also
## in screen space, avoiding the coordinate mismatch that breaks physics
## raycasting inside CanvasLayers.
func _find_card_at_mouse() -> Card:
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var best_card: Card = null
	var best_z: int = -1
	var half_w: float = CARD_WIDTH * 0.5
	var half_h: float = CARD_HEIGHT * 0.5
	for card: Card in _get_card_children():
		if card.state == CardTypes.CardState.DISABLED:
			continue
		# Scale the hit rect to match the card's current visual size.
		var sw: float = half_w * card.scale.x
		var sh: float = half_h * card.scale.y
		var center: Vector2 = card.global_position
		if mouse.x >= center.x - sw and mouse.x <= center.x + sw \
				and mouse.y >= center.y - sh and mouse.y <= center.y + sh:
			if card.z_index > best_z:
				best_card = card
				best_z = card.z_index
	return best_card


## Return the currently hovered card, or null.
func _get_hovered_card() -> Card:
	for card: Card in _get_all_cards():
		if card.state == CardTypes.CardState.HOVERED:
			return card
	return null


## Return the currently selected (dragged) card, or null.
func _get_selected_card() -> Card:
	for card: Card in _get_all_cards():
		if card.state == CardTypes.CardState.SELECTED:
			return card
	return null


## Find a card's index within the filtered card array (not the raw child index).
func _card_index(card: Card) -> int:
	var cards: Array[Card] = _get_card_children()
	return cards.find(card)


func connect_card_signals(card: Card) -> void:
	card.card_event.connect(_on_card_event)


func _on_card_event(_card: Card, _event: CardTypes.CardEvent) -> void:
	# Hover is handled by _update_hover() via per-frame bounding-rect check.
	# Area2D signals are unreliable when collision shapes move during tweens.
	pass


## Shake the card sprite. intensity_scale multiplies the shake distance only —
## timing stays the same so bigger shakes feel snappier, not sluggish.
func shake_card(card: Card, intensity_scale: float = 1.0) -> void:
	# Shake the sprite child instead of the card node to avoid conflicting
	# with arrange_hand()'s position tween on the card itself.
	var sprite: Sprite2D = card.card_image
	var origin: Vector2 = sprite.position
	var shake: float = SHAKE_INTENSITY * intensity_scale
	var tween: Tween = sprite.create_tween()
	tween.tween_property(sprite, "position", origin + Vector2(shake, 0), SHAKE_DURATION)
	tween.tween_property(sprite, "position", origin + Vector2(-shake, 0), SHAKE_DURATION)
	tween.tween_property(sprite, "position", origin + Vector2(shake * 0.6, 0), SHAKE_DURATION)
	tween.tween_property(sprite, "position", origin + Vector2(-shake * 0.3, 0), SHAKE_DURATION * 0.7)
	tween.tween_property(sprite, "position", origin, SHAKE_DURATION * 0.7)


# =============================================================================
# Hand Operations
# =============================================================================

## How many cards are currently in the hand.
func hand_size() -> int:
	return _get_card_children().size()


## Whether the hand is currently in targeting mode (waiting for hex selection).
func is_targeting() -> bool:
	return _mode == HandMode.TARGETING


## Called when the deck signals it's built and ready to draw from.
func _on_deck_ready() -> void:
	draw_cards(6)


## Draw multiple cards from the deck into the hand.
func draw_cards(count: int) -> void:
	for i: int in range(count):
		var data: CardData = deck.draw()
		if data == null:
			break
		var card: Card = _instance_card(data)
		add_child(card)
	arrange_hand()


## Instantiate the correct card scene for this card type and populate it.
func _instance_card(data: CardData) -> Card:
	var scene: PackedScene = _card_scenes.get(data.card_type, _card_scenes[CardTypes.CardType.CREATURE])
	var card: Card = scene.instantiate()
	# setup() must run after _ready() so the node is in the tree.
	# call_deferred ensures _ready() fires first.
	card.call_deferred("setup", data)
	return card


## Play a card — transition to PLAYED, emit signal, discard its data, remove node.
## Use _finalize_play() instead when going through the play card flow.
func play_card(card: Card) -> void:
	card.set_state(CardTypes.CardState.PLAYED)
	if card.card_data:
		deck.add_to_discard(card.card_data)
		card_played.emit(card.card_data)
	card.queue_free()
	arrange_hand()


## Discard a card from hand without playing it (forced discard, discard cost, etc.).
func discard_card(card: Card) -> void:
	if card.card_data:
		deck.add_to_discard(card.card_data)
		card_discarded.emit(card.card_data)
	card.queue_free()
	arrange_hand()


## Return a card from hand back into the draw pile and shuffle it in.
func return_to_deck(card: Card) -> void:
	if card.card_data:
		deck.insert_at_random(card.card_data)
	card.queue_free()
	arrange_hand()
