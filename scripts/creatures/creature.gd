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

## Label showing current HP / max HP below the name label.
@onready var _hp_label: Label = $HPLabel


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

	# Initialize cooldowns for all actives at 0 (ready to use).
	for i: int in range(data.actives.size()):
		_active_cooldowns[i] = 0

	# Position on the grid. Add DEPTH_OFFSET to match 2.5D tile positioning.
	hex_position = hex
	position = HexHelper.hex_to_world(hex, hex_size) + Vector2(0, HexTileRenderer.DEPTH_OFFSET)

	# Z-order: creatures render above ground and middle tiles at the same row.
	z_index = hex.y * 3 + 2

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

## Populate the overhead name and HP labels with current values.
func _create_overhead_labels() -> void:
	if _name_label:
		_name_label.text = creature_name
	_update_hp_label()

	# Connect signals to auto-update the HP label.
	damaged.connect(_on_hp_changed)
	healed.connect(_on_hp_changed)


## Update the HP label text.
func _update_hp_label() -> void:
	if _hp_label:
		_hp_label.text = "%d / %d" % [current_hp, max_hp]


## Called when HP changes from damage or healing.
func _on_hp_changed(_creature: Creature, _amount: int) -> void:
	_update_hp_label()


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
	_tick_status_effects()
	check_passive_triggers(CardTypes.TriggerType.START_OF_TURN, {"creature": self})


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
	if ability_index < 0 or ability_index >= card_data.actives.size():
		return false
	if has_used_active:
		return false
	if has_status(CardTypes.StatusEffect.STUNNED):
		return false
	if has_status(CardTypes.StatusEffect.SILENCED):
		return false

	var ability: Dictionary = card_data.actives[ability_index]

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

	var ability: Dictionary = card_data.actives[ability_index]

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
	if ability_index < 0 or ability_index >= card_data.actives.size():
		return []

	var ability: Dictionary = card_data.actives[ability_index]
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
			# TODO: Dispatch remaining effect types (DEAL_DAMAGE, HEAL, etc.).
			# When implemented, reuse Card._resolve_effect_targets + dispatch logic.
			pass


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
	if card_data == null:
		return 0
	return card_data.actives.size()


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
## Called by the game event system whenever something happens.
func check_passive_triggers(trigger_type: CardTypes.TriggerType, context: Dictionary) -> void:
	if card_data == null:
		return
	for i: int in range(card_data.passives.size()):
		var passive: Dictionary = card_data.passives[i]
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
## Returns an array of passive dictionaries with their index.
func get_aura_passives() -> Array[Dictionary]:
	if card_data == null:
		return []
	var auras: Array[Dictionary] = []
	for i: int in range(card_data.passives.size()):
		var passive: Dictionary = card_data.passives[i]
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

	# Flip sprite to face the target.
	var dir: Vector2 = target.position - position
	if animated_sprite and dir.x != 0.0:
		animated_sprite.flip_h = dir.x < 0.0

	# Walk to the target — stop adjacent to the target sprite.
	var approach_offset: float = 30.0
	var approach_pos: Vector2 = target.position + (home_pos - target.position).normalized() * approach_offset

	if state_machine:
		state_machine.play_walk()
	var walk_tween: Tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	walk_tween.tween_property(self, "position", approach_pos, 0.35)
	await walk_tween.finished
	if state_machine:
		state_machine.stop_walking()

	# Play attack animation and wait for the hit frame.
	if state_machine:
		state_machine.play_attack()
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

	# Walk back to home position.
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

	# Restore default sprite facing.
	if is_enemy() and animated_sprite:
		animated_sprite.flip_h = true
	elif not is_enemy() and animated_sprite:
		animated_sprite.flip_h = false

	return actual_damage


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


## Modify armor by a delta.
func modify_armor(delta: int) -> void:
	current_armor = maxi(current_armor + delta, 0)


# =============================================================================
# Movement
# =============================================================================

## Move this creature to a new hex with walk animation and tween.
## The creature plays the walk animation, tweens to the destination,
## then returns to idle.
func move_to(new_hex: Vector2i, hex_size: float) -> void:
	var old_hex: Vector2i = hex_position
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
	tween.tween_property(self, "position", target_pos, 1.5)  # DEBUG: was 0.4
	await tween.finished

	# Stop walking, return to idle.
	if state_machine:
		state_machine.stop_walking()

	# Update z-order for new row.
	z_index = new_hex.y * 3 + 2

	moved.emit(self, old_hex, new_hex)
	check_passive_triggers(CardTypes.TriggerType.ON_MOVE, {
		"creature": self, "from_hex": old_hex, "to_hex": new_hex,
	})


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
func _tick_status_effects() -> void:
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
