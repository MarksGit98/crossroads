## Greatsword Skeleton — enemy elite striker.
## A towering undead wielding a blade as tall as a man.
class_name EnemyData_GreatswordSkeleton
extends RefCounted


static func data() -> EnemyData:
	var enemy := EnemyData.new()

	# Identity
	enemy.id = "enemy_greatsword_skeleton"
	enemy.display_name = "Greatsword Skeleton"
	enemy.is_elite = true

	# Stats
	enemy.atk = 5
	enemy.hp = 8
	enemy.armor = 1
	enemy.move_range = 1
	enemy.move_pattern = CardTypes.MovePattern.STANDARD
	enemy.attack_range = 1
	enemy.attack_pattern = CardTypes.AttackPattern.CLEAVE
	enemy.damage_type = CardTypes.DamageType.PHYSICAL

	# Role & Keywords
	enemy.role = CardTypes.CreatureRole.STRIKER
	enemy.keywords = [CardTypes.Keyword.HEAVY, CardTypes.Keyword.REACH]

	# Spawning
	enemy.can_spawn_enemies = false
	enemy.creature_scene_path = "res://scenes/creatures/enemy/regular/greatsword_skeleton.tscn"

	# Heavy attack — Executioner's Swing: single massive hit at extended range.
	enemy.heavy_attack = {
		"id": "greatsword_skeleton_executioner_swing",
		"name": "Executioner's Swing",
		"description": "Two-handed overhead cleave that deals 8 damage to a target up to 2 hexes away.",
		"animation": &"heavy_attack",
		"cooldown": 3,
		"range": 2,
		"target_rule": CardTypes.TargetRule.ANY_ENEMY,
		"max_targets": 1,
		"effects": [
			{
				"type": CardTypes.EffectType.DEAL_DAMAGE,
				"target": CardTypes.EffectTarget.SELECTED,
				"damage_type": CardTypes.DamageType.PHYSICAL,
				"value": 8,
			},
		],
		"self_effects": [],
		"telegraph_turns": 0,
	}

	return enemy
