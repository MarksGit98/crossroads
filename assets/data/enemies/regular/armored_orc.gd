## Armored Orc — enemy tank.
## Iron plates bolted to green skin. Slow but sturdy.
class_name EnemyData_ArmoredOrc
extends RefCounted


static func data() -> EnemyData:
	var enemy := EnemyData.new()

	# Identity
	enemy.id = "enemy_armored_orc"
	enemy.display_name = "Armored Orc"
	enemy.is_elite = false

	# Stats
	enemy.atk = 2
	enemy.hp = 6
	enemy.armor = 2
	enemy.move_range = 1
	enemy.move_pattern = CardTypes.MovePattern.STANDARD
	enemy.attack_range = 1
	enemy.attack_pattern = CardTypes.AttackPattern.MELEE
	enemy.damage_type = CardTypes.DamageType.PHYSICAL

	# Role & Keywords
	enemy.role = CardTypes.CreatureRole.TANK
	enemy.keywords = [CardTypes.Keyword.HEAVY]

	# Spawning
	enemy.can_spawn_enemies = false
	enemy.creature_scene_path = "res://scenes/creatures/enemy/regular/armored_orc.tscn"

	# Heavy attack — Shield Bash: melee hit that stuns.
	enemy.heavy_attack = {
		"id": "armored_orc_shield_bash",
		"name": "Shield Bash",
		"description": "Bashes a target with his shield for 4 damage, stunning them for 1 turn.",
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
				"value": 4,
			},
			{
				"type": CardTypes.EffectType.APPLY_STATUS,
				"target": CardTypes.EffectTarget.SELECTED,
				"status": CardTypes.StatusEffect.STUNNED,
				"duration": CardTypes.Duration.N_TURNS,
				"duration_turns": 1,
			},
		],
		"self_effects": [],
		"telegraph_turns": 0,
	}

	return enemy
