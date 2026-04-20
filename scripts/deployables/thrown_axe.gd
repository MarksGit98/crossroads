## Axed Marauder's thrown axe. Persistent DuelDeployable that embeds itself
## in the tile it lands on; the owner Marauder can walk back over it to
## reclaim a throw charge. Rendered as the Axe.png sprite, rotated 90°
## clockwise to stand upright when stuck in a tile.
##
## Pickup rule: only the owner creature recovers the axe. Other creatures
## (enemies, other Marauders if we ever add them) walk over it without
## interaction.
class_name ThrownAxe
extends DuelDeployable


# =============================================================================
# Constants
# =============================================================================

## Stable type key — matches Creature.deployable_charges[this] for ammo tracking.
const TYPE_ID: String = "axed_marauder_axe"

## Path to the axe image. Loaded in _ready() to avoid scene-level dependencies.
const AXE_TEXTURE: Texture2D = preload("res://assets/deployables/axe/axe.png")

## Target on-screen size of the embedded axe (pixels, long edge). The scale
## is derived from this and the source texture's dimensions.
const EMBED_SIZE: float = 32.0

## Resting rotation (radians) — 90° clockwise so the axe stands upright with
## the head pointing down into the tile like it's embedded in the ground.
const EMBED_ROTATION: float = PI * 0.5


# =============================================================================
# Nodes (built in _ready)
# =============================================================================

var _sprite: Sprite2D = null


# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	deployable_id = TYPE_ID
	display_name = "Axe"
	# Non-blocking — creatures must be able to step over it to trigger pickup.
	blocks_movement = false
	is_targetable = true
	_build_sprite()


## Build the axe visual. The sprite starts unrotated during throw (the
## DuelDeployable.play_throw_animation tweens rotation), then _on_landed
## snaps it to EMBED_ROTATION so it sits upright.
func _build_sprite() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = AXE_TEXTURE
	# Scale down to EMBED_SIZE on the long edge.
	var tex_size: Vector2 = Vector2(AXE_TEXTURE.get_width(), AXE_TEXTURE.get_height())
	var longest: float = maxf(tex_size.x, tex_size.y)
	if longest > 0.0:
		var s: float = EMBED_SIZE / longest
		_sprite.scale = Vector2(s, s)
	add_child(_sprite)


# =============================================================================
# Overrides
# =============================================================================

## Snap to upright embedded pose after the throw animation finishes.
func _on_landed() -> void:
	rotation = EMBED_ROTATION


## Owner creature stepped onto this tile — reclaim the axe.
## No-op for any other creature.
func on_creature_enter(c: Creature, ctx: DuelContext) -> void:
	if c != owner_creature or c == null:
		return
	# Refund a charge on the owner. deployable_charges is keyed by type id.
	var current: int = c.deployable_charges.get(TYPE_ID, 0)
	c.deployable_charges[TYPE_ID] = current + 1
	# Refresh the owner's stats bar so the CHARGES slot updates immediately.
	if c.has_method("refresh_stats_bar"):
		c.refresh_stats_bar()
	pick_up(c, ctx)
