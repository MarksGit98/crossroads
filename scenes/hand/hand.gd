extends Node2D

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


const COLLISION_MASK_CARD: int = 1
const IDLE_CARD_Z_INDEX: int = 1
const HOVERED_CARD_Z_INDEX: int = 10
const DRAGGED_CARD_Z_INDEX: int = 20
const DRAG_OFFSET_LERP_SPEED: float = 0.0025
const DRAG_FOLLOW_SPEED: float = 0.05
const SHAKE_INTENSITY: float = 9.0
const SHAKE_DURATION: float = 0.06

var VIEWPORT_SIZE_Y: float = get_viewport_rect().size.y
var VIEWPORT_SIZE_X: float = get_viewport_rect().size.x
var CARD_HEIGHT: float;

## How far (in local Y) a hovered card lifts above its resting arc position.
## Derived at runtime from the card's collision shape so it scales with card size.
var HOVER_LIFT = VIEWPORT_SIZE_Y - CARD_HEIGHT
# ============================================================================
# State
# =============================================================================

var current_hovered_card: Node2D = null
var hovered_index: int = -1
var card_being_dragged: Node2D = null
var drag_offset: Vector2
var screen_size: Vector2




func _ready() -> void:
	screen_size = get_viewport_rect().size
	# Anchor the hand at the bottom-center of the screen.
	# All card positions calculated by arrange_hand() are relative to this point.
	position = Vector2(screen_size.x / 2.0, screen_size.y - 150.0)
	_compute_card_size()
	arrange_hand()


## Calculates hover lift from the card's collision height.
##
## We lift by roughly half the card's height. This is enough to reveal the full
## card above the hand area, but NOT so much that the mouse leaves the collision
## shape (which would cause hover flicker). The mouse stays in the bottom half
## of the card after the lift.
func _compute_card_size() -> void:
	if get_child_count() == 0:
		return
	var sample_card: Node2D = get_child(0)
	# Read the visual height from the sprite texture rather than the collision
	# shape. This stays correct regardless of what collision shape type is used.
	var sprite: Sprite2D = sample_card.card_image
	if sprite and sprite.texture:
		CARD_HEIGHT = sprite.texture.get_height() * sprite.scale.y
	


func _process(_delta: float) -> void:
	RenderingServer.global_shader_parameter_set("mouse_screen_pos", get_global_mouse_position())
	if card_being_dragged:
		apply_drag_follow()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var card: Node2D = raycast_check_for_card()
			if card:
				start_drag(card)
		else:
			if card_being_dragged:
				finish_drag()


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
## When a card is hovered:
##   - It rises HOVER_LIFT pixels above its arc position
##   - Its rotation straightens to 0 (faces the player)
##   - It scales up to HOVERED_CARD_SCALE
##   - Neighboring cards are pushed apart along the arc by adding angular
##     offset: immediate neighbors get NEIGHBOR_PUSH_ANGLE degrees of push,
##     cards 2 away get half that, etc. This creates a smooth "parting" effect
##     that follows the curve naturally.
func arrange_hand() -> void:
	var cards: Array[Node] = get_children()
	var count: int = cards.size()
	if count == 0:
		return

	# Total fan angle scales with card count but caps at MAX_FAN_ANGLE.
	# 1 card = 0 deg (centered), 5 cards = 20 deg, 9 cards = 40 deg.
	var total_angle_deg: float = minf(ANGLE_PER_CARD * float(count - 1), MAX_FAN_ANGLE)
	var total_angle_rad: float = deg_to_rad(total_angle_deg)

	for i in count:
		var card: Node2D = cards[i] as Node2D

		# The dragged card is controlled by the drag system, skip it.
		if card == card_being_dragged:
			continue

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

		# -- Hovered card: lift out of the hand --
		if i == hovered_index:
			# Lift relative to the card's arc position. hover_lift is derived
			# from the card's collision height so it scales with card size.
			card_pos.y = VIEWPORT_SIZE_Y
			
			# Straighten so the player can read it.
			card_rot = 0.0
			target_scale = HOVERED_CARD_SCALE
			target_z = HOVERED_CARD_Z_INDEX

		card.z_index = target_z
		# Tween to the target transform. A new tween on the same property
		# automatically supersedes any in-progress tween in Godot 4.
		var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.set_parallel(true)
		print(card_pos)
		tween.tween_property(card, "position", card_pos, TWEEN_DURATION)
		tween.tween_property(card, "rotation", card_rot, TWEEN_DURATION)
		tween.tween_property(card, "scale", target_scale, TWEEN_DURATION)


# =============================================================================
# Drag System
# =============================================================================

func apply_drag_follow() -> void:
	# Shrink the grab offset toward zero so the card drifts to the cursor over time.
	drag_offset = drag_offset.lerp(Vector2.ZERO, DRAG_OFFSET_LERP_SPEED)
	var target: Vector2 = get_global_mouse_position() + drag_offset
	# Clamp to viewport so the card can't be dragged offscreen.
	target.x = clampf(target.x, 0.0, screen_size.x)
	target.y = clampf(target.y, 0.0, screen_size.y)
	# Use global_position since Hand is offset from the world origin.
	card_being_dragged.global_position = card_being_dragged.global_position.lerp(target, DRAG_FOLLOW_SPEED)


func start_drag(card: Node2D) -> void:
	card_being_dragged = card
	# Store the initial offset between card and cursor so the grab doesn't snap.
	drag_offset = card.global_position - get_global_mouse_position()
	card.scale = DEFAULT_CARD_SCALE
	card.z_index = DRAGGED_CARD_Z_INDEX
	card.set_hover_shader(true)
	# Clear hover state — the remaining cards rearrange to fill the gap.
	hovered_index = -1
	current_hovered_card = null
	arrange_hand()


func finish_drag() -> void:
	card_being_dragged.set_hover_shader(false)
	card_being_dragged = null
	# Check if the cursor landed on another card after releasing.
	var hovered: Node2D = raycast_check_for_card()
	if hovered:
		current_hovered_card = hovered
		hovered_index = hovered.get_index()
	arrange_hand()


# =============================================================================
# Card Interaction
# =============================================================================

func raycast_check_for_card() -> Node2D:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var parameters := PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD
	var result: Array[Dictionary] = space_state.intersect_point(parameters)
	if result.size() > 0:
		return get_card_with_highest_z_index(result)
	return null


func get_card_with_highest_z_index(cards: Array[Dictionary]) -> Node2D:
	var highest_z_card: Node2D = cards[0].collider.get_parent()
	var highest_z_index: int = highest_z_card.z_index
	for i in range(1, cards.size()):
		var current_card: Node2D = cards[i].collider.get_parent()
		if current_card.z_index > highest_z_index:
			highest_z_card = current_card
			highest_z_index = current_card.z_index
	return highest_z_card


func connect_card_signals(card: Node2D) -> void:
	card.card_event.connect(_on_card_event)


func _on_card_event(card: Node2D, event: CardTypes.CardEvent) -> void:
	match event:
		CardTypes.CardEvent.HOVER_ON:
			if card_being_dragged:
				return
			current_hovered_card = card
			hovered_index = card.get_index()
			shake_card(card)
			arrange_hand()
		CardTypes.CardEvent.HOVER_OFF:
			if card_being_dragged:
				return
			# Check if the cursor moved directly onto another card.
			var new_hovered: Node2D = raycast_check_for_card()
			if new_hovered:
				current_hovered_card = new_hovered
				hovered_index = new_hovered.get_index()
			else:
				current_hovered_card = null
				hovered_index = -1
			arrange_hand()


func shake_card(card: Node2D) -> void:
	# Shake the sprite child instead of the card node to avoid conflicting
	# with arrange_hand()'s position tween on the card itself.
	var sprite: Node2D = card.card_image
	var origin: Vector2 = sprite.position
	var tween: Tween = sprite.create_tween()
	tween.tween_property(sprite, "position", origin + Vector2(SHAKE_INTENSITY, 0), SHAKE_DURATION)
	tween.tween_property(sprite, "position", origin + Vector2(-SHAKE_INTENSITY, 0), SHAKE_DURATION)
	tween.tween_property(sprite, "position", origin + Vector2(SHAKE_INTENSITY * 0.6, 0), SHAKE_DURATION)
	tween.tween_property(sprite, "position", origin + Vector2(-SHAKE_INTENSITY * 0.3, 0), SHAKE_DURATION * 0.7)
	tween.tween_property(sprite, "position", origin, SHAKE_DURATION * 0.7)


# =============================================================================
# Hand Operations
# =============================================================================

func draw_card() -> void:
	# TODO: Instantiate card from deck, add_child(), call arrange_hand()
	pass


func play_card(_card: Node2D) -> void:
	# TODO: Remove card from hand, trigger play logic, call arrange_hand()
	pass
