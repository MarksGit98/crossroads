## Orc Rider — enemy striker.
## Mounted and dangerous. Covers ground fast.
class_name EnemyData_OrcRider
extends RefCounted


static func data() -> EnemyData:
	var enemy := EnemyData.new()

	# Identity
	enemy.id = "enemy_orc_rider"
	enemy.display_name = "Orc Rider"
	enemy.is_elite = false

	# Stats
	enemy.atk = 3
	enemy.hp = 5
	enemy.armor = 1
	enemy.move_range = 3
	enemy.move_pattern = CardTypes.MovePattern.STANDARD
	enemy.attack_range = 1
	enemy.attack_pattern = CardTypes.AttackPattern.MELEE
	enemy.damage_type = CardTypes.DamageType.PHYSICAL

	# Role & Keywords
	enemy.role = CardTypes.CreatureRole.STRIKER
	enemy.keywords = [CardTypes.Keyword.SWIFT]

	# Spawning
	enemy.can_spawn_enemies = false
	enemy.creature_scene_path = "res://scenes/creatures/enemy/regular/orc_rider.tscn"

	# Heavy attack — Trampling Charge: high damage that inflicts bleeding.
	enemy.heavy_attack = {
		"id": "orc_rider_trampling_charge",
		"name": "Trampling Charge",
		"description": "Charges through a target dealing 5 damage and applying BLEEDING for 2 turns.",
		"animation": &"heavy_attack",
		"cooldown": 3,
		"range": 1,
		"target_rule": CardTypes.TargetRule.ANY_ENEMY,
		"max_targets": 1,
		"effects": [
			{
				"type": CardTypes.EffectType.DEAL_DAMAGE,
				"target": CardTypes.EffectTarget.SELECTED,
				"damage_type": CardTypes.DamageType.PHYSICAL,
				"value": 5,
			},
			{
				"type": CardTypes.EffectType.APPLY_STATUS,
				"target": CardTypes.EffectTarget.SELECTED,
				"status": CardTypes.StatusEffect.BLEEDING,
				"duration": CardTypes.Duration.N_TURNS,
				"duration_turns": 2,
			},
		],
		"self_effects": [],
		"telegraph_turns": 0,
	}

	return enemy
