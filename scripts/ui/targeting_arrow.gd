## A Slay the Spire / Hearthstone-style curved targeting arrow drawn from a
## source (a creature, a card) to the player's current cursor target. Turns
## red when the target is valid, gray when invalid. Pulses its arrow head
## gently to read as "alive" while selection is active.
##
## Built as a world-space Node2D: both source and target are passed in world
## coordinates. Parent this to the duel root (or any world-space node) so
## it renders above hex tiles but below UI panels — z_index is set high to
## ensure it draws over creatures.
##
## Usage:
##   arrow.show_arrow(creature.global_position, mouse_world, is_valid)  (each frame)
##   arrow.hide_arrow()                                                  (when done)
class_name TargetingArrow
extends Node2D


# =============================================================================
# Visual Constants
# =============================================================================

## Number of sampled points along the bezier. Higher = smoother curve, more
## draw cost. 24 is plenty for any realistic source→target distance.
const NUM_SEGMENTS: int = 24

## Stroke width of the curved body at the tip. The source end tapers thinner
## via the Line2D width_curve.
const LINE_WIDTH: float = 10.0

## Edge length of the triangular arrow head in pixels.
const HEAD_SIZE: float = 26.0

## Fraction of the source→target distance that the bezier control point is
## pulled upward. 0.4 gives a natural arc without being cartoonish.
const ARC_LIFT: float = 0.4

## Colors for the two validity states. Alpha baked in so the gray variant
## reads as a "dimmed, disabled" hover while red reads as a commit target.
const COLOR_VALID: Color = Color(0.95, 0.2, 0.2, 0.95)
const COLOR_INVALID: Color = Color(0.55, 0.55, 0.55, 0.7)

## How long the color crossfade takes when validity flips (seconds).
const COLOR_FADE_DURATION: float = 0.12

## Pulse animation on the arrow head — scale bounces between 1.0 and this
## value over PULSE_DURATION seconds, looping while the arrow is visible.
const PULSE_SCALE: float = 1.18
const PULSE_DURATION: float = 0.45


# =============================================================================
# Nodes (built in _ready)
# =============================================================================

var _line: Line2D = null
var _head: Polygon2D = null


# =============================================================================
# State
# =============================================================================

## Currently displayed validity. Used to skip the color tween if validity
## hasn't actually changed between frames.
var _is_valid: bool = false

## Whether the arrow is currently on screen. Used to stop redundant work.
var _showing: bool = false

## Tween handles so we can cancel cleanly on hide / re-validity.
var _color_tween: Tween = null
var _pulse_tween: Tween = null


# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_build_line()
	_build_head()
	visible = false
	# Render above creatures and tiles; DuelTestScene's UI CanvasLayers
	# naturally draw over this since they're on separate layers.
	z_index = 200


func _build_line() -> void:
	_line = Line2D.new()
	_line.width = LINE_WIDTH
	_line.default_color = COLOR_INVALID
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_line.antialiased = true

	# Taper: narrow at the source (t=0), full width at the tip (t=1).
	# Creates a subtle "drawn from the caster" feel.
	var width_curve := Curve.new()
	width_curve.add_point(Vector2(0.0, 0.25))
	width_curve.add_point(Vector2(1.0, 1.0))
	_line.width_curve = width_curve

	add_child(_line)


func _build_head() -> void:
	_head = Polygon2D.new()
	# Triangle pointing along +x so we can rotate it to match the tangent.
	# Apex at +HEAD_SIZE, base centered on origin.
	var half_base: float = HEAD_SIZE * 0.6
	_head.polygon = PackedVector2Array([
		Vector2(HEAD_SIZE, 0.0),
		Vector2(-HEAD_SIZE * 0.5, -half_base),
		Vector2(-HEAD_SIZE * 0.5, half_base),
	])
	_head.color = COLOR_INVALID
	# Slight outline-ish effect via darker border polygon could be added
	# later; for tier 1 the flat polygon reads fine.
	add_child(_head)


# =============================================================================
# Public API
# =============================================================================

## Show or update the arrow, drawn from from_world to to_world in world space.
## is_valid controls the color (red = valid, gray = invalid).
## Safe to call every frame — cheap enough since we only rebuild Line2D points
## and reposition the head.
func show_arrow(from_world: Vector2, to_world: Vector2, is_valid: bool) -> void:
	if not _showing:
		visible = true
		_showing = true
		_start_pulse()

	_update_curve(from_world, to_world)
	_apply_validity(is_valid)


## Hide the arrow and stop its animations.
func hide_arrow() -> void:
	if not _showing:
		return
	_showing = false
	visible = false
	_stop_pulse()
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	_color_tween = null


## Whether the arrow is currently drawn.
func is_showing() -> bool:
	return _showing


# =============================================================================
# Curve & Orientation
# =============================================================================

## Rebuild the Line2D points along a quadratic bezier from source to target,
## and place + orient the arrow head at the tip.
##
## The control point is lifted straight up by ARC_LIFT * distance to create
## the natural overhead arc targeting arrows use. For very short distances
## the lift is small, so the arrow stays compact.
func _update_curve(from_w: Vector2, to_w: Vector2) -> void:
	var mid: Vector2 = (from_w + to_w) * 0.5
	var dist: float = from_w.distance_to(to_w)
	var control: Vector2 = mid + Vector2(0.0, -dist * ARC_LIFT)

	var pts := PackedVector2Array()
	pts.resize(NUM_SEGMENTS + 1)
	for i: int in range(NUM_SEGMENTS + 1):
		var t: float = float(i) / float(NUM_SEGMENTS)
		pts[i] = _bezier(from_w, control, to_w, t)
	_line.points = pts

	# Place the head at the tip, rotated to match the bezier tangent at t=1.
	_head.position = to_w
	var tangent: Vector2 = (to_w - control) * 2.0  # derivative of bezier at t=1
	if tangent.length_squared() > 0.0001:
		_head.rotation = tangent.angle()


## Quadratic bezier interpolation.
func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return (u * u) * p0 + (2.0 * u * t) * p1 + (t * t) * p2


# =============================================================================
# Validity (color)
# =============================================================================

func _apply_validity(is_valid: bool) -> void:
	if is_valid == _is_valid and _color_tween != null:
		return  # Already crossfading to / resting at the right color.
	_is_valid = is_valid

	var target_color: Color = COLOR_VALID if is_valid else COLOR_INVALID

	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	_color_tween = create_tween().set_parallel(true)
	_color_tween.tween_property(_line, "default_color", target_color, COLOR_FADE_DURATION)
	_color_tween.tween_property(_head, "color", target_color, COLOR_FADE_DURATION)


# =============================================================================
# Pulse animation on the arrow head
# =============================================================================

func _start_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		return
	_head.scale = Vector2.ONE
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(_head, "scale", Vector2(PULSE_SCALE, PULSE_SCALE), PULSE_DURATION)
	_pulse_tween.tween_property(_head, "scale", Vector2.ONE, PULSE_DURATION)


func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	if _head:
		_head.scale = Vector2.ONE
