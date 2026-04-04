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
	enemy.creature_scene_path = "res://scenes/creatures/enemy/werebear.tscn"

	return enemy
