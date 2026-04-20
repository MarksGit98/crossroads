## Spell card — one-time effect that resolves and goes to the discard pile.
class_name SpellCard
extends Card

## Spell card template texture — swapped into the layout's CardBackground during bake.
var _spell_template: Texture2D = preload("res://assets/cards/spells/spell_template.png")


# =============================================================================
# Bake — use spell template instead of creature template
# =============================================================================

## Override: swap the CardBackground texture to the spell template, and
## populate the description with full effect text + keywords + flavor.
func _populate_layout(layout: Control, data: CardData) -> void:
	# Replace the background with the spell card art.
	var bg: TextureRect = layout.get_node_or_null("CardBackground")
	if bg:
		bg.texture = _spell_template
	super._populate_layout(layout, data)
	# Override the description label with full effect text built from card data.
	var desc_label: Label = layout.get_node_or_null("DescriptionLabel")
	if desc_label:
		desc_label.text = CardDescriptionBuilder.build_spell_description(data)


# =============================================================================
# Play System — target validation and one-shot resolution
# =============================================================================

func can_play(ctx: DuelContext) -> bool:
	if not super.can_play(ctx):
		return false
	# Spells that need targeting must have at least one valid target on the board.
	if needs_targeting():
		if ctx and ctx.board and get_valid_targets(ctx.board).is_empty():
			return false
	return true


func play(ctx: DuelContext) -> void:
	super.play(ctx)
	# Spells are one-shot — all effect logic handled by resolve_effects() in base.


func needs_targeting() -> bool:
	if card_data == null:
		return false
	# Auto-target spells (ALL_ENEMIES, ALL_ALLIES, etc.) skip target selection.
	match card_data.target_rule:
		CardTypes.TargetRule.ALL_ENEMIES, \
		CardTypes.TargetRule.ALL_ALLIES, \
		CardTypes.TargetRule.ALL_UNITS, \
		CardTypes.TargetRule.SELF:
			return false
	return true


func get_valid_targets(board: HexGrid) -> Array[Vector2i]:
	if card_data == null or board == null:
		return []
	# TODO: Filter hexes/units by target_rule and spell_range.
	# For now return all occupied hexes within range as valid targets.
	var valid: Array[Vector2i] = []
	for coord: Vector2i in board.tiles:
		var tile: HexTileData = board.tiles[coord]
		match card_data.target_rule:
			CardTypes.TargetRule.ANY_HEX:
				valid.append(coord)
			CardTypes.TargetRule.EMPTY_HEX:
				if not tile.is_occupied():
					valid.append(coord)
			CardTypes.TargetRule.ANY_UNIT, \
			CardTypes.TargetRule.ANY_ENEMY, \
			CardTypes.TargetRule.ANY_ALLY:
				if tile.is_occupied():
					valid.append(coord)
			_:
				valid.append(coord)
	return valid
