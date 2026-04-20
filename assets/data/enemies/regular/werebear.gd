## Werebear — enemy elite tank.
## A mountain of fur and rage. Will not stay down.
class_name EnemyData_Werebear
extends RefCounted


static func data() -> EnemyData:
	var enemy := EnemyData.new()

	# Identity
	enemy.id = "enemy_werebear"
	enemy.display_name = "Werebear"
	enemy.is_elite = true

	# Stats
	enemy.atk = 4
	enemy.hp = 12
	enemy.armor = 2
	enemy.move_range = 2
	enemy.move_pattern = CardTypes.MovePattern.STANDARD
	enemy.attack_range = 1
	enemy.attack_pattern = CardTypes.AttackPattern.CLEAVE
	enemy.damage_type = CardTypes.DamageType.PHYSICAL

	# Role & Keywords
	enemy.role = CardTypes.CreatureRole.TANK
	enemy.keywords = [CardTypes.Keyword.HEAVY, CardTypes.Keyword.REGENERATE, CardTypes.Keyword.UNDYING]

	# Spawning
	enemy.can_spawn_enemies = false
	enemy.creature_scene_path = "res://scenes/creatures/enemy/regular/werebear.tscn"

	# Heavy attack — Savage Maul: high damage + lifesteal via self-heal.
	enemy.heavy_attack = {
		"id": "werebear_savage_maul",
		"name": "Savage Maul",
		"description": "Rends a target for 6 damage and heals the Werebear for 3 HP.",
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
				"value": 6,
			},
			{
				"type": CardTypes.EffectType.APPLY_STATUS,
				"target": CardTypes.EffectTarget.SELECTED,
				"status": CardTypes.StatusEffect.BLEEDING,
				"duration": CardTypes.Duration.N_TURNS,
				"duration_turns": 2,
			},
		],
		"self_effects": [
			{
				"type": CardTypes.EffectType.HEAL,
				"target": CardTypes.EffectTarget.CASTER,
				"value": 3,
			},
		],
		"telegraph_turns": 0,
	}

	return enemy
