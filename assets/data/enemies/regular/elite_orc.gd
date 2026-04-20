## Elite Orc — enemy elite tank.
## Warchief of the orc warband. Commands lesser orcs.
class_name EnemyData_EliteOrc
extends RefCounted


static func data() -> EnemyData:
	var enemy := EnemyData.new()

	# Identity
	enemy.id = "enemy_elite_orc"
	enemy.display_name = "Elite Orc"
	enemy.is_elite = true

	# Stats
	enemy.atk = 4
	enemy.hp = 10
	enemy.armor = 3
	enemy.move_range = 1
	enemy.move_pattern = CardTypes.MovePattern.STANDARD
	enemy.attack_range = 1
	enemy.attack_pattern = CardTypes.AttackPattern.MELEE
	enemy.damage_type = CardTypes.DamageType.PHYSICAL

	# Role & Keywords
	enemy.role = CardTypes.CreatureRole.TANK
	enemy.keywords = [CardTypes.Keyword.TAUNT, CardTypes.Keyword.HEAVY, CardTypes.Keyword.BULWARK]

	# Spawning
	enemy.can_spawn_enemies = true
	enemy.creature_scene_path = "res://scenes/creatures/enemy/regular/elite_orc.tscn"

	# Heavy attack — Warchief's Cleave: damages the target and an adjacent ally.
	enemy.heavy_attack = {
		"id": "elite_orc_cleave",
		"name": "Warchief's Cleave",
		"description": "Sweeping cleave that deals 5 damage to the target and 3 damage to one adjacent enemy.",
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
				"type": CardTypes.EffectType.DEAL_DAMAGE,
				"target": CardTypes.EffectTarget.ALL_ENEMIES_IN_AREA,
				"damage_type": CardTypes.DamageType.PHYSICAL,
				"value": 3,
				"aoe_radius": 1,
				"max_targets": 1,
				"exclude_primary_target": true,
			},
		],
		"self_effects": [],
		"telegraph_turns": 0,
	}

	return enemy
