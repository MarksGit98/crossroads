## Base class for persistent objects that sit on hexes during a duel and
## communicate with creatures, cards, hexes, and effects. Examples:
##   - ThrownAxe (Axed Marauder's throwable axes that stick in tiles)
##   - future: traps, totems, summoned zones, crafted buildings, etc.
##
## Lives in world space as a Node2D sibling of creatures, registered in the
## DuelContext.deployables registry so any system can query "what's on hex X?"
## or "what belongs to creature Y?".
##
## Subclasses override lifecycle hooks (on_creature_enter, on_destroyed, etc)
## for their specific behavior. The base handles:
##   - Board position tracking
##   - Scene attachment / detachment
##   - Instant deploy() vs animated throw_to() entry paths
##   - Registry communication (emits signals on add/remove)
class_name DuelDeployable
extends Node2D


# =============================================================================
# Signals
# =============================================================================

## Fired when a creature picks this deployable up (pick_up() called).
signal picked_up(by: Creature)

## Fired when this deployable is destroyed (destroy() called). Final signal;
## the node is queue_free()'d after.
signal destroyed

## Fired when an effect resolves against this deployable (future hook).
signal effect_applied(effect: Dictionary)


# =============================================================================
# Identity
# =============================================================================

## Stable type key — e.g. "axed_marauder_axe". Used to look up deployables of
## the same type across the board (registry.of_type(id)) and to correlate with
## creature.deployable_charges[id] for ammo-like mechanics.
@export var deployable_id: String = ""

## Player-facing name — shown in tooltips, info labels, log messages.
@export var display_name: String = ""


# =============================================================================
# Ownership
# =============================================================================

## The creature that deployed this object. Null for duel-wide effects or
## unowned deployables. Used for pickup gating (only owners can reclaim axes)
## and for attribution (damage-dealt-by, etc.).
var owner_creature: Creature = null

## Side that owns this deployable, independent of creature reference (so
## deployables survive their owner's death if the design calls for it).
## &"player" or &"enemy". Defaults to "player".
var owner_side: StringName = &"player"


# =============================================================================
# Board state
# =============================================================================

## Axial hex coordinate this deployable rests on.
var hex_position: Vector2i = Vector2i(-1, -1)

## Whether this deployable occupies its hex like a creature does (prevents
## movement into the tile). Default false: most deployables are overlays
## that creatures can still step on (which is how axe pickup works).
@export var blocks_movement: bool = false

## Whether effects / abilities can target this deployable specifically (via
## a future EffectTarget.DEPLOYABLE_AT_HEX). Default true.
@export var is_targetable: bool = true


# =============================================================================
# Visual tuning constants
# =============================================================================

## Pixel-per-second travel speed used by throw_to()'s default animation.
const THROW_SPEED_PX_PER_SEC: float = 420.0

## Full rotations per second during throw — visual spin rate.
const ROTATIONS_PER_SECOND: float = 4.0

## Minimum and maximum clamp on throw animation duration (seconds).
const THROW_MIN_DURATION: float = 0.2
const THROW_MAX_DURATION: float = 0.7


# =============================================================================
# Lifecycle — entry
# =============================================================================

## Spawn the deployable instantly at the given hex, with no travel animation.
## Use for traps, placed-on-self effects, static terrain modifications.
##
## Handles scene attachment + registry add; subclasses generally don't need
## to override this.
func deploy(ctx: DuelContext, hex: Vector2i) -> void:
	if ctx == null or ctx.board == null:
		push_warning("DuelDeployable.deploy: invalid DuelContext")
		return
	hex_position = hex
	global_position = HexHelper.hex_to_world(hex, ctx.board.hex_size)
	_attach_to_scene(ctx)
	if ctx.deployables:
		ctx.deployables.add(self)


## Spawn the deployable at `from_hex`, animate it flying + spinning to
## `to_hex`, then register it there. Use for thrown projectiles that should
## visibly travel before settling.
##
## Awaits the throw animation, so callers can use `await deployable.throw_to(...)`
## and then run follow-up logic (damage resolution, UI updates) after landing.
func throw_to(ctx: DuelContext, from_hex: Vector2i, to_hex: Vector2i) -> void:
	if ctx == null or ctx.board == null:
		push_warning("DuelDeployable.throw_to: invalid DuelContext")
		return
	hex_position = to_hex
	var from_w: Vector2 = HexHelper.hex_to_world(from_hex, ctx.board.hex_size)
	var to_w: Vector2 = HexHelper.hex_to_world(to_hex, ctx.board.hex_size)
	global_position = from_w
	_attach_to_scene(ctx)
	await play_throw_animation(from_w, to_w)
	if ctx.deployables:
		ctx.deployables.add(self)


## Default throw visual: linear position tween + continuous rotation.
## Override in subclasses for different flavor (arcing grenades, homing
## missiles, etc.). Returns when the animation completes.
func play_throw_animation(from_w: Vector2, to_w: Vector2) -> void:
	var distance: float = from_w.distance_to(to_w)
	var duration: float = clampf(
		distance / THROW_SPEED_PX_PER_SEC,
		THROW_MIN_DURATION,
		THROW_MAX_DURATION,
	)
	var rotations: float = duration * ROTATIONS_PER_SECOND

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", to_w, duration)
	tween.tween_property(self, "rotation", rotation + TAU * rotations, duration)
	await tween.finished
	# Land flat — subclasses that want a "stuck upright" pose can override
	# _on_landed() to set a resting rotation.
	_on_landed()


## Hook called once the throw animation completes. Subclasses can set the
## resting pose (e.g. axe rotated 90° to stand upright in the tile). Default
## resets rotation to 0.
func _on_landed() -> void:
	rotation = 0.0


# =============================================================================
# Lifecycle — exit
# =============================================================================

## Remove this deployable from the board (picked up by a creature). Fires
## picked_up and removes from the registry before queue_free'ing.
func pick_up(by: Creature, ctx: DuelContext) -> void:
	picked_up.emit(by)
	_remove_from_registry(ctx)
	queue_free()


## Destroy this deployable without pickup semantics (effect destroyed it,
## duel ended, etc.). Fires `destroyed` and cleans up.
func destroy(ctx: DuelContext) -> void:
	destroyed.emit()
	_remove_from_registry(ctx)
	on_destroyed(ctx)
	queue_free()


# =============================================================================
# Lifecycle hooks — override in subclasses
# =============================================================================

## A creature moved onto this deployable's hex. Default: no-op.
## Subclasses (e.g. ThrownAxe) use this to trigger pickup when the owner
## creature walks back over it.
func on_creature_enter(_c: Creature, _ctx: DuelContext) -> void:
	pass


## A creature moved off this deployable's hex. Default: no-op.
func on_creature_exit(_c: Creature, _ctx: DuelContext) -> void:
	pass


## End of a turn tick. Default: no-op. Time-based deployables (burning
## ground, decaying traps) use this to count down their lifespan.
func on_turn_end(_ctx: DuelContext) -> void:
	pass


## Called just before queue_free() during destroy(). Last chance to emit
## a dying effect (e.g. a trap releasing its payload on destruction).
func on_destroyed(_ctx: DuelContext) -> void:
	pass


# =============================================================================
# Internal helpers
# =============================================================================

## Parent the deployable under the creatures node so it renders in world
## space alongside creatures and tiles. Matches creature z-index conventions
## so it sorts correctly with the 2.5D depth scheme.
func _attach_to_scene(ctx: DuelContext) -> void:
	if get_parent() != null:
		return  # Already attached (idempotent).
	var parent: Node2D = ctx.creatures_node if ctx.creatures_node else ctx.board
	if parent:
		parent.add_child(self)
	# Match the creature z-index band so deployables draw over ground tiles
	# but still participate in row-based depth sort.
	z_index = HexTileRenderer.Z_BAND_OBJECTS + hex_position.y * 3 + 2


func _remove_from_registry(ctx: DuelContext) -> void:
	if ctx and ctx.deployables:
		ctx.deployables.remove(self)
