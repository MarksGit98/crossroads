## Equipment card — attaches to a creature on the board, modifying its stats.
class_name EquipCard
extends Card

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
		# A target was already picked — validate it.
		if board:
			var tile: HexTileData = board.get_tile(target_hexes[0])
			if tile == null or not tile.is_occupied():
				return false
			# Must target a friendly Creature.
			if not tile.occupant is Creature:
				return false
			if tile.occupant.is_enemy():
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


func get_valid_targets(board: HexGrid) -> Array[Vector2i]:
	if board == null:
		return []
	# Valid targets are hexes with friendly (non-enemy) creatures.
	var valid: Array[Vector2i] = []
	for coord: Vector2i in board.tiles:
		var tile: HexTileData = board.tiles[coord]
		if tile.is_occupied() and tile.occupant is Creature and not tile.occupant.is_enemy():
			valid.append(coord)
	return valid


# =============================================================================
# Attachment
# =============================================================================

## Attach this equipment to a creature. Applies stat modifiers.
func attach(creature: Creature) -> void:
	if attached_to:
		detach()
	attached_to = creature
	_apply_modifiers(creature, 1)


## Detach from the current creature. Removes stat modifiers.
func detach() -> void:
	if attached_to:
		_apply_modifiers(attached_to, -1)
		attached_to = null


## Apply (or reverse) stat modifiers from this equipment's keywords/passives.
func _apply_modifiers(creature: Creature, direction: int) -> void:
	if card_data == null:
		return
	# Resolve passives through the variant helper so an upgraded equip uses
	# its upgraded passive values. Equip cards use card_data.is_upgraded
	# directly (no Creature instance owns the equip, the card does).
	var passives: Array = CardData.resolve_variants(card_data.passives, card_data.is_upgraded)
	for passive: Dictionary in passives:
		var ptype: int = passive.get("type", -1)
		if ptype == CardTypes.PassiveType.STAT_AURA:
			var stat: int = passive.get("stat", -1)
			var value: int = passive.get("value", 0) * direction
			match stat:
				CardTypes.Stat.ATK:
					creature.modify_atk(value)
				CardTypes.Stat.ARMOR:
					creature.modify_armor(value)
