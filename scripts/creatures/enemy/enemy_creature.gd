## Enemy creature — extends base Creature for AI-controlled enemies.
## Enemies are not summoned through cards. They spawn at battle start
## or via elite enemy / tower abilities during combat.
##
## Adds intent system (Slay the Spire style) showing planned next action
## above the creature's head, plus enemy-specific initialization from EnemyData.
class_name EnemyCreature
extends Creature

# =============================================================================
# Intent System
# =============================================================================

## Possible intents an enemy can telegraph.
enum Intent {
	NONE,       ## No intent shown (e.g., freshly spawned).
	ATTACK,     ## Will attack a target.
	MOVE,       ## Will move toward a target.
	DEFEND,     ## Will block or gain armor.
	ABILITY,    ## Will use an active ability.
	SPAWN,      ## Will summon additional enemies.
	BUFF,       ## Will buff self or allies.
	DEBUFF,     ## Will apply a debuff to player creatures.
}

## Current telegraphed intent.
var current_intent: Intent = Intent.NONE

## Numeric value shown with the intent (e.g., attack damage amount).
var intent_value: int = 0

## The EnemyData this creature was spawned from.
var enemy_data: EnemyData

## Whether this is an elite enemy.
var is_elite: bool = false

## Label node for displaying intent above the creature.
@onready var _intent_label: Label = $IntentLabel


# =============================================================================
# Initialization
# =============================================================================

## Set up this enemy from EnemyData and place it at a hex coordinate.
## Mirrors Creature.initialize() but uses EnemyData instead of CardData.
func initialize_enemy(data: EnemyData, hex: Vector2i, hex_size: float) -> void:
	enemy_data = data
	creature_name = data.display_name
	is_elite = data.is_elite

	# Set base and live stats.
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

	# Position on the grid.
	hex_position = hex
	position = HexHelper.hex_to_world(hex, hex_size) + Vector2(0, HexTileRenderer.DEPTH_OFFSET)

	# Z-order: enemies sit in the objects band alongside player creatures
	# (see HexTileRenderer.Z_BAND_OBJECTS) so ground tiles never overlap
	# them regardless of row. Row-based sub-sort preserves the 2.5D feel.
	z_index = HexTileRenderer.Z_BAND_OBJECTS + hex.y * 3 + 2

	# Scale the creature to fit the hex.
	_apply_creature_scale(hex_size)

	# Apply inverse scale to intent label so it renders at native resolution.
	if _intent_label and scale.x != 0.0:
		_intent_label.scale = Vector2(1.0 / scale.x, 1.0 / scale.y)

	# Orient the sprite to face the player. Most sprite sheets are authored
	# facing right, so flipping horizontally points them at the player's
	# side of the board (left). Art that's already drawn facing left (e.g.
	# Minotaur) sets sprite_faces_left=true and skips the flip. We cache
	# the resting value so perform_attack() can restore it after its
	# approach-and-return animation.
	_default_sprite_flip_h = not data.sprite_faces_left
	if animated_sprite:
		animated_sprite.flip_h = _default_sprite_flip_h

	# Initialize the state machine.
	if state_machine:
		state_machine.setup(animated_sprite)
		state_machine.attack_hit.connect(_on_attack_hit)
	else:
		if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(&"idle"):
			animated_sprite.play(&"idle")

	# Detect heavy-attack support based on SpriteFrames content, then start
	# the cooldown at its full length so enemies cannot open the fight with
	# their ultimate on turn 1 — players need a window to set up.
	_detect_heavy_attack_support()
	if has_heavy_attack:
		start_heavy_attack_cooldown()

	# Create overhead labels (name + HP) and intent indicator.
	_create_overhead_labels()
	_create_intent_label()

	# Wire up click/hover detection.
	_connect_click_area()


# =============================================================================
# Intent Display
# =============================================================================

## Initialize the intent label with current intent.
func _create_intent_label() -> void:
	_update_intent_display()


## Set the enemy's current intent and update the visual.
func set_intent(intent: Intent, value: int = 0) -> void:
	current_intent = intent
	intent_value = value
	_update_intent_display()


## Update the intent label text based on current intent.
func _update_intent_display() -> void:
	if _intent_label == null:
		return

	match current_intent:
		Intent.NONE:
			_intent_label.text = ""
		Intent.ATTACK:
			_intent_label.text = "⚔ %d" % intent_value
		Intent.MOVE:
			_intent_label.text = "➤"
		Intent.DEFEND:
			_intent_label.text = "🛡 %d" % intent_value
		Intent.ABILITY:
			_intent_label.text = "★"
		Intent.SPAWN:
			_intent_label.text = "✦"
		Intent.BUFF:
			_intent_label.text = "↑"
		Intent.DEBUFF:
			_intent_label.text = "↓"
