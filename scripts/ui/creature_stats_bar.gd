## Overhead UI that hovers above every creature on the board. Owns both the
## name label (top) and the stats bar (below) as a single parented unit so
## there's only one thing the Creature script needs to position.
##
## The stats bar displays up to five icons (health, attack, armor, range,
## slow) with a number label stacked on top of each. Health and attack are
## always shown; armor, range, and slow icons are hidden until relevant
## (armor > 0, move speed buffed, CHILLED/SLOWED status applied, etc.).
##
## This container is a child of the creature, so it inherits the creature's
## world position. It applies an inverse scale so icons and text stay at a
## consistent pixel size regardless of the creature's scale factor.
class_name CreatureStatsBar
extends Node2D


# =============================================================================
# Icon Textures (preloaded)
# =============================================================================

const ICON_HEALTH: Texture2D = preload("res://assets/creatures/stats/health.png")
const ICON_ATTACK: Texture2D = preload("res://assets/creatures/stats/attack.png")
const ICON_ARMOR: Texture2D = preload("res://assets/creatures/stats/armor.png")
const ICON_RANGE: Texture2D = preload("res://assets/creatures/stats/range.png")
const ICON_SLOW: Texture2D = preload("res://assets/creatures/stats/slow.png")


# =============================================================================
# Layout Constants
# =============================================================================

## Target on-screen size of each icon in pixels (square). The sprite's scale
## is derived from this and the source texture's native resolution.
const ICON_SIZE: float = 28.0

## Horizontal pixel gap between adjacent icons.
const ICON_SPACING: float = 3.0

## Font size for the number label on each icon.
const LABEL_FONT_SIZE: int = 18

## Font size for the creature name label above the bar.
const NAME_FONT_SIZE: int = 14

## Vertical offset of the label's center relative to the icon's center.
## Negative = above; positive = below. We draw the label inside the icon's
## upper portion so the number reads clearly without extra vertical real
## estate above the bar.
const LABEL_OFFSET_Y: float = -1.0

## Pixel gap between the baseline of the name label and the top of the
## stats row. The icon row is centered on this node's origin, so the name
## label sits at a negative y offset equal to half the icon size plus this gap.
const NAME_LABEL_GAP: float = 4.0


# =============================================================================
# Slot enum — index into _slots
# =============================================================================

enum Slot { HEALTH, ATTACK, ARMOR, RANGE, SLOW }
const SLOT_COUNT: int = 5


# =============================================================================
# State
# =============================================================================

## Ordered array of {icon: Sprite2D, label: Label} dicts keyed by Slot enum.
var _slots: Array[Dictionary] = []

## Name label sitting above the icon row. Populated from creature.creature_name
## in set_creature(). Exposed via set_display_name() if callers need to override.
var _name_label: Label = null

## The creature this bar tracks. Null until set_creature() is called.
var _creature: Creature = null


# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_build_name_label()
	_build_slots()


## Build the creature name label that sits above the icon row. Centered
## horizontally on this node's origin.
func _build_name_label() -> void:
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	_name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_name_label.add_theme_constant_override("outline_size", 3)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.z_index = 1
	add_child(_name_label)


## Build one icon+label pair for each stat slot. Every slot is created up
## front and hidden by default — _refresh() toggles visibility based on
## current creature state.
func _build_slots() -> void:
	_slots.resize(SLOT_COUNT)
	_slots[Slot.HEALTH] = _make_slot(ICON_HEALTH, Color(1.0, 0.85, 0.85))
	_slots[Slot.ATTACK] = _make_slot(ICON_ATTACK, Color(1.0, 0.95, 0.8))
	_slots[Slot.ARMOR] = _make_slot(ICON_ARMOR, Color(0.85, 0.9, 1.0))
	_slots[Slot.RANGE] = _make_slot(ICON_RANGE, Color(0.85, 1.0, 0.9))
	_slots[Slot.SLOW] = _make_slot(ICON_SLOW, Color(0.85, 0.9, 1.0))


## Create one icon + label child pair. The label sits as a child of the icon
## so positioning stays consistent even after layout reshuffles.
func _make_slot(tex: Texture2D, label_color: Color) -> Dictionary:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.visible = false
	# Scale so the rendered icon is ICON_SIZE pixels on its long edge.
	var tex_size: Vector2 = Vector2(tex.get_width(), tex.get_height())
	var longest: float = maxf(tex_size.x, tex_size.y)
	if longest > 0.0:
		var scale_factor: float = ICON_SIZE / longest
		sprite.scale = Vector2(scale_factor, scale_factor)
	add_child(sprite)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	label.add_theme_color_override("font_color", label_color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Center the label on the icon by offsetting half the label's size.
	# We'll reposition in _layout_slots once size is known.
	label.z_index = 1
	sprite.add_child(label)

	return {"icon": sprite, "label": label}


# =============================================================================
# Public API
# =============================================================================

## Wire this bar to a creature. Connects signals so the bar auto-updates
## whenever the creature's HP/attack/armor/status changes. Call once after
## the creature has been initialized.
func set_creature(creature: Creature) -> void:
	_creature = creature
	if _creature == null:
		return

	# Populate the name label from the creature.
	set_display_name(_creature.creature_name)

	# Connect every mutation signal that could change a displayed value.
	_creature.damaged.connect(_on_stats_changed.unbind(2))
	_creature.healed.connect(_on_stats_changed.unbind(2))
	_creature.status_applied.connect(_on_stats_changed.unbind(2))
	_creature.status_removed.connect(_on_stats_changed.unbind(2))
	if _creature.has_signal("atk_changed"):
		_creature.atk_changed.connect(_on_stats_changed)
	if _creature.has_signal("armor_changed"):
		_creature.armor_changed.connect(_on_stats_changed)

	_refresh()


## Override the name shown above the icon row. Called automatically from
## set_creature(), but exposed for cases where the display name should differ
## from the creature's data name (e.g. transformations).
func set_display_name(display_name: String) -> void:
	if _name_label:
		_name_label.text = display_name
		_name_label.reset_size()


## Manually trigger a re-read of creature stats. Useful right after a
## bulk change (e.g. equipping a piece of gear) if signal plumbing missed it.
func refresh() -> void:
	_refresh()


# =============================================================================
# Refresh
# =============================================================================

func _on_stats_changed(_a = null) -> void:
	_refresh()


## Read the creature's current state and update icon visibility + label text.
## Then re-lay-out the visible icons so they stay horizontally centered.
func _refresh() -> void:
	if _creature == null:
		return

	# -- Health: always visible --
	_set_slot(Slot.HEALTH, true, str(_creature.current_hp))

	# -- Attack: always visible --
	_set_slot(Slot.ATTACK, true, str(_creature.current_atk))

	# -- Armor: visible when > 0 --
	_set_slot(Slot.ARMOR, _creature.current_armor > 0, str(_creature.current_armor))

	# -- Range: visible when a move/attack buff is active (HASTED status) --
	# Shows current move range so the player sees the buffed value.
	var hasted: bool = _creature.has_status(CardTypes.StatusEffect.HASTED)
	_set_slot(Slot.RANGE, hasted, str(_creature.current_move_range))

	# -- Slow: visible when CHILLED or SLOWED — shows remaining turns --
	var chilled_turns: int = _creature.status_effects.get(CardTypes.StatusEffect.CHILLED, 0)
	var slowed_turns: int = _creature.status_effects.get(CardTypes.StatusEffect.SLOWED, 0)
	var slow_turns: int = maxi(chilled_turns, slowed_turns)
	_set_slot(Slot.SLOW, slow_turns > 0, str(slow_turns))

	_layout_slots()


## Toggle a slot's visibility and update its label.
func _set_slot(slot: Slot, visible_now: bool, label_text: String) -> void:
	var entry: Dictionary = _slots[slot]
	var icon: Sprite2D = entry["icon"]
	var label: Label = entry["label"]
	icon.visible = visible_now
	label.text = label_text


## Arrange currently visible icons in a centered horizontal row. Invisible
## slots are skipped so the row collapses tidily around what's showing.
## Also re-centers the name label above the row.
func _layout_slots() -> void:
	# Gather visible icons in slot order.
	var visible_slots: Array[Dictionary] = []
	for entry: Dictionary in _slots:
		if entry["icon"].visible:
			visible_slots.append(entry)

	var count: int = visible_slots.size()
	if count > 0:
		var total_width: float = count * ICON_SIZE + (count - 1) * ICON_SPACING
		var start_x: float = -total_width * 0.5 + ICON_SIZE * 0.5

		for i: int in range(count):
			var entry: Dictionary = visible_slots[i]
			var icon: Sprite2D = entry["icon"]
			var label: Label = entry["label"]

			icon.position = Vector2(start_x + i * (ICON_SIZE + ICON_SPACING), 0.0)

			# Re-center the label inside the icon. Label size isn't valid until
			# the text has been set at least once, so force a size recompute.
			label.reset_size()
			# Labels are children of the Sprite2D and inherit its scale. Divide
			# by the sprite's scale so the label renders at native size.
			var inv: Vector2 = Vector2(1.0 / icon.scale.x, 1.0 / icon.scale.y)
			label.scale = inv
			# Center relative to the icon origin (Sprite2D is centered on origin).
			var label_size: Vector2 = label.size * label.scale
			label.position = Vector2(-label_size.x * 0.5, -label_size.y * 0.5 + LABEL_OFFSET_Y)

	# Position the name label centered horizontally above the icon row.
	# The icon row is centered on y=0 with half-height ICON_SIZE/2, so the
	# name sits at -(ICON_SIZE/2 + NAME_LABEL_GAP + name_height).
	if _name_label:
		_name_label.reset_size()
		var name_size: Vector2 = _name_label.size
		_name_label.position = Vector2(
			-name_size.x * 0.5,
			-(ICON_SIZE * 0.5 + NAME_LABEL_GAP + name_size.y)
		)
