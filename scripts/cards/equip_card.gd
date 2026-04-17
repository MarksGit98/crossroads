## Equipment card — attaches to a creature on the board, modifying its stats.
class_name EquipCard
extends Card

## The creature this equipment is currently attached to, or null.
var attached_to: Creature = null


# =============================================================================
# Bake — populate description with full passive text + granted keywords + flavor
# =============================================================================

func _populate_layout(layout: Control, data: CardData) -> void:
	super._populate_layout(layout, data)
	var desc_label: Label = layout.get_node_or_null("DescriptionLabel")
	if desc_label:
		desc_label.text = CardDescriptionBuilder.build_equip_description(data)


# =============================================================================
# Play System — attach to a friendly creature
# =============================================================================

func can_play(context: Dictionary) -> bool:
	if not super.can_play(context):
		return false
	var board: HexGrid = context.get("board")
	var target_hexes: Array = context.get("target_hexes", [])

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


func play(context: Dictionary) -> void:
	super.play(context)
	var target_hexes: Array = context.get("target_hexes", [])
	var board: HexGrid = context.get("board")
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
	# Apply stat bonuses defined in passives.
	for passive: Dictionary in card_data.passives:
		var ptype: int = passive.get("type", -1)
		if ptype == CardTypes.PassiveType.STAT_AURA:
			var stat: int = passive.get("stat", -1)
			var value: int = passive.get("value", 0) * direction
			match stat:
				CardTypes.Stat.ATK:
					creature.modify_atk(value)
				CardTypes.Stat.ARMOR:
					creature.modify_armor(value)
