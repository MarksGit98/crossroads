## Board entity representing a summoned creature on the hex grid.
## Holds live combat stats, hex position, status effects, movement logic,
## active abilities (player-activated), and passive abilities (trigger-based).
## Spawned by CreatureCard.play() — the card goes to discard, this stays on the board.
class_name Creature
extends Node2D

# =============================================================================
# Signals
# =============================================================================

signal damaged(creature: Creature, amount: int)
signal healed(creature: Creature, amount: int)
signal died(creature: Creature)
signal moved(creature: Creature, from_hex: Vector2i, to_hex: Vector2i)
signal status_applied(creature: Creature, effect: CardTypes.StatusEffect)
signal status_removed(creature: Creature, effect: CardTypes.StatusEffect)

## Emitted whenever current_atk changes (modify_atk, buffs, debuffs).
## Consumers like CreatureStatsBar use this to refresh the displayed value.
signal atk_changed(creature: Creature, new_value: int)

## Emitted whenever current_armor changes (modify_armor, take_damage absorption).
signal armor_changed(creature: Creature, new_value: int)
signal active_used(creature: Creature, ability_index: int)
signal passive_triggered(creature: Creature, passive_index: int)
signal clicked(creature: Creature)
signal hovered(creature: Creature)
signal unhovered(creature: Creature)

# =============================================================================
# Identity (set once on spawn from CardData)
# =============================================================================

## Scale multiplier applied on top of hex-fitted base scale.
## Tune per-creature in sub-scenes if some creatures should appear larger/smaller.
@export var sprite_scale_factor: float = 2.5

## The card data this creature was summoned from.
var card_data: CardData

## Display name (cached from card_data for convenience).
var creature_name: String

# =============================================================================
# Live Stats
# =============================================================================

## Base values from card_data — used for "reset to base" effects.
var base_atk: int = 0
var base_hp: int = 0
var base_armor: int = 0

## Current live values that change during combat.
var current_hp: int = 0
var max_hp: int = 0
var current_atk: int = 0
var current_armor: int = 0
var current_move_range: int = 0
var attack_range: int = 1
var attack_pattern: CardTypes.AttackPattern = CardTypes.AttackPattern.SINGLE_TARGET
var damage_type: CardTypes.DamageType = CardTypes.DamageType.PHYSICAL

# =============================================================================
# Board State
# =============================================================================

## Offset coordinate on the hex grid.
var hex_position: Vector2i = Vector2i(-1, -1)

## Whether this creature has already moved this turn.
var has_moved: bool = false

## Whether this creature has already attacked this turn.
var has_attacked: bool = false

## Whether this creature has already used its active ability this turn.
var has_used_active: bool = false

## Active status effects: StatusEffect enum -> remaining turns (-1 = permanent).
var status_effects: Dictionary = {}

## Per-active cooldown tracking: ability index -> remaining cooldown turns.
var _active_cooldowns: Dictionary = {}

## Whether this creature has been upgraded. Mirrors card_data.is_upgraded
## at init time so the value is stable per-instance (detached from the
## shared CardData if it gets re-upgraded mid-duel). Calling upgrade()
## mid-duel flips BOTH this field and card_data.is_upgraded so future
## summons of the same card id also come out upgraded for the rest of
## the run. Mid-duel upgrades do NOT retroactively re-fire ON_SUMMON
## passives — the new variants apply going forward.
var is_upgraded: bool = false

## Consumable charges for deployable-throwing abilities. Keyed by the
## deployable type id (e.g. "axed_marauder_axe"). An ability that throws a
## deployable decrements its count; picking the deployable back up restores
## a charge. Other ability types that want "ammo" semantics can reuse this
## dict without the creature class needing to know about their specifics.
##
## Example: Axed Marauder spawns with `{"axed_marauder_axe": 2}` (or 3 when
## upgraded). can_use_active() gates the throw on count > 0.
var deployable_charges: Dictionary = {}

## The sprite's resting flip_h value, captured at init. `perform_attack()`
## flips the sprite to face its target mid-attack, then restores this value
## on the return trip. Player creatures default to false (face right);
## enemies default to true (face left, toward the player), unless their
## EnemyData says the source art is already drawn facing left.
var _default_sprite_flip_h: bool = false

## Whether this creature can perform a heavy/special attack (true if its
## SpriteFrames contain a heavy_attack or heavy_attack_start animation).
## Populated at init time by looking up the sprite_frames.
var has_heavy_attack: bool = false

## Turns remaining before this creature can use its heavy attack again.
## Decremented at start_turn(). 0 = ready.
var heavy_attack_cd_remaining: int = 0

## Default heavy-attack cooldown (turns) when a creature has one. Per-creature
## overrides can be added later by reading from CardData / EnemyData.
const HEAVY_ATTACK_COOLDOWN: int = 3

# =============================================================================
# Node References
# =============================================================================

## Animated sprite for creature visuals (idle, attack, hurt, death animations).
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

## Animation player for property animations (flash on hit, scale bounce, fade).
@onready var anim_player: AnimationPlayer = $AnimationPlayer

## Composition-based state machine for board behavior (IDLE, WALKING, ATTACKING, etc.).
@onready var state_machine: CreatureStateMachine = $CreatureStateMachine

## Click/hover detection area for player interaction.
@onready var click_area: Area2D = $ClickArea

## Label showing creature name above the sprite.
@onready var _name_label: Label = $NameLabel

## Legacy HP label — superseded by CreatureStatsBar. Kept as a scene node
## for backward compatibility but hidden at startup.
@onready var _hp_label: Label = $HPLabel

## Overhead stats bar (name + icons + number labels). Lives as a child in
## creature.tscn so the node is visible/editable in the Godot editor.
## Its children (icons, labels) are still built programmatically in the
## bar's own _ready() to keep layout constants centralized.
## See scripts/ui/creature_stats_bar.gd and scenes/ui/creature_stats_bar.tscn.
@onready var _stats_bar: CreatureStatsBar = $CreatureStatsBar

## Desired gap in screen pixels between the top edge of the creature's
## collision shape and the center of the stats bar. Negative means "above".
## This is converted to local space via the creature's current scale so the
## gap remains constant regardless of how the creature is scaled to fit a hex.
const STATS_BAR_WORLD_GAP: float = -12.0


# =============================================================================
# Initialization
# =============================================================================

## Set up this creature from card data and place it at a hex coordinate.
func initialize(data: CardData, hex: Vector2i, hex_size: float) -> void:
	card_data = data
	creature_name = data.card_name

	# Set base and live stats from card data.
	base_atk = data.atk
	base_hp = data.hp
	base_armor = data.armor

	current_atk = base_atk
	current_hp = base_hp
	max_hp = base_hp
	current_armor = base_armor
	current_move_range = data.move_range
	attack_range = data.attack_range
	attack_pattern = data.attack_pattern
	damage_type = data.damage_type

	# Mirror the card's persistent upgrade flag onto this instance so our
	# get_actives / get_passives accessors resolve the right variant. If
	# the card gets upgraded later mid-duel, Creature.upgrade() updates both.
	is_upgraded = data.is_upgraded

	# Initialize cooldowns for all actives at 0 (ready to use). The count is
	# based on the raw actives array length — each ENTRY gets one slot,
	# regardless of whether it's variant-grouped or flat.
	for i: int in range(data.actives.size()):
		_active_cooldowns[i] = 0

	# Position on the grid. Add DEPTH_OFFSET to match 2.5D tile positioning.
	hex_position = hex
	position = HexHelper.hex_to_world(hex, hex_size) + Vector2(0, HexTileRenderer.DEPTH_OFFSET)

	# Z-order: creatures live in the objects band alongside walls/top tiles,
	# so ground tiles from any row sit beneath them. Within the objects
	# band, creatures still sort by row (+2 sub-layer so they're above
	# same-row walls/middle tiles) — walls in rows in front of the creature
	# correctly draw over it.
	z_index = HexTileRenderer.Z_BAND_OBJECTS + hex.y * 3 + 2

	# Scale the creature to fit the hex based on sprite frame size.
	_apply_creature_scale(hex_size)

	# Initialize the state machine with the AnimatedSprite2D reference.
	if state_machine:
		state_machine.setup(animated_sprite)
		state_machine.attack_hit.connect(_on_attack_hit)
	else:
		# Fallback if state machine node isn't present.
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(&"idle"):
			animated_sprite.play(&"idle")

	# Detect whether this creature has a heavy attack animation — either a
	# single-phase "heavy_attack" or the minotaur-style multi-phase
	# "heavy_attack_start" sequence. Cooldown starts ready (0).
	_detect_heavy_attack_support()

	# Fire ON_SUMMON passives.
	check_passive_triggers(CardTypes.TriggerType.ON_SUMMON, {"creature": self})

	# Wire up click/hover detection.
	_connect_click_area()

	# Create overhead labels (name + HP).
	_create_overhead_labels()


## Connect click area signals for player interaction.
func _connect_click_area() -> void:
	if not click_area:
		return
	click_area.input_event.connect(_on_click_area_input_event)
	click_area.mouse_entered.connect(_on_click_area_mouse_entered)
	click_area.mouse_exited.connect(_on_click_area_mouse_exited)


# =============================================================================
# Overhead Labels
# =============================================================================

## Configure the overhead stats bar (added in creature.tscn at editor time)
## and hide the legacy NameLabel/HPLabel — the stats bar owns all overhead
## display now.
func _create_overhead_labels() -> void:
	if _name_label:
		_name_label.visible = false
	if _hp_label:
		_hp_label.visible = false

	if _stats_bar:
		_stats_bar.set_creature(self)
		# Counter the creature's scale so icons and labels render at native
		# pixel size, and position the bar above the collision shape in
		# world-space pixels.
		_apply_stats_bar_inverse_scale()


# =============================================================================
# Input Detection
# =============================================================================

## Handle mouse clicks on the creature's click area.
func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(self)
			# Consume the input so the hex grid doesn't also process the click.
			get_viewport().set_input_as_handled()


## Handle mouse entering the creature's click area.
func _on_click_area_mouse_entered() -> void:
	hovered.emit(self)


## Handle mouse leaving the creature's click area.
func _on_click_area_mouse_exited() -> void:
	unhovered.emit(self)


# =============================================================================
# Scaling
# =============================================================================

## Scale the creature node to fit the hex grid based on sprite frame dimensions.
## Uses hex_size to compute a base scale, then multiplies by sprite_scale_factor.
func _apply_creature_scale(hex_size: float) -> void:
	var frame_width: float = _get_frame_width()
	if frame_width <= 0.0:
		# No frame data — apply scale factor directly.
		scale = Vector2(sprite_scale_factor, sprite_scale_factor)
		_apply_label_inverse_scale()
		return
	var hex_diameter: float = hex_size * 2.0
	var base_scale: float = hex_diameter / frame_width
	var final_scale: float = base_scale * sprite_scale_factor
	scale = Vector2(final_scale, final_scale)
	_apply_label_inverse_scale()


## Counter the parent's scale on labels so text renders at native resolution.
func _apply_label_inverse_scale() -> void:
	var inv: Vector2 = Vector2(1.0 / scale.x, 1.0 / scale.y)
	if _name_label:
		_name_label.scale = inv
	if _hp_label:
		_hp_label.scale = inv
	_apply_stats_bar_inverse_scale()


## Counter the parent's scale on the stats bar (so icons/labels render at
## consistent pixel size across creatures of different scale factors) and
## position the bar a fixed screen-pixel gap above the top of the creature's
## collision shape. This way taller creatures get the bar higher and shorter
## creatures get it lower — it always hugs the sprite regardless of art size.
func _apply_stats_bar_inverse_scale() -> void:
	if _stats_bar == null:
		return
	var inv: Vector2 = Vector2(1.0 / scale.x, 1.0 / scale.y)
	_stats_bar.scale = inv

	# Compute the top edge of the click area's collision shape in local space.
	# Fallback to a reasonable default if the shape isn't available yet.
	var collision_top_local: float = -20.0
	if click_area:
		var shape_node: CollisionShape2D = click_area.get_node_or_null("CollisionShape2D")
		if shape_node and shape_node.shape is RectangleShape2D:
			var rect: RectangleShape2D = shape_node.shape
			# Top-of-shape Y = shape node's local Y minus half its height.
			collision_top_local = shape_node.position.y - rect.size.y * 0.5

	# Convert the desired screen-pixel gap to local space. scale.y > 0 is
	# guaranteed after _apply_creature_scale() runs.
	var gap_local: float = STATS_BAR_WORLD_GAP / scale.y
	_stats_bar.position = Vector2(0.0, collision_top_local + gap_local)


## Read the width of the first idle animation frame to determine sprite size.
func _get_frame_width() -> float:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return 0.0
	if animated_sprite.sprite_frames.has_animation(&"idle"):
		var frame_count: int = animated_sprite.sprite_frames.get_frame_count(&"idle")
		if frame_count > 0:
			var texture: Texture2D = animated_sprite.sprite_frames.get_frame_texture(&"idle", 0)
			if texture:
				return texture.get_width()
	return 0.0


## Called at the start of the owning player's turn.
func start_turn() -> void:
	has_moved = false
	has_attacked = false
	has_used_active = false
	_tick_cooldowns()
	_tick_heavy_attack_cooldown()
	_tick_status_effects()
	check_passive_triggers(CardTypes.TriggerType.START_OF_TURN, {"creature": self})
	# Refresh the stats bar so the ult cooldown counter updates on tick.
	if _stats_bar:
		_stats_bar.refresh()


## Called at the end of the owning player's turn.
func end_turn() -> void:
	check_passive_triggers(CardTypes.TriggerType.END_OF_TURN, {"creature": self})


# =============================================================================
# Active Abilities
# =============================================================================
# Each active is a Dictionary from card_data.actives with keys:
#   "name":        String — display name
#   "cost":        int — mana cost to activate (0 = free)
#   "cooldown":    int — turns between uses (0 = usable every turn)
#   "range":       int — targeting range in hexes from creature
#   "target_rule": CardTypes.TargetRule — what can be targeted
#   "effects":     Array[Dictionary] — effects to resolve on target

## Whether a specific active ability can be used right now.
func can_use_active(ability_index: int, ctx: DuelContext) -> bool:
	if card_data == null:
		return false
	var ability: Dictionary = get_active(ability_index)
	if ability.is_empty():
		return false
	if has_used_active:
		return false
	if has_status(CardTypes.StatusEffect.STUNNED):
		return false
	if has_status(CardTypes.StatusEffect.SILENCED):
		return false

	# Check cooldown.
	var remaining_cd: int = _active_cooldowns.get(ability_index, 0)
	if remaining_cd > 0:
		return false

	# Check cost (defaults to MANA; abilities may specify "cost_type" for HEALTH, etc.).
	var cost: int = ability.get("cost", 0)
	if cost > 0:
		var cost_type: int = ability.get("cost_type", CardTypes.CostType.MANA)
		var player: Player = ctx.player if ctx else null
		if player == null or not player.can_afford(cost, cost_type):
			return false

	# Effect-specific checks.
	var effects: Array = ability.get("effects", [])
	for effect: Dictionary in effects:
		var effect_type: int = effect.get("type", -1)
		if effect_type == CardTypes.EffectType.MARK_SPAWN:
			# Don't allow marking a hex that is already a valid spawn location.
			var grid: HexGrid = ctx.board if ctx else null
			if grid:
				var tile: HexTileData = grid.get_tile(hex_position)
				if tile and tile.valid_spawn:
					return false

	return true


## Execute an active ability against the given duel context (with targets).
func use_active(ability_index: int, ctx: DuelContext) -> void:
	if not can_use_active(ability_index, ctx):
		return

	var ability: Dictionary = get_active(ability_index)

	# Pay the cost (mana by default, health if "cost_type" is set).
	var cost: int = ability.get("cost", 0)
	if cost > 0:
		var cost_type: int = ability.get("cost_type", CardTypes.CostType.MANA)
		var player: Player = ctx.player if ctx else null
		if player:
			player.pay_cost(cost, cost_type)

	# Stamp the caster on the context so effects targeting EffectTarget.CASTER
	# (self-buffs, self-heals) can find this creature.
	if ctx:
		ctx.caster = self

	# Resolve all effects in the ability.
	var effects: Array = ability.get("effects", [])
	for effect: Dictionary in effects:
		_apply_active_effect(effect, ctx)

	# Start cooldown.
	var cooldown: int = ability.get("cooldown", 0)
	_active_cooldowns[ability_index] = cooldown

	has_used_active = true
	active_used.emit(self, ability_index)

	# Play attack animation via state machine.
	if state_machine:
		state_machine.play_attack()
	elif animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(&"attack"):
		animated_sprite.play(&"attack")


## Compute valid target hexes for a specific active ability.
## Filters by range from creature position and target_rule.
func get_active_targets(ability_index: int, board: HexGrid) -> Array[Vector2i]:
	if card_data == null or board == null:
		return []
	var ability: Dictionary = get_active(ability_index)
	if ability.is_empty():
		return []
	var ability_range: int = ability.get("range", 1)
	var target_rule: int = ability.get("target_rule", CardTypes.TargetRule.ANY_ENEMY)

	# Get all hexes within range of this creature.
	var hexes_in_range: Array[Vector2i] = HexHelper.hex_range(hex_position, ability_range)

	var valid: Array[Vector2i] = []
	for coord: Vector2i in hexes_in_range:
		if not board.is_in_bounds(coord):
			continue
		var tile: HexTileData = board.get_tile(coord)
		if tile == null:
			continue
		if _matches_target_rule(tile, target_rule):
			valid.append(coord)
	return valid


## Check if a tile matches a target rule for ability targeting.
func _matches_target_rule(tile: HexTileData, target_rule: int) -> bool:
	match target_rule:
		CardTypes.TargetRule.ANY_ENEMY:
			# TODO: Check allegiance once factions are implemented.
			return tile.is_occupied() and tile.occupant != self
		CardTypes.TargetRule.ANY_ALLY:
			# TODO: Check allegiance.
			return tile.is_occupied() and tile.occupant != self
		CardTypes.TargetRule.ANY_UNIT:
			return tile.is_occupied()
		CardTypes.TargetRule.SELF:
			return tile.occupant == self
		CardTypes.TargetRule.EMPTY_HEX:
			return not tile.is_occupied() and tile.is_passable()
		CardTypes.TargetRule.ANY_HEX:
			return true
		CardTypes.TargetRule.ADJACENT_ENEMY:
			if not tile.is_occupied() or tile.occupant == self:
				return false
			return HexHelper.hex_distance(hex_position, tile.coord) == 1
		CardTypes.TargetRule.ADJACENT_ALLY:
			if not tile.is_occupied() or tile.occupant == self:
				return false
			return HexHelper.hex_distance(hex_position, tile.coord) == 1
		_:
			return tile.is_occupied()


## Apply a single effect from an active ability.
func _apply_active_effect(effect: Dictionary, ctx: DuelContext) -> void:
	var effect_type: int = effect.get("type", -1)
	match effect_type:
		CardTypes.EffectType.MARK_SPAWN:
			var grid: HexGrid = ctx.board if ctx else null
			if grid:
				grid.mark_spawn(hex_position)
		_:
			# Fallback: delegate to the unified static dispatcher so all other
			# effect types (DEAL_DAMAGE, HEAL, APPLY_STATUS, etc.) route through
			# the same code path as card-driven effects and heavy attacks.
			apply_effect(effect, ctx)


## Tick down active cooldowns. Called at start of turn.
func _tick_cooldowns() -> void:
	for i: int in _active_cooldowns:
		if _active_cooldowns[i] > 0:
			_active_cooldowns[i] -= 1


## Get the remaining cooldown for an active ability.
func get_active_cooldown(ability_index: int) -> int:
	return _active_cooldowns.get(ability_index, 0)


## Get the number of active abilities this creature has.
func active_count() -> int:
	return get_actives().size()


# =============================================================================
# Variant-aware Active/Passive Accessors
# =============================================================================
# All gameplay code that needs to read this creature's abilities should go
# through get_actives() / get_passives() rather than touching card_data /
# enemy_data directly. The accessors resolve the regular/upgraded variant
# per-entry based on `is_upgraded`, transparently supporting both the
# variant-grouped and legacy-flat schemas.

## Return this creature's currently active abilities (regular or upgraded).
## Reads from card_data (player creatures) or enemy_data (enemies).
func get_actives() -> Array:
	return CardData.resolve_variants(_raw_actives(), is_upgraded)


## Return this creature's currently active passives (regular or upgraded).
func get_passives() -> Array:
	return CardData.resolve_variants(_raw_passives(), is_upgraded)


## Fetch a single resolved active entry by index. Returns {} if out of range.
func get_active(ability_index: int) -> Dictionary:
	var list: Array = get_actives()
	if ability_index < 0 or ability_index >= list.size():
		return {}
	return list[ability_index]


## Upgrade this creature — future active/passive lookups will return the
## "upgraded" variant of each ability that defines one. Idempotent.
##
## Also flips card_data.is_upgraded so every OTHER copy of the same card
## in the player's deck (and any future summons of this card type) become
## upgraded for the rest of the run. Matches the "per-card-type, per-run"
## persistence the upgrade system was designed for.
func upgrade() -> void:
	if is_upgraded:
		return
	is_upgraded = true
	if card_data:
		card_data.is_upgraded = true
	# Refresh the overhead stats bar so any upgrade-dependent display updates.
	if _stats_bar:
		_stats_bar.refresh()


# -- Internal: source arrays --

## Raw (unresolved) actives array from whichever data resource backs this
## creature. Used internally by the accessors before variant resolution.
func _raw_actives() -> Array:
	if card_data:
		return card_data.actives
	if self is EnemyCreature:
		var ed: EnemyData = (self as EnemyCreature).enemy_data
		if ed:
			return ed.actives
	return []


## Raw (unresolved) passives array.
func _raw_passives() -> Array:
	if card_data:
		return card_data.passives
	if self is EnemyCreature:
		var ed: EnemyData = (self as EnemyCreature).enemy_data
		if ed:
			return ed.passives
	return []


# =============================================================================
# Passive Abilities
# =============================================================================
# Each passive is a Dictionary from card_data.passives with keys:
#   "name":            String — display name
#   "type":            CardTypes.PassiveType — what kind of passive
#   "trigger":         CardTypes.TriggerType — when it activates (for ON_TRIGGER type)
#   "condition":       CardTypes.Condition — optional condition to check
#   "condition_value": int/float — value for the condition check
#   "effects":         Array[Dictionary] — effects to resolve when triggered
#
# Aura-type passives (STAT_AURA, DAMAGE_AURA, HEAL_AURA) are continuous and
# checked by the board system each turn. Trigger-type passives fire in response
# to game events and are checked via check_passive_triggers().

## Check all passives for matching triggers and fire them if conditions are met.
## Called by the game event system whenever something happens. Uses the
## variant-resolved passive list so upgraded creatures fire their upgraded
## passives automatically.
func check_passive_triggers(trigger_type: CardTypes.TriggerType, context: Dictionary) -> void:
	var passives: Array = get_passives()
	if passives.is_empty():
		return
	for i: int in range(passives.size()):
		var passive: Dictionary = passives[i]
		var ptype: int = passive.get("type", -1)

		# Only ON_TRIGGER passives respond to game events.
		if ptype != CardTypes.PassiveType.ON_TRIGGER:
			continue

		var passive_trigger: int = passive.get("trigger", -1)
		if passive_trigger != trigger_type:
			continue

		# Check optional condition.
		if passive.has("condition"):
			if not _evaluate_condition(passive, context):
				continue

		# Fire the passive's effects.
		_resolve_passive(passive, context)
		passive_triggered.emit(self, i)


## Evaluate a condition dictionary against the current context.
func _evaluate_condition(passive: Dictionary, _context: Dictionary) -> bool:
	var condition: int = passive.get("condition", -1)
	var condition_value: float = passive.get("condition_value", 0.0)

	match condition:
		CardTypes.Condition.HP_BELOW_PCT:
			if max_hp <= 0:
				return false
			return (float(current_hp) / float(max_hp)) * 100.0 < condition_value
		CardTypes.Condition.HP_ABOVE_PCT:
			if max_hp <= 0:
				return false
			return (float(current_hp) / float(max_hp)) * 100.0 > condition_value
		CardTypes.Condition.HP_FULL:
			return current_hp >= max_hp
		CardTypes.Condition.HAS_STATUS:
			var status: int = passive.get("status", -1)
			return has_status(status as CardTypes.StatusEffect)
		CardTypes.Condition.LACKS_STATUS:
			var status: int = passive.get("status", -1)
			return not has_status(status as CardTypes.StatusEffect)
		CardTypes.Condition.HAS_KEYWORD:
			var keyword: int = passive.get("keyword", -1)
			return card_data != null and (keyword as CardTypes.Keyword) in card_data.keywords
		CardTypes.Condition.IS_ROLE:
			var role: int = passive.get("role", -1)
			return card_data != null and card_data.role == role
		_:
			# Unhandled condition — default to true so the passive still fires.
			return true


## Resolve a passive's effects.
func _resolve_passive(passive: Dictionary, context: Dictionary) -> void:
	var effects: Array = passive.get("effects", [])
	for effect: Dictionary in effects:
		_apply_passive_effect(effect, context)


## Apply a single effect from a passive ability.
func _apply_passive_effect(_effect: Dictionary, _context: Dictionary) -> void:
	# TODO: Dispatch to the effect system based on effect["type"].
	pass


## Get all aura-type passives for continuous board evaluation.
## Returns an array of passive dictionaries with their index. Uses the
## variant-resolved passive list so upgraded auras expose their upgraded
## stat values to the board.
func get_aura_passives() -> Array[Dictionary]:
	var passives: Array = get_passives()
	if passives.is_empty():
		return []
	var auras: Array[Dictionary] = []
	for i: int in range(passives.size()):
		var passive: Dictionary = passives[i]
		var ptype: int = passive.get("type", -1)
		match ptype:
			CardTypes.PassiveType.STAT_AURA, \
			CardTypes.PassiveType.DAMAGE_AURA, \
			CardTypes.PassiveType.HEAL_AURA:
				var entry: Dictionary = passive.duplicate()
				entry["_index"] = i
				auras.append(entry)
	return auras


# =============================================================================
# Combat
# =============================================================================

## Apply damage using consumable armor model. Armor absorbs damage first,
## remaining damage hits HP. Returns total damage dealt (armor + HP).
func take_damage(amount: int, p_damage_type: CardTypes.DamageType = CardTypes.DamageType.PHYSICAL) -> int:
	var armor_absorbed: int = 0
	if p_damage_type == CardTypes.DamageType.PHYSICAL and current_armor > 0:
		armor_absorbed = mini(amount, current_armor)
		current_armor -= armor_absorbed
		armor_changed.emit(self, current_armor)
	var hp_damage: int = amount - armor_absorbed
	current_hp -= hp_damage
	damaged.emit(self, amount)

	# Trigger ON_DAMAGED passives.
	check_passive_triggers(CardTypes.TriggerType.ON_DAMAGED, {
		"creature": self, "damage": amount, "damage_type": p_damage_type,
	})

	# Play hurt animation via state machine.
	if state_machine and current_hp > 0:
		state_machine.play_hurt()
	elif animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(&"hurt"):
		animated_sprite.play(&"hurt")

	if current_hp <= 0:
		current_hp = 0
		_on_death()
	return amount


## Execute an attack against a target creature.
## Walks to the target, plays attack animation, applies damage, walks back.
## Does NOT consume movement — this is a cosmetic approach animation.
## Returns the damage dealt.
func perform_attack(target: Creature, hex_grid: HexGrid) -> int:
	if not can_attack() or not target.is_alive():
		return 0

	has_attacked = true
	var home_pos: Vector2 = position

	# Flip sprite to face the target. Ranged units fire in place so they
	# only need this one flip; melee units approach and return.
	var dir: Vector2 = target.position - position
	if animated_sprite and dir.x != 0.0:
		animated_sprite.flip_h = dir.x < 0.0

	var is_ranged: bool = is_ranged_attacker()

	# -- Melee-only: walk up to the target before swinging --
	if not is_ranged:
		var approach_offset: float = 30.0
		var approach_pos: Vector2 = target.position + (home_pos - target.position).normalized() * approach_offset

		if state_machine:
			state_machine.play_walk()
		var walk_tween: Tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		walk_tween.tween_property(self, "position", approach_pos, 0.35)
		await walk_tween.finished
		if state_machine:
			state_machine.stop_walking()

	# Play attack animation and wait for the hit frame. Randomly cycle
	# between attack01 and attack02 when both exist to add visual variety.
	# Applies to both melee and ranged — ranged units fire from home_pos.
	if state_machine:
		state_machine.play_attack(_pick_basic_attack_anim())
		await state_machine.attack_hit

	# Guard: target may have died from another source between anim start and hit.
	var actual_damage: int = 0
	if target.is_alive():
		actual_damage = target.take_damage(current_atk, damage_type)

		# If the target died, clear tile occupancy.
		if not target.is_alive():
			hex_grid.remove_creature(target.hex_position)

	# Wait for attack animation to finish.
	if state_machine and state_machine.current_state == CreatureStateMachine.State.ATTACKING:
		await state_machine.animation_finished

	# -- Melee-only: walk back to home position after the swing --
	if not is_ranged:
		if state_machine:
			state_machine.play_walk()
		# Flip sprite for the return trip.
		if animated_sprite:
			animated_sprite.flip_h = not animated_sprite.flip_h
		var return_tween: Tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		return_tween.tween_property(self, "position", home_pos, 0.35)
		await return_tween.finished
		if state_machine:
			state_machine.stop_walking()

	# Restore the sprite's default facing as set at init time.
	if animated_sprite:
		animated_sprite.flip_h = _default_sprite_flip_h

	return actual_damage


# =============================================================================
# Heavy / Special Attack
# =============================================================================

## Inspect the creature's SpriteFrames for a heavy-attack animation and
## flag `has_heavy_attack` accordingly. Accepts either a single-phase
## "heavy_attack" animation or a multi-phase "heavy_attack_start"+loop+end
## sequence (minotaur-style). Called once from initialize().
func _detect_heavy_attack_support() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		has_heavy_attack = false
		return
	var sf: SpriteFrames = animated_sprite.sprite_frames
	has_heavy_attack = sf.has_animation(&"heavy_attack") or sf.has_animation(&"heavy_attack_start")


## Whether the creature can fire its heavy attack right now.
## Requires heavy-attack support + 0 cooldown remaining + off-status gates.
func can_use_heavy_attack() -> bool:
	if not has_heavy_attack:
		return false
	if heavy_attack_cd_remaining > 0:
		return false
	if has_status(CardTypes.StatusEffect.STUNNED):
		return false
	if not can_attack():
		return false
	return true


## Reset the heavy-attack cooldown. Reads the per-creature cooldown from
## the heavy_attack spec (falling back to HEAVY_ATTACK_COOLDOWN if unset).
## Call after the heavy attack fires.
func start_heavy_attack_cooldown() -> void:
	heavy_attack_cd_remaining = _heavy_attack_cooldown_value()


## Look up this creature's heavy-attack cooldown length in turns.
func _heavy_attack_cooldown_value() -> int:
	var spec: Dictionary = _get_heavy_attack_spec()
	return spec.get("cooldown", HEAVY_ATTACK_COOLDOWN)


## Tick the heavy-attack cooldown down by one (called from start_turn).
func _tick_heavy_attack_cooldown() -> void:
	if heavy_attack_cd_remaining > 0:
		heavy_attack_cd_remaining -= 1


# =============================================================================
# Static Effect Dispatcher
# =============================================================================
# Creatures own all state-mutation logic — damage, heal, status, etc. Cards
# are pure data; when a card resolves, it hands its effect list to this
# dispatcher. Creature heavy attacks do the same. Keeping the dispatcher
# here ensures there's one authoritative place that knows how to turn an
# effect dictionary into a state change on a target.

## Apply a list of effect dictionaries in order.
static func apply_effect_list(effects: Array, ctx: DuelContext) -> void:
	for effect: Dictionary in effects:
		apply_effect(effect, ctx)


## Apply a single effect dictionary. Resolves the effect target(s) from the
## duel context and dispatches to the appropriate Creature mutation method.
static func apply_effect(effect: Dictionary, ctx: DuelContext) -> void:
	var effect_type: int = effect.get("type", -1)
	var targets: Array[Creature] = resolve_effect_targets(effect, ctx)

	match effect_type:
		CardTypes.EffectType.DEAL_DAMAGE:
			var value: int = effect.get("value", 0)
			var dmg_type: int = effect.get("damage_type", CardTypes.DamageType.PHYSICAL)
			for creature: Creature in targets:
				if creature.is_alive():
					creature.take_damage(value, dmg_type as CardTypes.DamageType)

		CardTypes.EffectType.HEAL:
			var value: int = effect.get("value", 0)
			for creature: Creature in targets:
				if creature.is_alive():
					creature.heal(value)

		CardTypes.EffectType.MODIFY_STAT:
			var stat: int = effect.get("stat", -1)
			var value: int = effect.get("value", 0)
			for creature: Creature in targets:
				if creature.is_alive():
					match stat:
						CardTypes.Stat.ATK:
							creature.modify_atk(value)
						CardTypes.Stat.ARMOR:
							creature.modify_armor(value)
						CardTypes.Stat.HP, CardTypes.Stat.MAX_HP:
							creature.heal(value) if value > 0 else creature.take_damage(-value)

		CardTypes.EffectType.APPLY_STATUS:
			var status: int = effect.get("status", -1)
			# BURNING defaults to 3 turns; other statuses default to 1 if unspecified.
			var default_duration: int = 3 if status == CardTypes.StatusEffect.BURNING else 1
			var duration_turns: int = effect.get("duration_turns", default_duration)
			if status >= 0:
				for creature: Creature in targets:
					if creature.is_alive():
						creature.apply_status(status as CardTypes.StatusEffect, duration_turns)

		CardTypes.EffectType.REMOVE_STATUS:
			var status: int = effect.get("status", -1)
			if status >= 0:
				for creature: Creature in targets:
					creature.remove_status(status as CardTypes.StatusEffect)

		CardTypes.EffectType.CLEANSE:
			for creature: Creature in targets:
				if creature.has_method("cleanse"):
					creature.cleanse()

		CardTypes.EffectType.SHIELD:
			var value: int = effect.get("value", 0)
			for creature: Creature in targets:
				if creature.is_alive():
					creature.modify_armor(value)

		CardTypes.EffectType.DRAW_CARD:
			# Drawing is player-level, not creature-level.
			var value: int = effect.get("value", 1)
			var player: Player = ctx.player if ctx else null
			if player and player.has_method("draw_cards"):
				player.draw_cards(value)

		CardTypes.EffectType.STUN:
			for creature: Creature in targets:
				if creature.is_alive():
					creature.apply_status(CardTypes.StatusEffect.STUNNED, 1)

		CardTypes.EffectType.SILENCE:
			for creature: Creature in targets:
				if creature.is_alive():
					creature.apply_status(CardTypes.StatusEffect.SILENCED, 1)

		CardTypes.EffectType.PUSH:
			# TODO: Displacement effects require hex grid pathfinding.
			pass

		CardTypes.EffectType.PULL:
			# TODO: Displacement effects require hex grid pathfinding.
			pass

		CardTypes.EffectType.MARK_SPAWN:
			var board: HexGrid = ctx.board if ctx else null
			var target_hexes: Array = ctx.target_hexes if ctx else []
			if board and not target_hexes.is_empty():
				board.mark_spawn(target_hexes[0])

		CardTypes.EffectType.DESTROY:
			for creature: Creature in targets:
				if creature.is_alive():
					creature.take_damage(creature.current_hp)

		CardTypes.EffectType.EXECUTE:
			var threshold_pct: int = effect.get("value", 0)
			for creature: Creature in targets:
				if creature.is_alive():
					var pct: float = (float(creature.current_hp) / float(creature.max_hp)) * 100.0
					if pct <= threshold_pct:
						creature.take_damage(creature.current_hp)

		_:
			push_warning("Creature.apply_effect: unhandled effect type %d" % effect_type)


## Resolve which creatures are targeted by a single effect.
##
## Supports these optional effect fields for AoE-style abilities:
##   "aoe_radius":             int  — limits ALL_*_IN_AREA results by hex distance.
##   "aoe_center":             String — "caster" uses the caster's hex as center;
##                                    otherwise defaults to target_hexes[0].
##   "max_targets":            int  — caps result size; -1 = no cap.
##   "exclude_primary_target": bool — drops target_hexes[0]'s occupant.
static func resolve_effect_targets(effect: Dictionary, ctx: DuelContext) -> Array[Creature]:
	var result: Array[Creature] = []
	if ctx == null:
		return result
	var board: HexGrid = ctx.board
	var target_hexes: Array = ctx.target_hexes
	var effect_target: int = effect.get("target", CardTypes.EffectTarget.SELECTED)

	if board == null:
		return result

	# Pick the AoE center hex for ALL_*_IN_AREA effects.
	var aoe_center: Vector2i = Vector2i(-1, -1)
	if effect.get("aoe_center", "") == "caster" and ctx.caster:
		aoe_center = ctx.caster.hex_position
	elif not target_hexes.is_empty():
		aoe_center = target_hexes[0]
	var aoe_radius: int = effect.get("aoe_radius", -1)

	match effect_target:
		CardTypes.EffectTarget.SELECTED:
			for hex: Vector2i in target_hexes:
				var tile: HexTileData = board.get_tile(hex)
				if tile and tile.is_occupied() and tile.occupant is Creature:
					result.append(tile.occupant as Creature)

		CardTypes.EffectTarget.CASTER:
			if ctx.caster:
				result.append(ctx.caster)

		CardTypes.EffectTarget.ALL_IN_AREA:
			for coord: Vector2i in board.tiles:
				var tile: HexTileData = board.tiles[coord]
				if not tile.is_occupied() or not tile.occupant is Creature:
					continue
				if _passes_aoe_filter(coord, aoe_center, aoe_radius):
					result.append(tile.occupant as Creature)

		CardTypes.EffectTarget.ALL_ENEMIES_IN_AREA:
			for coord: Vector2i in board.tiles:
				var tile: HexTileData = board.tiles[coord]
				if not tile.is_occupied() or not tile.occupant is Creature:
					continue
				var creature: Creature = tile.occupant as Creature
				var is_opposing: bool = _is_opposing_side(creature, ctx)
				if is_opposing and _passes_aoe_filter(coord, aoe_center, aoe_radius):
					result.append(creature)

		CardTypes.EffectTarget.ALL_ALLIES_IN_AREA:
			for coord: Vector2i in board.tiles:
				var tile: HexTileData = board.tiles[coord]
				if not tile.is_occupied() or not tile.occupant is Creature:
					continue
				var creature: Creature = tile.occupant as Creature
				var is_opposing: bool = _is_opposing_side(creature, ctx)
				if not is_opposing and _passes_aoe_filter(coord, aoe_center, aoe_radius):
					result.append(creature)

		_:
			for hex: Vector2i in target_hexes:
				var tile: HexTileData = board.get_tile(hex)
				if tile and tile.is_occupied() and tile.occupant is Creature:
					result.append(tile.occupant as Creature)

	if effect.get("exclude_primary_target", false) and not target_hexes.is_empty():
		var primary_tile: HexTileData = board.get_tile(target_hexes[0])
		if primary_tile and primary_tile.is_occupied():
			result.erase(primary_tile.occupant as Creature)

	var max_targets: int = effect.get("max_targets", -1)
	if max_targets >= 0 and result.size() > max_targets:
		result.resize(max_targets)

	return result


## Whether a hex passes the AoE radius filter.
static func _passes_aoe_filter(coord: Vector2i, center: Vector2i, radius: int) -> bool:
	if radius < 0:
		return true
	if center == Vector2i(-1, -1):
		return true
	return HexHelper.hex_distance(coord, center) <= radius


## Whether a creature is on the opposite side from the effect's caster.
## Without a caster (hand-played spell), falls back to treating EnemyCreatures
## as the opposing side.
static func _is_opposing_side(creature: Creature, ctx: DuelContext) -> bool:
	if ctx.caster:
		return ctx.caster.is_enemy() != creature.is_enemy()
	return creature.is_enemy()


## Execute this creature's heavy (special) attack against a target hex.
## Reads the heavy_attack dict from card_data / enemy_data, plays the
## appropriate animation (single or multi-phase), dispatches effects +
## self_effects via the shared Card.apply_effect_list() dispatcher, and
## starts the cooldown.
##
## Returns total damage dealt to the primary selected target (if any),
## for use by callers that want to log or react to the result.
func perform_heavy_attack(target_hex: Vector2i, hex_grid: HexGrid, ctx: DuelContext) -> int:
	if not can_use_heavy_attack():
		return 0

	var spec: Dictionary = _get_heavy_attack_spec()
	if spec.is_empty():
		return 0

	has_attacked = true

	# Face the target for single-target flavor attacks.
	if animated_sprite and target_hex != hex_position:
		var world_target: Vector2 = HexHelper.hex_to_world(target_hex, hex_grid.hex_size)
		var dir: Vector2 = world_target - position
		if dir.x != 0.0:
			animated_sprite.flip_h = dir.x < 0.0

	# Play the animation. Multi-phase (start → loop → end) for creatures
	# like the Minotaur; single-phase for the rest.
	var anim_sequence: Array = spec.get("animation_sequence", [])
	if anim_sequence.size() >= 3 and state_machine:
		await _play_heavy_attack_sequence(anim_sequence)
	elif state_machine:
		var anim_name: StringName = spec.get("animation", &"heavy_attack")
		state_machine.play_attack(anim_name)
		await state_machine.attack_hit

	# Stamp caster + target onto the context for effect resolution.
	if ctx:
		ctx.set_targets([target_hex], [], self)

	# Resolve primary effects, then self_effects (which always target CASTER).
	var effects: Array = spec.get("effects", [])
	apply_effect_list(effects, ctx)

	var self_effects: Array = spec.get("self_effects", [])
	if not self_effects.is_empty():
		# Self-effects always resolve on the caster regardless of their
		# "target" field. Force it to CASTER so existing dispatch works.
		var rebound: Array = []
		for e: Dictionary in self_effects:
			var copy: Dictionary = e.duplicate()
			copy["target"] = CardTypes.EffectTarget.CASTER
			rebound.append(copy)
		apply_effect_list(rebound, ctx)

	# Tally damage dealt to the primary target, if any.
	var primary_damage: int = 0
	var primary_tile: HexTileData = hex_grid.get_tile(target_hex)
	if primary_tile and primary_tile.is_occupied() and primary_tile.occupant is Creature:
		# Best-effort — real damage number was already applied inside
		# creature.take_damage(). Caller can read primary.current_hp if
		# exact accounting is needed.
		primary_damage = 1

	# Start cooldown and refresh UI.
	start_heavy_attack_cooldown()
	if _stats_bar:
		_stats_bar.refresh()

	# Wait for animation finish for visual completeness.
	if state_machine and state_machine.current_state == CreatureStateMachine.State.ATTACKING:
		await state_machine.animation_finished

	# Clear transient context state we stamped.
	if ctx:
		ctx.clear_transient()

	return primary_damage


## Play a multi-phase heavy-attack sequence (e.g. minotaur start → loop → end).
##
## This drives the AnimatedSprite2D directly instead of routing every phase
## through the state machine, for two reasons:
##
##   1. Some phases (like the Minotaur's spin loop) have loop=true on their
##      SpriteFrames entry. Godot never emits animation_finished for looping
##      animations, so awaiting the state machine's animation_finished would
##      hang forever. We drive those phases off a frame-count timer instead.
##
##   2. The state machine's transition_to() early-returns on same-state
##      transitions. Calling state_machine.play_attack() while already in
##      ATTACKING leaves the previous sprite animation playing. We'd never
##      advance past the middle phase.
##
## We enter ATTACKING once at the start and let the state machine exit back
## to IDLE naturally when the final (non-looping) phase's sprite animation
## finishes. Effects fire at the impact moment of the final phase.
func _play_heavy_attack_sequence(sequence: Array) -> void:
	if state_machine == null or animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var sf: SpriteFrames = animated_sprite.sprite_frames

	# Enter ATTACKING state once (plays phase 1 via the state machine so
	# has_used_active, click gating, etc. all see ATTACKING correctly).
	state_machine.play_attack(sequence[0])
	# Phase 1 is non-looping — wait for its sprite animation to finish.
	await animated_sprite.animation_finished
	# Completing phase 1 causes the state machine's _on_sprite_animation_finished
	# to transition us back to IDLE. That's expected; subsequent phases play
	# the sprite directly, keeping the state machine out of the way.

	# Phase 2: spin loop. Bypass the state machine and play directly.
	if sf.has_animation(sequence[1]):
		animated_sprite.play(sequence[1])
		await get_tree().create_timer(_anim_duration(sequence[1])).timeout

	# Phase 3: impact. Play directly; wait ~until the hit frame (~1/3 through)
	# so the caller can apply effects in sync with the visual impact. The
	# remaining frames play out on their own after this function returns.
	if sf.has_animation(sequence[2]):
		animated_sprite.play(sequence[2])
		var hit_delay: float = _anim_duration(sequence[2]) * 0.33
		await get_tree().create_timer(hit_delay).timeout


## Return the duration in seconds of a named animation on this creature's
## SpriteFrames. Returns 0 if the animation doesn't exist or has no speed.
func _anim_duration(anim_name: StringName) -> float:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return 0.0
	var sf: SpriteFrames = animated_sprite.sprite_frames
	if not sf.has_animation(anim_name):
		return 0.0
	var count: int = sf.get_frame_count(anim_name)
	var speed: float = sf.get_animation_speed(anim_name)
	if speed <= 0.0:
		return 0.0
	return float(count) / speed


## Look up the heavy_attack dict from whichever data resource backs this
## creature (CardData for summoned creatures, EnemyData for enemies).
## Returns empty dict if the creature has no heavy attack.
func _get_heavy_attack_spec() -> Dictionary:
	# Enemies read from enemy_data; player creatures read from card_data.
	# Both fields are Dictionary so we can probe either without type errors.
	if self is EnemyCreature:
		var enemy_data: EnemyData = (self as EnemyCreature).enemy_data
		if enemy_data:
			return enemy_data.heavy_attack
	if card_data and &"heavy_attack" in card_data:
		var spec: Variant = card_data.get(&"heavy_attack")
		if spec is Dictionary:
			return spec
	return {}


## Whether this creature is a ranged attacker — true if attack_range > 1
## OR if it carries the RANGED keyword. Drives the perform_attack() branch
## that skips the approach/return walk, so archers/mages fire in place
## instead of walking into melee range every turn.
func is_ranged_attacker() -> bool:
	if attack_range > 1:
		return true
	# Keywords live on either CardData or EnemyData depending on unit type.
	if card_data and CardTypes.Keyword.RANGED in card_data.keywords:
		return true
	if self is EnemyCreature:
		var ed: EnemyData = (self as EnemyCreature).enemy_data
		if ed and CardTypes.Keyword.RANGED in ed.keywords:
			return true
	return false


## Randomly pick between attack01 and attack02 for basic-attack visual variety.
## Falls back to attack01 alone if attack02 isn't in this creature's SpriteFrames.
func _pick_basic_attack_anim() -> StringName:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return &"attack01"
	var sf: SpriteFrames = animated_sprite.sprite_frames
	var has01: bool = sf.has_animation(&"attack01")
	var has02: bool = sf.has_animation(&"attack02")
	if has01 and has02:
		return &"attack02" if randf() < 0.5 else &"attack01"
	if has02 and not has01:
		return &"attack02"
	return &"attack01"


## Restore HP, clamped to max.
func heal(amount: int) -> void:
	var actual: int = mini(amount, max_hp - current_hp)
	if actual > 0:
		current_hp += actual
		healed.emit(self, actual)
		check_passive_triggers(CardTypes.TriggerType.ON_HEALED, {
			"creature": self, "heal": actual,
		})


## Modify ATK by a delta (positive = buff, negative = debuff).
func modify_atk(delta: int) -> void:
	current_atk = maxi(current_atk + delta, 0)
	atk_changed.emit(self, current_atk)


## Modify armor by a delta.
func modify_armor(delta: int) -> void:
	current_armor = maxi(current_armor + delta, 0)
	armor_changed.emit(self, current_armor)


# =============================================================================
# Movement
# =============================================================================

## Move this creature to a new hex with walk animation and tween.
## The creature plays the walk animation, tweens to the destination,
## then returns to idle.
## Move this creature to a new hex with walk animation and tween.
##
## If `ctx` is provided, fires deployable on_creature_exit / on_creature_enter
## hooks at the old and new hex so objects on tiles can react to the movement
## (e.g. the Axed Marauder stepping back onto his own thrown axe picks it up).
func move_to(new_hex: Vector2i, hex_size: float, ctx: DuelContext = null) -> void:
	var old_hex: Vector2i = hex_position

	# Fire exit hooks at the old hex BEFORE updating hex_position so the
	# deployable sees the creature still on its tile during the callback.
	if ctx and ctx.deployables:
		for d: DuelDeployable in ctx.deployables.at_hex(old_hex):
			d.on_creature_exit(self, ctx)

	hex_position = new_hex
	has_moved = true

	var target_pos: Vector2 = HexHelper.hex_to_world(new_hex, hex_size) + Vector2(0, HexTileRenderer.DEPTH_OFFSET)

	# Flip sprite to face movement direction.
	var direction: Vector2 = target_pos - position
	if animated_sprite and direction.x != 0.0:
		animated_sprite.flip_h = direction.x < 0.0

	# Play walk animation via state machine.
	if state_machine:
		state_machine.play_walk()

	# Tween to the target position.
	var tween: Tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "position", target_pos, 0.4)
	await tween.finished

	# Stop walking, return to idle.
	if state_machine:
		state_machine.stop_walking()

	# Update z-order for new row (see initialize() for band rationale).
	z_index = HexTileRenderer.Z_BAND_OBJECTS + new_hex.y * 3 + 2

	moved.emit(self, old_hex, new_hex)
	check_passive_triggers(CardTypes.TriggerType.ON_MOVE, {
		"creature": self, "from_hex": old_hex, "to_hex": new_hex,
	})

	# Fire enter hooks at the new hex AFTER the move lands. A deployable's
	# on_creature_enter can call pick_up(self, ctx) to remove itself from
	# the board — that's the axe pickup flow.
	if ctx and ctx.deployables:
		# Duplicate the list since pickup mutates the registry during iteration.
		for d: DuelDeployable in ctx.deployables.at_hex(new_hex).duplicate():
			d.on_creature_enter(self, ctx)


# =============================================================================
# Status Effects
# =============================================================================

## Apply a status effect for a number of turns (-1 = permanent).
func apply_status(effect: CardTypes.StatusEffect, duration: int = 1) -> void:
	status_effects[effect] = duration
	status_applied.emit(self, effect)
	check_passive_triggers(CardTypes.TriggerType.ON_STATUS_GAIN, {
		"creature": self, "status": effect,
	})


## Remove a status effect.
func remove_status(effect: CardTypes.StatusEffect) -> void:
	if status_effects.has(effect):
		status_effects.erase(effect)
		status_removed.emit(self, effect)
		check_passive_triggers(CardTypes.TriggerType.ON_STATUS_LOSE, {
			"creature": self, "status": effect,
		})


## Whether this creature has a given status effect.
func has_status(effect: CardTypes.StatusEffect) -> bool:
	return status_effects.has(effect)


## Tick down status durations. Called at start of turn.
## Also applies per-turn damage-over-time effects (BURNING, POISONED, BLEEDING).
## By default these deal 1 HP each tick — can be extended later with
## per-creature intensity stacking.
func _tick_status_effects() -> void:
	# -- Damage-over-time effects: apply damage before decrementing duration --
	if has_status(CardTypes.StatusEffect.BURNING):
		take_damage(1, CardTypes.DamageType.FIRE)
	if has_status(CardTypes.StatusEffect.POISONED):
		take_damage(1, CardTypes.DamageType.POISON)
	# BLEEDING is documented as movement-based ("takes damage when moving"),
	# so we intentionally do NOT tick it here — it fires from the movement path.

	# Early exit if the DoT killed us — no point ticking further.
	if not is_alive():
		return

	var expired: Array[CardTypes.StatusEffect] = []
	for effect: CardTypes.StatusEffect in status_effects:
		var remaining: int = status_effects[effect]
		if remaining > 0:
			status_effects[effect] = remaining - 1
			if remaining - 1 <= 0:
				expired.append(effect)
		# -1 = permanent, don't decrement.
	for effect: CardTypes.StatusEffect in expired:
		remove_status(effect)


# =============================================================================
# Queries
# =============================================================================

## Whether this creature can still move this turn.
func can_move() -> bool:
	if has_moved:
		return false
	if has_status(CardTypes.StatusEffect.STUNNED):
		return false
	if has_status(CardTypes.StatusEffect.FROZEN):
		return false
	return current_move_range > 0


## Whether this creature can still attack this turn.
func can_attack() -> bool:
	if has_attacked:
		return false
	if has_status(CardTypes.StatusEffect.STUNNED):
		return false
	if has_status(CardTypes.StatusEffect.PHASED):
		return false
	return current_atk > 0


## Whether this creature is alive.
func is_alive() -> bool:
	return current_hp > 0


## Whether this creature belongs to the enemy side.
func is_enemy() -> bool:
	return self is EnemyCreature


## Whether this creature is hostile to another creature.
func is_hostile_to(other: Creature) -> bool:
	return is_enemy() != other.is_enemy()


## Whether this creature is friendly to another creature.
func is_friendly_to(other: Creature) -> bool:
	return is_enemy() == other.is_enemy()


# =============================================================================
# Animation Helpers
# =============================================================================

## Called when the state machine's attack animation reaches the hit frame.
## Override in subclasses for custom hit behavior (VFX, damage application, etc.).
func _on_attack_hit() -> void:
	# Base implementation — damage is applied by the combat system, not here.
	# This hook exists for VFX/SFX timing.
	pass


## Play a named animation if it exists in the sprite frames.
func play_anim(anim_name: StringName) -> void:
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)


## Play a property animation from the AnimationPlayer if it exists.
func play_effect_anim(anim_name: StringName) -> void:
	if anim_player.has_animation(anim_name):
		anim_player.play(anim_name)


# =============================================================================
# Death
# =============================================================================

func _on_death() -> void:
	check_passive_triggers(CardTypes.TriggerType.ON_DEATH, {"creature": self})
	died.emit(self)

	# Play death animation via state machine, wait for DEAD state, then remove.
	if state_machine:
		state_machine.play_death()
		# Wait for the death animation to finish (state machine emits animation_finished).
		await state_machine.animation_finished
		# Play fade-out effect if available.
		play_effect_anim(&"fade_out")
		if anim_player.has_animation(&"fade_out"):
			await anim_player.animation_finished
	elif animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(&"death"):
		animated_sprite.play(&"death")
		await animated_sprite.animation_finished
	queue_free()
