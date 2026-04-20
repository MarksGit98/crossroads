## Equipment card — attaches to a creature on the board, modifying its stats.
class_name EquipCard
extends Card

## Sign multipliers for _apply_modifiers(). BUFF (+1) applies a modifier's
## declared value as-is; DEBUFF (-1) flips it to reverse the modifier. Lets
## the same parser handle both attach-time and detach-time bookkeeping.
const BUFF: int = 1
const DEBUFF: int = -1

## Equip card template texture — swapped into the layout's CardBackground
## during bake so equipment cards have their own visual frame, not the
## creature template. Swap this constant for per-card art later.
var _equip_template: Texture2D = preload("res://assets/cards/equips/equip_template.png")

## The creature this equipment is currently attached to, or null.
var attached_to: Creature = null


# =============================================================================
# Bake — equip template background + passive description text
# =============================================================================

## Override: swap the CardBackground texture to the equip template and
## populate the description with full passive text + granted keywords +
## flavor (same approach SpellCard uses for its own template).
func _populate_layout(layout: Control, data: CardData) -> void:
	var bg: TextureRect = layout.get_node_or_null("CardBackground")
	if bg:
		bg.texture = _equip_template
	super._populate_layout(layout, data)
	var desc_label: Label = layout.get_node_or_null("DescriptionLabel")
	if desc_label:
		desc_label.text = CardDescriptionBuilder.build_equip_description(data)


# =============================================================================
# Play System — attach to a friendly creature
# =============================================================================

func can_play(ctx: DuelContext) -> bool:
	if not super.can_play(ctx):
		return false
	if ctx == null:
		return false
	var board: HexGrid = ctx.board
	var target_hexes: Array = ctx.target_hexes

	if target_hexes.is_empty():
		# No target chosen yet — verify at least one valid target exists.
		if board and get_valid_targets(board).is_empty():
			return false
	else:
		# A target was already picked — validate it against both:
		#   (a) base targeting rules (occupied by a friendly Creature)
		#   (b) the two-layer equip gate (card's equip_rules + creature's
		#       can_accept_equip). Mirrors get_valid_targets() so a target
		#       that wasn't offered can't slip through via direct stamping.
		if board:
			var tile: HexTileData = board.get_tile(target_hexes[0])
			if tile == null or not tile.is_occupied():
				return false
			if not tile.occupant is Creature or tile.occupant.is_enemy():
				return false
			var c: Creature = tile.occupant as Creature
			if not c.matches_equip_rules(card_data.equip_rules):
				return false
			if not c.can_accept_equip(card_data):
				return false
	return true


func play(ctx: DuelContext) -> void:
	super.play(ctx)
	if ctx == null:
		return
	var target_hexes: Array = ctx.target_hexes
	var board: HexGrid = ctx.board
	if not target_hexes.is_empty() and board:
		var tile: HexTileData = board.get_tile(target_hexes[0])
		if tile and tile.occupant is Creature:
			attach(tile.occupant as Creature)


func needs_targeting() -> bool:
	return true


## Valid target hexes for this equip: every friendly creature that ALSO
## passes the card's equip_rules AND has room to accept another equip.
##
## Both gates must pass — if the card says "Viking only" the non-Viking
## friendly creatures are excluded; if a creature is already at its equip
## slot cap, it's excluded even if the card would otherwise allow it.
func get_valid_targets(board: HexGrid) -> Array[Vector2i]:
	if board == null:
		return []
	var valid: Array[Vector2i] = []
	var rules: Dictionary = card_data.equip_rules if card_data else {}
	for coord: Vector2i in board.tiles:
		var tile: HexTileData = board.tiles[coord]
		if not tile.is_occupied() or not tile.occupant is Creature:
			continue
		var c: Creature = tile.occupant as Creature
		if c.is_enemy():
			continue
		# Card says "this creature qualifies" (class/role/keyword/atk band).
		if not c.matches_equip_rules(rules):
			continue
		# Creature says "I can accept another equip" (slot cap, status veto).
		if not c.can_accept_equip(card_data):
			continue
		valid.append(coord)
	return valid


# =============================================================================
# Attachment
# =============================================================================

## Attach this equipment to a creature. Applies modifiers and records
## the equip in the creature's equipped_items list so slot-cap checks on
## future equip plays see it.
func attach(creature: Creature) -> void:
	if attached_to:
		detach()
	attached_to = creature
	if card_data and not (card_data in creature.equipped_items):
		creature.equipped_items.append(card_data)
	_apply_modifiers(creature, BUFF)


## Detach from the current creature. Reverses modifiers and frees the
## equipment slot. Currently only called from attach()'s safety path (if
## re-attaching) since Card nodes are queue_freed after play — future
## "destroy equipment" effects will call this directly through a registry.
func detach() -> void:
	if attached_to:
		_apply_modifiers(attached_to, DEBUFF)
		if card_data:
			attached_to.equipped_items.erase(card_data)
		attached_to = null


## Apply or reverse every modifier in the card's equip_modifiers list.
##
## direction:
##   BUFF  (+1) — attach-time. Stat deltas applied as-is; APPLY_STATUS
##                adds the status; REMOVE_STATUS strips it (one-shot).
##   DEBUFF (-1) — detach-time. Stat deltas negated so the creature ends
##                up at the pre-equip value; APPLY_STATUS is reversed
##                (status removed); REMOVE_STATUS is NOT re-applied
##                (it's treated as a one-shot cleanse — the status was
##                gone already, we don't know what intensity to restore).
func _apply_modifiers(creature: Creature, direction: int) -> void:
	if card_data == null:
		return
	# Resolve through the variant helper so an upgraded equip uses its
	# upgraded modifier values automatically.
	var mods: Array = CardData.resolve_variants(card_data.equip_modifiers, card_data.is_upgraded)
	for mod: Dictionary in mods:
		_apply_single_modifier(creature, mod, direction)


## Dispatch a single modifier dict to the right mutator on the creature.
## Extracted from _apply_modifiers so callers can apply ad-hoc modifiers
## too (e.g. future "steal equip" or "temporary enchant" effects).
func _apply_single_modifier(creature: Creature, mod: Dictionary, direction: int) -> void:
	var mtype: int = mod.get("type", -1)
	match mtype:
		CardTypes.EquipModifierType.MODIFY_STAT:
			var stat: int = mod.get("stat", -1)
			var value: int = mod.get("value", 0) * direction
			match stat:
				CardTypes.Stat.ATK:
					creature.modify_atk(value)
				CardTypes.Stat.ARMOR:
					creature.modify_armor(value)
				CardTypes.Stat.HP, CardTypes.Stat.MAX_HP:
					creature.modify_hp(value)
				CardTypes.Stat.MOVE_RANGE:
					creature.modify_move_range(value)
				CardTypes.Stat.ATTACK_RANGE:
					creature.modify_attack_range(value)
				_:
					push_warning("EquipCard: unknown stat id %d" % stat)

		CardTypes.EquipModifierType.APPLY_STATUS:
			var status: int = mod.get("status", -1)
			if status < 0:
				return
			if direction == BUFF:
				var duration: int = mod.get("duration", -1)
				creature.apply_status(status as CardTypes.StatusEffect, duration)
			else:
				# Detaching — pull the status we applied back off.
				creature.remove_status(status as CardTypes.StatusEffect)

		CardTypes.EquipModifierType.REMOVE_STATUS:
			# One-shot cleanse on attach; no reversal on detach.
			if direction == BUFF:
				var status: int = mod.get("status", -1)
				if status >= 0:
					creature.remove_status(status as CardTypes.StatusEffect)

		_:
			push_warning("EquipCard: unknown modifier type %d" % mtype)
