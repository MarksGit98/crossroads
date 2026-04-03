## Creature card — has ATK/HP stats, can be placed on the hex grid.
## When played, spawns a Creature board entity on a valid hex.
class_name CreatureCard
extends Card

## Fallback creature scene when CardData has no creature_scene_path.
var _default_creature_scene: PackedScene = preload("res://scenes/creatures/creature.tscn")

# =============================================================================
# Board State (populated when placed on the hex grid)
# =============================================================================

## Live HP that decreases as the creature takes damage.
var current_hp: int = 0

## Live ATK that can be modified by buffs/debuffs.
var current_atk: int = 0

## Live armor value.
var current_armor: int = 0

## Axial hex coordinate on the board, or (-1, -1) if not placed.
var hex_position: Vector2i = Vector2i(-1, -1)

## Whether this creature is currently on the board.
var is_on_board: bool = false

## Active status effects: StatusEffect enum -> remaining turns.
var status_effects: Dictionary = {}


# =============================================================================
# Setup
# =============================================================================

func setup(data: CardData) -> void:
	super.setup(data)
	current_hp = data.hp
	current_atk = data.atk
	current_armor = data.armor


# =============================================================================
# Bake — shows ATK and HP on the card face
# =============================================================================

## Override: populate ATK/HP labels and make them visible.
func _populate_layout(layout: Control, data: CardData) -> void:
	super._populate_layout(layout, data)

	var atk_label: Label = layout.get_node_or_null("AtkLabel")
	var hp_label: Label = layout.get_node_or_null("HpLabel")

	if atk_label:
		atk_label.text = str(data.atk)
		atk_label.visible = true
	if hp_label:
		hp_label.text = str(data.hp)
		hp_label.visible = true


## Override rebake to use live stats instead of base data.
func rebake() -> void:
	if card_data == null:
		return
	# Temporarily patch the data with live stats for the bake.
	var original_atk: int = card_data.atk
	var original_hp: int = card_data.hp
	card_data.atk = current_atk
	card_data.hp = current_hp
	_bake_card_texture(card_data)
	card_data.atk = original_atk
	card_data.hp = original_hp


# =============================================================================
# Play System — summon creature onto a hex
# =============================================================================

func can_play(context: Dictionary) -> bool:
	if not super.can_play(context):
		return false
	# Affordability is enough to enter targeting mode.
	# Hex validation happens in get_valid_targets() / _is_valid_summon_hex().
	return true


func play(context: Dictionary) -> void:
	super.play(context)
	var target_hexes: Array = context.get("target_hexes", [])
	var board: HexGrid = context.get("board")
	if not target_hexes.is_empty() and board:
		_spawn_creature(board, target_hexes[0])


func needs_targeting() -> bool:
	return true


## Compute which hexes this creature can be summoned on.
## Checks spawn zone, passability, occupancy, and creature-specific terrain rules.
func get_valid_targets(board: HexGrid) -> Array[Vector2i]:
	return _compute_valid_summoning_hexes(board)


## Core summoning hex computation. Filters tiles by:
## 1. valid_spawn flag (spawn zone)
## 2. Passable terrain (unless creature has FLY or SWIM overrides)
## 3. Not occupied by another unit
func _compute_valid_summoning_hexes(board: HexGrid) -> Array[Vector2i]:
	var valid: Array[Vector2i] = []
	var can_fly: bool = card_data != null and CardTypes.Keyword.FLYING in card_data.keywords
	var can_swim: bool = card_data != null and CardTypes.MovePattern.SWIM == card_data.move_pattern

	for coord: Vector2i in board.tiles:
		var tile: HexTileData = board.tiles[coord]
		if not tile.valid_spawn:
			continue
		if tile.is_occupied():
			continue
		# Check terrain passability — flying ignores it, swim allows water/river.
		if not can_fly:
			if not tile.is_passable():
				if can_swim and tile.terrain == TerrainTypes.Terrain.RIVER:
					pass  # Swim creatures can spawn on rivers.
				else:
					continue
		valid.append(coord)
	return valid


## Spawn a Creature board entity on the given hex.
## Uses the creature_scene_path from CardData if set, otherwise falls back to the base scene.
## Adds the creature to board.creature_parent (or the board itself as fallback).
func _spawn_creature(board: HexGrid, hex: Vector2i) -> void:
	var scene: PackedScene
	if card_data.creature_scene_path != "":
		scene = load(card_data.creature_scene_path) as PackedScene
	else:
		scene = _default_creature_scene
	var creature: Creature = scene.instantiate()

	# Add to the dedicated Creatures node if available, otherwise to the board.
	var parent: Node2D = board.creature_parent if board.creature_parent else board
	parent.add_child(creature)

	# Initialize stats, position, z-order, and start idle animation.
	# DEPTH_OFFSET and z_index are set inside initialize().
	creature.initialize(card_data, hex, board.hex_size)

	# Play summon effect animation if available.
	if creature.anim_player and creature.anim_player.has_animation(&"summon"):
		creature.anim_player.play(&"summon")

	# Register the creature as the tile's occupant.
	var tile: HexTileData = board.get_tile(hex)
	if tile:
		tile.occupant = creature


# =============================================================================
# Combat (stubs — implemented when board system is built)
# =============================================================================

## Apply damage after armor reduction. Returns actual damage dealt.
func take_damage(amount: int, damage_type: CardTypes.DamageType = CardTypes.DamageType.PHYSICAL) -> int:
	var reduced: int = amount
	if damage_type == CardTypes.DamageType.PHYSICAL:
		reduced = maxi(amount - current_armor, 0)
	current_hp -= reduced
	if current_hp <= 0:
		current_hp = 0
		_on_death()
	rebake()
	return reduced


## Restore HP, clamped to max.
func heal(amount: int) -> void:
	if card_data:
		current_hp = mini(current_hp + amount, card_data.hp)
		rebake()


## Modify ATK by a delta (positive = buff, negative = debuff).
func modify_atk(delta: int) -> void:
	current_atk = maxi(current_atk + delta, 0)
	rebake()


## Called when HP reaches 0.
func _on_death() -> void:
	is_on_board = false
	# Death rattle, discard, etc. will be handled by the board/combat system.
